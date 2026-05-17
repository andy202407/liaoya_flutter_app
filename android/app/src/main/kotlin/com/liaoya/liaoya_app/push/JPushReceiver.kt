package com.liaoya.liaoya_app.push

import android.app.NotificationManager
import android.content.Context
import android.util.Log
import cn.jpush.android.api.CustomMessage
import cn.jpush.android.api.JPushMessage
import cn.jpush.android.api.NotificationMessage
import cn.jpush.android.service.JPushMessageReceiver
import com.liaoya.liaoya_app.MyApplication
import me.leolin.shortcutbadger.ShortcutBadger

class JPushReceiver : JPushMessageReceiver() {

    companion object {
        private const val TAG = "JPushReceiver"
        private const val PREFS = "liaoya_prefs"
        private const val KEY_BADGE = "badge_count"

        fun clearAll(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putInt(KEY_BADGE, 0).apply()
            try { ShortcutBadger.removeCount(context) } catch (_: Exception) {}
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancelAll()
            } catch (_: Exception) {}
        }
    }

    override fun onMessage(context: Context, customMessage: CustomMessage) {
        Log.d(TAG, "收到透传消息: ${customMessage.message}")
    }

    override fun onNotifyMessageArrived(context: Context, message: NotificationMessage) {
        Log.d(TAG, "通知到达: ${message.notificationTitle}")
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val badge = prefs.getInt(KEY_BADGE, 0) + 1
        prefs.edit().putInt(KEY_BADGE, badge).apply()
        try { ShortcutBadger.applyCount(context, badge) } catch (_: Exception) {}
    }

    override fun onNotifyMessageOpened(context: Context, message: NotificationMessage) {
        Log.d(TAG, "通知点击: ${message.notificationTitle}")
        clearAll(context)
    }

    override fun onRegister(context: Context, registrationId: String) {
        Log.d(TAG, "JPush onRegister: $registrationId")
        val app = context.applicationContext as? MyApplication
        MyApplication.onJPushRegistered(app, registrationId)
    }

    override fun onTagOperatorResult(context: Context, jPushMessage: JPushMessage) {}
    override fun onAliasOperatorResult(context: Context, jPushMessage: JPushMessage) {}
}
