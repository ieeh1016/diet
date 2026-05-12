package com.example.diet

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.telephony.SmsManager
import androidx.core.app.NotificationCompat
import java.time.Instant
import java.util.Calendar
import kotlin.math.max
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LunchActivityForegroundService : Service(), LocationListener, SensorEventListener {
    private val serviceNotificationId = 1101
    private val alertNotificationId = 1300
    private val serviceChannelId = "lunch_activity_service"
    private val alertChannelId = "activity_safety_alerts"

    private var locationManager: LocationManager? = null
    private var sensorManager: SensorManager? = null
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            LunchActivityScheduler.actionStart -> startMonitoring()
            LunchActivityScheduler.actionEvaluate -> evaluateAndStop()
            LunchActivityScheduler.actionCancel -> {
                stopMonitoringSensors()
                stopSelf()
            }
            else -> startMonitoring()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        serviceScope.cancel()
        stopMonitoringSensors()
        super.onDestroy()
    }

    private fun startMonitoring() {
        startForeground(serviceNotificationId, buildServiceNotification())

        val now = System.currentTimeMillis()
        val prefs = BackgroundPrefs.prefs(this)
        prefs.edit()
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStatus), "active")
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStartedAt), Instant.ofEpochMilli(now).toString())
            .also { BackgroundPrefs.putInt(it, BackgroundPrefs.keySteps, 0) }
            .also { BackgroundPrefs.putDouble(it, BackgroundPrefs.keyDistanceMeters, 0.0) }
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastLatitude))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastLongitude))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastAccuracy))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastTimestamp))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStepBaseline))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastDegradedReason))
            .apply()

        startStepCounter()
        startLocationUpdates()
    }

    private fun evaluateAndStop() {
        startForeground(serviceNotificationId, buildServiceNotification("활동을 평가하고 있어요."))
        stopMonitoringSensors()

        val prefs = BackgroundPrefs.prefs(this)
        val sensorSteps = BackgroundPrefs.getInt(this, BackgroundPrefs.keySteps)
        val distanceMeters = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyDistanceMeters)
        val minimumSteps = BackgroundPrefs.getInt(this, BackgroundPrefs.keyMinimumSteps, 2000)
        val minimumDistanceMeters = BackgroundPrefs.getDouble(
            this,
            BackgroundPrefs.keyMinimumDistanceMeters,
            1000.0
        )
        val now = System.currentTimeMillis()
        val todayKey = dateKey(now)
        val alreadyEvaluatedToday = prefs.getString(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyEvaluatedDateKey),
            null
        ) == todayKey

        if (alreadyEvaluatedToday) {
            stopMonitoringSensors()
            LunchActivityScheduler.scheduleNextWeekday(this)
            stopForeground(STOP_FOREGROUND_DETACH)
            stopSelf()
            return
        }

        serviceScope.launch {
            val window = todayWindow(now)
            val stepReadResult = withContext(Dispatchers.IO) {
                HealthConnectSteps.readStepsAggregate(
                    this@LunchActivityForegroundService,
                    window.first,
                    window.second
                )
            }
            HealthConnectSteps.saveReadResult(this@LunchActivityForegroundService, stepReadResult)
            val correctedSteps = stepReadResult.steps ?: sensorSteps
            finishEvaluation(
                prefs = prefs,
                steps = correctedSteps,
                distanceMeters = distanceMeters,
                minimumSteps = minimumSteps,
                minimumDistanceMeters = minimumDistanceMeters,
                now = now,
                todayKey = todayKey
            )
        }
    }

    private fun finishEvaluation(
        prefs: android.content.SharedPreferences,
        steps: Int,
        distanceMeters: Double,
        minimumSteps: Int,
        minimumDistanceMeters: Double,
        now: Long,
        todayKey: String
    ) {
        val requiresAlert = steps <= minimumSteps || distanceMeters <= minimumDistanceMeters

        prefs.edit()
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStatus), "evaluated")
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyEndedAt), Instant.ofEpochMilli(now).toString())
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyEvaluatedDateKey), todayKey)
            .also { BackgroundPrefs.putInt(it, BackgroundPrefs.keySteps, steps) }
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStepBaseline))
            .apply()

        if (requiresAlert) {
            val message = "활동 안전 알림: 평일 11:00-13:00 활동이 점심 시간 최소 활동 목표보다 낮아요. " +
                "걸음수 $steps/$minimumSteps, 이동거리 ${"%.2f".format(distanceMeters / 1000.0)}km/${"%.1f".format(minimumDistanceMeters / 1000.0)}km입니다. 확인해 주세요."
            showSafetyAlert(message)
            sendSmsIfPossible(message)
        }

        LunchActivityScheduler.scheduleNextWeekday(this)
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf()
    }

    override fun onLocationChanged(location: Location) {
        if (location.accuracy <= 0 || location.accuracy > 65) return

        val prefs = BackgroundPrefs.prefs(this)
        val lastLatitude = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyLastLatitude, Double.NaN)
        val lastLongitude = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyLastLongitude, Double.NaN)
        val lastAccuracy = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyLastAccuracy, Double.NaN)
        val editor = prefs.edit()

        if (!lastLatitude.isNaN() && !lastLongitude.isNaN() && !lastAccuracy.isNaN()) {
            val last = Location(location.provider).apply {
                latitude = lastLatitude
                longitude = lastLongitude
                accuracy = lastAccuracy.toFloat()
            }
            val addedMeters = location.distanceTo(last).toDouble()
            if (addedMeters >= 5) {
                val current = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyDistanceMeters)
                BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyDistanceMeters, current + addedMeters)
            }
        }

        BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyLastLatitude, location.latitude)
        BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyLastLongitude, location.longitude)
        BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyLastAccuracy, location.accuracy.toDouble())
        editor.putString(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastTimestamp),
            Instant.ofEpochMilli(location.time).toString()
        )
        editor.apply()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        val cumulativeSteps = event.values.firstOrNull()?.toInt() ?: return
        val prefs = BackgroundPrefs.prefs(this)
        var baseline = BackgroundPrefs.getInt(this, BackgroundPrefs.keyStepBaseline, -1)
        if (baseline < 0) {
            baseline = cumulativeSteps
            prefs.edit().also { BackgroundPrefs.putInt(it, BackgroundPrefs.keyStepBaseline, baseline) }.apply()
        }
        prefs.edit()
            .also { BackgroundPrefs.putInt(it, BackgroundPrefs.keySteps, max(0, cumulativeSteps - baseline)) }
            .apply()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onProviderEnabled(provider: String) = Unit

    override fun onProviderDisabled(provider: String) = Unit

    @Deprecated("Deprecated in Android SDK")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    private fun startLocationUpdates() {
        if (checkSelfPermissionCompat(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermissionCompat(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            saveDegradedReason("위치 권한이 없어 백그라운드에서 GPS 이동거리를 기록할 수 없어요.")
            return
        }

        val manager = locationManager ?: return
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        for (provider in providers) {
            if (manager.isProviderEnabled(provider)) {
                manager.requestLocationUpdates(provider, 30_000L, 10f, this)
            }
        }
    }

    private fun startStepCounter() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermissionCompat(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            saveDegradedReason("신체 활동 권한이 없어 백그라운드 걸음수 기록이 제한돼요.")
            return
        }

        val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            saveDegradedReason("이 기기에서는 걸음수 센서를 사용할 수 없어요.")
            return
        }
        sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    private fun stopMonitoringSensors() {
        locationManager?.removeUpdates(this)
        sensorManager?.unregisterListener(this)
    }

    private fun showSafetyAlert(message: String) {
        val notification = NotificationCompat.Builder(this, alertChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("활동 안전 알림")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(appPendingIntent())
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(alertNotificationId, notification)
    }

    private fun sendSmsIfPossible(message: String) {
        if (checkSelfPermissionCompat(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            saveDegradedReason("문자 권한이 없어 긴급 문자를 보내지 못했어요.")
            return
        }
        val phone = BackgroundPrefs.prefs(this)
            .getString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyContactPhone), null)
            ?.takeIf { it.isNotBlank() }
            ?: return
        try {
            SmsManager.getDefault().sendTextMessage(phone, null, message, null, null)
        } catch (error: Exception) {
            saveDegradedReason("문자 전송에 실패했어요: ${error.message}")
        }
    }

    private fun buildServiceNotification(): Notification {
        return buildServiceNotification("13시까지 점심시간 걸음수와 GPS를 기록하고 있어요.")
    }

    private fun buildServiceNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, serviceChannelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("활동 안전이 측정 중이에요")
            .setContentText(contentText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(appPendingIntent())
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(
            NotificationChannel(
                serviceChannelId,
                "점심 활동 측정",
                NotificationManager.IMPORTANCE_LOW
            )
        )
        notificationManager.createNotificationChannel(
            NotificationChannel(
                alertChannelId,
                "활동 안전 알림",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "점심시간 활동이 최소 활동 목표보다 낮을 때 보내는 높은 우선순위 알림입니다."
                enableVibration(true)
            }
        )
    }

    private fun appPendingIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun checkSelfPermissionCompat(permission: String): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(permission)
        } else {
            PackageManager.PERMISSION_GRANTED
        }
    }

    private fun saveDegradedReason(reason: String) {
        BackgroundPrefs.prefs(this)
            .edit()
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastDegradedReason), reason)
            .apply()
    }

    private fun dateKey(millis: Long): String {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        return "${calendar.get(Calendar.YEAR)}-${calendar.get(Calendar.MONTH) + 1}-${calendar.get(Calendar.DAY_OF_MONTH)}"
    }

    private fun todayWindow(millis: Long): Pair<Long, Long> {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        calendar.set(Calendar.HOUR_OF_DAY, 11)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val start = calendar.timeInMillis
        calendar.set(Calendar.HOUR_OF_DAY, 13)
        return start to calendar.timeInMillis
    }
}
