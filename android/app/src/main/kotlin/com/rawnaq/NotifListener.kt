package com.rawnaq

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * يجمع آخر تنبيهات التطبيقات (العنوان والنص فقط) لمركز التنبيهات برونق.
 * يتفعّل بصلاحية قراءة التنبيهات يمنحها install.bat. ما يرسل أي شي لبرّا الجهاز.
 */
class NotifListener : NotificationListenerService() {

    override fun onListenerConnected() {
        connected = true
        runCatching { activeNotifications?.forEach { add(it) } }
    }

    override fun onListenerDisconnected() {
        connected = false
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn != null) add(sbn)
    }

    private fun add(sbn: StatusBarNotification) {
        val n = sbn.notification ?: return
        if (sbn.isOngoing || sbn.packageName == packageName) return
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val ex = n.extras ?: return
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = ex.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        if (title.isEmpty() && text.isEmpty()) return
        val label = runCatching { packageManager.getApplicationLabel(packageManager.getApplicationInfo(sbn.packageName, 0)).toString() }
            .getOrDefault(sbn.packageName)
        synchronized(items) {
            items.removeAll { it["key"] == sbn.key }
            items.add(0, mapOf("key" to sbn.key, "package" to sbn.packageName, "app" to label, "title" to title, "text" to text, "time" to sbn.postTime))
            while (items.size > 40) items.removeAt(items.size - 1)
        }
    }

    companion object {
        @Volatile var connected = false
        val items = mutableListOf<Map<String, Any>>()
        fun snapshot(): List<Map<String, Any>> = synchronized(items) { items.toList() }
        fun clear() = synchronized(items) { items.clear() }
    }
}
