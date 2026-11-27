import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home.dart';
import 'screens/screensaver.dart';
import 'brand.dart' show BootWriting, loaderWriteSeconds;
import 'platform.dart';
import 'state.dart';
import 'wallpaper_fetcher.dart';
import 'widgets.dart' show fade, RemoteNav;
import 'system_services.dart';
import 'screens/system_screens.dart';
import 'screens/streamer_screens.dart' show handleStar;
import 'screens/family_screens.dart' show KidsLockScreen, OccasionWelcome, showPowerCountdown, showUpdateReady;
import 'family_services.dart' show OccasionMode;
import 'streamer_services.dart';

/// سجل أخطاء على الجهاز (يسحبه rescue.bat): Android/data/com.rawnaq/files/rawnaq-errors.log
String? _logPath;
void logError(Object e, StackTrace? st) {
  final line = '${DateTime.now().toIso8601String()}  $e\n${st ?? ''}\n';
  debugPrint('RAWNAQ-ERROR $line');
  final path = _logPath;
  if (path == null) return;
  try {
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > 400000) f.writeAsStringSync('');
    f.writeAsStringSync(line, mode: FileMode.append, flush: true);
  } catch (_) {}
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      logError(d.exception, d.stack);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      logError(e, st);
      return true; // لا نطيّح التطبيق بسبب خطأ غير متوقع
    };
    // أي ويدجت يفشل يظهر مكانه فراغ هادئ بدل الشاشة الرمادية
    ErrorWidget.builder = (d) => const SizedBox.shrink();
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      NativeBridge.listen();
      final dir = await NativeBridge.wallpaperDir().timeout(const Duration(seconds: 3));
      _logPath = '${File(dir).parent.path}/rawnaq-errors.log';
    } catch (e, st) {
      logError(e, st);
    }
    // أول لقطة: نفس ثيم شاشة أندرويد الأولى، ونعرف إذا الجهاز توه مشتغل (أقل من ٣ دقايق)
    try {
      final b = await NativeBridge.splashInfo().timeout(const Duration(seconds: 1));
      AppState.I.bootDay = b.day;
      AppState.I.coldBoot = b.uptimeMs > 0 && b.uptimeMs < 180000;
    } catch (_) {}
    // حارس الإقلاع: ٣ تشغيلات متقاربة = توقف متكرر → الوضع الآمن
    AppState.I.safe = await BootGuard.check();
    // شاشة الإقلاع تطلع فوراً، والتهيئة تكمل خلفها — ما تبقى الشاشة سوداء أبداً
    runApp(const _Root());
  }, logError);
}

/// الجذر: شاشة الإقلاع حتى تخلص التهيئة (أو ٨ ثوانٍ كحد أقصى)، بعدها الواجهة.
class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    try {
      await AppState.I.init().timeout(const Duration(seconds: 8));
    } catch (e, st) {
      logError('init: $e', st);
    }
    AppState.I.bootStep.value = 4;
    try {
      // أول تشغيل بعد الانتقال من «الحافظ»: ترجع الإعدادات وحدها
      await Backups.migrateOnce().timeout(const Duration(seconds: 4));
    } catch (e, st) {
      logError('migrate: $e', st);
    }
    try {
      final cfg = AppState.I.cfg;
      if (cfg.b('misc.blockSystemSaver')) NativeBridge.disableSystemSaver();
      if (cfg.b('misc.forceLandscape')) NativeBridge.setForceLandscape(true);
      // تنزيل الخلفيات يبدأ بعد دقيقتين حتى ما يثقّل أول تشغيل
      Future.delayed(const Duration(minutes: 2), WallpaperFetcher.start);
      SystemWatch.I.start();
      StreamerServices.start();
    } catch (e, st) {
      logError(e, st);
    }
    // نخلي الشعار يبين لحظة قصيرة بس بدون ما نأخر المستخدم
    final shown = DateTime.now().difference(started);
    if (shown < const Duration(milliseconds: 700)) await Future.delayed(const Duration(milliseconds: 700) - shown);
    // «انتظر الكتابة»: القلم يكمل اسم رونق ونقاطه ثم تفتح الواجهة (بحد أقصى المدة + ثانية ونص)
    final cfg = AppState.I.cfg;
    final wait = switch (cfg.s('loader.waitBoot')) { 'always' => true, 'off' => false, _ => AppState.I.coldBoot };
    _syncSplash();
    AppState.I.addListener(_syncSplash);
    if (cfg.b('loader.write') && wait) {
      final max = Duration(milliseconds: ((loaderWriteSeconds() + 1.5) * 1000).round());
      // أي زر بالريموت يتخطى الكتابة ويفتح الواجهة فوراً
      bool skip(KeyEvent e) {
        if (e is KeyDownEvent) BootWriting.finish();
        return false;
      }

      HardwareKeyboard.instance.addHandler(skip);
      try {
        await BootWriting.done.timeout(max);
      } catch (_) {}
      HardwareKeyboard.instance.removeHandler(skip);
    }
    if (mounted) setState(() => _ready = true);
  }

  // أول لقطة بالتشغيل الجاي تتبع ثيم رونق الحالي (ليلي/نهاري)، حتى يبقى الانتقال بلا قفزة
  bool? _splashDay;
  void _syncSplash() {
    final day = !AppState.I.palette.night;
    if (_splashDay == day) return;
    _splashDay = day;
    NativeBridge.setSplashTheme(day).catchError((_) => false);
  }

  @override
  void dispose() {
    AppState.I.removeListener(_syncSplash);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _ready
          ? const RawnaqLauncher()
          : const MaterialApp(debugShowCheckedModeBanner: false, home: BootSplash()),
    );
  }
}

