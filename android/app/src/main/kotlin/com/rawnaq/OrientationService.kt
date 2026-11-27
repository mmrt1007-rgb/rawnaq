package com.rawnaq

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ActivityInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.View
import android.view.WindowManager

/**
 * يفرض الوضع العرضي على كل التطبيقات (حتى المصممة للهاتف بالوضع الطولي):
 * نافذة شفافة بحجم صفر فوق الشاشة تطلب الاتجاه العرضي، والنظام يطبقه على الكل.
 * يحتاج صلاحية الظهور فوق التطبيقات (يمنحها install.bat عبر adb).
 */
class OrientationService : Service() {
    private var view: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel("orientation", "الوضع العرضي", NotificationManager.IMPORTANCE_MIN))
            val n = Notification.Builder(this, "orientation")
                .setContentTitle("رونق")
                .setContentText("فرض الوضع العرضي مفعّل")
                .setSmallIcon(android.R.drawable.ic_menu_rotate)
                .build()
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(7, n, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(7, n)
            }
        }
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_PHONE
        val lp = WindowManager.LayoutParams(
            0, 0, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        )
        lp.screenOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        val v = View(this)
        runCatching { wm.addView(v, lp) }.onSuccess { view = v }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        view?.let { v -> runCatching { (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(v) } }
        view = null
        super.onDestroy()
    }
}
