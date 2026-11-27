import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'arabic.dart';
import 'config.dart';
import 'prayer.dart';
import 'state.dart';
import 'streamer_services.dart';

// ═══════════════════════════════════════════════════════════════════════
//  خدمات صفحتي ١٢ و١٣: رمز الأهل، سجل النشاط، سجل الأطفال، المناسبات،
//  رمضان، والمزامنة بين شاشات البيت.
// ═══════════════════════════════════════════════════════════════════════

Config get _c => AppState.I.cfg;

String dayKey(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

// ═══════════════════ رمز الأهل: محاولات وقفل مؤقت ═══════════════════

class PinGuard {
  static int get attemptsLeft => (_c.i('pin.attempts') - _c.i('pin.fails')).clamp(0, 99);
  static DateTime? get lockedUntil {
    final u = _c.i('pin.until');
    if (u <= 0) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(u);
    return t.isAfter(DateTime.now()) ? t : null;
  }

  static bool get locked => lockedUntil != null;

  /// يتحقق من الرمز: الصح يصفّر العداد، والغلط يحسب، وبعد الحد ينقفل مؤقتاً.
  static bool verify(String v) {
    if (locked) return false;
    if (v == _c.s('misc.pin')) {
      _c.set('pin.fails', 0);
      return true;
    }
    final fails = _c.i('pin.fails') + 1;
    if (fails >= _c.i('pin.attempts')) {
      _c.set('pin.fails', 0);
      _c.set('pin.until', DateTime.now().add(Duration(minutes: _c.i('pin.lockMins'))).millisecondsSinceEpoch);
      ActivityLog.add('lock', 'انقفل رمز الأهل مؤقتاً', 'بعد ${Ar.n(_c.i('pin.attempts'))} محاولات غلط');
      Notices.add('lock', 'محاولات رمز غلط', 'الرمز انقفل ${Ar.n(_c.i('pin.lockMins'))} دقائق');
    } else {
      _c.set('pin.fails', fails);
    }
    return false;
  }

  static void change(String v) {
    _c.set('misc.pin', v);
    _c.set('pin.changed', DateTime.now().millisecondsSinceEpoch);
    ActivityLog.add('key-round', 'تغيّر رمز الأهل', '');
  }
}

// ═══════════════════ سجل النشاط ═══════════════════

class LogEntry {
  final DateTime t;
  final String icon, title, sub, kind;
  const LogEntry(this.t, this.icon, this.title, this.sub, this.kind);
}

class ActivityLog {
  static final ValueNotifier<int> rev = ValueNotifier(0);

  static List<LogEntry> get all {
    try {
      final l = jsonDecode(_c.s('activity.log'));
      if (l is! List) return [];
      return [
        for (final m in l.whereType<Map>())
          LogEntry(DateTime.fromMillisecondsSinceEpoch((m['t'] as num?)?.toInt() ?? 0), '${m['i'] ?? 'info'}', '${m['a'] ?? ''}', '${m['b'] ?? ''}', '${m['k'] ?? 'misc'}'),
      ];
    } catch (_) {
      return [];
    }
  }

  /// [kind]: profile | guard | power | update | backup | kids | security | misc
  static void add(String icon, String title, String sub, {String kind = 'misc'}) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final l = [
      {'t': DateTime.now().millisecondsSinceEpoch, 'i': icon, 'a': title, 'b': sub, 'k': kind},
      for (final e in all)
        if (e.t.millisecondsSinceEpoch > cutoff) {'t': e.t.millisecondsSinceEpoch, 'i': e.icon, 'a': e.title, 'b': e.sub, 'k': e.kind},
    ].take(300).toList();
    _c.set('activity.log', jsonEncode(l));
    rev.value++;
  }

  static int countWeek(String kind) {
    final from = DateTime.now().subtract(const Duration(days: 7));
    return all.where((e) => e.kind == kind && e.t.isAfter(from)).length;
  }

  static void clear() {
    _c.set('activity.log', '');
    rev.value++;
  }
}