class RawnaqLauncher extends StatefulWidget {
  const RawnaqLauncher({super.key});

  @override
  State<RawnaqLauncher> createState() => _RawnaqLauncherState();
}

class _RawnaqLauncherState extends State<RawnaqLauncher> with WidgetsBindingObserver {
  final _nav = GlobalKey<NavigatorState>();
  DateTime _lastInput = DateTime.now();
  bool _resumed = true;
  bool _saverOpen = false;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    homeSignal.addListener(_goHome);
    AppState.I.sleepFallback.addListener(_blackout);
    starSignal.addListener(_star);
    Profiles.lock.addListener(_kidsLock);
    Updater.available.addListener(_updateReady);
    SystemWatch.I.offCountdown.addListener(_countdown);
    OccasionMode.welcome.addListener(_welcome);
    _idle = Timer.periodic(const Duration(seconds: 15), (_) => _checkIdle());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    homeSignal.removeListener(_goHome);
    AppState.I.sleepFallback.removeListener(_blackout);
    starSignal.removeListener(_star);
    Profiles.lock.removeListener(_kidsLock);
    Updater.available.removeListener(_updateReady);
    SystemWatch.I.offCountdown.removeListener(_countdown);
    OccasionMode.welcome.removeListener(_welcome);
    _idle?.cancel();
    super.dispose();
  }

  /// نجمة الريموت ورونق قدامك.
  void _star() {
    _lastInput = DateTime.now();
    final nav = _nav.currentState;
    if (nav != null) handleStar(nav);
  }

  bool _lockOpen = false;

  BuildContext? get _ctx => _nav.currentState?.overlay?.context;

  /// تحديث جاهز: نافذة أنيقة مرة وحدة لكل إصدار (فيكما صفحة ١٢).
  void _updateReady() {
    final u = Updater.available.value;
    final ctx = _ctx;
    if (u == null || ctx == null || Profiles.kids) return;
    if (AppState.I.cfg.s('update.prompted') == u.version) return;
    AppState.I.set('update.prompted', u.version);
    showUpdateReady(ctx, u);
  }

  /// عد تنازلي قبل الإطفاء المجدول، يقدر يلغيه لليوم.
  bool _cdOpen = false;
  Future<void> _countdown() async {
    final at = SystemWatch.I.offCountdown.value;
    final ctx = _ctx;
    if (at == null || ctx == null || _cdOpen) return;
    _cdOpen = true;
    await showPowerCountdown(ctx, at);
    _cdOpen = false;
  }

  /// ترحيب يوم المناسبة.
  void _welcome() {
    final w = OccasionMode.welcome.value;
    final nav = _nav.currentState;
    if (w == null || nav == null || Profiles.lock.value != null) return;
    OccasionMode.welcome.value = null;
    nav.push(fade(OccasionWelcome(title: w.$1, date: w.$2)));
  }

  /// ملف الأطفال: انتهى الوقت أو وقت النوم → شاشة القفل فوق كل شي.
  Future<void> _kidsLock() async {
    if (Profiles.lock.value == null || _lockOpen) return;
    final nav = _nav.currentState;
    if (nav == null) return;
    _lockOpen = true;
    nav.popUntil((r) => r.isFirst);
    await nav.push(fade(const KidsLockScreen()));
    _lockOpen = false;
  }

  /// انتهى مؤقت الإطفاء والجهاز ما يسمح بإطفاء الشاشة: شاشة سوداء تماماً حتى أي زر.
  void _blackout() {
    _nav.currentState?.push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => const _Blackout(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 1200),
    ));
  }

  /// زر الهوم: يسكّر أي شاشة أو نافذة مفتوحة ويرجع للواجهة.
  void _goHome() {
    _lastInput = DateTime.now();
    _nav.currentState?.popUntil((r) => r.isFirst);
  }

  bool _onKey(KeyEvent e) {
    _lastInput = DateTime.now();
    return false; // لا نستهلك الزر، فقط نسجل النشاط
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    SystemWatch.I.resumed = _resumed;
    if (_resumed) {
      _lastInput = DateTime.now();
      AppState.I.reloadApps();
      AppState.I.refreshWallpapers();
    }
  }

  Future<void> _checkIdle() async {
    final minutes = AppState.I.cfg.i('saver.minutes');
    if (minutes == 0 || AppState.I.cfg.b('misc.dnd') || SystemWatch.I.quietNow || !_resumed || _saverOpen || ScreensaverScreen.open > 0) return;
    if (DateTime.now().difference(_lastInput) < Duration(minutes: minutes)) return;
    final nav = _nav.currentState;
    if (nav == null) return;
    _saverOpen = true;
    await nav.push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 900),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const ScreensaverScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    _saverOpen = false;
    _lastInput = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _nav,
      navigatorObservers: [routeObserver, RemoteNav.observer],
      debugShowCheckedModeBanner: false,
      title: 'رونق',
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      theme: ThemeData(useMaterial3: true, splashFactory: NoSplash.splashFactory),
      // اتجاه عربي (يمين ← يسار) مفروض على كل القوائم والإعدادات والنوافذ، مهما كانت لغة الجهاز
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: DesignCanvas(child: RemoteNav(child: child!))),
      // الوضع الآمن أولاً، ثم معالج الإعداد لأول تشغيل، وإلا الواجهة
      home: AppState.I.safe ? const SafeModeScreen() : (!AppState.I.cfg.b('setup.done') ? const SetupWizard() : const HomeScreen()),
    );
  }
}

