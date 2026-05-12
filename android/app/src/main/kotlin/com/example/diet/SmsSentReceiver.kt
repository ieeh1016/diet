package com.example.diet

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import java.time.Instant

class SmsSentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val phone = intent.getStringExtra(extraPhone).orEmpty()
        val dateKey = intent.getStringExtra(extraDateKey).orEmpty()
        val errorMessage = messageForResult(resultCode)
        val sent = resultCode == Activity.RESULT_OK

        val editor = BackgroundPrefs.prefs(context).edit()
            .putString(
                BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastStatus),
                if (sent) "sent" else "failed"
            )
            .putString(
                BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastPhone),
                phone
            )
            .putString(
                BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastDateKey),
                dateKey
            )

        if (sent) {
            editor
                .putString(
                    BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastSentAt),
                    Instant.now().toString()
                )
                .remove(BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastError))
        } else {
            editor
                .putString(
                    BackgroundPrefs.flutterKey(BackgroundPrefs.keySmsLastError),
                    errorMessage
                )
                .putString(
                    BackgroundPrefs.flutterKey(BackgroundPrefs.keyLastDegradedReason),
                    errorMessage
                )
        }

        editor.apply()
    }

    private fun messageForResult(resultCode: Int): String {
        return when (resultCode) {
            Activity.RESULT_OK -> ""
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "문자 전송에 실패했어요: 일반 오류"
            SmsManager.RESULT_ERROR_NO_SERVICE -> "문자 전송에 실패했어요: 통신 서비스 없음"
            SmsManager.RESULT_ERROR_NULL_PDU -> "문자 전송에 실패했어요: 메시지 형식 오류"
            SmsManager.RESULT_ERROR_RADIO_OFF -> "문자 전송에 실패했어요: 통신 모듈 꺼짐"
            else -> "문자 전송에 실패했어요: 결과 코드 $resultCode"
        }
    }

    companion object {
        const val actionSmsSent = "com.example.diet.ACTION_SMS_SENT"
        const val extraPhone = "phone"
        const val extraDateKey = "dateKey"
    }
}
