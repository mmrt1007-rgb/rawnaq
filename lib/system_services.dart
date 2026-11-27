import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arabic.dart';
import 'build_info.dart';
import 'platform.dart';
import 'state.dart';
import 'family_services.dart' show ActivityLog;
import 'streamer_services.dart';

// ═══════════════════ حارس الإقلاع (الوضع الآمن) ═══════════════════

/// يعدّ مرات التشغيل المتقاربة: إذا التطبيق انفتح ٣ مرات خلال دقيقتين (يعني يطيح ويرجع)
/// يفتح بالوضع الآمن. بعد ٤٠ ثانية تشغيل مستقر يرجع العداد صفر.
class BootGuard {
  static Future<bool> check() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      var n = sp.getInt('boot.crashes') ?? 0;
      if (now - (sp.getInt('boot.last') ?? 0) > 120000) n = 0;
      n++;
      await sp.setInt('boot.crashes', n);
      await sp.setInt('boot.last', now);
      Future.delayed(const Duration(seconds: 40), () => sp.setInt('boot.crashes', 0));
      return n >= 3;
    } catch (_) {
      return false;
    }
  }
}

/// سجل الأخطاء على الجهاز (نفس ملف main.dart).
class ErrorLog {
  static Future<File?> file() async {
    try {
      final dir = await NativeBridge.wallpaperDir();
      if (dir.isEmpty) return null;
      return File('${File(dir).parent.path}/rawnaq-errors.log');
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> lastErrors({int max = 20}) async {
    final f = await file();
    if (f == null || !f.existsSync()) return const [];
    final lines = f.readAsLinesSync().where((l) => RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(l)).toList();
    return lines.reversed.take(max).toList();
  }

  /// عدد الأعطال خلال آخر ٧ أيام.
  static Future<int> weekCount() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    var n = 0;
    for (final l in await lastErrors(max: 500)) {
      final t = DateTime.tryParse(l.split(' ').first);
      if (t != null && t.isAfter(since)) n++;
    }
    return n;
  }
}

// ═══════════════════ النسخ الاحتياطي ═══════════════════

class BackupInfo {
  final File file;
  final DateTime time;
  final bool auto;
  final int keys, bytes;
  const BackupInfo(this.file, this.time, this.auto, this.keys, this.bytes);
}

class Backups {
  static Future<Directory?> dir() async {
    final w = await NativeBridge.wallpaperDir();
    if (w.isEmpty) return null;
    final d = Directory('${File(w).parent.path}/backups');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Map<String, dynamic> _payload(bool auto) {
    final s = AppState.I;
    return {
      'app': 'rawnaq',
      'version': 1,
      'time': DateTime.now().toIso8601String(),
      'auto': auto,
      'config': s.cfg.dump(),
      'favorites': s.favorites,
      'labels': s.labels,
      'artModes': s.artModes,
      'locked': s.locked.toList(),
    };
  }

  static String _name(DateTime t, bool auto) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'rawnaq-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${auto ? '-auto' : ''}.json';
  }

  /// نسخة الآن. التلقائية تحتفظ بآخر ٧ نسخ فقط.
  static Future<BackupInfo?> create({bool auto = false, Directory? into}) async {
    final d = into ?? await dir();
    if (d == null) return null;
    final now = DateTime.now();
    final f = File('${d.path}/${_name(now, auto)}');
    final data = const JsonEncoder.withIndent(' ').convert(_payload(auto));
    await f.writeAsString(data, flush: true);
    if (into == null) {
      AppState.I.cfg.set('backup.last', now.millisecondsSinceEpoch);
      if (auto) {
        Notices.add('download', 'نسخة احتياطية تلقائية', 'تمت، ${Ar.n((data.length / 1024).ceil())} ك.ب');
        ActivityLog.add('download', 'نسخة احتياطية تلقائية', '${Ar.n((data.length / 1024).ceil())} ك.ب', kind: 'backup');
        final autos = (await list()).where((b) => b.auto).toList();
        for (final b in autos.skip(7)) {
          try {
            b.file.deleteSync();
          } catch (_) {}
        }
      }
    }
    return BackupInfo(f, now, auto, AppState.I.cfg.dump().length, data.length);
  }

  static Future<List<BackupInfo>> list([Directory? from]) async {
    final d = from ?? await dir();
    if (d == null || !d.existsSync()) return const [];
    final out = <BackupInfo>[];
    for (final e in d.listSync().whereType<File>().where((f) => f.path.endsWith('.json') && (f.path.contains('rawnaq-') || f.path.contains('hafidh-')))) {
      try {
        final m = jsonDecode(e.readAsStringSync()) as Map<String, dynamic>;
        out.add(BackupInfo(e, DateTime.tryParse('${m['time']}') ?? e.lastModifiedSync(), m['auto'] == true,
            (m['config'] as Map?)?.length ?? 0, e.lengthSync()));
      } catch (_) {}
    }
    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }

  static Future<bool> restore(File f) async {
    try {
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      // نسخ الاسم القديم (الحافظ) تنقبل هم حتى ينتقل كل شي للتطبيق الجديد
      if (m['app'] != 'rawnaq' && m['app'] != 'hafidh') return false;
      final s = AppState.I;
      s.cfg.restore((m['config'] as Map).cast<String, dynamic>());
      s.restoreLists(
        favorites: ((m['favorites'] as List?) ?? const []).cast<String>(),
        labels: ((m['labels'] as Map?) ?? const {}).cast<String, String>(),
        artModes: ((m['artModes'] as Map?) ?? const {}).cast<String, String>(),
        locked: ((m['locked'] as List?) ?? const []).cast<String>(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// فلاشات متصلة: مجلد رونق الخاص على كل وحدة.
  static Future<List<Directory>> usb() async => [for (final p in await NativeBridge.usbDirs()) Directory(p)];

  /// أول تشغيل بعد الانتقال من الاسم القديم: install.bat ينسخ ملفات التطبيق القديم هنا،
  /// فنرجّع آخر نسخة احتياطية وحدها حتى ترجع إعداداتك وترتيبك بدون أي خطوة.
  static Future<bool> migrateOnce() async {
    final c = AppState.I.cfg;
    if (c.b('migrated.rawnaq') || c.b('setup.done')) return false;
    final l = await list();
    if (l.isEmpty || !await restore(l.first.file)) return false;
    c.set('migrated.rawnaq', true);
    c.set('setup.done', true);
    if (c.s('home.brand') == 'الحافظ') c.set('home.brand', 'رونق');
    if (kUpdateUrl.isNotEmpty) c.set('update.url', kUpdateUrl);
    AppState.I.touch();
    Notices.add('sparkles', 'أهلاً بك في رونق', 'رجعت إعداداتك وترتيبك من الحافظ');
    return true;
  }

  /// النسخة التلقائية اليومية (تُستدعى عند التشغيل وكل ساعة).
  static Future<void> autoTick() async {
    final c = AppState.I.cfg;
    if (!c.b('backup.auto')) return;
    final last = DateTime.fromMillisecondsSinceEpoch(c.i('backup.last'));
    if (DateTime.now().difference(last) >= const Duration(hours: 24)) await create(auto: true);
  }
}

// ═══════════════════ المراقب: الجدول والسلاسة ═══════════════════

class SystemWatch {
  static final SystemWatch I = SystemWatch._();
  SystemWatch._();

  Timer? _t;
  bool resumed = true;
  final ValueNotifier<String?> notice = ValueNotifier(null); // تنبيه قصير (قبل الإطفاء)
  /// عد تنازلي قبل الإطفاء التلقائي: وقت الإطفاء (main.dart يعرض النافذة).
  final ValueNotifier<DateTime?> offCountdown = ValueNotifier(null);
  DateTime? _offDoneFor;
  int _offWaits = 0;

  // سلاسة الواجهة: متوسط الإطارات بالثانية من توقيتات المحرك
  final List<int> _frameUs = [];
  double get fps {
    if (_frameUs.isEmpty) return 60;
    final avg = _frameUs.reduce((a, b) => a + b) / _frameUs.length;
    return (1e6 / avg.clamp(16667, 200000)).clamp(1, 60).toDouble();
  }

  void start() {
    SchedulerBinding.instance.addTimingsCallback((list) {
      for (final t in list) {
        _frameUs.add(t.totalSpan.inMicroseconds);
      }
      if (_frameUs.length > 120) _frameUs.removeRange(0, _frameUs.length - 120);
    });
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
    Future.delayed(const Duration(seconds: 15), Backups.autoTick);
    Timer.periodic(const Duration(hours: 1), (_) => Backups.autoTick());
  }

  static int _mins(DateTime t) => t.hour * 60 + t.minute;

  bool get quietNow {
    final c = AppState.I.cfg;
    if (!c.b('sched.quiet')) return false;
    final m = _mins(DateTime.now()), a = c.i('sched.quietFrom'), b = c.i('sched.quietTo');
    return a <= b ? (m >= a && m < b) : (m >= a || m < b);
  }

  Future<void> _tick() async {
    final c = AppState.I.cfg;
    final now = DateTime.now();

    // الإطفاء التلقائي
    if (c.b('sched.off')) {
      final at = c.i('sched.offAt');
      final target = DateTime(now.year, now.month, now.day, at ~/ 60, at % 60);
      final diff = now.difference(target);
      final cd = c.i('power.countdown');
      if (cd > 0 && diff.inSeconds >= -(cd + 22) && diff.inSeconds < -1 && _offDoneFor != target && offCountdown.value != target) {
        offCountdown.value = target;
      }
      if (c.b('sched.warn') && diff.inSeconds >= -70 && diff.inSeconds < -40) {
        notice.value = 'الشاشة راح تطفي بعد دقيقة — اضغط أي زر بالإعدادات لإلغاء الإطفاء اليوم';
      }
      if (diff.inSeconds >= 0 && diff.inMinutes < 180 && _offDoneFor != target) {
        // تطبيق ثاني شغّال (فيلم/مباراة): ننتظر ١٥ دقيقة ونعيد، لحد ساعتين
        if (c.b('sched.waitVideo') && !resumed && _offWaits < 8 && diff.inMinutes < _offWaits * 15 + 15) {
          if (diff.inSeconds < 25) _offWaits++;
        } else {
          _offDoneFor = target;
          _offWaits = 0;
          ActivityLog.add('power', 'إطفاء تلقائي حسب الجدول', '', kind: 'power');
          final ok = await NativeBridge.sleepNow();
          if (!ok) AppState.I.sleepFallback.value++;
        }
      }
    }
  }

  /// إلغاء إطفاء اليوم.
  void skipToday() {
    final c = AppState.I.cfg;
    final now = DateTime.now();
    final at = c.i('sched.offAt');
    _offDoneFor = DateTime(now.year, now.month, now.day, at ~/ 60, at % 60);
    notice.value = null;
    offCountdown.value = null;
    ActivityLog.add('power', 'تأجيل الإطفاء التلقائي', 'لهذا اليوم', kind: 'power');
  }
}
