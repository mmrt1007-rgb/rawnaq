import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, AppLifecycleState;
import 'package:hijri/hijri_calendar.dart';

import 'arabic.dart';
import 'platform.dart';
import 'state.dart';
import 'weather.dart' show WeatherHub;
import 'system_services.dart';
import 'family_services.dart';

// ═══════════════════ آخر ما فتحته ═══════════════════

class Recents {
  /// يُستدعى مع كل فتح تطبيق من رونق.
  static void record(String pkg) {
    final c = AppState.I.cfg;
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = [(pkg, now), ...entries().where((e) => e.$1 != pkg).map((e) => (e.$1, e.$2.millisecondsSinceEpoch))].take(12);
    c.set('recent.list', list.map((e) => '${e.$1}|${e.$2}').join(','));
  }

  static List<(String, DateTime)> entries() {
    final raw = AppState.I.cfg.s('recent.list');
    if (raw.isEmpty) return const [];
    final out = <(String, DateTime)>[];
    for (final part in raw.split(',')) {
      final b = part.split('|');
      if (b.length != 2) continue;
      final t = int.tryParse(b[1]);
      if (t != null && AppState.I.app(b[0]) != null) out.add((b[0], DateTime.fromMillisecondsSinceEpoch(t)));
    }
    return out;
  }

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'قبل ${Ar.n(d.inMinutes)} د';
    if (d.inHours < 24) return 'قبل ${Ar.n(d.inHours)} س';
    if (d.inDays == 1) return 'أمس';
    return 'قبل ${Ar.n(d.inDays)} أيام';
  }
}

// ═══════════════════ ملفات العائلة ═══════════════════

class Profiles {
  static const ids = ['family', 'kids', 'guest'];
  static String name(String id) => switch (id) { 'kids' => 'الأطفال', 'guest' => 'الضيف', _ => 'العائلة' };
  static String get active => AppState.I.cfg.s('profile.active');
  static bool get kids => active == 'kids';
  static bool get guest => active == 'guest';
  static bool get restricted => kids || guest;

  static List<String> get kidsApps => AppState.I.cfg.s('kids.apps').split(',').where((e) => e.isNotEmpty && AppState.I.app(e) != null).toList();

  static void setKidsApps(List<String> pkgs) => AppState.I.set('kids.apps', pkgs.join(','));

  /// التطبيقات الظاهرة بالواجهة حسب الملف.
  static List<String> visible(List<String> favorites) {
    if (!kids) return favorites;
    final k = kidsApps;
    return k.isEmpty ? favorites.take(4).toList() : k;
  }

  /// سبب قفل ملف الأطفال الآن (أو null).
  static final ValueNotifier<String?> lock = ValueNotifier(null);

  static int _secs = 0;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static int get usedToday {
    final c = AppState.I.cfg;
    return c.s('kids.day') == _today() ? c.i('kids.used') : 0;
  }

  static int get allowedToday {
    final c = AppState.I.cfg;
    final limit = KidsLog.limitFor(DateTime.now());
    if (limit <= 0) return 0;
    return limit + (c.s('kids.day') == _today() ? c.i('kids.extra') : 0);
  }

  static bool get bedtimeNow {
    final bed = AppState.I.cfg.i('kids.bed');
    if (bed < 0) return false;
    final n = DateTime.now();
    final m = n.hour * 60 + n.minute;
    return m >= bed || m < 360; // من وقت النوم لحد ٦ الصبح
  }

