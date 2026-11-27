package com.rawnaq

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * حارس الواجهة: إذا طلعت واجهة كوكل الأصلية (بعد تحديث النظام أو بزر الهوم)
 * يرجّع رونق خلال لحظة. ما يقرأ محتوى الشاشة: يكفيه اسم التطبيق الظاهر فقط،
 * وملف الإعداد (xml/home_guard.xml) يحصر الأحداث بواجهات كوكل وحدها.
 * يتفعّل بصلاحية «إمكانية الوصول» يمنحها install.bat مرة وحدة.
 */
class HomeGuardService : AccessibilityService() {
    private var last = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg !in GOOGLE_LAUNCHERS) return
        val p = prefs(this)
        if (!p.getBoolean("guard.on", true)) return
        val now = System.currentTimeMillis()
        if (now < p.getLong("guard.pauseUntil", 0L)) return
        if (now - last < 1500) return
        last = now
        try {
            val i = Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                .putExtra("fromGuard", true)
            startActivity(i)
            p.edit().putLong("guard.last", now).putInt("guard.count", p.getInt("guard.count", 0) + 1).apply()
        } catch (_: Exception) {
        }
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        running = true
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    companion object {
        @Volatile var running = false
        val GOOGLE_LAUNCHERS = setOf(
            "com.google.android.apps.tv.launcherx",
            "com.google.android.tvlauncher",
            "com.google.android.leanbacklauncher"
        )
        fun prefs(c: Context) = c.getSharedPreferences("rawnaq_native", Context.MODE_PRIVATE)
    }
}
