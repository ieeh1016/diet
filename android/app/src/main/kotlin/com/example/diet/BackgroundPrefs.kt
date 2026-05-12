package com.example.diet

import android.content.Context

object BackgroundPrefs {
    private const val prefsName = "FlutterSharedPreferences"
    private const val doublePrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"
    const val appName = "다이어트 프로젝트"
    const val defaultAlertMessageTemplate =
        "{appName} 알림: 평일 11:00-13:00 점심 활동이 최소 활동 목표보다 낮아요. " +
            "걸음수 {steps}/{minimumSteps}, 이동거리 {distanceKm}km/{minimumDistanceKm}km, " +
            "획득고도 {elevationGainMeters}m/{minimumElevationGainMeters}m입니다. 확인해 주세요."
    const val legacyDefaultAlertMessageTemplate =
        "{appName} 알림: 평일 11:00-13:00 점심 활동이 최소 활동 목표보다 낮아요. " +
            "걸음수 {steps}/{minimumSteps}, 이동거리 {distanceKm}km/{minimumDistanceKm}km입니다. 확인해 주세요."

    const val keyStatus = "background.session.status"
    const val keyStartedAt = "background.session.started_at"
    const val keyEndedAt = "background.session.ended_at"
    const val keySteps = "background.session.steps"
    const val keyDistanceMeters = "background.session.distance_meters"
    const val keyElevationGainMeters = "background.session.elevation_gain_meters"
    const val keyBaselineAltitudeMeters = "background.session.baseline_altitude_meters"
    const val keyBaselineAltitudeSumMeters = "background.session.baseline_altitude_sum_meters"
    const val keyBaselineAltitudeSampleCount = "background.session.baseline_altitude_sample_count"
    const val keyLastLatitude = "background.session.last_latitude"
    const val keyLastLongitude = "background.session.last_longitude"
    const val keyLastAccuracy = "background.session.last_accuracy"
    const val keyLastTimestamp = "background.session.last_timestamp"
    const val keyStepBaseline = "background.session.step_baseline"
    const val keyLatestStepCounter = "background.session.latest_step_counter"
    const val keyEvaluatedDateKey = "background.session.evaluated_date_key"
    const val keyIsScheduled = "background.is_scheduled"
    const val keyLastDegradedReason = "background.degraded_reason"
    const val keyHealthConnectStepsGranted = "health_connect.steps_granted"
    const val keyHealthConnectLastSuccessful = "health_connect.last_successful"
    const val keyHealthConnectLastCorrectedSteps = "health_connect.last_corrected_steps"
    const val keyHealthConnectMessage = "health_connect.message"
    const val keyAlertAttemptedDateKey = "alert.attempted_date_key"
    const val keySmsLastStatus = "sms.last_status"
    const val keySmsLastError = "sms.last_error"
    const val keySmsLastAttemptedAt = "sms.last_attempted_at"
    const val keySmsLastSentAt = "sms.last_sent_at"
    const val keySmsLastPhone = "sms.last_phone"
    const val keySmsLastDateKey = "sms.last_date_key"

    const val keyMinimumSteps = "activity.minimum_steps"
    const val keyMinimumDistanceMeters = "activity.minimum_distance_meters"
    const val keyMinimumElevationGainMeters = "activity.minimum_elevation_gain_meters"
    const val keyContactName = "activity.contact_name"
    const val keyContactPhone = "activity.contact_phone"
    const val keyAlertMessageTemplate = "activity.alert_message_template"

    fun prefs(context: Context) = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    fun flutterKey(key: String) = "flutter.$key"

    fun putDouble(editor: android.content.SharedPreferences.Editor, key: String, value: Double) {
        editor.putString(flutterKey(key), doublePrefix + value.toString())
    }

    fun putInt(editor: android.content.SharedPreferences.Editor, key: String, value: Int) {
        editor.putLong(flutterKey(key), value.toLong())
    }

    fun getInt(context: Context, key: String, defaultValue: Int = 0): Int {
        val value = prefs(context).all[flutterKey(key)] ?: return defaultValue
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: defaultValue
            else -> defaultValue
        }
    }

    fun getDouble(context: Context, key: String, defaultValue: Double = 0.0): Double {
        val raw = prefs(context).getString(flutterKey(key), null) ?: return defaultValue
        return if (raw.startsWith(doublePrefix)) {
            raw.removePrefix(doublePrefix).toDoubleOrNull() ?: defaultValue
        } else {
            raw.toDoubleOrNull() ?: defaultValue
        }
    }

    fun getString(context: Context, key: String, defaultValue: String = ""): String {
        return prefs(context).getString(flutterKey(key), null)?.takeIf { it.isNotBlank() }
            ?: defaultValue
    }
}