  /// يُستدعى كل ٢٠ ثانية من المراقب.
  static void tick(int seconds) {
    if (!kids) {
      if (lock.value != null) lock.value = null;
      return;
    }
    final c = AppState.I.cfg;
    if (c.s('kids.day') != _today()) {
      c.set('kids.day', _today());
      c.set('kids.used', 0);
      c.set('kids.extra', 0);
    }
    _secs += seconds;
    if (_secs >= 60) {
      c.set('kids.used', c.i('kids.used') + _secs ~/ 60);
      KidsLog.addMinutes(_secs ~/ 60);
      _secs %= 60;
    }
    final allowed = allowedToday;
    final reason = bedtimeNow ? 'bed' : (allowed > 0 && usedToday >= allowed ? 'time' : null);
    if (reason != lock.value) {
      lock.value = reason;
      if (reason != null) ActivityLog.add(reason == 'bed' ? 'moon-star' : 'hourglass', reason == 'bed' ? 'وقت نوم الأطفال' : 'انتهى وقت مشاهدة الأطفال', 'انقفلت واجهة الأطفال', kind: 'kids');
      if (reason != null) Streamer.toFront();
    }
  }

  static void extend(int minutes) {
    final c = AppState.I.cfg;
    ActivityLog.add('timer', 'تمديد وقت الأطفال', '${Ar.n(minutes)} دقيقة بالرمز', kind: 'kids');
    c.set('kids.day', _today());
    c.set('kids.extra', c.i('kids.extra') + minutes);
    lock.value = null;
    AppState.I.touch();
  }
}

// ═══════════════════ مركز التنبيهات ═══════════════════

class Notice {
  final String icon, title, sub;
  final DateTime time;
  final String? package; // تنبيه تطبيق
  const Notice(this.icon, this.title, this.sub, this.time, {this.package});
  Map<String, Object> toJson() => {'i': icon, 't': title, 's': sub, 'm': time.millisecondsSinceEpoch};
  static Notice fromJson(Map m) => Notice('${m['i']}', '${m['t']}', '${m['s']}', DateTime.fromMillisecondsSinceEpoch((m['m'] as num).toInt()));
}

class Notices {
  static final ValueNotifier<int> unread = ValueNotifier(0);
  static List<Notice> _own = [];
  static List<Notice> _apps = [];
  static Timer? _t;

  static void start() {
    try {
      final raw = AppState.I.prefs.getString('notices') ?? '[]';
      _own = [for (final m in jsonDecode(raw) as List) Notice.fromJson(m as Map)];
    } catch (_) {
      _own = [];
    }
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    refresh();
  }

  /// تنبيه من رونق نفسه (أذان، نسخة احتياطية، تحديث، الحارس، القابس…).
  static void add(String icon, String title, String sub) {
    _own.insert(0, Notice(icon, title, sub, DateTime.now()));
    if (_own.length > 30) _own = _own.take(30).toList();
    try {
      AppState.I.prefs.setString('notices', jsonEncode([for (final n in _own) n.toJson()]));
    } catch (_) {}
    _count();
  }

  static Future<void> refresh() async {
    final c = AppState.I.cfg;
    if (c.b('notif.apps')) {
      final raw = await Streamer.notifications();
      final seenKeys = <String>{};
      final last = <String, int>{};
      _apps = [];
      for (final m in raw) {
        final k = '${m['key']}';
        if (!seenKeys.add(k)) continue;
        final t = (m['time'] as num?)?.toInt() ?? 0;
        if ((last[m['package']] ?? 0) == t) continue;
        last['${m['package']}'] = t;
        final title = '${m['app']}${(m['title'] as String? ?? '').isNotEmpty ? ' · ${m['title']}' : ''}';
        _apps.add(Notice('app', title, '${m['text'] ?? ''}', DateTime.fromMillisecondsSinceEpoch(t), package: '${m['package']}'));
      }
      final fresh = _apps.where((n) => n.time.millisecondsSinceEpoch > _lastPopup).toList();
      if (fresh.isNotEmpty) {
        _lastPopup = fresh.first.time.millisecondsSinceEpoch;
        if (c.b('notif.popup') && !(c.b('notif.quietMute') && SystemWatch.I.quietNow) && _primed) {
          SystemWatch.I.notice.value = '${fresh.first.title}\n${fresh.first.sub}';
        }
      }
      _primed = true;
    } else {
      _apps = [];
    }
    // الحارس تدخّل؟ نسجلها تنبيه
    final g = await Streamer.guardStatus();
    final cnt = (g['count'] as int?) ?? 0;
    final known = AppState.I.prefs.getInt('guard.known') ?? 0;
    if (cnt > known) {
      AppState.I.prefs.setInt('guard.known', cnt);
      if (known > 0 || cnt == 1) {
        add('shield-check', 'الحارس رجّع رونق', 'طلعت واجهة كوكل، وما يحتاج منك شي');
        ActivityLog.add('shield-check', 'الحارس رجّع رونق بعد ظهور واجهة كوكل', '', kind: 'guard');
      }
    }
    _count();
  }

