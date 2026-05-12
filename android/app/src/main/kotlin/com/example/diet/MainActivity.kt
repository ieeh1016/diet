package com.example.diet

import android.content.Intent
import android.os.Bundle
import android.telephony.SmsManager
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {
    private val smsChannel = "diet/sms"
    private val backgroundChannel = "diet/background_monitoring"
    private val healthConnectChannel = "diet/health_connect"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var requestHealthPermissions: ActivityResultLauncher<Set<String>>
    private var pendingHealthConnectResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHealthPermissions = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { _ ->
            val result = pendingHealthConnectResult
            pendingHealthConnectResult = null
            if (result != null) {
                scope.launch {
                    result.success(HealthConnectSteps.statusMap(this@MainActivity))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val message = call.argument<String>("message")

                        if (phoneNumber.isNullOrBlank() || message.isNullOrBlank()) {
                            result.error("invalid_sms_args", "전화번호와 메시지가 필요해요.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val smsManager = SmsManager.getDefault()
                            val parts = smsManager.divideMessage(message)
                            if (parts.size > 1) {
                                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                            } else {
                                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                            }
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("sms_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backgroundChannel)
            .setMethodCallHandler(BackgroundMonitoringBridge(applicationContext))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, healthConnectChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentStatus" -> {
                        scope.launch {
                            result.success(HealthConnectSteps.statusMap(this@MainActivity))
                        }
                    }
                    "requestReadStepsPermission" -> {
                        if (!HealthConnectSteps.isAvailable(this)) {
                            scope.launch {
                                result.success(HealthConnectSteps.statusMap(this@MainActivity))
                            }
                            return@setMethodCallHandler
                        }
                        if (pendingHealthConnectResult != null) {
                            result.error("health_connect_busy", "이미 권한 요청을 진행하고 있어요.", null)
                            return@setMethodCallHandler
                        }
                        pendingHealthConnectResult = result
                        requestHealthPermissions.launch(HealthConnectSteps.permissions)
                    }
                    "openSettings" -> {
                        val opened = try {
                            startActivity(Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS))
                            true
                        } catch (_: Exception) {
                            false
                        }
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        pendingHealthConnectResult = null
        scope.cancel()
        super.onDestroy()
    }
}
