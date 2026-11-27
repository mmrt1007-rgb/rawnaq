package com.rawnaq

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import java.net.HttpURLConnection
import java.net.URL

/**
 * التلفزيون والطاقة: لما الستريمر ينام (تنطفي الشاشة) ننتظر ثوانٍ قليلة حتى يوصل أمر
 * الإطفاء عبر HDMI-CEC، وبعدها نقطع كهرباء التلفزيون بالقابس الذكي (Shelly أو Tasmota).
 * ولما الستريمر يصحى نرجّع الكهرباء فوراً، والتلفزيون يشتغل وحده إذا وضع «التشغيل
 * عند رجوع الكهرباء» مفعّل بإعداداته. الإعداد يوصل من شاشة «التلفزيون والطاقة».
 */
object PowerWatch {
    private var registered = false
    private val main = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null
    private var lock: PowerManager.WakeLock? = null

    fun ensure(ctx: Context) {
        if (registered) return
        val app = ctx.applicationContext
        val f = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                when (i.action) {
                    Intent.ACTION_SCREEN_OFF -> onOff(app)
                    Intent.ACTION_SCREEN_ON -> onOn(app)
                }
            }
        }
        if (android.os.Build.VERSION.SDK_INT >= 33) app.registerReceiver(r, f, Context.RECEIVER_NOT_EXPORTED) else app.registerReceiver(r, f)
        registered = true
    }

    private fun usesPlug(ctx: Context): Boolean {
        val p = HomeGuardService.prefs(ctx)
        val m = p.getString("power.method", "cec") ?: "cec"
        return (m == "plug" || m == "both") && !p.getString("plug.off", "").isNullOrBlank()
    }

    private fun onOff(ctx: Context) {
        if (!usesPlug(ctx)) return
        val p = HomeGuardService.prefs(ctx)
        val wait = p.getInt("plug.wait", 10).coerceIn(0, 120)
        val url = p.getString("plug.off", "") ?: ""
        pending?.let { main.removeCallbacks(it) }
        runCatching {
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
            lock?.let { if (it.isHeld) it.release() }
            lock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "rawnaq:plug").apply { acquire((wait + 20) * 1000L) }
        }
        val r = Runnable {
            pending = null
            Thread {
                val ok = get(url)
                p.edit().putLong("plug.lastOff", System.currentTimeMillis()).putBoolean("plug.lastOffOk", ok).apply()
                runCatching { lock?.let { if (it.isHeld) it.release() } }
            }.start()
        }
        pending = r
        main.postDelayed(r, wait * 1000L)
    }

    private fun onOn(ctx: Context) {
        pending?.let { main.removeCallbacks(it); pending = null }
        runCatching { lock?.let { if (it.isHeld) it.release() } }
        if (!usesPlug(ctx)) return
        val p = HomeGuardService.prefs(ctx)
        val url = p.getString("plug.on", "") ?: ""
        if (url.isBlank()) return
        Thread {
            // الشبكة أحياناً تتأخر ثانية أو ثنتين بعد الصحيان: نعيد المحاولة
            var ok = false
            for (i in 0 until 5) {
                ok = get(url)
                if (ok) break
                Thread.sleep(1500)
            }
            p.edit().putLong("plug.lastOn", System.currentTimeMillis()).putBoolean("plug.lastOnOk", ok).apply()
        }.start()
    }

    fun get(url: String): Boolean = try {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 4000
        c.readTimeout = 4000
        val code = c.responseCode
        c.disconnect()
        code in 200..299
    } catch (_: Exception) {
        false
    }
}