  static int _lastPopup = 0;
  static bool _primed = false;

  static List<Notice> get all => [..._own, ..._apps]..sort((a, b) => b.time.compareTo(a.time));

  static void _count() {
    final seen = AppState.I.cfg.i('notif.seen');
    unread.value = all.where((n) => n.time.millisecondsSinceEpoch > seen).length;
  }

  static void markSeen() {
    AppState.I.cfg.set('notif.seen', DateTime.now().millisecondsSinceEpoch);
    _count();
  }

  static Future<void> clear() async {
    _own = [];
    _apps = [];
    try {
      AppState.I.prefs.setString('notices', '[]');
    } catch (_) {}
    await Streamer.notifClear();
    markSeen();
  }
}

// ═══════════════════ التحديث الذاتي ═══════════════════

class UpdateInfo {
  final String version, apk;
  final List<String> notes;
  final int size;
  final String sha256;
  const UpdateInfo(this.version, this.apk, this.notes, this.size, [this.sha256 = '']);
}

class Updater {
  static final ValueNotifier<UpdateInfo?> available = ValueNotifier(null);
  static final ValueNotifier<double?> progress = ValueNotifier(null);
  static String lastError = '';

  static List<int> _v(String s) => [for (final p in s.split(RegExp(r'[.+\-]'))) int.tryParse(p) ?? 0];

  static bool newer(String a, String b) {
    final x = _v(a), y = _v(b);
    for (var i = 0; i < 4; i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }
    return false;
  }

  /// يقرأ ملف التحديث: {"version":"3.7.1","apk":"https://…/app.apk","notes":["…"],"size":19000000}
  static Future<UpdateInfo?> check() async {
    final c = AppState.I.cfg;
    final url = c.s('update.url').trim();
    c.set('update.last', DateTime.now().millisecondsSinceEpoch);
    if (url.isEmpty) {
      lastError = 'ما محدد رابط التحديث';
      return null;
    }
    if (!_trusted(url)) {
      lastError = 'رابط التحديث لازم يكون https من GitHub';
      return null;
    }
    try {
      final cl = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final rq = await cl.getUrl(Uri.parse(url));
      final rs = await rq.close().timeout(const Duration(seconds: 12));
      final body = await rs.transform(utf8.decoder).join();
      cl.close();
      final m = jsonDecode(body) as Map<String, dynamic>;
      final v = '${m['version'] ?? ''}';
      final info = UpdateInfo(v, '${m['apk'] ?? ''}', [for (final n in (m['notes'] as List? ?? const [])) '$n'], (m['size'] as num?)?.toInt() ?? 0, '${m['sha256'] ?? ''}'.toLowerCase());
      if (!_trusted(info.apk)) {
        lastError = 'رابط التحديث مو من GitHub الآمن، ما راح ننزله';
        available.value = null;
        return null;
      }
      lastError = '';
      if (v.isNotEmpty && info.apk.isNotEmpty && newer(v, AppState.I.version)) {
        if (available.value?.version != v) Notices.add('cloud-download', 'تحديث $v جاهز', 'افتحه من الإعدادات ← التحديث التلقائي');
        available.value = info;
        return info;
      }
      available.value = null;
      return null;
    } catch (e) {
      lastError = 'تعذر الوصول لملف التحديث';
      return null;
    }
  }

