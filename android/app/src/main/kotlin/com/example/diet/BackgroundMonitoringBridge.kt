package com.example.diet

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BackgroundMonitoringBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "currentStatus" -> result.success(statusMap())
            "scheduleWeekdayMonitoring" -> {
                val start = call.argument<Number>("startMillis")?.toLong()
                val end = call.argument<Number>("endMillis")?.toLong()
                if (start == null || end == null) {
                    result.error("invalid_window", "시작 시간과 종료 시간이 필요해요.", null)
                    return
                }
                LunchActivityScheduler.scheduleWindow(context, start, end)
                result.success(statusMap())
            }
            "startWindow" -> {
                startService(LunchActivityScheduler.actionStart)
                result.success(statusMap())
            }
            "stopAndEvaluate" -> {
                val nativeEvaluate = call.argument<Boolean>("nativeEvaluate") ?: false
                if (nativeEvaluate) {
                    startService(LunchActivityScheduler.actionEvaluate)
                }
                result.success(statusMap())
            }
            "openExactAlarmSettings" -> result.success(openExactAlarmSettings())
            "cancelSchedule" -> {
                LunchActivityScheduler.cancel(context)
                context.stopService(
                    Intent(context, LunchActivityForegroundService::class.java)
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startService(action: String) {
        val intent = Intent(context, LunchActivityForegroundService::class.java).setAction(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun statusMap(): Map<String, Any?> {
        val prefs = BackgroundPrefs.prefs(context)
        val status = prefs.getString(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyStatus),
            "idle"
        )
        val exactAvailable = LunchActivityScheduler.canScheduleExact(context)
        val degraded = prefs.getString(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastDegradedReason),
            null
        ) ?: if (exactAvailable) null else "정확 알람 권한이 없어 13시 평가가 지연될 수 있어요."

        return mapOf(
            "nativeAvailable" to true,
            "isScheduled" to prefs.getBoolean(
                BackgroundPrefs.flutterKey(BackgroundPrefs.keyIsScheduled),
                false
            ),
            "isRunning" to (status == "active"),
            "exactAlarmAvailable" to exactAvailable,
            "locationAlwaysGranted" to hasBackgroundLocation(),
            "degradedReason" to degraded,
            "sessionStatus" to status,
            "startedAtMillis" to parseIsoMillis(
                prefs.getString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyStartedAt), null)
            ),
            "endedAtMillis" to parseIsoMillis(
                prefs.getString(BackgroundPrefs.flutterKey(BackgroundPrefs.keyEndedAt), null)
            ),
            "steps" to BackgroundPrefs.getInt(context, BackgroundPrefs.keySteps),
            "distanceMeters" to BackgroundPrefs.getDouble(context, BackgroundPrefs.keyDistanceMeters)
        )
    }

    private fun parseIsoMillis(value: String?): Long? {
        return try {
            if (value == null) null else java.time.Instant.parse(value).toEpochMilli()
        } catch (_: Exception) {
            null
        }
    }

    private fun hasBackgroundLocation(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        val intent = Intent(
            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
            Uri.parse("package:${context.packageName}")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
