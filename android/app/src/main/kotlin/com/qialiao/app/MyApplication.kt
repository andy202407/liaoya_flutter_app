package com.qialiao.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import cn.jpush.android.api.JPushInterface
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class MyApplication : Application() {

    companion object {
        private const val TAG = "QiaLiao"
        private const val API_BASE = "https://bb.ql52.com/api/v1"

        fun onUserLogin(app: Application?, authToken: String?) {
            app ?: return
            val prefs = app.getSharedPreferences("qialiao_prefs", Context.MODE_PRIVATE)
            if (!authToken.isNullOrEmpty()) {
                prefs.edit().putString("auth_token", authToken).apply()
                Log.d(TAG, "authToken 已保存")
            }
            val savedAuth = prefs.getString("auth_token", "") ?: return
            if (savedAuth.isEmpty()) return

            val registrationId = JPushInterface.getRegistrationID(app)
            if (!registrationId.isNullOrEmpty()) {
                Log.d(TAG, "登录时 registrationId 已就绪，立即上报")
                (app as? MyApplication)?.uploadTokenToServer(registrationId)
            } else {
                Log.w(TAG, "登录时 registrationId 未就绪，等待 onRegister 回调")
            }
        }

        fun onJPushRegistered(app: Application?, registrationId: String?) {
            app ?: return
            if (registrationId.isNullOrEmpty()) return
            Log.d(TAG, "JPush 注册成功: $registrationId")
            val prefs = app.getSharedPreferences("qialiao_prefs", Context.MODE_PRIVATE)
            val authToken = prefs.getString("auth_token", "") ?: ""
            if (authToken.isNotEmpty()) {
                (app as? MyApplication)?.uploadTokenToServer(registrationId)
            } else {
                Log.w(TAG, "registrationId 就绪但用户未登录，等待登录后上报")
            }
        }

        fun onUserLogout(app: Application?) {
            app ?: return
            app.getSharedPreferences("qialiao_prefs", Context.MODE_PRIVATE)
                .edit().remove("auth_token").apply()
        }
    }

    override fun onCreate() {
        super.onCreate()
        JPushInterface.setDebugMode(true)
        JPushInterface.init(this)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "chat_messages", "聊天消息",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "新消息通知"
                enableVibration(true)
                setShowBadge(true)
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    fun uploadTokenToServer(registrationId: String) {
        Thread {
            try {
                val prefs = getSharedPreferences("qialiao_prefs", Context.MODE_PRIVATE)
                val authToken = prefs.getString("auth_token", "") ?: ""
                if (authToken.isEmpty()) {
                    Log.w(TAG, "用户未登录，跳过上报")
                    return@Thread
                }
                val body = JSONObject().apply {
                    put("token", registrationId)
                    put("device_type", "android")
                }.toString()

                val url = URL("$API_BASE/user/tpns/register")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("Authorization", "Bearer $authToken")
                conn.doOutput = true
                conn.connectTimeout = 10000
                conn.readTimeout = 10000
                conn.outputStream.use { it.write(body.toByteArray()) }
                Log.d(TAG, "token 上报结果: HTTP ${conn.responseCode}")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "token 上报失败: ${e.message}")
            }
        }.start()
    }
}
