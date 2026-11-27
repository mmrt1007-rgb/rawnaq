package com.rawnaq

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

/** نتيجة تثبيت التحديث. إذا النظام يريد موافقة المستخدم نحفظ شاشة التأكيد،
 *  والواجهة تفتحها (فتحها من هنا ممكن ينمنع بأندرويد ١٠+ لأنها من الخلفية). */
class InstallReceiver : BroadcastReceiver() {
    companion object {
        @Volatile var pending: Intent? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val confirm: Intent? = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_INTENT)
            confirm?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            pending = confirm
        }
        HomeGuardService.prefs(context).edit().putInt("update.status", status)
            .putString("update.message", intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "").apply()
    }
}
