package com.example.diet

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object LunchActivityScheduler {
    const val actionStart = "com.example.diet.ACTION_LUNCH_ACTIVITY_START"
    const val actionEvaluate = "com.example.diet.ACTION_LUNCH_ACTIVITY_EVALUATE"
    const val actionCancel = "com.example.diet.ACTION_LUNCH_ACTIVITY_CANCEL"

    private const val requestStart = 1100
    private const val requestEvaluate = 1300

    fun scheduleNextWeekday(context: Context) {
        val (startMillis, endMillis) = nextWeekdayWindow()
        scheduleWindow(context, startMillis, endMillis)
    }

    fun isScheduleEnabled(context: Context): Boolean {
        return BackgroundPrefs.prefs(context).getBoolean(
            BackgroundPrefs.flutterKey(BackgroundPrefs.keyIsScheduled),
            false
        )
    }

    fun scheduleWindow(context: Context, startMillis: Long, endMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        schedule(alarmManager, context, actionStart, requestStart, startMillis)
        schedule(alarmManager, context, actionEvaluate, requestEvaluate, endMillis)
        BackgroundPrefs.prefs(context)
            .edit()
            .putBoolean(BackgroundPrefs.flutterKey(BackgroundPrefs.keyIsScheduled), true)
            .apply()
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context, actionStart, requestStart))
        alarmManager.cancel(pendingIntent(context, actionEvaluate, requestEvaluate))
        BackgroundPrefs.prefs(context)
            .edit()
            .putBoolean(BackgroundPrefs.flutterKey(BackgroundPrefs.keyIsScheduled), false)
            .apply()
    }

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun schedule(
        alarmManager: AlarmManager,
        context: Context,
        action: String,
        requestCode: Int,
        triggerAtMillis: Long
    ) {
        val operation = pendingIntent(context, action, requestCode)
        if (canScheduleExact(context)) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
            }
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
            BackgroundPrefs.prefs(context)
                .edit()
                .putString(
                    BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastDegradedReason),
                    "정확 알람 권한이 없어 13시 평가가 지연될 수 있어요."
                )
                .apply()
        }
    }

    private fun pendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, LunchActivityAlarmReceiver::class.java)
            .setAction(action)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun nextWeekdayWindow(): Pair<Long, Long> {
        val calendar = Calendar.getInstance()
        if (calendar.get(Calendar.HOUR_OF_DAY) >= 13) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }
        while (calendar.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY ||
            calendar.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY
        ) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }
        calendar.set(Calendar.HOUR_OF_DAY, 11)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val start = calendar.timeInMillis
        calendar.set(Calendar.HOUR_OF_DAY, 13)
        val end = calendar.timeInMillis
        return start to end
    }
}
