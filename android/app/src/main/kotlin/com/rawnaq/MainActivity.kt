package com.rawnaq

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * الطبقة الأصلية للانچر:
 *  - قراءة كل التطبيقات المثبتة القابلة للفتح (تطبيقات التلفزيون + العادية)
 *  - جلب الأيقونة الرسمية والبانر الأفقي لكل تطبيق
 *  - فتح التطبيقات، صفحة معلومات التطبيق، إلغاء التثبيت، إعدادات النظام
 *  - إشعار Flutter عند تثبيت أو حذف أو تحديث أي تطبيق
 */
class MainActivity : FlutterActivity() {

    private val io = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private var packageReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val channel = MethodChannel(messenger, "rawnaq/apps")
        appsChannel = channel
        StreamerBridge.attach(this, messenger)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getApps" -> io.execute {
                    val apps = try { listApps() } catch (e: Exception) { emptyList() }
                    main.post { result.success(apps) }
                }
                "getIcons" -> {
                    val pkg = call.argument<String>("package") ?: return@setMethodCallHandler result.error("ARG", "package", null)
                    io.execute {
                        val icons = try { loadIcons(pkg) } catch (e: Exception) { null }
                        main.post { result.success(icons) }
                    }
                }
                "launch" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(launch(pkg))
                }
                "appInfo" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(startSafely(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))))
                }
                "uninstall" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(startSafely(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg"))))
                }
                "wallpaperDir" -> result.success(wallpaperDir().absolutePath)
                // مجلدات التطبيق الخاصة على الفلاشات (قابلة للكتابة بدون صلاحيات)
                "usbDirs" -> result.success(getExternalFilesDirs(null).drop(1).filterNotNull().map { it.absolutePath })
                "listImages" -> {
                    val dir = File(call.argument<String>("dir") ?: wallpaperDir().absolutePath)
                    io.execute {
                        val files = (dir.listFiles() ?: emptyArray())
                            .filter { it.isFile && isImage(it.name) }
                            .sortedBy { it.name.lowercase() }
                            .map { it.absolutePath }
                        main.post { result.success(files) }
                    }
                }
                "deleteFile" -> {
                    val f = File(call.argument<String>("path") ?: "")
                    // يحذف فقط من مجلد الخلفيات الخاص بالتطبيق
                    val ok = f.canonicalPath.startsWith(wallpaperDir().canonicalPath) && f.delete()
                    result.success(ok)
                }
                "requestStorage" -> {
                    if (hasStorage()) {
                        result.success(true)
                    } else {
                        pendingPermission = result
                        val perm = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES
                        else Manifest.permission.READ_EXTERNAL_STORAGE
                        requestPermissions(arrayOf(perm), 41)
                    }
                }
                "deviceInfo" -> {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val mi = android.app.ActivityManager.MemoryInfo()
                    am.getMemoryInfo(mi)
                    val dm = android.util.DisplayMetrics()
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay.getRealMetrics(dm)
                    result.success(mapOf(
                        "sdk" to Build.VERSION.SDK_INT,
                        "ramMb" to (mi.totalMem / (1024 * 1024)).toInt(),
                        "lowRam" to am.isLowRamDevice,
                        "width" to dm.widthPixels,
                        "height" to dm.heightPixels,
                        "density" to dm.density.toDouble(),
                        "xdpi" to dm.xdpi.toDouble(),
                        "ydpi" to dm.ydpi.toDouble(),
                        "model" to Build.MODEL,
                        "version" to (runCatching { packageManager.getPackageInfo(packageName, 0).versionName }.getOrNull() ?: ""),
                        "updatedAt" to (runCatching { packageManager.getPackageInfo(packageName, 0).lastUpdateTime }.getOrNull() ?: 0L),
                        "cores" to Runtime.getRuntime().availableProcessors()
                    ))
                }
                "importImages" -> io.execute {
                    val n = try { importImages() } catch (e: Exception) { 0 }
                    main.post { result.success(n) }
                }
                "systemStatus" -> io.execute {
                    val st = try { systemStatus() } catch (e: Exception) { emptyMap<String, Any>() }
                    main.post { result.success(st) }
                }
                "cleanMemory" -> io.execute {
                    val freed = try { cleanMemory() } catch (e: Exception) { 0 }
                    main.post { result.success(freed) }
                }
                "setVolume" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                    val v = call.argument<Int>("value") ?: 0
                    runCatching { am.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, v, android.media.AudioManager.FLAG_SHOW_UI) }
                    result.success(am.getStreamVolume(android.media.AudioManager.STREAM_MUSIC))
                }
                "sleepNow" -> {
                    // يطفي الشاشة (وضع الاستعداد) إذا صلاحية مدير الجهاز مفعلة من install.bat
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
                    val admin = android.content.ComponentName(this, AdminReceiver::class.java)
                    val ok = dpm.isAdminActive(admin) && runCatching { dpm.lockNow() }.isSuccess
                    result.success(ok)
                }
                "keepScreenOn" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                }
                "disableSystemSaver" -> {
                    // يحتاج صلاحية WRITE_SECURE_SETTINGS (يمنحها install.bat عبر adb)
                    val ok = runCatching {
                        Settings.Secure.putInt(contentResolver, "screensaver_enabled", 0)
                        Settings.Secure.putInt(contentResolver, "screensaver_activate_on_sleep", 0)
                        Settings.Secure.putInt(contentResolver, "screensaver_activate_on_dock", 0)
                    }.isSuccess
                    result.success(ok)
                }
                "setForceLandscape" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    val intent = Intent(this, OrientationService::class.java)
                    if (!on) {
                        stopService(intent)
                        result.success("off")
                    } else if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(this)) {
                        result.success("no_permission")
                    } else {
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        result.success("on")
                    }
                }
                "systemSettings" -> result.success(startSafely(Intent(Settings.ACTION_SETTINGS)))
                "wifiSettings" -> result.success(startSafely(Intent(Settings.ACTION_WIFI_SETTINGS)))
                "bluetoothSettings" -> result.success(startSafely(Intent(Settings.ACTION_BLUETOOTH_SETTINGS)))
                "displaySettings" -> result.success(startSafely(Intent(Settings.ACTION_DISPLAY_SETTINGS)))
                "soundSettings" -> result.success(startSafely(Intent(Settings.ACTION_SOUND_SETTINGS)))
                "setPrivateDns" -> {
                    // حجب الإعلانات على مستوى الجهاز (AdGuard DNS) — يحتاج WRITE_SECURE_SETTINGS من install.bat
                    val on = call.argument<Boolean>("on") ?: false
                    val ok = runCatching {
                        if (on) {
                            Settings.Global.putString(contentResolver, "private_dns_specifier", "dns.adguard-dns.com")
                            Settings.Global.putString(contentResolver, "private_dns_mode", "hostname")
                        } else {
                            Settings.Global.putString(contentResolver, "private_dns_mode", "off")
                        }
                    }.isSuccess
                    result.success(ok)
                }
                "setMute" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                    val on = call.argument<Boolean>("on") ?: false
                    runCatching {
                        if (Build.VERSION.SDK_INT >= 23) am.adjustStreamVolume(android.media.AudioManager.STREAM_MUSIC,
                            if (on) android.media.AudioManager.ADJUST_MUTE else android.media.AudioManager.ADJUST_UNMUTE, android.media.AudioManager.FLAG_SHOW_UI)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "rawnaq/app_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        events.success(mapOf(
                            "action" to (intent.action ?: ""),
                            "package" to (intent.data?.schemeSpecificPart ?: "")
                        ))
                    }
                }
                val filter = IntentFilter().apply {
                    addAction(Intent.ACTION_PACKAGE_ADDED)
                    addAction(Intent.ACTION_PACKAGE_REMOVED)
                    addAction(Intent.ACTION_PACKAGE_CHANGED)
                    addAction(Intent.ACTION_PACKAGE_REPLACED)
                    addDataScheme("package")
                }
                if (Build.VERSION.SDK_INT >= 33) {
                    registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    registerReceiver(receiver, filter)
                }
                packageReceiver = receiver
            }

            override fun onCancel(arguments: Any?) {
                packageReceiver?.let { runCatching { unregisterReceiver(it) } }
                packageReceiver = null
            }
        })
    }

    /** كل التطبيقات القابلة للفتح، مدموجة حسب الحزمة، بدون اللانچر نفسه. */
    private fun listApps(): List<Map<String, Any>> {
        val pm = packageManager
        val result = LinkedHashMap<String, MutableMap<String, Any>>()

        fun collect(category: String, isTv: Boolean) {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(category)
            for (ri in pm.queryIntentActivities(intent, 0)) {
                val pkg = ri.activityInfo.packageName
                if (pkg == packageName) continue
                val existing = result[pkg]
                if (existing == null) {
                    result[pkg] = mutableMapOf(
                        "package" to pkg,
                        "label" to ri.loadLabel(pm).toString(),
                        "isTv" to isTv
                    )
                } else if (isTv) {
                    existing["isTv"] = true
                }
            }
        }

        collect(Intent.CATEGORY_LEANBACK_LAUNCHER, true)
        collect(Intent.CATEGORY_LAUNCHER, false)
        return result.values.sortedBy { it["label"] as String }
    }

    /** الأيقونة الرسمية + البانر الأفقي (إن وجد) كصور PNG. */
    private fun loadIcons(pkg: String): Map<String, Any?> {
        val pm = packageManager
        var banner: Drawable? = null

        val tvIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER).setPackage(pkg)
        pm.queryIntentActivities(tvIntent, 0).firstOrNull()?.let { ri ->
            banner = ri.activityInfo.loadBanner(pm)
        }
        if (banner == null) {
            banner = runCatching { pm.getApplicationBanner(pkg) }.getOrNull()
        }
        val icon = runCatching { pm.getApplicationIcon(pkg) }.getOrNull()

        return mapOf(
            "banner" to banner?.let { toPng(it, 480, 270) },
            "icon" to icon?.let { toPng(it, 256, 256) }
        )
    }

    private fun toPng(d: Drawable, fallbackW: Int, fallbackH: Int): ByteArray {
        val bmp: Bitmap = if (d is BitmapDrawable && d.bitmap != null) {
            d.bitmap
        } else {
            val w = if (d.intrinsicWidth > 0) d.intrinsicWidth.coerceAtMost(fallbackW * 2) else fallbackW
            val h = if (d.intrinsicHeight > 0) d.intrinsicHeight.coerceAtMost(fallbackH * 2) else fallbackH
            val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(b)
            d.setBounds(0, 0, w, h)
            d.draw(c)
            b
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    private fun launch(pkg: String): Boolean {
        val pm = packageManager
        val intent = pm.getLeanbackLaunchIntentForPackage(pkg) ?: pm.getLaunchIntentForPackage(pkg) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return startSafely(intent)
    }

    private fun startSafely(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }

    // ---------- حالة النظام (اللوحة السريعة) ----------
    private fun systemStatus(): Map<String, Any> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        var net = "none"
        if (Build.VERSION.SDK_INT >= 23) {
            val caps = cm.getNetworkCapabilities(cm.activeNetwork)
            if (caps != null) {
                net = when {
                    caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                    caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                    else -> "other"
                }
            }
        }
        var ip = ""
        runCatching {
            for (nif in java.net.NetworkInterface.getNetworkInterfaces()) {
                if (!nif.isUp || nif.isLoopback) continue
                for (a in nif.inetAddresses) {
                    if (a is java.net.Inet4Address && !a.isLoopbackAddress) { ip = a.hostAddress ?: ""; break }
                }
                if (ip.isNotEmpty()) break
            }
        }
        val stat = android.os.StatFs(Environment.getDataDirectory().path)
        val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val mi = android.app.ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        val audio = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
        return mapOf(
            "net" to net,
            "ip" to ip,
            "storageFree" to (stat.availableBytes / 1048576L).toInt(),
            "storageTotal" to (stat.totalBytes / 1048576L).toInt(),
            "ramFree" to (mi.availMem / 1048576L).toInt(),
            "ramTotal" to (mi.totalMem / 1048576L).toInt(),
            "volume" to audio.getStreamVolume(android.media.AudioManager.STREAM_MUSIC),
            "volumeMax" to audio.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC),
            "canSleep" to dpm.isAdminActive(android.content.ComponentName(this, AdminReceiver::class.java)),
            "privateDns" to (runCatching { Settings.Global.getString(contentResolver, "private_dns_mode") }.getOrNull() == "hostname"),
            "muted" to (Build.VERSION.SDK_INT >= 23 && audio.isStreamMute(android.media.AudioManager.STREAM_MUSIC)),
            "model" to (Build.MODEL ?: ""),
            "bt" to (runCatching { android.bluetooth.BluetoothAdapter.getDefaultAdapter()?.isEnabled == true }.getOrNull() ?: false)
        )
    }

    /** يوقف عمليات التطبيقات بالخلفية (المسموح لتطبيق عادي) ويرجع الذاكرة المحررة بالميغا. */
    private fun cleanMemory(): Int {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val before = android.app.ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }.availMem
        for (app in packageManager.getInstalledApplications(0)) {
            if (app.packageName == packageName) continue
            runCatching { am.killBackgroundProcesses(app.packageName) }
        }
        Thread.sleep(1200)
        val after = android.app.ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }.availMem
        return ((after - before) / 1048576L).toInt().coerceAtLeast(0)
    }

    // ---------- زر الهوم وأنت بالواجهة ----------
    private var appsChannel: MethodChannel? = null

    private var front = false
    private var pausedAt = 0L

    override fun onResume() {
        super.onResume()
        front = true
    }

    override fun onPause() {
        front = false
        pausedAt = System.currentTimeMillis()
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // النظام أحياناً يوقف النشاط لحظة قبل توصيل الـ Intent، فنعتبره قدامك إذا توقف قبل أقل من ثانية
        val wasFront = front || System.currentTimeMillis() - pausedAt < 800
        when {
            // زر النجمة بالريموت يفتح رونق كتطبيق (فئة LEANBACK_LAUNCHER): إذا رونق قدامك ينفّذ إجراء النجمة
            !intent.hasCategory(Intent.CATEGORY_HOME) && !intent.getBooleanExtra("fromGuard", false) &&
                (intent.hasCategory(Intent.CATEGORY_LEANBACK_LAUNCHER) || intent.hasCategory(Intent.CATEGORY_LAUNCHER)) ->
                appsChannel?.invokeMethod("starPressed", mapOf("wasFront" to wasFront))
            intent.hasCategory(Intent.CATEGORY_HOME) || intent.action == Intent.ACTION_MAIN ->
                appsChannel?.invokeMethod("homePressed", null)
        }
    }

    // ---------- الخلفيات ----------
    private var pendingPermission: MethodChannel.Result? = null

    private fun wallpaperDir(): File {
        val dir = getExternalFilesDir("wallpapers") ?: File(filesDir, "wallpapers")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun isImage(name: String): Boolean {
        val n = name.lowercase()
        return n.endsWith(".jpg") || n.endsWith(".jpeg") || n.endsWith(".png") || n.endsWith(".webp")
    }

    private fun hasStorage(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        val perm = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE
        return checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 41) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }

    /** ينسخ الصور من الفلاشات وذاكرة الجهاز (Pictures, Download, DCIM) إلى مجلد الخلفيات. */
    private fun importImages(): Int {
        val target = wallpaperDir()
        val roots = mutableListOf<File>()
        @Suppress("DEPRECATION")
        val primary = Environment.getExternalStorageDirectory()
        listOf("Pictures", "Download", "DCIM", "Wallpapers").forEach { roots.add(File(primary, it)) }
        File("/storage").listFiles()?.forEach { f ->
            if (f.isDirectory && f.name != "emulated" && f.name != "self") roots.add(f)
        }
        File("/mnt/media_rw").listFiles()?.forEach { roots.add(it) }
        File("/mnt/usb").listFiles()?.forEach { roots.add(it) }

        var copied = 0
        fun walk(dir: File, depth: Int) {
            if (depth > 4 || copied >= 300) return
            val items = dir.listFiles() ?: return
            for (f in items) {
                if (f.isDirectory) {
                    if (!f.name.startsWith(".") && f.canonicalPath != target.canonicalPath) walk(f, depth + 1)
                } else if (isImage(f.name) && f.length() in 20_000L..60_000_000L) {
                    val dest = File(target, f.name)
                    if (!dest.exists()) {
                        runCatching { f.copyTo(dest) }.onSuccess { copied++ }
                    }
                }
            }
        }
        roots.distinctBy { runCatching { it.canonicalPath }.getOrDefault(it.path) }
            .forEach { if (it.exists()) walk(it, 0) }
        return copied
    }

    override fun onDestroy() {
        packageReceiver?.let { runCatching { unregisterReceiver(it) } }
        io.shutdown()
        super.onDestroy()
    }
}