// ═══════════════════ سجل الأطفال (للتقرير الأسبوعي) ═══════════════════

class KidsLog {
  static String? lastApp;

  static Map<String, int> _map(String key) {
    try {
      final m = jsonDecode(_c.s(key));
      if (m is Map) return {for (final e in m.entries) '${e.key}': (e.value as num).toInt()};
    } catch (_) {}
    return {};
  }

  /// دقائق كل يوم (آخر ١٤ يوم).
  static Map<String, int> get days => _map('kids.log');

  /// دقائق كل تطبيق (آخر ٧ أيام تقريباً).
  static Map<String, int> get apps => _map('kids.appLog');

  static void addMinutes(int m) {
    if (m <= 0) return;
    final d = days;
    final k = dayKey(DateTime.now());
    d[k] = (d[k] ?? 0) + m;
    final keep = (d.keys.toList()..sort()).reversed.take(14).toSet();
    d.removeWhere((key, _) => !keep.contains(key));
    _c.set('kids.log', jsonEncode(d));
    final app = lastApp;
    if (app != null) {
      final a = apps;
      a[app] = (a[app] ?? 0) + m;
      _c.set('kids.appLog', jsonEncode(a));
    }
  }

  /// آخر ٧ أيام بالترتيب (الأقدم أولاً).
  static List<(DateTime, int)> week() {
    final d = days;
    final now = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        (DateTime(now.year, now.month, now.day).subtract(Duration(days: i)), d[dayKey(now.subtract(Duration(days: i)))] ?? 0),
    ];
  }

  static bool isWeekend(DateTime t) => _c.s('kids.weekendDays').split(',').contains('${t.weekday}');

  /// حد اليوم حسب يوم عادي أو عطلة.
  static int limitFor(DateTime t) {
    final w = _c.i('kids.weekend');
    return isWeekend(t) && w > 0 ? w : _c.i('kids.limit');
  }

  /// كل أسبوع (يوم السبت) يرسل التقرير لمركز التنبيهات.
  static void tick() {
    final now = DateTime.now();
    if (now.weekday != DateTime.saturday || now.hour < 10) return;
    final k = 'kids.rep.${dayKey(now)}';
    if (AppState.I.prefs.getBool(k) == true) return;
    AppState.I.prefs.setBool(k, true);
    final total = week().fold<int>(0, (a, b) => a + b.$2);
    if (total > 0) Notices.add('chart-column', 'تقرير الأطفال الأسبوعي', 'شاهدوا ${Ar.n((total / 60).toStringAsFixed(1)).replaceAll('.', '٫')} ساعة هذا الأسبوع');
  }
}

// ═══════════════════ وضع المناسبات ═══════════════════

class OccasionMode {
  /// ترحيب يوم المناسبة (main.dart يعرضه فوق الواجهة).
  static final ValueNotifier<(String, String)?> welcome = ValueNotifier(null);

  static bool get mourning {
    final h = Hijri.of(DateTime.now());
    return h.m == 1 && h.d <= 13 || (h.m == 2 && h.d >= 18 && h.d <= 21);
  }

  static void tick() {
    if (!_c.b('occ.mode')) return;
    final now = DateTime.now();
    final h = Hijri.of(now);
    // ثيم الحسيني بعشرة محرم والأربعين، ويرجع الثيم السابق بعدها
    if (_c.b('occ.theme')) {
      final cur = _c.s('theme.preset');
      if (mourning && cur != 'husaini') {
        _c.set('occ.prevPreset', cur);
        final p = ThemePreset.byId('husaini');
        AppState.I.applyTheme(p);
        ActivityLog.add('calendar-heart', 'ثيم الحسيني', 'بمناسبة ${Ar.hijriMonths[h.m - 1]}', kind: 'misc');
      } else if (!mourning && _c.s('occ.prevPreset').isNotEmpty) {
        final prev = _c.s('occ.prevPreset');
        _c.set('occ.prevPreset', '');
        if (cur == 'husaini') {
          AppState.I.applyTheme(ThemePreset.byId(prev));
        }
      }
    }
    final o = Hijri.occasionOf(h);
    if (o != null && _c.b('occ.welcome') && _c.s('occ.shown') != dayKey(now) && now.hour >= 8) {
      _c.set('occ.shown', dayKey(now));
      welcome.value = (o, Hijri.label(h));
    }
  }
}