/// كل الواجهة مصممة على لوحة ثابتة 1920×1080.
/// هذه الطبقة تقيس الشاشة الفعلية (أي حجم وأي كثافة) وتكبّر أو تصغّر اللوحة
/// بنسبة واحدة دقيقة، فتبقى المسافات والأحجام متناسقة تماماً بدون قص أو تداخل.
/// وتضيف هامش أمان اختياري للشاشات اللي تقص الحواف (Overscan).
class DesignCanvas extends StatelessWidget {
  static const designWidth = 1920.0;
  final Widget child;
  const DesignCanvas({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final safe = 1 - AppState.I.cfg.i('misc.overscan') / 100;
        // حجم الواجهة (الأداء والحجم): لوحة أعرض = عناصر أصغر، وأضيق = أكبر
        final designWidth = switch (AppState.I.cfg.s('ui.scale')) { 'small' => 2112.0, 'large' => 1760.0, _ => DesignCanvas.designWidth };
        final sw = mq.size.width * safe, sh = mq.size.height * safe;
        if (sw <= 0 || sh <= 0) return const SizedBox.shrink();
        // العرض ثابت ١٩٢٠ والارتفاع يتبع نسبة الشاشة الفعلية (16:9، 21:9، 16:10...)
        // فتملأ الواجهة أي شاشة بالكامل بدون أشرطة أو قص، وبنفس المقاسات بالضبط.
        final designHeight = (designWidth * sh / sw).clamp(900.0, 1440.0);
        final design = Size(designWidth, designHeight);
        final scale = math.min(sw / design.width, sh / design.height);
        return ColoredBox(
          color: AppState.I.palette.bg,
          child: Center(
            child: SizedBox(
              width: design.width * scale,
              height: design.height * scale,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox.fromSize(
                  size: design,
                  child: MediaQuery(
                    data: mq.copyWith(
                      size: design,
                      devicePixelRatio: mq.devicePixelRatio * scale,
                      textScaler: TextScaler.noScaling,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                      systemGestureInsets: EdgeInsets.zero,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _Blackout extends StatelessWidget {
  const _Blackout();

  @override
  Widget build(BuildContext context) => Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent) Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        },
        child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
      );
}
