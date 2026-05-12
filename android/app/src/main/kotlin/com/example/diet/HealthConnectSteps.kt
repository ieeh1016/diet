package com.example.diet

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant

data class HealthConnectStepReadResult(
    val steps: Int?,
    val successful: Boolean,
    val message: String?
)

object HealthConnectSteps {
    val readStepsPermission: String = HealthPermission.getReadPermission(StepsRecord::class)
    val permissions: Set<String> = setOf(readStepsPermission)

    fun isAvailable(context: Context): Boolean {
        return HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
    }

    suspend fun hasReadStepsPermission(context: Context): Boolean {
        if (!isAvailable(context)) return false
        val client = HealthConnectClient.getOrCreate(context)
        val granted = client.permissionController.getGrantedPermissions()
        return granted.containsAll(permissions)
    }

    suspend fun statusMap(context: Context): Map<String, Any?> {
        val available = isAvailable(context)
        val granted = if (available) hasReadStepsPermission(context) else false
        val prefs = BackgroundPrefs.prefs(context)

        if (available) {
            prefs.edit()
                .putBoolean(
                    BackgroundPrefs.flutterKey(BackgroundPrefs.keyHealthConnectStepsGranted),
                    granted
                )
                .apply()
        }

        return mapOf(
            "available" to available,
            "readPermissionGranted" to granted,
            "lastReadSuccessful" to prefs.getBoolean(
                BackgroundPrefs.flutterKey(BackgroundPrefs.keyHealthConnectLastSuccessful),
                false
            ),
            "lastCorrectedSteps" to BackgroundPrefs.getInt(
                context,
                BackgroundPrefs.keyHealthConnectLastCorrectedSteps,
                -1
            ).takeIf { it >= 0 },
            "message" to prefs.getString(
                BackgroundPrefs.flutterKey(BackgroundPrefs.keyHealthConnectMessage),
                null
            )
        )
    }

    suspend fun readStepsAggregate(
        context: Context,
        startMillis: Long,
        endMillis: Long
    ): HealthConnectStepReadResult {
        if (!isAvailable(context)) {
            return HealthConnectStepReadResult(
                steps = null,
                successful = false,
                message = "Health Connect를 사용할 수 없는 기기예요."
            )
        }

        if (!hasReadStepsPermission(context)) {
            return HealthConnectStepReadResult(
                steps = null,
                successful = false,
                message = "Health Connect 걸음수 읽기 권한이 필요해요."
            )
        }

        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val response = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startMillis),
                        Instant.ofEpochMilli(endMillis)
                    )
                )
            )
            val steps = response[StepsRecord.COUNT_TOTAL]?.toInt()
            HealthConnectStepReadResult(
                steps = steps,
                successful = steps != null,
                message = if (steps == null) {
                    "Health Connect에 해당 시간대 걸음수 데이터가 아직 없어요."
                } else {
                    null
                }
            )
        } catch (error: Exception) {
            HealthConnectStepReadResult(
                steps = null,
                successful = false,
                message = "Health Connect 걸음수 보정에 실패했어요: ${error.message}"
            )
        }
    }

    fun saveReadResult(context: Context, result: HealthConnectStepReadResult) {
        BackgroundPrefs.prefs(context)
            .edit()
            .putBoolean(
                BackgroundPrefs.flutterKey(BackgroundPrefs.keyHealthConnectLastSuccessful),
                result.successful
            )
            .also { editor ->
                if (result.steps != null) {
                    BackgroundPrefs.putInt(
                        editor,
                        BackgroundPrefs.keyHealthConnectLastCorrectedSteps,
                        result.steps
                    )
                }
            }
            .also { editor ->
                if (result.message == null) {
                    editor.remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keyHealthConnectMessage))
                } else {
                    editor.putString(
                        BackgroundPrefs.flutterKey(BackgroundPrefs.keyHealthConnectMessage),
                        result.message
                    )
                }
            }
            .apply()
    }
}
