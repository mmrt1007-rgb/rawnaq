import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'arabic.dart';
import 'lucide.dart';
import 'state.dart';

/// فئة خلفيات: المعرّف، الاسم، الأيقونة، وتصنيف "الصور المختارة" بويكيميديا كومنز.
/// الصور المختارة (Featured pictures) صور حقيقية عالية الجودة يصوّت عليها مجتمع كومنز،
/// كلها بتراخيص حرة، فنعرض مع كل صورة اسم المصوّر ورخصتها.
class WallCategory {
  final String id, name, commons;
  final Lu icon;
  const WallCategory(this.id, this.name, this.icon, this.commons);

  static const all = [
    WallCategory('landscapes', 'طبيعة ومناظر', Lu.leaf, 'Featured pictures of landscapes'),
    WallCategory('mountains', 'جبال', Lu.mountain, 'Featured pictures of mountains'),
    WallCategory('coasts', 'بحار وشواطئ', Lu.waves, 'Featured pictures of coasts'),
    WallCategory('water', 'أنهار وبحيرات', Lu.droplets, 'Featured pictures of bodies of water'),
    WallCategory('plants', 'نباتات وزهور', Lu.flower, 'Featured pictures of plants'),
    WallCategory('mammals', 'حيوانات', Lu.paw, 'Featured pictures of mammals'),
    WallCategory('birds', 'طيور', Lu.bird, 'Featured pictures of birds'),
    WallCategory('food', 'طعام', Lu.utensils, 'Featured pictures of food'),
    WallCategory('astronomy', 'سماء وفضاء', Lu.telescope, 'Featured pictures of astronomy'),
    WallCategory('mosques', 'مساجد وعمارة', Lu.landmark, 'Quality images of mosques'),
  ];

  static WallCategory? of(String id) => all.where((c) => c.id == id).firstOrNull;
}

/// بيانات صورة تلقائية (للعرض مع الصورة: المصوّر والرخصة والفئة).
class WallCredit {
  final String title, author, license, category;
  const WallCredit(this.title, this.author, this.license, this.category);

  Map<String, String> toJson() => {'t': title, 'a': author, 'l': license, 'c': category};
  factory WallCredit.fromJson(Map<String, dynamic> m) =>
      WallCredit('${m['t'] ?? ''}', '${m['a'] ?? ''}', '${m['l'] ?? ''}', '${m['c'] ?? ''}');

  /// سطر الحقوق الظاهر أسفل شاشة السكون.
  String get line => [
        if (author.isNotEmpty) 'تصوير: $author',
        if (license.isNotEmpty) license,
        'ويكيميديا كومنز',
      ].join(' · ');
}

/// حقوق الصور المحفوظة بملف credits.json بمجلد الخلفيات.
class WallCredits {
  static Map<String, WallCredit> _m = {};
  static String _dir = '';

  static File _file(String dir) => File('$dir/credits.json');

  /// يقرا حقوق الصور: اللي جابها الجهاز (credits.json) + اللي نزّلها سكربت التنصيب (credits-install.json).
  static void load(String dir) {
    _dir = dir;
    final m = <String, WallCredit>{};
    for (final name in const ['credits-install.json', 'credits.json']) {
      try {
        final f = File('$dir/$name');
        if (!f.existsSync()) continue;
        var text = f.readAsStringSync();
        if (text.startsWith('\uFEFF')) text = text.substring(1);
        final raw = jsonDecode(text) as Map<String, dynamic>;
        raw.forEach((k, v) {
          if (v is Map) m[k] = WallCredit.fromJson(Map<String, dynamic>.from(v));
        });
      } catch (_) {}
    }
    _m = m;
  }

  static WallCredit? of(String path) => _m[path.split('/').last];

  static int countFor(String cat) => _m.values.where((c) => c.category == cat).length;

  static void put(String file, WallCredit c) => _m[file] = c;

  static void prune(Set<String> existing) => _m.removeWhere((k, _) => !existing.contains(k));

  static Future<void> save() async {
    if (_dir.isEmpty) return;
    try {
      await _file(_dir).writeAsString(jsonEncode(_m.map((k, v) => MapEntry(k, v.toJson()))), flush: true);
    } catch (_) {}
  }
}