  /// مرحلة التحديث الحالية حتى تبين بالنافذة: تنزيل · تحقق · تجهيز · موافقة.
  static final ValueNotifier<String> phase = ValueNotifier('');

  /// ينزّل الملف (مع مهلة إذا الشبكة وكفت)، يتحقق منه بالخلفية حتى الواجهة ما تعلگ،
  /// يسلّمه للنظام، وإذا النظام يريد موافقة يفتح شاشتها من الواجهة نفسها.
  static Future<bool> downloadAndInstall(UpdateInfo u) async {
    if (progress.value != null) return false;
    progress.value = 0;
    phase.value = 'جاري التنزيل';
    File? f;
    try {
      final dir = await Backups.dir();
      if (dir == null) throw 'no dir';
      f = File('${dir.parent.path}/rawnaq-update.apk');
      var done = false;
      for (var attempt = 0; attempt < 2 && !done; attempt++) {
        final cl = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        try {
          final rs = await (await cl.getUrl(Uri.parse(u.apk))).close().timeout(const Duration(seconds: 30));
          if (rs.statusCode != 200) throw 'http ${rs.statusCode}';
          final total = rs.contentLength > 0 ? rs.contentLength : u.size;
          final sink = f.openWrite();
          var got = 0;
          try {
            // إذا ما وصل شي ٤٠ ثانية نعتبرها انقطاع ونعيد مرة وحدة
            await for (final chunk in rs.timeout(const Duration(seconds: 40))) {
              sink.add(chunk);
              got += chunk.length;
              if (total > 0) progress.value = (got / total).clamp(0, 0.99).toDouble();
            }
          } finally {
            await sink.close();
          }
          done = true;
        } catch (_) {
          if (attempt == 1) rethrow;
        } finally {
          cl.close(force: true);
        }
      }
      // تحقق قبل التثبيت: الحجم وبصمة SHA-256 — البصمة تنحسب بمعالج ثاني حتى الواجهة ما تعلگ
      phase.value = 'جاري التحقق من الملف';
      progress.value = 1;
      if (u.size > 0 && await f.length() != u.size) throw 'size';
      if (u.sha256.isNotEmpty) {
        final path = f.path;
        final digest = await Isolate.run(() async => (await crypto.sha256.bind(File(path).openRead()).first).toString());
        if (digest != u.sha256) throw 'hash';
      }
      if (AppState.I.cfg.b('update.backup')) {
        phase.value = 'حفظ نسخة احتياطية';
        try {
          await Backups.create().timeout(const Duration(seconds: 20));
        } catch (_) {}
      }
      phase.value = 'تجهيز التثبيت';
      final handed = await Streamer.installApk(f.path);
      if (!handed) throw 'install';
      ActivityLog.add('cloud-download', 'تحديث للإصدار ${Ar.n(u.version)}', 'تم تسليمه للنظام', kind: 'update');
      // ننتظر جواب النظام: يا ينصب وحده (أندرويد ١٢+)، يا يطلب موافقة فنفتح شاشتها
      phase.value = 'بانتظار النظام';
      for (var i = 0; i < 120; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final st = await Streamer.updateStatus();
        final code = (st?['status'] as int?) ?? -99;
        if (code == -99) continue;
        if (code == -1) {
          phase.value = 'وافق على التثبيت بالشاشة اللي طلعت';
          await Streamer.confirmInstall();
          break;
        }
        if (code == 0) {
          phase.value = 'تم التثبيت، رونق يعيد التشغيل';
          break;
        }
        throw 'status:${st?['message'] ?? code}';
      }
      progress.value = null;
      return true;
    } catch (e) {
      final m = '$e';
      lastError = e == 'hash' || e == 'size'
          ? 'الملف المنزّل ما يطابق بصمة الإصدار، انمسح للأمان'
          : m.startsWith('status:')
              ? 'النظام رفض التثبيت: ${m.substring(7)}'
              : e == 'install'
                  ? 'النظام ما قبل ملف التحديث'
                  : 'فشل التنزيل، تأكد من الشبكة وجرب مرة ثانية';
      if (e == 'hash' || e == 'size') ActivityLog.add('lock', 'رُفض ملف تحديث', 'بصمته ما تطابق الإصدار', kind: 'update');
      try {
        f?.deleteSync();
      } catch (_) {}
      progress.value = null;
      phase.value = '';
      return false;
    }
  }