// ═══════════════════ رمضان ═══════════════════

class Ramadan {
  static bool get active {
    final m = _c.s('ramadan.mode');
    if (m == 'on') return true;
    if (m == 'off') return false;
    return Hijri.of(DateTime.now()).m == 9;
  }

  static int get day => Hijri.of(DateTime.now()).d;

  static DateTime? _t(String id, DateTime day) {
    for (final p in Prayers.forDay(day)) {
      if (p.id == id) return p.time;
    }
    return null;
  }

  static DateTime? get imsak => _t('imsak', DateTime.now());
  static DateTime? get iftar => _t('maghrib', DateTime.now());

  /// الحدث الجاي: (الاسم، الوقت).
  static (String, DateTime)? get next {
    final now = DateTime.now();
    final im = imsak, ift = iftar;
    if (ift != null && now.isBefore(ift) && (im == null || now.isAfter(im))) return ('الإفطار', ift);
    if (im != null && now.isBefore(im)) return ('الإمساك', im);
    final tm = _t('imsak', now.add(const Duration(days: 1)));
    return tm == null ? null : ('الإمساك', tm);
  }
}

// ═══════════════════ المزامنة بين شاشات البيت ═══════════════════

class SyncPeer {
  final String ip, name, version;
  const SyncPeer(this.ip, this.name, this.version);
  Map<String, String> toJson() => {'ip': ip, 'n': name, 'v': version};
}

class Sync {
  static const port = 8787;
  static HttpServer? _server;
  static final ValueNotifier<int> rev = ValueNotifier(0);
  static bool scanning = false;
  static String myIp = '';

  static List<SyncPeer> get peers {
    try {
      final l = jsonDecode(_c.s('sync.peers'));
      if (l is List) return [for (final m in l.whereType<Map>()) SyncPeer('${m['ip']}', '${m['n']}', '${m['v'] ?? ''}')];
    } catch (_) {}
    return [];
  }

  static void _savePeers(List<SyncPeer> l) {
    _c.set('sync.peers', jsonEncode([for (final p in l) p.toJson()]));
    rev.value++;
  }

  static List<String> get _prefixes => [
        if (_c.b('sync.theme')) ...['day.', 'night.', 'theme.', 'font.', 'ui.', 'tile.', 'home.', 'motion.', 'saver.'],
        if (_c.b('sync.profiles')) ...['kids.limit', 'kids.bed', 'kids.name', 'kids.weekend', 'kids.weekendDays', 'kids.step', 'kids.style', 'guest.hours'],
      ];

  static Map<String, Object> _payload() {
    final s = AppState.I;
    final pre = _prefixes;
    return {
      'app': 'rawnaq',
      'from': _c.s('sync.name'),
      'config': {for (final e in s.cfg.dump().entries) if (pre.any(e.key.startsWith)) e.key: e.value},
      if (_c.b('sync.favorites')) 'favorites': s.favorites,
    };
  }

