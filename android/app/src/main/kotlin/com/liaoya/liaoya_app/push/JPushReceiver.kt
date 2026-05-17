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

        /** 当前角标数（供外部读取） */
        fun getBadgeCount(context: Context): Int =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getInt(KEY_BADGE, 0)

        /** 重置角标数并清除通知栏所有推送 */
        fun clearAll(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putInt(KEY_BADGE, 0).apply()
            try {
                ShortcutBadger.removeCount(context)
            } catch (e: Exception) {
                Log.w(TAG, "清除角标失败: ${e.message}")
            }
            // 清除通知栏所有通知
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancelAll()
            } catch (e: Exception) {
                Log.w(TAG, "清除通知栏失败: ${e.message}")
            }
        }
    }

    /** 收到透传消息（不显示通知栏，仅业务处理） */
    override fun onMessage(context: Context, customMessage: CustomMessage) {
        Log.d(TAG, "收到透传消息: ${customMessage.message}")
    }

    /** 通知到达（通知栏出现时触发） */
    override fun onNotifyMessageArrived(context: Context, message: NotificationMessage) {
        Log.d(TAG, "通知到达: ${message.notificationTitle}")
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val badge = prefs.getInt(KEY_BADGE, 0) + 1
        prefs.edit().putInt(KEY_BADGE, badge).apply()
        try {
            ShortcutBadger.applyCount(context, badge)
            Log.d(TAG, "角标更新为: $badge")
        } catch (e: Exception) {
            Log.w(TAG, "设置角标失败: ${e.message}")
        }
    }

    /** 用户点击通知（从通知栏点进来） */
    override fun onNotifyMessageOpened(context: Context, message: NotificationMessage) {
        Log.d(TAG, "通知点击: ${message.notificationTitle}")
        // 点击单条通知时清零（进入 App 后 onResume 也会再清一次）
        clearAll(context)
    }

    /** JPush 注册成功，registrationId 就绪 */
    override fun onRegister(context: Context, registrationId: String) {
        Log.d(TAG, "JPush onRegister: $registrationId")
        val app = context.applicationContext as? MyApplication
        MyApplication.onJPushRegistered(app, registrationId)
    }

    override fun onTagOperatorResult(context: Context, jPushMessage: JPushMessage) {}
    override fun onAliasOperatorResult(context: Context, jPushMessage: JPushMessage) {}
}