  /// التحديث يقبل بس https من GitHub (الملف نفسه والتحويل لخوادم GitHub تلقائي).
  static bool _trusted(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https') return false;
    return u.host == 'github.com' || u.host.endsWith('.github.com') || u.host.endsWith('.githubusercontent.com');
  }

  /// فحص دوري (كل ١٥ دقيقة افتراضياً، ويه كل رجوع للواجهة). إذا التثبيت التلقائي مفعّل ورونق بالواجهة:
  /// ينزّل وينصب مباشرة (أندرويد ١٢+ بدون سؤال بعد أول تحديث ذاتي، وغيره شاشة موافقة وحدة).
  static Future<void> tick() async {
    final c = AppState.I.cfg;
    if (!c.b('update.auto') || c.s('update.url').isEmpty) return;
    final last = DateTime.fromMillisecondsSinceEpoch(c.i('update.last'));
    // الفحص خفيف جداً (ملف صغير)، فنخليه متقارب حتى النسخة توصل خلال دقائق من نشرها
    if (DateTime.now().difference(last) < Duration(minutes: c.i('update.every').clamp(5, 1440))) return;
    final u = await check();
    if (u == null || !c.b('update.autoInstall') || progress.value != null || Profiles.kids) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    await downloadAndInstall(u);
  }
}

// ═══════════════════ التلفزيون والطاقة (القابس الذكي) ═══════════════════

class PlugCfg {
  static String url(bool on, {String? kind, String? ip}) {
    final c = AppState.I.cfg;
    final k = kind ?? c.s('plug.kind');
    final h = (ip ?? c.s('plug.ip')).trim();
    if (h.isEmpty) return '';
    return switch (k) {
      'shelly1' => 'http://$h/relay/0?turn=${on ? 'on' : 'off'}',
      'tasmota' => 'http://$h/cm?cmnd=Power%20${on ? 'On' : 'Off'}',
      _ => 'http://$h/rpc/Switch.Set?id=0&on=$on',
    };
  }

  /// يرسل الإعداد للطبقة الأصلية (تراقب نوم وصحيان الستريمر).
  static Future<void> apply() {
    final c = AppState.I.cfg;
    return Streamer.powerConfig(method: c.s('power.method'), off: url(false), on: url(true), wait: c.i('plug.wait'));
  }