  static void _apply(Map<String, dynamic> m) {
    final s = AppState.I;
    final conf = m['config'];
    if (conf is Map) {
      for (final e in conf.entries) {
        final k = '${e.key}';
        // بس الثيم والترتيب والملفات اللي فعّلتها: ما ينقبل رابط تحديث ولا رمز ولا إعدادات طاقة من برّه
        if (Config.defaults.containsKey(k) && e.value != null && _prefixes.any(k.startsWith)) s.cfg.set(k, e.value as Object);
      }
    }
    final fav = m['favorites'];
    if (fav is List) {
      s.restoreLists(favorites: fav.map((e) => '$e').where((p) => s.app(p) != null).toList(), labels: s.labels, artModes: s.artModes, locked: s.locked.toList());
    }
    _c.set('sync.last', DateTime.now().millisecondsSinceEpoch);
    ActivityLog.add('monitor-smartphone', 'وصلت إعدادات من «${m['from'] ?? 'شاشة ثانية'}»', 'الثيم والترتيب', kind: 'misc');
    s.touch();
  }

  /// يشغّل أو يوقف خادم المزامنة الصغير حسب الإعداد.
  static Future<void> apply() async {
    if (_c.b('sync.on')) {
      if (_server != null) return;
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
        _server!.listen(_handle, onError: (_) {});
      } catch (_) {
        _server = null;
      }
      myIp = await localIp() ?? '';
    } else {
      await _server?.close(force: true);
      _server = null;
    }
    rev.value++;
  }

  // حماية المزامنة: محاولات الرمز الغلط من كل جهاز محدودة، والرمز السهل ممنوع.
  static final Map<String, (int, DateTime)> _fails = {};
  static bool get weakPin => const {'0000', '1234', '1111', '0123', '4321'}.contains(_c.s('misc.pin'));

  static Future<void> _handle(HttpRequest r) async {
    try {
      r.response.headers.contentType = ContentType.json;
      final path = r.uri.path;
      final ip = r.connectionInfo?.remoteAddress.address ?? '?';
      final f = _fails[ip];
      final blocked = f != null && f.$1 >= 5 && DateTime.now().difference(f.$2) < const Duration(minutes: 15);
      if (path == '/rawnaq') {
        r.response.write(jsonEncode({'app': 'rawnaq', 'name': _c.s('sync.name'), 'v': AppState.I.version}));
      } else if (blocked) {
        r.response.statusCode = 429;
        r.response.write('{"error":"locked"}');
      } else if (weakPin) {
        r.response.statusCode = 403;
        r.response.write('{"error":"weak-pin"}');
      } else if (r.headers.value('x-pin') != _c.s('misc.pin')) {
        final n = (f == null || DateTime.now().difference(f.$2) > const Duration(minutes: 15)) ? 1 : f.$1 + 1;
        _fails[ip] = (n, DateTime.now());
        if (n == 5) {
          ActivityLog.add('lock', 'محاولات رمز غلط من جهاز بالشبكة', ip, kind: 'guard');
          Notices.add('lock', 'محاولات دخول للمزامنة', 'جهاز $ip جرّب رموز غلط، وانقفل ربع ساعة');
        }
        await Future.delayed(const Duration(milliseconds: 600)); // يبطّئ التخمين
        r.response.statusCode = 403;
        r.response.write('{"error":"pin"}');
      } else if (path == '/config' && r.method == 'GET') {
        _fails.remove(ip);
        r.response.write(jsonEncode(_payload()));
      } else if (path == '/config' && r.method == 'POST') {
        _fails.remove(ip);
        if ((r.contentLength) > 256 * 1024) throw 'too big';
        final body = await utf8.decoder.bind(r).join();
        if (body.length > 256 * 1024) throw 'too big';
        _apply(jsonDecode(body) as Map<String, dynamic>);
        r.response.write('{"ok":true}');
      } else {
        r.response.statusCode = 404;
      }
    } catch (_) {
      r.response.statusCode = 500;
    }
    await r.response.close();
  }


  static Future<String?> localIp() async {
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (!a.isLoopback && (a.address.startsWith('192.168.') || a.address.startsWith('10.') || a.address.startsWith('172.'))) return a.address;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> _get(String ip, String path, {Duration t = const Duration(milliseconds: 700), bool pin = false}) async {
    final cl = HttpClient()..connectionTimeout = t;
    try {
      final rq = await cl.getUrl(Uri.parse('http://$ip:$port$path'));
      if (pin) rq.headers.set('x-pin', _c.s('misc.pin'));
      final rs = await rq.close().timeout(t * 3);
      if (rs.statusCode != 200) return null;
      return jsonDecode(await utf8.decoder.bind(rs).join()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      cl.close(force: true);
    }
  }

  /// يدور على شاشات رونق بنفس الشبكة.
  static Future<List<SyncPeer>> discover() async {
    final ip = myIp.isNotEmpty ? myIp : (await localIp() ?? '');
    if (ip.isEmpty) return peers;
    scanning = true;
    rev.value++;
    final base = ip.substring(0, ip.lastIndexOf('.') + 1);
    final found = <SyncPeer>[];
    for (var start = 1; start < 255; start += 32) {
      await Future.wait([
        for (var k = start; k < start + 32 && k < 255; k++)
          if ('$base$k' != ip)
            _get('$base$k', '/rawnaq').then((m) {
              if (m != null && m['app'] == 'rawnaq') found.add(SyncPeer('$base$k', '${m['name'] ?? 'شاشة'}', '${m['v'] ?? ''}'));
            }),
      ]);
    }
    scanning = false;
    final merged = {for (final p in [...peers, ...found]) p.ip: p}.values.toList();
    _savePeers(merged);
    return merged;
  }

  /// يرسل إعدادات هذي الشاشة للشاشة الثانية.
  static Future<bool> push(SyncPeer p) async {
    final cl = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final rq = await cl.postUrl(Uri.parse('http://${p.ip}:$port/config'));
      rq.headers.set('x-pin', _c.s('misc.pin'));
      rq.headers.contentType = ContentType.json;
      rq.add(utf8.encode(jsonEncode(_payload())));
      final rs = await rq.close().timeout(const Duration(seconds: 8));
      final ok = rs.statusCode == 200;
      if (ok) {
        _c.set('sync.last', DateTime.now().millisecondsSinceEpoch);
        ActivityLog.add('monitor-smartphone', 'نُسخت الإعدادات إلى «${p.name}»', p.ip);
        rev.value++;
      }
      return ok;
    } catch (_) {
      return false;
    } finally {
      cl.close(force: true);
    }
  }

  /// يجيب إعدادات الشاشة الثانية ويطبقها هنا.
  static Future<bool> pull(SyncPeer p) async {
    final m = await _get(p.ip, '/config', t: const Duration(seconds: 3), pin: true);
    if (m == null) return false;
    _apply(m);
    return true;
  }

  static void forget(SyncPeer p) => _savePeers(peers.where((x) => x.ip != p.ip).toList());
}

// ═══════════════════ التشغيل ═══════════════════

class FamilyServices {
  static bool _started = false;
  static void start() {
    // تنبيه مرة وحدة إذا رمز الأهل بعده الافتراضي
    if (Sync.weakPin && !_c.b('pin.warned')) {
      _c.set('pin.warned', true);
      Notices.add('key-round', 'غيّر رمز الأهل', 'الرمز الحالي سهل التخمين: الإعدادات ← الأمان ورمز الأهل');
    }
    if (_started) return;
    _started = true;
    Sync.apply();
    Timer.periodic(const Duration(minutes: 1), (_) {
      OccasionMode.tick();
      KidsLog.tick();
      _guestTick();
    });
    Future.delayed(const Duration(seconds: 12), OccasionMode.tick);
  }

  static void _guestTick() {
    final h = _c.i('guest.hours');
    if (!Profiles.guest || h <= 0) return;
    final since = _c.i('guest.since');
    if (since > 0 && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(since)).inMinutes >= h * 60) {
      AppState.I.set('profile.active', 'family');
      ActivityLog.add('users', 'رجع ملف العائلة', 'انتهت مدة الضيف', kind: 'profile');
    }
  }
}
