package com.example.diet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class LunchActivityAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, LunchActivityForegroundService::class.java)
            .setAction(intent.action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}

