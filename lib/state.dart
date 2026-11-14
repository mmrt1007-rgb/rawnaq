import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'palette.dart';
import 'platform.dart';
import 'prayer.dart';
import 'wallpaper_fetcher.dart';
import 'weather.dart';

/// مصدر صورة التطبيق.
enum ArtMode { auto, icon, banner }

/// الحالة العامة: الإعدادات، التطبيقات، المفضلة، الخلفيات، الوقت، الطقس.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  late SharedPreferences _p;
  final Config cfg = Config();

  // ---------- التطبيقات ----------
  List<InstalledApp> installed = [];
  final Map<String, AppArt> _art = {};
  final Set<String> _loadingArt = {};
  List<String> favorites = [];
  Map<String, String> labels = {};
  Map<String, String> artModes = {};
  Set<String> locked = {};

  // ---------- الخلفيات ----------
  String wallpaperDir = '';
  List<String> wallpapers = [];

  // ---------- مؤقت الإطفاء ----------
  DateTime? sleepAt;
  bool _sleeping = false;

  /// يرجع عند انتهاء المؤقت إذا لازم نعرض شاشة سوداء (الإطفاء الحقيقي غير متاح).
  final ValueNotifier<int> sleepFallback = ValueNotifier(0);

  /// صار true إذا انتقلت الواجهة للتصميم الجديد بهذا التشغيل (تظهر رسالة ترحيب).
  bool upgradedTo32 = false;

  /// آخر مدة اختارها المستخدم للمؤقت (للتظليل باللوحة السريعة).
  int sleepMinutes = 0;

  void setSleepTimer(int minutes) {
    sleepMinutes = minutes < 0 ? 0 : minutes;
    sleepAt = minutes <= 0 ? null : DateTime.now().add(Duration(minutes: minutes));
    notifyListeners();
  }

  Duration? get sleepLeft {
    final at = sleepAt;
    if (at == null) return null;
    final d = at.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  Future<void> _checkSleep() async {
    final at = sleepAt;
    if (at == null || _sleeping || DateTime.now().isBefore(at)) return;
    _sleeping = true;
    sleepAt = null;
    notifyListeners();
    final ok = await NativeBridge.sleepNow();
    if (!ok) sleepFallback.value++;
    _sleeping = false;
  }

  // ---------- الوقت والطقس ----------
  DateTime now = DateTime.now();
  Weather? weather;
  Timer? _clock, _weatherTimer;
  StreamSubscription? _pkgSub;

  // ---------- الجهاز والأداء ----------
  int sdk = 0;
  int ramMb = 0;
  bool lowRam = false;
  String model = '';
  int screenW = 0, screenH = 0;
  double density = 1, xdpi = 0, ydpi = 0;

  /// قطر الشاشة التقريبي بالبوصة (بعض الشاشات تبلّغ كثافة غير دقيقة، فنرجع null إذا القيمة غير منطقية).
  double? get screenInches {
    if (xdpi <= 0 || ydpi <= 0 || screenW == 0) return null;
    final w = screenW / xdpi, h = screenH / ydpi;
    final d = math.sqrt(w * w + h * h);
    return (d >= 15 && d <= 120) ? d : null;
  }

  /// وضع خفيف للأجهزة الضعيفة: بدون تغبيش حي ولا حركات مستمرة.
  /// الوضع الآمن: يتفعّل إذا توقف التطبيق ٣ مرات خلال دقيقتين — بدون حركة وبأخف رسم.
  bool safe = false;
  /// شاشة الإقلاع: ثيمها نفس أول لقطة أندرويد (اللي تثبتت بالتشغيل السابق)، وهل الجهاز توه مشتغل.
  bool bootDay = false;
  bool coldBoot = true;

  /// إصدار التطبيق المنصّب ووقت آخر تحديث (من النظام).
  String version = '';
  int updatedAt = 0;

  SharedPreferences get prefs => _p;

  /// خطوة التحميل الحالية لشاشة الإقلاع (٠ بداية، ١ الإعدادات، ٢ التطبيقات، ٣ الخلفيات، ٤ جاهز).
  final ValueNotifier<int> bootStep = ValueNotifier(0);

  bool get lite {
    if (safe) return true;
    final mode = cfg.s('ui.performance');
    if (mode == 'fast') return true;
    if (mode == 'quality') return false;
    return lowRam || (ramMb > 0 && ramMb < 1800) || (sdk > 0 && sdk < 29);
  }

  Timer? _artNotify;

  /// تجميع تحديثات الأيقونات حتى ما تنرسم الواجهة عشرات المرات بالبداية.
  void _notifySoon() {
    _artNotify ??= Timer(const Duration(milliseconds: 80), () {
      _artNotify = null;
      notifyListeners();
    });
  }

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    final info = await NativeBridge.deviceInfo();
    sdk = (info['sdk'] as int?) ?? 0;
    ramMb = (info['ramMb'] as int?) ?? 0;
    lowRam = (info['lowRam'] as bool?) ?? false;
    model = (info['model'] as String?) ?? '';
    version = (info['version'] as String?) ?? '';
    updatedAt = (info['updatedAt'] as num?)?.toInt() ?? 0;
    screenW = (info['width'] as int?) ?? 0;
    screenH = (info['height'] as int?) ?? 0;
    density = (info['density'] as num?)?.toDouble() ?? 1;
    xdpi = (info['xdpi'] as num?)?.toDouble() ?? 0;
    ydpi = (info['ydpi'] as num?)?.toDouble() ?? 0;
    cfg.load(_p);
    // الثيمان القديمان صاروا من ثيمات أهل البيت (ع)
    final oldPreset = cfg.s('theme.preset');
    if (oldPreset == 'ottoman') cfg.set('theme.preset', 'husaini');
    if (oldPreset == 'umayyad') cfg.set('theme.preset', 'muhammadi');
    // من يرقّي من نسخة سابقة ما يحتاج معالج الإعداد الأول
    if (cfg.i('cfg.rev') > 0 && !cfg.b('setup.done')) cfg.set('setup.done', true);
    bootStep.value = 1;
    favorites = _p.getStringList('favorites') ?? [];
    labels = _decode('labels');
    artModes = _decode('artModes');
    locked = (_p.getStringList('locked') ?? []).toSet();

    await reloadApps();
    bootStep.value = 2;
    if (favorites.isEmpty) _seedFavorites();
    await refreshWallpapers();
    bootStep.value = 3;

    // ترقية ٣٫٢: التصاميم الجديدة من فيكما تصير هي الواجهة (الزجاج السائل) مرة وحدة،
    // حتى لو كانت إعدادات النسخة الأولى محفوظة على الجهاز. الثيم والتطبيقات تبقى مثل ما هي.
    if (cfg.i('cfg.rev') < 6) {
      if (cfg.s('ui.style') != 'modern') {
        setStyle('modern');
      } else {
        cfg.loadSnapshot(stylePreset('modern'));
      }
      cfg.set('cfg.rev', 6);
      upgradedTo32 = true;
    }

    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkSleep();
      final t = DateTime.now();
      if (t.minute != now.minute || t.hour != now.hour) {
        now = t;
        notifyListeners();
      }
    });
    refreshWeather();
    // الطقس المختصر يتحدث مع شاشة الطقس (WeatherHub.refreshAll يحدّثه بعد كل جلب)
    _weatherTimer = Timer.periodic(Duration(minutes: cfg.i('weather.refresh').clamp(5, 60)), (_) => refreshWeather());
    _pkgSub = NativeBridge.packageEvents.listen((_) => reloadApps());
  }

  Map<String, String> _decode(String key) {
    try {
      return Map<String, String>.from(jsonDecode(_p.getString(key) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _weatherTimer?.cancel();
    _pkgSub?.cancel();
    super.dispose();
  }

  // ---------- الإعدادات ----------
  /// تغيير أي إعداد وإعادة رسم الواجهة فوراً.
  void set(String key, Object value) {
    cfg.set(key, value);
    if (key == 'misc.city') refreshWeather();
    if (key.startsWith('prayer.')) _sun = null;
    if (key == 'weather.refresh') {
      _weatherTimer?.cancel();
      _weatherTimer = Timer.periodic(Duration(minutes: cfg.i('weather.refresh').clamp(5, 60)), (_) => refreshWeather());
      WeatherHub.restartTimer();
    }
    notifyListeners();
  }

  void touch() => notifyListeners();

  // ---------- الأنماط وترتيب كل نمط ----------
  static const styles = ['modern', 'soft', 'liquid', 'classic', 'glass', 'cinema', 'ribbons', 'minimal', 'magazine'];

  static String styleName(String id) => switch (id) {
        'glass' => 'زجاج مغبش',
        'cinema' => 'سينمائي (ترتيب Apple TV)',
        'ribbons' => 'شرائط عصرية',
        'liquid' => 'الزجاج السائل',
        'modern' => 'الحديث',
        'soft' => 'الناعم العصري',
        'minimal' => 'البسيط الهادئ',
        'magazine' => 'المجلة',
        _ => 'كلاسيكي أنيق',
      };

  /// الترتيب الافتراضي لكل نمط (يتطبق أول مرة، أو عند "إعادة ترتيب هذا النمط").
  Map<String, Object> stylePreset(String style) {
    final hasWalls = wallpapers.isNotEmpty;
    switch (style) {
      case 'glass':
        return {
          'home.layout': 'row',
          'home.align': 'center',
          'home.bg': hasWalls ? 'slideshow' : 'art',
          'home.art': 'orbs',
          'home.dim': 0.30,
          'tile.style': 'banner',
          'tile.size': 260.0,
          'tile.radius': 26.0,
          'tile.labels': 'focus',
          'saver.layout': 'stack',
          'saver.position': 'auto',
          'saver.bg': hasWalls ? 'slideshow' : 'art',
          'saver.art': 'orbs',
        };
      case 'cinema':
        return {
          // ترتيب على طريقة Apple TV: مساحة كبيرة للخلفية بالأعلى، وشبكة تطبيقاتك تحتها
          'home.layout': 'tvgrid',
          'home.cols': 5,
          'home.bg': hasWalls ? 'slideshow' : 'art',
          'home.art': 'orbs',
          'home.dim': 0.10,
          'home.padX': 110.0,
          'home.padY': 56.0,
          'home.dateSize': 28.0,
          'tile.style': 'banner',
          'tile.radius': 16.0,
          'tile.gap': 40.0,
          'tile.labels': 'focus',
          'tile.focusScale': 1.12,
          'tile.ringWidth': 0.0,
          'tile.shadow': true,
          'tile.glint': true,
          'tile.showAdd': false,
          'tile.showAll': true,
          'saver.layout': 'elegant',
          'saver.bg': hasWalls ? 'slideshow' : 'art',
          'saver.art': 'stars',
          'saver.kenburns': true,
          'saver.interval': 25,
        };
      case 'ribbons':
        return {
          'home.layout': 'ribbons',
          'home.bg': 'solid',
          'home.padX': 112.0,
          'home.padY': 52.0,
          'tile.style': 'banner',
          'tile.size': 216.0,
          'tile.radius': 18.0,
          'tile.gap': 26.0,
          'tile.labels': 'all',
          'tile.focusScale': 1.1,
          'tile.showAdd': true,
          'tile.showAll': false,
          'saver.layout': 'elegant',
          'saver.bg': hasWalls ? 'slideshow' : 'art',
          'saver.art': 'waves',
        };
      case 'liquid':
        return {
          // الزجاج السائل: خلفية حيّة، شريط تنقل زجاجي بالأعلى، ورف تطبيقات زجاجي عائم بالأسفل
          'home.layout': 'liquid',
          'home.bg': hasWalls ? 'slideshow' : 'art',
          'home.art': 'orbs',
          'home.dim': 0.12,
          'home.padX': 112.0,
          'home.padY': 56.0,
          'tile.style': 'banner',
          'tile.size': 236.0,
          'tile.radius': 28.0,
          'tile.gap': 36.0,
          'tile.labels': 'all',
          'tile.focusScale': 1.12,
          'tile.ringWidth': 3.0,
          'tile.shadow': true,
          'tile.glint': true,
          'tile.showAdd': false,
          'tile.showAll': true,
          'saver.layout': 'calm',
          'saver.bg': 'stars',
          'saver.style': 'stars',
        };
      case 'soft':
        return {
          // الناعم العصري (ترقية فيكما الشاملة كنمط مستقل): حواف متصلة لكل البطاقات، ظلال أنعم، وأورورا
          'home.layout': 'modern',
          'home.bg': 'aurora',
          'home.padX': 104.0,
          'home.padY': 60.0,
          'tile.style': 'banner',
          'tile.size': 204.0,
          'tile.shape': 'squircle',
          'tile.focus': 'lift',
          'tile.gap': 30.0,
          'tile.labels': 'focus',
          'tile.focusScale': 1.06,
          'tile.shadow': true,
          'motion.style': 'soft',
          'motion.page': 'zoom',
          'saver.layout': 'calm',
          'saver.bg': 'stars',
        };
      case 'modern':
        return {
          // الحديث (ترقية ٣٫٤ من فيكما صفحة 08): أورورا خفيفة، بطاقة بارزة، ومربعات ناعمة ترتفع عند التركيز
          'home.layout': 'modern',
          'home.bg': 'aurora',
          'home.padX': 96.0,
          'home.padY': 56.0,
          'tile.style': 'banner',
          'tile.size': 196.0,
          'tile.radius': 30.0,
          'tile.shape': 'squircle',
          'tile.focus': 'lift',
          'tile.gap': 28.0,
          'tile.labels': 'focus',
          'tile.focusScale': 1.06,
          'tile.shadow': true,
          'tile.showAdd': false,
          'tile.showAll': true,
          'motion.style': 'soft',
          'saver.layout': 'calm',
          'saver.bg': 'stars',
          'saver.style': 'stars',
        };
      case 'minimal':
        return {
          // البسيط: مرسى أيقونات بدون أسماء، فراغ واسع، وشاشة سكون فيها الساعة فقط
          'home.layout': 'dock',
          'home.bg': 'solid',
          'home.showGreeting': false,
          'home.showHint': false,
          'home.padX': 140.0,
          'home.padY': 72.0,
          'tile.style': 'icon',
          'tile.size': 168.0,
          'tile.radius': 40.0,
          'tile.gap': 34.0,
          'tile.labels': 'none',
          'tile.focusScale': 1.12,
          'tile.shadow': true,
          'tile.showAdd': false,
          'tile.showAll': true,
          'saver.layout': 'minimal',
          'saver.bg': 'black',
        };
      case 'magazine':
        return {
          // المجلة: بطاقة بارزة كبيرة بعنوان، وشريط تطبيقات بأسماء واضحة
          'home.layout': 'hero',
          'home.bg': hasWalls ? 'slideshow' : 'gradient',
          'home.dim': 0.25,
          'home.padX': 112.0,
          'home.padY': 56.0,
          'tile.style': 'banner',
          'tile.size': 240.0,
          'tile.radius': 20.0,
          'tile.gap': 28.0,
          'tile.labels': 'all',
          'tile.focusScale': 1.1,
          'tile.shadow': true,
          'saver.layout': 'elegant',
          'saver.bg': hasWalls ? 'slideshow' : 'stars',
          'saver.kenburns': true,
        };
      default:
        return {
          'saver.layout': 'calm',
          'saver.bg': 'stars',
          'saver.style': 'stars',
        };
    }
  }

  /// تبديل النمط: يحفظ ترتيب النمط الحالي، ويحمّل ترتيب النمط الجديد (أو ترتيبه الافتراضي).
  void setStyle(String style) {
    final current = cfg.s('ui.style');
    if (style == current) return;
    cfg.set('profile.$current', jsonEncode(cfg.snapshot()));
    final saved = cfg.s('profile.$style');
    Map<String, dynamic>? m;
    if (saved.isNotEmpty) {
      try {
        m = jsonDecode(saved) as Map<String, dynamic>;
      } catch (_) {}
    }
    cfg.loadSnapshot(m ?? stylePreset(style));
    cfg.set('ui.style', style);
    notifyListeners();
  }

  /// إرجاع ترتيب النمط الحالي لترتيبه الافتراضي.
  void resetStyleArrangement() {
    cfg.loadSnapshot(stylePreset(cfg.s('ui.style')));
    cfg.set('profile.${cfg.s('ui.style')}', '');
    notifyListeners();
  }

  /// للاختصار بالواجهة: كلاسيكي ← زجاج ← سينمائي ← كلاسيكي.
  String cycleStyle() {
    final i = styles.indexOf(cfg.s('ui.style'));
    final next = styles[(i + 1) % styles.length];
    setStyle(next);
    return next;
  }

  bool get isNight {
    final mode = cfg.s('theme.mode');
    if (mode == 'day') return false;
    if (mode == 'night') return true;
    if (mode == 'hours') {
      final h = now.hour, ds = cfg.i('theme.dayStart'), ns = cfg.i('theme.nightStart');
      return ds < ns ? (h >= ns || h < ds) : (h >= ns && h < ds);
    }
    // تلقائي: نهار من الشروق للغروب الحقيقي بمدينتك (من حساب المواقيت، بدون إنترنت)
    final (rise, set) = _sunToday();
    final t = DateTime.now();
    return t.isBefore(rise) || !t.isBefore(set);
  }

  (int, DateTime, DateTime)? _sun;
  (DateTime, DateTime) _sunToday() {
    final t = DateTime.now();
    final key = t.year * 10000 + t.month * 100 + t.day;
    final c = _sun;
    if (c != null && c.$1 == key) return (c.$2, c.$3);
    var rise = DateTime(t.year, t.month, t.day, 6), set = DateTime(t.year, t.month, t.day, 17, 30);
    try {
      for (final p in Prayers.forDay(t)) {
        if (p.id == 'sunrise') rise = p.time;
        if (p.id == 'sunset') set = p.time;
      }
    } catch (_) {}
    _sun = (key, rise, set);
    return (rise, set);
  }

  /// يمسح حساب الشروق والغروب (بعد تغيير المدينة).
  void resetSun() => _sun = null;

  Palette get palette => Palette.from(cfg, isNight);

  /// مدة حركة مضبوطة بسرعة الحركة المختارة (أو صفر عند تقليل الحركة).
  /// منحنى الحركة حسب "أسلوب الحركة" (من فيكما: الحركة والسرعة).
  Curve get curve => switch (cfg.s('motion.style')) {
        'spring' => Curves.easeOutBack,
        'elegant' => Curves.easeInOutCubic,
        'swift' => Curves.easeOutQuad,
        _ => Curves.easeOutCubic,
      };

  Duration anim(int ms) {
    if (safe || cfg.b('misc.reduceMotion') || cfg.s('motion.style') == 'off') return Duration.zero;
    ms = (ms * switch (cfg.s('motion.style')) { 'spring' => 1.3, 'elegant' => 1.7, 'swift' => 0.55, _ => 1.0 }).round();
    if (lite) ms = (ms * 0.75).round();
    return Duration(milliseconds: (ms / cfg.d('misc.animSpeed')).round());
  }

  // ---------- التطبيقات ----------
  Future<void> reloadApps() async {
    try {
      installed = await NativeBridge.getApps();
    } catch (_) {
      return;
    }
    final present = installed.map((a) => a.package).toSet();
    favorites = favorites.where(present.contains).toList();
    _art.removeWhere((k, _) => !present.contains(k));
    _saveFavorites();
    notifyListeners();
  }

  void _seedFavorites() {
    const wanted = ['youtube', 'cinemana', 'netflix', 'shahid', 'tod', 'quran', 'files', 'filemanager'];
    for (final key in wanted) {
      for (final a in installed) {
        if (a.package.toLowerCase().contains(key) && !favorites.contains(a.package)) {
          favorites.add(a.package);
          break;
        }
      }
    }
    if (favorites.isEmpty) {
      favorites = installed.where((a) => a.isTv).take(6).map((a) => a.package).toList();
    }
    _saveFavorites();
  }

  InstalledApp? app(String pkg) {
    for (final a in installed) {
      if (a.package == pkg) return a;
    }
    return null;
  }

  String labelOf(String pkg) => labels[pkg] ?? app(pkg)?.label ?? pkg;

  ArtMode artModeOf(String pkg) =>
      ArtMode.values.firstWhere((m) => m.name == artModes[pkg], orElse: () => ArtMode.auto);

  AppArt? artOf(String pkg) {
    final a = _art[pkg];
    if (a == null && !_loadingArt.contains(pkg)) {
      _loadingArt.add(pkg);
      NativeBridge.getArt(pkg).then((art) {
        _art[pkg] = art;
        _loadingArt.remove(pkg);
        _notifySoon();
      }).catchError((_) {
        _loadingArt.remove(pkg);
      });
    }
    return a;
  }

  bool isFavorite(String pkg) => favorites.contains(pkg);

  void toggleFavorite(String pkg) {
    if (isFavorite(pkg)) {
      favorites.remove(pkg);
    } else {
      favorites.add(pkg);
    }
    _saveFavorites();
    notifyListeners();
  }

  void removeFavorite(String pkg) {
    favorites.remove(pkg);
    _saveFavorites();
    notifyListeners();
  }

  /// تحريك تطبيق بالمفضلة بمقدار [delta] خانة. يرجع الموضع الجديد.
  int move(String pkg, int delta) {
    final i = favorites.indexOf(pkg);
    final to = (i + delta).clamp(0, favorites.length - 1);
    if (i < 0 || to == i) return i;
    favorites.removeAt(i);
    favorites.insert(to, pkg);
    _saveFavorites();
    notifyListeners();
    return to;
  }

  void sortFavorites() {
    favorites.sort((a, b) => labelOf(a).compareTo(labelOf(b)));
    _saveFavorites();
    notifyListeners();
  }

  void customize(String pkg, {String? label, ArtMode? art, bool? lock}) {
    if (label != null) {
      final original = app(pkg)?.label;
      if (label.trim().isEmpty || label.trim() == original) {
        labels.remove(pkg);
      } else {
        labels[pkg] = label.trim();
      }
    }
    if (art != null) {
      if (art == ArtMode.auto) {
        artModes.remove(pkg);
      } else {
        artModes[pkg] = art.name;
      }
    }
    if (lock != null) {
      if (lock) {
        locked.add(pkg);
      } else {
        locked.remove(pkg);
      }
    }
    _p.setString('labels', jsonEncode(labels));
    _p.setString('artModes', jsonEncode(artModes));
    _p.setStringList('locked', locked.toList());
    notifyListeners();
  }

  void resetApp(String pkg) {
    labels.remove(pkg);
    artModes.remove(pkg);
    locked.remove(pkg);
    customize(pkg);
  }

  // ---------- الخلفيات ----------
  Future<void> refreshWallpapers() async {
    try {
      wallpaperDir = await NativeBridge.wallpaperDir();
      wallpapers = await NativeBridge.listImages(wallpaperDir);
      WallCredits.load(wallpaperDir);
    } catch (_) {
      wallpapers = [];
    }
    // إذا الصورة المختارة انحذفت، نرجع للافتراضي
    for (final k in ['home.image', 'saver.image']) {
      final v = cfg.s(k);
      if (v.isNotEmpty && !wallpapers.contains(v)) cfg.set(k, '');
    }
    notifyListeners();
  }

  Future<void> deleteWallpaper(String path) async {
    await NativeBridge.deleteFile(path);
    await refreshWallpapers();
  }

  // ---------- الطقس ----------
  Future<void> refreshWeather() async {
    final w = await WeatherService.fetch(city: cfg.s('misc.city'));
    if (w != null) {
      weather = w;
      notifyListeners();
    }
  }

  void _saveFavorites() => _p.setStringList('favorites', favorites);

  /// استعادة القوائم من نسخة احتياطية.
  void restoreLists({required List<String> favorites, required Map<String, String> labels, required Map<String, String> artModes, required List<String> locked}) {
    this.favorites = favorites;
    this.labels = labels;
    this.artModes = artModes;
    this.locked = locked.toSet();
    _p.setStringList('favorites', favorites);
    _p.setString('labels', jsonEncode(labels));
    _p.setString('artModes', jsonEncode(artModes));
    _p.setStringList('locked', locked);
    notifyListeners();
  }
}
