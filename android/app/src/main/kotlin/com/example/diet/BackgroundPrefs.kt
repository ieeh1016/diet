package com.example.diet

import android.content.Context

object BackgroundPrefs {
    private const val prefsName = "FlutterSharedPreferences"
    private const val doublePrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    const val keyStatus = "background.session.status"
    const val keyStartedAt = "background.session.started_at"
    const val keyEndedAt = "background.session.ended_at"
    const val keySteps = "background.session.steps"
    const val keyDistanceMeters = "background.session.distance_meters"
    const val keyLastLatitude = "background.session.last_latitude"
    const val keyLastLongitude = "background.session.last_longitude"
    const val keyLastAccuracy = "background.session.last_accuracy"
    const val keyLastTimestamp = "background.session.last_timestamp"
    const val keyStepBaseline = "background.session.step_baseline"
    const val keyEvaluatedDateKey = "background.session.evaluated_date_key"
    const val keyIsScheduled = "background.is_scheduled"
    const val keyLastDegradedReason = "background.degraded_reason"
    const val keyHealthConnectStepsGranted = "health_connect.steps_granted"
    const val keyHealthConnectLastSuccessful = "health_connect.last_successful"
    const val keyHealthConnectLastCorrectedSteps = "health_connect.last_corrected_steps"
    const val keyHealthConnectMessage = "health_connect.message"

    const val keyMinimumSteps = "activity.minimum_steps"
    const val keyMinimumDistanceMeters = "activity.minimum_distance_meters"
    const val keyContactPhone = "activity.contact_phone"

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
}