  static Future<bool> get(String u) async {
    if (u.isEmpty) return false;
    try {
      final cl = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final rs = await (await cl.getUrl(Uri.parse(u))).close().timeout(const Duration(seconds: 6));
      await rs.drain<void>();
      cl.close();
      return rs.statusCode >= 200 && rs.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// يكتشف نوع القابس على هذا العنوان.
  static Future<String?> detect(String ip) async {
    if (await get('http://$ip/rpc/Shelly.GetDeviceInfo')) return 'shelly2';
    if (await get('http://$ip/shelly')) return 'shelly1';
    if (await get('http://$ip/cm?cmnd=Status')) return 'tasmota';
    return null;
  }
}

// ═══════════════════ التقويم الهجري والمناسبات ═══════════════════

class HijriDay {
  final int y, m, d;
  final DateTime g;
  const HijriDay(this.y, this.m, this.d, this.g);
}

class Hijri {
  static int get offset => AppState.I.cfg.i('misc.hijriOffset');

  static HijriDay of(DateTime g) {
    final h = HijriCalendar.fromDate(g.add(Duration(days: offset)));
    return HijriDay(h.hYear, h.hMonth, h.hDay, DateTime(g.year, g.month, g.day));
  }

  /// أيام الشهر الهجري الحالي مع التاريخ الميلادي المقابل.
  static List<HijriDay> month(DateTime around) {
    final t = of(around);
    final start = DateTime(around.year, around.month, around.day).subtract(Duration(days: t.d - 1));
    final out = <HijriDay>[];
    for (var i = 0; i < 31; i++) {
      final g = start.add(Duration(days: i));
      final h = of(g);
      if (h.m != t.m) break;
      out.add(h);
    }
    return out;
  }

  /// المناسبات (الشهر، اليوم) — التقويم المعتمد بالعراق.
  static const occasions = <(int, int), String>{
    (1, 1): 'رأس السنة الهجرية',
    (1, 10): 'ذكرى عاشوراء، استشهاد الإمام الحسين (ع)',
    (2, 20): 'زيارة الأربعين',
    (2, 28): 'ذكرى وفاة النبي (ص) واستشهاد الإمام الحسن (ع)',
    (3, 8): 'ذكرى استشهاد الإمام الحسن العسكري (ع)',
    (3, 17): 'المولد النبوي الشريف',
    (6, 3): 'ذكرى استشهاد السيدة فاطمة الزهراء (ع)',
    (6, 20): 'ذكرى ولادة السيدة فاطمة الزهراء (ع)',
    (7, 1): 'ذكرى ولادة الإمام محمد الباقر (ع)',
    (7, 13): 'ذكرى ولادة الإمام علي (ع)',
    (7, 25): 'ذكرى استشهاد الإمام موسى الكاظم (ع)',
    (7, 27): 'المبعث النبوي الشريف',
    (8, 3): 'ذكرى ولادة الإمام الحسين (ع)',
    (8, 15): 'ذكرى ولادة الإمام المهدي (عج)',
    (9, 1): 'أول شهر رمضان المبارك',
    (9, 15): 'ذكرى ولادة الإمام الحسن (ع)',
    (9, 19): 'ذكرى ضربة الإمام علي (ع)',
    (9, 21): 'ذكرى استشهاد الإمام علي (ع)',
    (9, 23): 'ليلة القدر',
    (10, 1): 'عيد الفطر المبارك',
    (10, 25): 'ذكرى استشهاد الإمام جعفر الصادق (ع)',
    (11, 11): 'ذكرى ولادة الإمام علي الرضا (ع)',
    (12, 9): 'يوم عرفة',
    (12, 10): 'عيد الأضحى المبارك',
    (12, 18): 'عيد الغدير الأغر',
  };

  static String? occasionOf(HijriDay h) => occasions[(h.m, h.d)];

  /// المناسبات القادمة خلال [days] يوم.
  static List<(HijriDay, String)> upcoming({int days = 120, int max = 6}) {
    final now = DateTime.now();
    final out = <(HijriDay, String)>[];
    for (var i = 0; i < days && out.length < max; i++) {
      final h = of(now.add(Duration(days: i)));
      final o = occasionOf(h);
      if (o != null) out.add((h, o));
    }
    return out;
  }

  static String label(HijriDay h) => '${Ar.n(h.d)} ${Ar.hijriMonths[h.m - 1]}';
}

// ═══════════════════ المحتوى اليومي ═══════════════════

class Daily {
  static const ayat = [
    ('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ', 'سورة الرعد، الآية ٢٨'),
    ('وَقُل رَّبِّ زِدْنِي عِلْمًا', 'سورة طه، الآية ١١٤'),
    ('إِنَّ مَعَ الْعُسْرِ يُسْرًا', 'سورة الشرح، الآية ٦'),
    ('وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ', 'سورة الطلاق، الآية ٣'),
    ('فَاذْكُرُونِي أَذْكُرْكُمْ', 'سورة البقرة، الآية ١٥٢'),
    ('وَاصْبِرْ وَمَا صَبْرُكَ إِلَّا بِاللَّهِ', 'سورة النحل، الآية ١٢٧'),
    ('لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا', 'سورة البقرة، الآية ٢٨٦'),
    ('وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ', 'سورة الحديد، الآية ٤'),
    ('رَبِّ اشْرَحْ لِي صَدْرِي', 'سورة طه، الآية ٢٥'),
    ('وَقُولُوا لِلنَّاسِ حُسْنًا', 'سورة البقرة، الآية ٨٣'),
    ('إِنَّ اللَّهَ مَعَ الصَّابِرِينَ', 'سورة البقرة، الآية ١٥٣'),
    ('وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ', 'سورة الضحى، الآية ٥'),
  ];
  static const ahadith = [
    ('«إنّما الأعمالُ بالنيّات»', 'حديث نبوي شريف'),
    ('«الكلمةُ الطيّبةُ صدقة»', 'حديث نبوي شريف'),
    ('«خيرُكم مَن تعلّم القرآنَ وعلّمه»', 'حديث نبوي شريف'),
    ('«تبسّمُك في وجهِ أخيك صدقة»', 'حديث نبوي شريف'),
    ('«أنا مدينةُ العلمِ وعليٌّ بابُها»', 'حديث نبوي شريف'),
    ('«قيمةُ كلِّ امرئٍ ما يُحسنُه»', 'الإمام علي (ع)، نهج البلاغة'),
    ('«الناسُ صنفان: إمّا أخٌ لك في الدين، أو نظيرٌ لك في الخلق»', 'الإمام علي (ع)، نهج البلاغة'),
  ];
  static const adiya = [
    ('اللّهمّ صلِّ على محمدٍ وآلِ محمد', 'الصلوات'),
    ('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 'سورة البقرة، الآية ٢٠١'),
    ('رَّبِّ اغْفِرْ لِي وَلِوَالِدَيَّ', 'سورة نوح، الآية ٢٨'),
    ('حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ', 'سورة آل عمران، الآية ١٧٣'),
    ('يا مقلّبَ القلوب، ثبّت قلبي على دينك', 'دعاء مأثور'),
    ('لا حولَ ولا قوّةَ إلّا بالله العليّ العظيم', 'ذكر'),
  ];

  static List<(String, String)> list(String kind) => switch (kind) { 'hadith' => ahadith, 'dua' => adiya, _ => ayat };

  static (String, String) today([String? kind, DateTime? at]) {
    final t = at ?? DateTime.now();
    final l = list(kind ?? AppState.I.cfg.s('daily.kind'));
    final day = t.difference(DateTime(t.year)).inDays;
    return l[day % l.length];
  }

  static bool get onHome {
    final c = AppState.I.cfg;
    if (!c.b('daily.on') || c.s('daily.where') == 'saver') return false;
    return !(Profiles.kids && !c.b('daily.kids'));
  }

  static bool get onSaver {
    final c = AppState.I.cfg;
    if (!c.b('daily.on') || c.s('daily.where') == 'home') return false;
    return !(Profiles.kids && !c.b('daily.kids'));
  }
}

// ═══════════════════ التشغيل ═══════════════════

class StreamerServices {
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    NativeBridge.onLaunch = (p) {
      Recents.record(p);
      KidsLog.lastApp = p;
    };
    Notices.start();
    PlugCfg.apply();
    Streamer.guardSet(AppState.I.cfg.b('guard.on'));
    Timer.periodic(const Duration(seconds: 20), (_) {
      Profiles.tick(20);
    });
    Future.delayed(const Duration(seconds: 8), WeatherHub.start);
    FamilyServices.start();
    Future.delayed(const Duration(seconds: 40), Updater.tick);
    Timer.periodic(const Duration(minutes: 5), (_) => Updater.tick());
  }
}