/// مكتبة الخلفيات التلقائية: تجيب صور 4K حقيقية من فئات "الصور المختارة" بويكيميديا كومنز،
/// موزعة على الفئات اللي تختارها (١٠ فئات)، حتى ١٠٠ صورة، وتجدد ثلثها كل أسبوع (أو المدة اللي تختارها).
/// صورك الخاصة ما تنمس أبداً — فقط الصور اللي اسمها يبدأ بـ auto-.
class WallpaperFetcher {
  static Timer? _timer;
  static bool _running = false;
  static final _rand = math.Random();

  /// حالة التحديث لشاشة المكتبة (فارغ = ما يشتغل).
  static final status = ValueNotifier<String>('');
  /// نسبة التحميل الحقيقية (null = ما بيه تحميل أو المدة غير معروفة).
  static final progress = ValueNotifier<double?>(null);

  static const _ua = {
    'User-Agent': 'RawnaqLauncher/3.0 (Android TV home screen; personal use)',
    'Api-User-Agent': 'RawnaqLauncher/3.0 (Android TV home screen; personal use)',
  };

  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 1), (_) => run());
    Future.delayed(const Duration(seconds: 30), run);
  }

  static bool get running => _running;

  static List<File> _autoFiles(String dir) {
    final d = Directory(dir);
    if (!d.existsSync()) return [];
    return d.listSync().whereType<File>().where((f) => f.uri.pathSegments.last.startsWith('auto-')).toList()
      ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
  }

  /// الفئات المفعّلة.
  static List<WallCategory> enabled() {
    final ids = AppState.I.cfg.s('walls.cats').split(',').where((e) => e.isNotEmpty).toSet();
    return WallCategory.all.where((c) => ids.contains(c.id)).toList();
  }

  static DateTime get lastUpdate => DateTime.fromMillisecondsSinceEpoch(AppState.I.cfg.i('walls.last'));

  static DateTime? get nextUpdate {
    final days = AppState.I.cfg.i('walls.days');
    if (days <= 0 || !AppState.I.cfg.b('walls.auto')) return null;
    return lastUpdate.add(Duration(days: days));
  }

  static Future<void> run({bool force = false}) async {
    final s = AppState.I;
    final c = s.cfg;
    final days = c.i('walls.days');
    if ((!force && (!c.b('walls.auto') || days <= 0)) || _running || s.wallpaperDir.isEmpty) return;
    final cats = enabled();
    if (cats.isEmpty) return;
    _running = true;
    try {
      final dir = s.wallpaperDir;
      WallCredits.load(dir);
      final target = c.i('walls.count').clamp(10, 100);
      var autos = _autoFiles(dir);
      final due = DateTime.now().difference(lastUpdate) > Duration(days: math.max(1, days));

      // الصور الزايدة عن العدد أو من فئة انلغت تنحذف
      final enabledIds = cats.map((e) => e.id).toSet();
      for (final f in autos) {
        final cat = f.uri.pathSegments.last.split('-').elementAtOrNull(1) ?? '';
        if (WallCategory.of(cat) != null && !enabledIds.contains(cat)) _delete(f);
      }
      autos = _autoFiles(dir);
      while (autos.length > target) {
        _delete(autos.removeAt(0));
      }

      // التجديد الدوري: ثلث الصور الأقدم يتبدل
      if ((due || force) && autos.length >= target) {
        for (final f in autos.take(math.max(1, autos.length ~/ 3)).toList()) {
          _delete(f);
        }
        autos = _autoFiles(dir);
      }

      final missing = target - autos.length;
      if (missing > 0) {
        final have = autos.map((f) => f.uri.pathSegments.last).toSet();
        // توزيع متساوي على الفئات، والفئة الأقل صوراً تبدأ أول
        final perCat = (target / cats.length).ceil();
        final order = [...cats]..sort((a, b) => WallCredits.countFor(a.id).compareTo(WallCredits.countFor(b.id)));
        var added = 0;
        progress.value = 0;
        for (final cat in order) {
          if (added >= missing) break;
          final want = math.min(perCat - WallCredits.countFor(cat.id), missing - added);
          if (want <= 0) continue;
          status.value = 'تجلب صور ${cat.name}…';
          final list = await _candidates(cat);
          list.shuffle(_rand);
          var got = 0;
          for (final img in list) {
            if (got >= want) break;
            final name = 'auto-${cat.id}-${img.pageId}.jpg';
            if (have.contains(name)) continue;
            if (await _download(img.url, '$dir/$name')) {
              WallCredits.put(name, WallCredit(img.title, img.author, img.license, cat.id));
              have.add(name);
              got++;
              added++;
              progress.value = (added / missing).clamp(0.0, 1.0);
              status.value = 'تمت إضافة ${Ar.n(added)} من ${Ar.n(missing)} · ${cat.name}';
              await Future.delayed(const Duration(milliseconds: 2500));
            }
          }
        }
      }
      WallCredits.prune(_autoFiles(dir).map((f) => f.uri.pathSegments.last).toSet());
      await WallCredits.save();
      if (due || force || missing > 0) c.set('walls.last', DateTime.now().millisecondsSinceEpoch);
      await s.refreshWallpapers();
    } finally {
      _running = false;
      status.value = '';
      progress.value = null;
    }
  }

  static void _delete(File f) {
    try {
      f.deleteSync();
    } catch (_) {}
  }

  /// قائمة صور الفئة من واجهة كومنز: أفقية فقط، وبعرض ٢٤٠٠ بكسل أو أكثر، ورابط مصغّر بعرض 3840.
  static Future<List<_Img>> _candidates(WallCategory cat) async {
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'generator': 'categorymembers',
      'gcmtitle': 'Category:${cat.commons}',
      'gcmtype': 'file',
      'gcmlimit': '50', // كومنز يرجع بيانات الصورة (imageinfo) لأول ٥٠ ملف بس بكل طلب
      'gcmsort': 'timestamp',
      'gcmdir': 'desc',
      'prop': 'imageinfo',
      'iiprop': 'url|size|mime|extmetadata',
      'iiurlwidth': '3840',
      'iiextmetadatafilter': 'Artist|LicenseShortName|ObjectName',
    });
    try {
      final res = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final pages = ((data['query'] as Map?)?['pages'] as List?) ?? const [];
      final out = <_Img>[];
      for (final p in pages) {
        final m = p as Map;
        final info = (m['imageinfo'] as List?)?.firstOrNull as Map?;
        if (info == null) continue;
        final w = (info['width'] as num?)?.toInt() ?? 0, h = (info['height'] as num?)?.toInt() ?? 1;
        final mime = '${info['mime'] ?? ''}';
        if (w < 2400 || w / h < 1.3 || !(mime == 'image/jpeg' || mime == 'image/png')) continue;
        final url = '${info['thumburl'] ?? info['url'] ?? ''}';
        if (url.isEmpty) continue;
        final meta = (info['extmetadata'] as Map?) ?? const {};
        String field(String k) => _plain('${(meta[k] as Map?)?['value'] ?? ''}');
        final title = field('ObjectName').isNotEmpty ? field('ObjectName') : '${m['title'] ?? ''}'.replaceFirst('File:', '').replaceAll(RegExp(r'\.(jpe?g|png)$', caseSensitive: false), '');
        out.add(_Img((m['pageid'] as num).toInt(), url, title, field('Artist'), field('LicenseShortName')));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// يشيل وسوم HTML من اسم المصوّر (كومنز يرجعه كرابط أحياناً).
  static String _plain(String html) {
    final t = html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll('&amp;', '&').replaceAll('&nbsp;', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 60 ? '${t.substring(0, 57)}…' : t;
  }

  /// تنزيل صورة. إذا كومنز رد ٤٢٩ (طلبات كثيرة) ننتظر ونعيد، بمهلة تتضاعف.
  static Future<bool> _download(String url, String path) async {
    var wait = 6;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final res = await http.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 120));
        if (res.statusCode == 429 || res.statusCode == 503) {
          final ra = int.tryParse(res.headers['retry-after'] ?? '');
          await Future.delayed(Duration(seconds: ra != null && ra > 0 && ra < 120 ? ra : wait));
          wait *= 2;
          continue;
        }
        if (res.statusCode != 200 || res.bodyBytes.length < 150000) return false;
        await File(path).writeAsBytes(res.bodyBytes, flush: true);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }
}

class _Img {
  final int pageId;
  final String url, title, author, license;
  const _Img(this.pageId, this.url, this.title, this.author, this.license);
}
