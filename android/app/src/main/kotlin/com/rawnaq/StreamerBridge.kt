package com.rawnaq

import android.app.Activity
import android.app.PendingIntent
import android.app.SearchManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.speech.RecognizerIntent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * قناة «rawnaq/streamer»: كل ما يخص الستريمر بعد واجهة كوكل —
 * الحارس، التنبيهات، الطاقة والقابس، البحث، العرض والصوت، التحديث الذاتي، والإعدادات العامة.
 */
object StreamerBridge {
    private val io = Executors.newSingleThreadExecutor()

    fun attach(a: Activity, messenger: BinaryMessenger) {
        PowerWatch.ensure(a)
        MethodChannel(messenger, "rawnaq/streamer").setMethodCallHandler { call, result ->
            val p = HomeGuardService.prefs(a)
            try {
                when (call.method) {
                    // ---------- الحارس ----------
                    "guardStatus" -> result.success(mapOf(
                        "serviceOn" to serviceEnabled(a, "enabled_accessibility_services", HomeGuardService::class.java),
                        "running" to HomeGuardService.running,
                        "guardOn" to p.getBoolean("guard.on", true),
                        "defaultHome" to defaultHome(a),
                        "google" to googleLauncherState(a),
                        "last" to p.getLong("guard.last", 0L),
                        "count" to p.getInt("guard.count", 0),
                        "canWrite" to canWriteSecure(a)
                    ))
                    "guardSet" -> {
                        val on = call.argument<Boolean>("on") ?: true
                        p.edit().putBoolean("guard.on", on).apply()
                        if (on) enableService(a, "enabled_accessibility_services", HomeGuardService::class.java, ':')
                        result.success(serviceEnabled(a, "enabled_accessibility_services", HomeGuardService::class.java))
                    }
                    "guardPause" -> {
                        val min = call.argument<Int>("minutes") ?: 5
                        p.edit().putLong("guard.pauseUntil", System.currentTimeMillis() + min * 60_000L).apply()
                        result.success(openGoogleHome(a))
                    }
                    "accessibilitySettings" -> result.success(start(a, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)))
                    "toFront" -> result.success(start(a, Intent(a, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)))

                    // ---------- التنبيهات ----------
                    "notifAccess" -> result.success(serviceEnabled(a, "enabled_notification_listeners", NotifListener::class.java))
                    "notifEnable" -> {
                        enableService(a, "enabled_notification_listeners", NotifListener::class.java, ':')
                        result.success(serviceEnabled(a, "enabled_notification_listeners", NotifListener::class.java))
                    }
                    "notifSettings" -> result.success(start(a, Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")))
                    "notifications" -> result.success(NotifListener.snapshot())
                    "notifClear" -> { NotifListener.clear(); result.success(true) }

                    // ---------- الطاقة والقابس ----------
                    "powerConfig" -> {
                        p.edit()
                            .putString("power.method", call.argument<String>("method") ?: "cec")
                            .putString("plug.off", call.argument<String>("off") ?: "")
                            .putString("plug.on", call.argument<String>("on") ?: "")
                            .putInt("plug.wait", call.argument<Int>("wait") ?: 10)
                            .apply()
                        result.success(true)
                    }
                    "powerStatus" -> result.success(mapOf(
                        "lastOff" to p.getLong("plug.lastOff", 0L), "lastOffOk" to p.getBoolean("plug.lastOffOk", false),
                        "lastOn" to p.getLong("plug.lastOn", 0L), "lastOnOk" to p.getBoolean("plug.lastOnOk", false)
                    ))

                    // ---------- إعدادات النظام العامة ----------
                    "getSetting" -> result.success(getSetting(a, call.argument<String>("ns") ?: "global", call.argument<String>("key") ?: ""))
                    "putSetting" -> result.success(putSetting(a, call.argument<String>("ns") ?: "global", call.argument<String>("key") ?: "", call.argument<String>("value") ?: ""))

                    // ---------- البحث ----------
                    "webSearch" -> {
                        val q = call.argument<String>("q") ?: ""
                        result.success(
                            start(a, Intent(Intent.ACTION_WEB_SEARCH).putExtra(SearchManager.QUERY, q)) ||
                                start(a, Intent("android.search.action.GLOBAL_SEARCH").putExtra(SearchManager.QUERY, q)) ||
                                start(a, Intent(Intent.ACTION_SEARCH).putExtra(SearchManager.QUERY, q))
                        )
                    }
                    "voiceSearch" -> result.success(
                        start(a, Intent(Intent.ACTION_ASSIST)) ||
                            start(a, Intent(RecognizerIntent.ACTION_VOICE_SEARCH_HANDS_FREE)) ||
                            start(a, Intent(Intent.ACTION_VOICE_COMMAND))
                    )

                    // ---------- العرض والصوت ----------
                    "displayInfo" -> result.success(displayInfo(a))

                    // ---------- التحديث الذاتي ----------
                    "installSource" -> result.success(installSource(a))
                    "installApk" -> {
                        val path = call.argument<String>("path") ?: ""
                        io.execute {
                            val ok = runCatching { installApk(a, File(path)) }.getOrDefault(false)
                            a.runOnUiThread { result.success(ok) }
                        }
                    }
                    "updateStatus" -> result.success(mapOf("status" to p.getInt("update.status", -99), "message" to (p.getString("update.message", "") ?: "")))
                    // شاشة موافقة التثبيت تنفتح من الواجهة نفسها (مسموح دائماً لأنها بالمقدمة)
                    "confirmInstall" -> {
                        val i = InstallReceiver.pending
                        if (i == null) result.success(false) else {
                            InstallReceiver.pending = null
                            result.success(start(a, i))
                        }
                    }
                    "hasPackage" -> result.success(runCatching { a.packageManager.getPackageInfo(call.argument<String>("package") ?: "", 0); true }.getOrDefault(false))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERR", e.message, null)
            }
        }
    }

    private fun start(a: Context, i: Intent): Boolean = try {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        a.startActivity(i)
        true
    } catch (_: Exception) {
        false
    }

    private fun canWriteSecure(a: Context) =
        a.checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS") == PackageManager.PERMISSION_GRANTED

    private fun serviceEnabled(a: Context, key: String, cls: Class<*>): Boolean {
        val list = Settings.Secure.getString(a.contentResolver, key) ?: return false
        val cn = ComponentName(a, cls)
        return list.split(':').any { ComponentName.unflattenFromString(it) == cn }
    }

    /** يضيف الخدمة لقائمة النظام (يحتاج WRITE_SECURE_SETTINGS من install.bat). */
    private fun enableService(a: Context, key: String, cls: Class<*>, sep: Char) {
        if (!canWriteSecure(a) || serviceEnabled(a, key, cls)) return
        val me = ComponentName(a, cls).flattenToString()
        val cur = Settings.Secure.getString(a.contentResolver, key).orEmpty()
        val next = if (cur.isBlank()) me else "$cur$sep$me"
        runCatching {
            Settings.Secure.putString(a.contentResolver, key, next)
            if (key == "enabled_accessibility_services") Settings.Secure.putString(a.contentResolver, "accessibility_enabled", "1")
        }
    }

    private fun defaultHome(a: Context): String {
        val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return a.packageManager.resolveActivity(i, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName ?: ""
    }

    private fun googleLauncherState(a: Context): String {
        for (pkg in HomeGuardService.GOOGLE_LAUNCHERS) {
            val info = runCatching { a.packageManager.getApplicationInfo(pkg, 0) }.getOrNull() ?: continue
            return if (info.enabled) "enabled" else "disabled"
        }
        return "missing"
    }

    private fun openGoogleHome(a: Context): Boolean {
        for (pkg in HomeGuardService.GOOGLE_LAUNCHERS) {
            val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).setPackage(pkg)
            if (start(a, i)) return true
        }
        return false
    }

    private fun getSetting(a: Context, ns: String, key: String): String? = runCatching {
        when (ns) {
            "secure" -> Settings.Secure.getString(a.contentResolver, key)
            "system" -> Settings.System.getString(a.contentResolver, key)
            else -> Settings.Global.getString(a.contentResolver, key)
        }
    }.getOrNull()

    private fun putSetting(a: Context, ns: String, key: String, value: String): Boolean = runCatching {
        when (ns) {
            "secure" -> Settings.Secure.putString(a.contentResolver, key, value)
            "system" -> Settings.System.putString(a.contentResolver, key, value)
            else -> Settings.Global.putString(a.contentResolver, key, value)
        }
    }.getOrDefault(false)

    private fun displayInfo(a: Activity): Map<String, Any> {
        @Suppress("DEPRECATION")
        val d = a.windowManager.defaultDisplay
        val out = HashMap<String, Any>()
        if (Build.VERSION.SDK_INT >= 23) {
            val m = d.mode
            out["w"] = m.physicalWidth
            out["h"] = m.physicalHeight
            out["hz"] = m.refreshRate.toDouble()
            out["modes"] = d.supportedModes.map { "${it.physicalWidth}x${it.physicalHeight}@${Math.round(it.refreshRate)}" }.distinct()
            val maxW = d.supportedModes.maxOfOrNull { it.physicalWidth } ?: m.physicalWidth
            out["maxW"] = maxW
        }
        if (Build.VERSION.SDK_INT >= 24) {
            @Suppress("DEPRECATION")
            out["hdr"] = (d.hdrCapabilities?.supportedHdrTypes ?: IntArray(0)).map {
                when (it) { 1 -> "Dolby Vision"; 2 -> "HDR10"; 3 -> "HLG"; 4 -> "HDR10+"; else -> "HDR" }
            }
        }
        if (Build.VERSION.SDK_INT >= 23) {
            val am = a.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            out["audio"] = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map {
                when (it.type) {
                    AudioDeviceInfo.TYPE_HDMI -> "hdmi"
                    AudioDeviceInfo.TYPE_HDMI_ARC -> "arc"
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "bluetooth"
                    AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
                    else -> "other"
                }
            }.distinct()
        }
        return out
    }

    private fun installSource(a: Context): String = runCatching {
        if (Build.VERSION.SDK_INT >= 30) a.packageManager.getInstallSourceInfo(a.packageName).installingPackageName ?: ""
        else @Suppress("DEPRECATION") a.packageManager.getInstallerPackageName(a.packageName) ?: ""
    }.getOrDefault("")

    /** يثبّت ملف APK بجلسة PackageInstaller (بدون FileProvider)، والنظام يطلب تأكيد المستخدم. */
    private fun installApk(a: Context, f: File): Boolean {
        if (!f.exists()) return false
        val pi = a.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(a.packageName)
        // أندرويد ١٢ وطالع: إذا رونق هو اللي نصّب نفسه آخر مرة، التحديث ينصب بدون سؤال
        if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        HomeGuardService.prefs(a).edit().putInt("update.status", -99).putString("update.message", "").apply()
        InstallReceiver.pending = null
        val id = pi.createSession(params)
        pi.openSession(id).use { s ->
            f.inputStream().use { input ->
                s.openWrite("rawnaq.apk", 0, f.length()).use { out ->
                    input.copyTo(out)
                    s.fsync(out)
                }
            }
            val flags = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            val intent = Intent(a, InstallReceiver::class.java).setPackage(a.packageName)
            val pending = PendingIntent.getBroadcast(a, 77, intent, flags)
            s.commit(pending.intentSender)
        }
        return true
    }
}
