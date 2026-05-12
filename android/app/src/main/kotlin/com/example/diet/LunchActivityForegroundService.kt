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
import kotlin.math.min
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

class LunchActivityForegroundService : Service(), LocationListener, SensorEventListener {
    private val serviceNotificationId = 1101
    private val alertNotificationId = 1300
    private val serviceChannelId = "lunch_activity_service"
    private val alertChannelId = "diet_project_alerts"
    private val maxReliableLocationAccuracyMeters = 50f
    private val minimumDistanceMetersPerWindow = 10.0
    private val minimumWalkingSpeedMetersPerSecond = 0.3
    private val maximumWalkingSpeedMetersPerSecond = 3.0

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
                finishService(scheduleNext = false)
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
            .also { BackgroundPrefs.putDouble(it, BackgroundPrefs.keyElevationGainMeters, 0.0) }
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastLatitude))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastLongitude))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastAccuracy))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastTimestamp))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStepBaseline))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLatestStepCounter))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyBaselineAltitudeMeters))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyBaselineAltitudeSumMeters))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyBaselineAltitudeSampleCount))
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
        val elevationGainMeters = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyElevationGainMeters)
        val minimumSteps = BackgroundPrefs.getInt(this, BackgroundPrefs.keyMinimumSteps, 2000)
        val minimumDistanceMeters = BackgroundPrefs.getDouble(
            this,
            BackgroundPrefs.keyMinimumDistanceMeters,
            1000.0
        )
        val minimumElevationGainMeters = BackgroundPrefs.getDouble(
            this,
            BackgroundPrefs.keyMinimumElevationGainMeters,
            50.0
        )
        val now = System.currentTimeMillis()
        val todayKey = dateKey(now)
        val alreadyEvaluatedToday = prefs.getString(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyEvaluatedDateKey),
            null
        ) == todayKey

        if (alreadyEvaluatedToday) {
            finishAlreadyEvaluated(
                prefs = prefs,
                steps = sensorSteps,
                distanceMeters = distanceMeters,
                elevationGainMeters = elevationGainMeters,
                minimumSteps = minimumSteps,
                minimumDistanceMeters = minimumDistanceMeters,
                minimumElevationGainMeters = minimumElevationGainMeters,
                now = now,
                todayKey = todayKey
            )
            return
        }

        serviceScope.launch {
            try {
                val window = todayWindow(now)
                val stepReadResult = withContext(Dispatchers.IO) {
                    withTimeoutOrNull(10_000L) {
                        HealthConnectSteps.readStepsAggregate(
                            this@LunchActivityForegroundService,
                            window.first,
                            window.second
                        )
                    }
                } ?: HealthConnectStepReadResult(
                    steps = null,
                    successful = false,
                    message = "Health Connect 걸음수 보정 시간이 초과되어 센서 기록으로 평가했어요."
                )
                HealthConnectSteps.saveReadResult(this@LunchActivityForegroundService, stepReadResult)
                val correctedSteps = mergeStepCount(sensorSteps, stepReadResult.steps)
                finishEvaluation(
                    prefs = prefs,
                    steps = correctedSteps,
                    distanceMeters = distanceMeters,
                    elevationGainMeters = elevationGainMeters,
                    minimumSteps = minimumSteps,
                    minimumDistanceMeters = minimumDistanceMeters,
                    minimumElevationGainMeters = minimumElevationGainMeters,
                    now = now,
                    todayKey = todayKey
                )
            } catch (error: Exception) {
                saveDegradedReason("활동 평가에 실패해 센서 기록으로 평가했어요: ${error.message}")
                finishEvaluation(
                    prefs = prefs,
                    steps = sensorSteps,
                    distanceMeters = distanceMeters,
                    elevationGainMeters = elevationGainMeters,
                    minimumSteps = minimumSteps,
                    minimumDistanceMeters = minimumDistanceMeters,
                    minimumElevationGainMeters = minimumElevationGainMeters,
                    now = now,
                    todayKey = todayKey
                )
            }
        }
    }

    private fun finishAlreadyEvaluated(
        prefs: android.content.SharedPreferences,
        steps: Int,
        distanceMeters: Double,
        elevationGainMeters: Double,
        minimumSteps: Int,
        minimumDistanceMeters: Double,
        minimumElevationGainMeters: Double,
        now: Long,
        todayKey: String
    ) {
        val requiresAlert =
            steps <= minimumSteps ||
                distanceMeters <= minimumDistanceMeters ||
                elevationGainMeters <= minimumElevationGainMeters
        prefs.edit()
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStatus), "evaluated")
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyEndedAt), Instant.ofEpochMilli(now).toString())
            .also { BackgroundPrefs.putInt(it, BackgroundPrefs.keySteps, steps) }
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStepBaseline))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLatestStepCounter))
            .apply()

        val alertAlreadyAttempted = prefs.getString(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyAlertAttemptedDateKey),
            null
        ) == todayKey
        if (requiresAlert && !alertAlreadyAttempted) {
            val message = buildAlertMessage(
                steps = steps,
                distanceMeters = distanceMeters,
                elevationGainMeters = elevationGainMeters,
                minimumSteps = minimumSteps,
                minimumDistanceMeters = minimumDistanceMeters,
                minimumElevationGainMeters = minimumElevationGainMeters
            )
            showDietProjectAlert(message)
            sendSmsIfPossible(message, todayKey)
        }

        finishService()
    }

    private fun finishEvaluation(
        prefs: android.content.SharedPreferences,
        steps: Int,
        distanceMeters: Double,
        elevationGainMeters: Double,
        minimumSteps: Int,
        minimumDistanceMeters: Double,
        minimumElevationGainMeters: Double,
        now: Long,
        todayKey: String
    ) {
        val requiresAlert =
            steps <= minimumSteps ||
                distanceMeters <= minimumDistanceMeters ||
                elevationGainMeters <= minimumElevationGainMeters

        prefs.edit()
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStatus), "evaluated")
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyEndedAt), Instant.ofEpochMilli(now).toString())
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyEvaluatedDateKey), todayKey)
            .also { BackgroundPrefs.putInt(it, BackgroundPrefs.keySteps, steps) }
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStepBaseline))
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLatestStepCounter))
            .apply()

        if (requiresAlert) {
            val message = buildAlertMessage(
                steps = steps,
                distanceMeters = distanceMeters,
                elevationGainMeters = elevationGainMeters,
                minimumSteps = minimumSteps,
                minimumDistanceMeters = minimumDistanceMeters,
                minimumElevationGainMeters = minimumElevationGainMeters
            )
            showDietProjectAlert(message)
            sendSmsIfPossible(message, todayKey)
        }

        finishService()
    }

    override fun onLocationChanged(location: Location) {
        if (location.accuracy <= 0 || location.accuracy > maxReliableLocationAccuracyMeters) {
            advanceStepCheckpoint()
            return
        }

        val prefs = BackgroundPrefs.prefs(this)
        val lastLatitude = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyLastLatitude, Double.NaN)
        val lastLongitude = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyLastLongitude, Double.NaN)
        val lastAccuracy = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyLastAccuracy, Double.NaN)
        val latestStepCounter = BackgroundPrefs.getInt(this, BackgroundPrefs.keyLatestStepCounter, -1)
        val stepBaseline = BackgroundPrefs.getInt(this, BackgroundPrefs.keyStepBaseline, -1)
        val currentLocationTime = locationTimeMillis(location)
        val editor = prefs.edit()
        applyElevationSample(location, currentLocationTime, editor)

        if (!lastLatitude.isNaN() && !lastLongitude.isNaN() && !lastAccuracy.isNaN()) {
            val last = Location(location.provider).apply {
                latitude = lastLatitude
                longitude = lastLongitude
                accuracy = lastAccuracy.toFloat()
            }
            val lastLocationTime = lastLocationTimeMillis()
            val addedMeters = location.distanceTo(last).toDouble()
            val accepted = isWalkingSampleAccepted(
                distanceMeters = addedMeters,
                elapsedMillis = currentLocationTime - lastLocationTime
            )
            if (accepted) {
                val current = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyDistanceMeters)
                BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyDistanceMeters, current + addedMeters)
                if (latestStepCounter >= 0 && stepBaseline >= 0) {
                    val currentSteps = BackgroundPrefs.getInt(this, BackgroundPrefs.keySteps)
                    BackgroundPrefs.putInt(
                        editor,
                        BackgroundPrefs.keySteps,
                        currentSteps + max(0, latestStepCounter - stepBaseline)
                    )
                }
            }
        }

        BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyLastLatitude, location.latitude)
        BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyLastLongitude, location.longitude)
        BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyLastAccuracy, location.accuracy.toDouble())
        if (latestStepCounter >= 0) {
            BackgroundPrefs.putInt(editor, BackgroundPrefs.keyStepBaseline, latestStepCounter)
        }
        editor.putString(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastTimestamp),
            Instant.ofEpochMilli(currentLocationTime).toString()
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
            .also { BackgroundPrefs.putInt(it, BackgroundPrefs.keyLatestStepCounter, cumulativeSteps) }
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
                manager.requestLocationUpdates(provider, 30_000L, 0f, this)
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

    private fun isWalkingSampleAccepted(distanceMeters: Double, elapsedMillis: Long): Boolean {
        val elapsedSeconds = elapsedMillis / 1000.0
        if (elapsedSeconds <= 0) return false
        val minimumDistance = max(
            minimumDistanceMetersPerWindow,
            minimumWalkingSpeedMetersPerSecond * elapsedSeconds
        )
        val maximumDistance = maximumWalkingSpeedMetersPerSecond * elapsedSeconds
        return distanceMeters > minimumDistance && distanceMeters < maximumDistance
    }

    private fun mergeStepCount(gatedSensorSteps: Int, healthConnectSteps: Int?): Int {
        if (healthConnectSteps == null) return gatedSensorSteps
        if (gatedSensorSteps <= 0) return 0
        return min(gatedSensorSteps, healthConnectSteps)
    }

    private fun applyElevationSample(
        location: Location,
        currentLocationTime: Long,
        editor: android.content.SharedPreferences.Editor
    ) {
        if (!isReliableAltitude(location)) return
        val startedAt = startedAtMillis() ?: return
        val altitude = location.altitude
        val baselineEnd = startedAt + 30L * 60L * 1000L
        if (currentLocationTime < baselineEnd) {
            val sum = BackgroundPrefs.getDouble(
                this,
                BackgroundPrefs.keyBaselineAltitudeSumMeters,
                0.0
            ) + altitude
            val count = BackgroundPrefs.getInt(
                this,
                BackgroundPrefs.keyBaselineAltitudeSampleCount,
                0
            ) + 1
            val baseline = sum / count
            BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyBaselineAltitudeSumMeters, sum)
            BackgroundPrefs.putInt(editor, BackgroundPrefs.keyBaselineAltitudeSampleCount, count)
            BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyBaselineAltitudeMeters, baseline)
            return
        }

        var baseline = BackgroundPrefs.getDouble(
            this,
            BackgroundPrefs.keyBaselineAltitudeMeters,
            Double.NaN
        )
        if (baseline.isNaN()) {
            val count = BackgroundPrefs.getInt(
                this,
                BackgroundPrefs.keyBaselineAltitudeSampleCount,
                0
            )
            baseline = if (count > 0) {
                BackgroundPrefs.getDouble(
                    this,
                    BackgroundPrefs.keyBaselineAltitudeSumMeters,
                    altitude
                ) / count
            } else {
                altitude
            }
            BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyBaselineAltitudeMeters, baseline)
        }

        val currentGain = BackgroundPrefs.getDouble(this, BackgroundPrefs.keyElevationGainMeters)
        val elevationGain = max(currentGain, max(0.0, altitude - baseline))
        BackgroundPrefs.putDouble(editor, BackgroundPrefs.keyElevationGainMeters, elevationGain)
    }

    private fun isReliableAltitude(location: Location): Boolean {
        if (!location.hasAltitude()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            location.hasVerticalAccuracy() &&
            location.verticalAccuracyMeters > 30f
        ) {
            return false
        }
        return true
    }

    private fun advanceStepCheckpoint() {
        val latestStepCounter = BackgroundPrefs.getInt(this, BackgroundPrefs.keyLatestStepCounter, -1)
        if (latestStepCounter < 0) return
        BackgroundPrefs.prefs(this)
            .edit()
            .also { BackgroundPrefs.putInt(it, BackgroundPrefs.keyStepBaseline, latestStepCounter) }
            .apply()
    }

    private fun locationTimeMillis(location: Location): Long {
        return if (location.time > 0) location.time else System.currentTimeMillis()
    }

    private fun lastLocationTimeMillis(): Long {
        val value = BackgroundPrefs.prefs(this)
            .getString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastTimestamp), null)
            ?: return System.currentTimeMillis()
        return try {
            Instant.parse(value).toEpochMilli()
        } catch (_: Exception) {
            System.currentTimeMillis()
        }
    }

    private fun startedAtMillis(): Long? {
        val value = BackgroundPrefs.prefs(this)
            .getString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStartedAt), null)
            ?: return null
        return try {
            Instant.parse(value).toEpochMilli()
        } catch (_: Exception) {
            null
        }
    }

    private fun buildAlertMessage(
        steps: Int,
        distanceMeters: Double,
        elevationGainMeters: Double,
        minimumSteps: Int,
        minimumDistanceMeters: Double,
        minimumElevationGainMeters: Double
    ): String {
        val contactName = BackgroundPrefs.getString(
            this,
            BackgroundPrefs.keyContactName,
            "보호자"
        )
        val template = BackgroundPrefs.getString(
            this,
            BackgroundPrefs.keyAlertMessageTemplate,
            BackgroundPrefs.defaultAlertMessageTemplate
        )
        val resolvedTemplate =
            if (template == BackgroundPrefs.legacyDefaultAlertMessageTemplate) {
                BackgroundPrefs.defaultAlertMessageTemplate
            } else {
                template
            }
        return resolvedTemplate
            .replace("{appName}", BackgroundPrefs.appName)
            .replace("{steps}", steps.toString())
            .replace("{minimumSteps}", minimumSteps.toString())
            .replace("{distanceKm}", "%.2f".format(distanceMeters / 1000.0))
            .replace("{minimumDistanceKm}", "%.1f".format(minimumDistanceMeters / 1000.0))
            .replace("{elevationGainMeters}", "%.0f".format(elevationGainMeters))
            .replace("{minimumElevationGainMeters}", "%.0f".format(minimumElevationGainMeters))
            .replace("{contactName}", contactName)
    }

    private fun showDietProjectAlert(message: String) {
        val notification = NotificationCompat.Builder(this, alertChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("다이어트 프로젝트 알림")
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

    private fun sendSmsIfPossible(message: String, todayKey: String) {
        if (checkSelfPermissionCompat(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            recordSmsFailure(
                phone = "",
                todayKey = todayKey,
                reason = "문자 권한이 없어 보호자 문자를 보내지 못했어요."
            )
            return
        }
        val phone = BackgroundPrefs.prefs(this)
            .getString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyContactPhone), null)
            ?.takeIf { it.isNotBlank() }
        if (phone == null) {
            recordSmsFailure(
                phone = "",
                todayKey = todayKey,
                reason = "보호자 전화번호가 없어 문자를 보내지 못했어요."
            )
            return
        }

        BackgroundPrefs.prefs(this)
            .edit()
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyAlertAttemptedDateKey), todayKey)
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastStatus), "requested")
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastPhone), phone)
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastDateKey), todayKey)
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastAttemptedAt), Instant.now().toString())
            .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastError))
            .apply()

        try {
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            val sentIntents = ArrayList<PendingIntent>(parts.size)
            val requestCodeBase = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
            for (index in parts.indices) {
                sentIntents.add(smsSentPendingIntent(phone, todayKey, requestCodeBase + index))
            }
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, sentIntents.first(), null)
            }
        } catch (error: Exception) {
            recordSmsFailure(
                phone = phone,
                todayKey = todayKey,
                reason = "문자 전송 요청에 실패했어요: ${error.message}"
            )
        }
    }

    private fun recordSmsFailure(phone: String, todayKey: String, reason: String) {
        BackgroundPrefs.prefs(this)
            .edit()
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyAlertAttemptedDateKey), todayKey)
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastStatus), "failed")
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastPhone), phone)
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastDateKey), todayKey)
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastAttemptedAt), Instant.now().toString())
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastError), reason)
            .putString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastDegradedReason), reason)
            .apply()
    }

    private fun smsSentPendingIntent(phone: String, todayKey: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, SmsSentReceiver::class.java)
            .setAction(SmsSentReceiver.actionSmsSent)
            .putExtra(SmsSentReceiver.extraPhone, phone)
            .putExtra(SmsSentReceiver.extraDateKey, todayKey)
        return PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildServiceNotification(): Notification {
        return buildServiceNotification("13시까지 점심시간 걸음수와 GPS를 기록하고 있어요.")
    }

    private fun buildServiceNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, serviceChannelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("다이어트 프로젝트가 측정 중이에요")
            .setContentText(contentText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(appPendingIntent())
            .build()
    }

    private fun finishService(scheduleNext: Boolean = true) {
        if (scheduleNext) {
            LunchActivityScheduler.scheduleNextWeekday(this)
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(serviceNotificationId)
        stopSelf()
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
                "다이어트 프로젝트 알림",
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
