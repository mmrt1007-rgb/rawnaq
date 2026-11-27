import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tile.dart';
import '../arabic.dart';
import '../backgrounds.dart';
import '../platform.dart';
import '../prayer.dart';
import '../prayer_view.dart';
import '../state.dart';
import '../widgets.dart';
import 'app_edit.dart';
import 'apps_screen.dart';
import 'quick_panel.dart';
import '../lucide.dart';
import '../brand.dart';
import '../liquid_glass.dart';
import 'layout_gallery.dart';
import 'saver_gallery.dart';
import 'system_screens.dart' show PowerNoticeBanner;
import 'streamer_screens.dart' show HomeActions, DailyBanner, openThemeSettings;
import '../streamer_services.dart' show Profiles;
import 'weather_screens.dart' show WeatherScreen, WeatherTileArt;
import 'family_screens.dart' show KidsHome;

const _add = '__add';
const _all = '__all';
const _wx = '__weather';

/// الواجهة الرئيسية بأربعة تخطيطات: صف، شبكة، صفحات، عمود.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {
  final Map<String, FocusNode> _nodes = {};
  final PageController _pages = PageController();
  int _page = 0;
  int _perPage = 1;
  int _cols = 1;
  String? _moving;
  final ScrollController _tvScroll = ScrollController();
  final ValueNotifier<String?> _focusedApp = ValueNotifier(null);

  AppState get s => AppState.I;
  String get layout => s.cfg.s('home.layout');

  FocusNode _node(String id) => _nodes.putIfAbsent(id, () => FocusNode(debugLabel: id));

  @override
  void dispose() {
    homeSignal.removeListener(_onHomePressed);
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    for (final n in _nodes.values) {
      n.dispose();
    }
    _pages.dispose();
    _tvScroll.dispose();
    _focusedApp.dispose();
    super.dispose();
  }

  List<String> get _items => [
        ...Profiles.visible(s.favorites),
        if (s.cfg.b('weather.tile') && s.weather != null && !Profiles.kids) _wx,
        if (s.cfg.b('tile.showAdd') && !Profiles.restricted) _add,
        if (s.cfg.b('tile.showAll') && !Profiles.kids) _all,
      ];

  Future<void> _open(String pkg) async {
    if (s.locked.contains(pkg) && !await askPin(context, title: 'هذا التطبيق مقفل')) return;
    await NativeBridge.launch(pkg);
  }

  @override
  void initState() {
    super.initState();
    homeSignal.addListener(_onHomePressed);
    WidgetsBinding.instance.addObserver(this);
    if (AppState.I.upgradedTo32) {
      AppState.I.upgradedTo32 = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toast(context, 'رونق ٣٫٤: الواجهة الحديثة — غيّرها من الإعدادات ← المظهر ← نمط الواجهة');
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  /// رجعت للواجهة من الإعدادات أو أي شاشة: التركيز على أول تطبيق.
  @override
  void didPopNext() => _toFirst();

  /// رجعت للواجهة بعد تشغيل تطبيق: أول تطبيق.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (ModalRoute.of(context)?.isCurrent ?? false)) _toFirst();
  }

  void _toFirst() {
    if (!mounted) return;
    if (_moving != null) setState(() => _moving = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _items.isNotEmpty) _focusIndex(0);
    });
  }

  /// زر الهوم وأنت بالواجهة: رجوع لأول تطبيق وأول صفحة.
  void _onHomePressed() {
    if (!mounted) return;
    setState(() => _moving = null);
    final items = _items;
    if (items.isEmpty) return;
    _focusIndex(0);
  }

  void _focusLater(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[id]?.requestFocus());
  }

  void _goToPage(int page, String focusId) {
    if (page == _page || !_pages.hasClients) {
      _focusLater(focusId);
      return;
    }
    setState(() => _page = page);
    final d = s.anim(380);
    final near = ((_pages.page ?? _page.toDouble()) - page).abs() <= 1.01;
    if (d == Duration.zero || !near) {
      _pages.jumpToPage(page);
      _focusLater(focusId);
    } else {
      _pages.animateToPage(page, duration: d, curve: Curves.easeOutCubic).then((_) => _focusLater(focusId));
    }
  }

  void _focusIndex(int i) {
    final items = _items;
    if (i < 0 || i >= items.length) return;
    final id = items[i];
    if (layout == 'pages' && _perPage > 0) {
      _goToPage(i ~/ _perPage, id);
    } else {
      final n = _nodes[id];
      if (n != null && n.context != null) {
        n.requestFocus();
      } else {
        _focusLater(id);
      }
    }
  }

  // ---------- وضع الترتيب ----------
  KeyEventResult _moveKeys(String pkg, KeyEvent e) {
    if (_moving != pkg) return KeyEventResult.ignored;
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.handled;
    final k = e.logicalKey;
    final vertical = layout == 'column';
    final rowStep = (layout == 'grid' || layout == 'pages' || layout == 'tvgrid' || layout == 'split') ? _cols : 1;
    int delta = 0;
    if (k == LogicalKeyboardKey.arrowRight && !vertical) delta = -1; // تقديم
    if (k == LogicalKeyboardKey.arrowLeft && !vertical) delta = 1; // تأخير
    if (k == LogicalKeyboardKey.arrowUp) delta = vertical ? -1 : -rowStep;
    if (k == LogicalKeyboardKey.arrowDown) delta = vertical ? 1 : rowStep;
    if (delta != 0) {
      final to = s.move(pkg, delta);
      if (layout == 'pages' && _perPage > 0) {
        _goToPage(to ~/ _perPage, pkg);
      } else {
        _focusLater(pkg);
      }
    } else if (isSelectKey(k) || isBackKey(k)) {
      setState(() => _moving = null);
    }
    return KeyEventResult.handled;
  }

  /// التنقل بالأسهم بترتيب القراءة:
  /// يسار = التالي، يمين = السابق. بنهاية الصف ينزل للصف اللي تحته، وبآخر تطبيق يرجع للأول.
  /// أعلى/أسفل بالشبكة والصفحات = صف كامل. بالعمود: أعلى/أسفل = السابق/التالي مع الالتفاف.
  KeyEventResult _nav(int index, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final n = _items.length;
    if (n == 0) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (arrowDirection(k) != null && repeatTooFast(e)) return KeyEventResult.handled;
    final wrap = s.cfg.b('remote.wrap');
    int? to;
    if (layout == 'column') {
      if (k == LogicalKeyboardKey.arrowDown) to = wrap ? (index + 1) % n : (index + 1 < n ? index + 1 : index);
      if (k == LogicalKeyboardKey.arrowUp) to = index == 0 ? null : index - 1;
    } else {
      if (k == LogicalKeyboardKey.arrowLeft) to = wrap ? (index + 1) % n : (index + 1 < n ? index + 1 : index);
      if (k == LogicalKeyboardKey.arrowRight) to = wrap ? (index - 1 + n) % n : (index > 0 ? index - 1 : index);
      if (layout == 'grid' || layout == 'pages' || layout == 'tvgrid' || layout == 'split') {
        final cols = _cols;
        if (k == LogicalKeyboardKey.arrowDown) {
          if (index + cols < n) {
            to = index + cols;
          } else if (index ~/ cols < (n - 1) ~/ cols) {
            to = n - 1;
          }
        }
        if (k == LogicalKeyboardKey.arrowUp && index - cols >= 0) to = index - cols;
      }
    }
    if (to == null || to == index) return to == index ? KeyEventResult.handled : KeyEventResult.ignored;
    _focusIndex(to);
    return KeyEventResult.handled;
  }

  Future<void> _options(String pkg) => showActions(context, s.labelOf(pkg), [
        ('فتح', Lu.play, () => _open(pkg), false),
        ('ترتيب (تقديم وتأخير)', Lu.move, () {
          setState(() => _moving = pkg);
          _focusLater(pkg);
        }, false),
        ('تخصيص', Lu.sliders, () => Navigator.push(context, fade(AppEditScreen(package: pkg))), false),
        ('معلومات التطبيق', Lu.info, () => NativeBridge.appInfo(pkg), false),
        ('إزالة من الواجهة', Lu.circleMinus, () => s.removeFavorite(pkg), true),
      ]);

  // ---------- مربع واحد ----------
  Widget _tile(String id, int index, TileMetrics m) {
    if (id == _wx) {
      return FocusTap(
        key: const ValueKey(_wx),
        focusNode: _node(id),
        ensureVisible: layout != 'tvgrid',
        onFocus: (f) {
          if (!f) return;
          _focusedApp.value = id;
          if (layout == 'tvgrid') _tvReveal(index);
        },
        onTap: () => Navigator.push(context, fade(const WeatherScreen())),
        onKey: (e) => _nav(index, e),
        builder: (context, f) => TileFrame(
          m: m,
          focused: f,
          label: 'الطقس',
          child: WeatherTileArt(width: m.width, height: m.artHeight),
        ),
      );
    }
    if (id == _add || id == _all) {
      final add = id == _add;
      return FocusTap(
        key: ValueKey(id),
        focusNode: _node(id),
        autofocus: s.favorites.isEmpty && index == 0,
        ensureVisible: layout != 'tvgrid',
        onFocus: (f) {
          if (!f) return;
          _focusedApp.value = id;
          if (layout == 'tvgrid') _tvReveal(index);
        },
        onTap: () => Navigator.push(context, fade(AppsScreen(pickMode: add))),
        onKey: (e) => _nav(index, e),
        builder: (context, f) => TileFrame(
          m: m,
          focused: f,
          dashed: add,
          label: add ? 'إضافة' : 'كل التطبيقات',
          child: ActionArt(icon: add ? Lu.plus : Lu.grid, m: m, focused: f, dashed: add),
        ),
      );
    }
    return FocusTap(
      key: ValueKey(id),
      focusNode: _node(id),
      autofocus: index == 0,
      ensureVisible: layout != 'tvgrid',
      onFocus: (f) {
        if (!f) return;
        _focusedApp.value = id;
        if (layout == 'tvgrid') _tvReveal(index);
      },
      onTap: () {
        if (_moving == id) {
          setState(() => _moving = null);
        } else {
          _open(id);
        }
      },
      onLongPress: _moving == null ? () => _options(id) : null,
      onKey: (e) {
        final r = _moveKeys(id, e);
        if (r == KeyEventResult.handled) return r;
        return _nav(index, e);
      },
      builder: (context, f) => AppTile(package: id, m: m, focused: f, moving: _moving == id),
    );
  }

  // ---------- البناء ----------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // رجوع بالواجهة: يلغي وضع الترتيب، وإلا يرجع لأول تطبيق
      onPopInvokedWithResult: (_, __) {
        if (_moving != null) {
          setState(() => _moving = null);
        } else {
          _toFirst();
        }
      },
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = s.palette;
          final c = s.cfg;
          // ملف الأطفال: واجهة خاصة بيهم بمربعات كبيرة ملونة (فيكما صفحة ١٣)
          if (Profiles.kids) return const Scaffold(body: KidsHome());
          return Scaffold(
            backgroundColor: p.bg,
            resizeToAvoidBottomInset: false,
            body: Stack(fit: StackFit.expand, children: [
              homeBackdrop(),
              if (layout == 'cinema' || layout == 'tvgrid') const _CinemaShade(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: c.d('home.padX'), vertical: c.d('home.padY')),
                child: switch (layout) {
                  'tvgrid' => _tvGridLayout(),
                  'ribbons' => _ribbonsLayout(),
                  'cinema' => _cinemaLayout(),
                  'liquid' => _liquidLayout(),
                  'modern' => _modernLayout(),
                  'dock' => _dockLayout(),
                  'hero' => _heroLayout(),
                  'split' => _splitLayout(),
                  'grid' => _gridLayout(),
                  'pages' => _pagesLayout(),
                  'column' => _columnLayout(),
                  _ => _rowLayout(),
                },
              ),
              // تنبيه الإطفاء المجدول فقط: ينزل من الأعلى ويختفي وحده، وما يسرق التركيز
              const Positioned(top: 40, left: 0, right: 0, child: Center(child: PowerNoticeBanner())),
              // المحتوى اليومي: أول مرة باليوم ٢٠ ثانية ويختفي (فيكما صفحة 11)
              const Positioned(top: 40, left: 0, right: 0, child: Center(child: DailyBanner())),
            ]),
          );
        },
      ),
    );
  }

  Widget _sectionHeader() {
    final p = s.palette;
    final title = s.cfg.s('home.sectionTitle');
    return Row(children: [
      if (title.isNotEmpty) Text(title, style: Fonts.body(26, p.ink, weight: FontWeight.w600)),
      const Spacer(),
      if (_moving != null)
        Text('الأسهم للتحريك · موافق للتثبيت', style: Fonts.body(22, p.accent))
      else if (s.cfg.b('home.showHint'))
        Flexible(child: FitText('ضغطة طويلة على أي تطبيق للترتيب أو التخصيص', style: Fonts.body(22, p.muted), alignment: AlignmentDirectional.centerEnd)),
    ]);
  }

  /// بشبكة Apple TV: الصف الأول يُبقي مساحة الخلفية الكبيرة ظاهرة،
  /// والنزول للصفوف التالية يرفع الشبكة بنعومة وتختفي المساحة.
  void _tvReveal(int index) {
    if (!_tvScroll.hasClients) return;
    final row = index ~/ math.max(1, _cols);
    final d = s.anim(320);
    if (row == 0) {
      if (d == Duration.zero) {
        _tvScroll.jumpTo(0);
      } else {
        _tvScroll.animateTo(0, duration: d, curve: Curves.easeOutCubic);
      }
      return;
    }
    final ctx = _nodes[_items[index]]?.context;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.42, duration: d, curve: Curves.easeOutCubic);
    }
  }

  /// ترتيب Apple TV بتطبيقاتك: مساحة واسعة للخلفية بالأعلى بيها اسم التطبيق المحدد،
  /// وتحتها شبكة تطبيقات بانر بعدد أعمدة ثابت.
  Widget _tvGridLayout() {
    final c = s.cfg;
    final cols = c.i('home.cols').clamp(3, 8);
    _cols = cols;
    final items = _items;
    final t = s.now;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _CinemaTop(),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final m0 = _fitWidth(box.maxWidth, cols);
          final m = TileMetrics(m0.width, onDark: true);
          final shelf = box.maxHeight - m.totalHeight - m.bleed * 2 - 24;
          return AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
            controller: _tvScroll,
            clipBehavior: Clip.none,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // مساحة الخلفية (Top Shelf): اسم التطبيق المحدد والتاريخ
              SizedBox(
                height: math.max(160.0, shelf),
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ValueListenableBuilder<String?>(
                      valueListenable: _focusedApp,
                      builder: (context, id, _) {
                        final name = id == null
                            ? ''
                            : id == _wx
                                ? 'الطقس'
                                : id == _all
                                ? 'كل التطبيقات'
                                : id == _add
                                    ? 'إضافة تطبيق'
                                    : s.labelOf(id);
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          AnimatedSwitcher(
                            duration: s.anim(220),
                            child: Text(name,
                                key: ValueKey(name),
                                style: Fonts.title(64, Colors.white).copyWith(shadows: _cinemaShadow)),
                          ),
                          if (c.b('home.showDate'))
                            Text(
                              '${Ar.dayName(t)} ${Ar.gregorian(t)}${c.b('home.showHijri') ? '  ·  ${Ar.hijri(t, c.i('misc.hijriOffset'))}' : ''}',
                              style: Fonts.body(c.d('home.dateSize') * 0.85, Colors.white.withValues(alpha: 0.82)).copyWith(shadows: _cinemaShadow),
                            ),
                          if (c.b('home.showNextPrayer')) ...[
                            const SizedBox(height: 8),
                            NextPrayerLine(size: c.d('home.dateSize') * 0.8, font: c.s('font.ui'), ink: Colors.white, accent: s.palette.ring, shadows: true),
                          ],
                        ]);
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(m.bleed),
                child: Wrap(
                  spacing: c.d('tile.gap'),
                  runSpacing: c.d('tile.gap'),
                  children: [for (final (i, id) in items.indexed) _tile(id, i, m)],
                ),
              ),
              SizedBox(height: box.maxHeight * 0.35),
            ]),
          ));
        }),
      ),
    ]);
  }

  // سينمائي: الخلفية تملأ الشاشة، معلومات هادئة بالأعلى، والتطبيقات تطفو بالأسفل
  /// شرائط عصرية: شريط علوي بتنقل، بطاقة بارزة للتطبيق المحدد، ثم شريط المفضلة وشريط كل التطبيقات.
  Widget _ribbonsLayout() {
    final c = s.cfg;
    final p = s.palette;
    final items = _items;
    final others = s.installed.map((a) => a.package).where((pkg) => !s.isFavorite(pkg)).toList();
    final m = TileMetrics(c.d('tile.size').clamp(160.0, 260.0));
    return AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
      clipBehavior: Clip.none,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _RibbonTop(onHome: () => _focusIndex(0)),
        const SizedBox(height: 26),
        // البطاقة البارزة
        ValueListenableBuilder<String?>(
          valueListenable: _focusedApp,
          builder: (context, id, _) {
            final pkg = (id == null || id == _add || id == _all || id == _wx) ? (s.favorites.isEmpty ? null : s.favorites.first) : id;
            final name = pkg == null ? 'رونق' : s.labelOf(pkg);
            return AnimatedContainer(
              duration: s.anim(300),
              height: 400,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerEnd,
                  end: AlignmentDirectional.centerStart,
                  colors: [Color.lerp(p.accent, Colors.black, p.night ? 0.35 : 0.15)!, p.accent],
                ),
              ),
              child: Stack(fit: StackFit.expand, children: [
                if (pkg != null)
                  PositionedDirectional(
                    end: 70,
                    top: 70,
                    bottom: 70,
                    child: Opacity(
                      opacity: 0.9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AppArtView(package: pkg, m: TileMetrics(460)),
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: 72,
                  top: 0,
                  bottom: 0,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AnimatedSwitcher(
                      duration: s.anim(220),
                      child: Text(name, key: ValueKey(name), style: Fonts.title(76, Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    Text('موافق للتشغيل · ضغطة طويلة للخيارات', style: Fonts.body(24, Colors.white.withValues(alpha: 0.85))),
                    if (c.b('home.showNextPrayer')) ...[
                      const SizedBox(height: 16),
                      NextPrayerLine(size: 24, font: c.s('font.ui'), ink: Colors.white, accent: p.ring),
                    ],
                  ]),
                ),
              ]),
            );
          },
        ),
        const SizedBox(height: 30),
        Text(c.s('home.sectionTitle').isEmpty ? 'المفضلة' : c.s('home.sectionTitle'), style: Fonts.body(26, p.ink, weight: FontWeight.w600)),
        SizedBox(
          height: m.totalHeight + m.bleed * 2,
          child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.all(m.bleed),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, id) in items.indexed) ...[
                if (i > 0) SizedBox(width: c.d('tile.gap')),
                _tile(id, i, m),
              ],
            ]),
          )),
        ),
        if (others.isNotEmpty) ...[
          Text('كل التطبيقات', style: Fonts.body(26, p.ink, weight: FontWeight.w600)),
          SizedBox(
            height: m.totalHeight + m.bleed * 2,
            child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: EdgeInsets.all(m.bleed),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (i, pkg) in others.indexed) ...[
                  if (i > 0) SizedBox(width: c.d('tile.gap')),
                  FocusTap(
                    key: ValueKey('all-$pkg'),
                    focusNode: _node('all-$pkg'),
                    onFocus: (f) {
                      if (f) _focusedApp.value = pkg;
                    },
                    onTap: () => _open(pkg),
                    onLongPress: () => _options(pkg),
                    onKey: (e) => gridNav(e, index: i, count: others.length, cols: others.length, focus: (j) => _nodes['all-${others[j]}']?.requestFocus()),
                    builder: (context, f) => AppTile(package: pkg, m: m, focused: f),
                  ),
                ],
              ]),
            )),
          ),
        ],
      ]),
    ));
  }

  Widget _cinemaLayout() {
    final m = TileMetrics(s.cfg.d('tile.size'), onDark: true);
    final items = _items;
    final p = s.palette;
    final c = s.cfg;
    final t = s.now;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _CinemaTop(),
      const Spacer(),
      // التحية والتاريخ فوق التطبيقات مباشرة
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (c.b('home.showGreeting'))
              Text(Ar.greeting(t), style: Fonts.title(c.d('home.dateSize') * 1.6, Colors.white).copyWith(shadows: _cinemaShadow)),
            if (c.b('home.showDate'))
              Text(
                '${Ar.dayName(t)} ${Ar.gregorian(t)}${c.b('home.showHijri') ? '  ·  ${Ar.hijri(t, c.i('misc.hijriOffset'))}' : ''}',
                style: Fonts.body(c.d('home.dateSize') * 0.85, Colors.white.withValues(alpha: 0.82)).copyWith(shadows: _cinemaShadow),
              ),
          ]),
        ),
        if (c.b('home.showNextPrayer'))
          NextPrayerLine(size: c.d('home.dateSize') * 0.85, font: c.s('font.ui'), ink: Colors.white, accent: p.ring, shadows: true),
      ]),
      const SizedBox(height: 18),
      SizedBox(
        height: m.totalHeight + m.bleed * 2,
        child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: EdgeInsets.all(m.bleed),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, id) in items.indexed) ...[
              if (i > 0) SizedBox(width: c.d('tile.gap')),
              _tile(id, i, m),
            ],
          ]),
        )),
      ),
    ]);
  }

  /// الخلفية داكنة أو صورة؟ (حتى النص الأبيض يبقى مقروء — بالنهار على خلفية فاتحة يصير بلون الحبر)
  bool get _darkStage {
    final p = s.palette;
    if (p.night || HomeSlides.active) return true;
    final k = s.cfg.s('home.bg');
    return k == 'image' || k == 'slideshow' || k == 'black';
  }

  /// الزجاج السائل (تصميم فيكما): الساعة يمين، شريط تنقل زجاجي بالوسط، معلومات زجاجية يسار،
  /// اسم التطبيق المحدد فوق رف زجاجي عائم بيه التطبيقات.
  Widget _liquidLayout() {
    final c = s.cfg;
    final p = s.palette;
    final t = s.now;
    final w = s.weather;
    final h24 = c.b('home.clock24');
    final ink = p.night ? Colors.white : p.ink;
    final sh = [Shadow(color: Colors.black.withValues(alpha: p.night ? 0.45 : 0.12), blurRadius: 20)];
    final m = TileMetrics(c.d('tile.size'), onDark: p.night);
    final items = _items;
    _cols = items.length;

    Widget navPill(String label, Lu icon, VoidCallback onTap, {bool on = false}) => FocusTap(
          ensureVisible: false,
          onTap: onTap,
          // من الشريط: ▼ ينزل لأول تطبيق مباشرة
          onKey: (e) {
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowDown) {
              _focusIndex(0);
              return KeyEventResult.handled;
            }
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
            return KeyEventResult.ignored;
          },
          builder: (context, f) => AnimatedContainer(
            duration: s.anim(150),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: on || f ? Colors.white.withValues(alpha: p.night ? (f ? 0.30 : 0.20) : (f ? 0.85 : 0.65)) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: f ? p.ring : (on ? Colors.white.withValues(alpha: 0.5) : Colors.transparent), width: f ? 3 : 1), boxShadow: royalShadows(p, f),
            ),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIcon(icon, color: ink, size: 22),
              const SizedBox(width: 10),
              Text(label, style: Fonts.body(20, ink.withValues(alpha: on || f ? 1 : 0.85), weight: on ? FontWeight.w600 : null)),
            ])),
          ),
        );

    Widget chip(String text, Object icon) => LiquidGlass(
          radius: 999,
          strength: 0.8,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
            AppIcon(icon, color: p.night ? p.ring : p.accent, size: 24),
            const SizedBox(width: 12),
            Text(text, style: Fonts.body(20, ink.withValues(alpha: 0.92))),
          ])),
        );

    final next = c.b('home.showNextPrayer') ? Prayers.next(t) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // الساعة والتاريخ
        if (c.b('home.showClock'))
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(Ar.time(t, h24: h24), style: Fonts.clock(132, ink, weight: FontWeight.w300).copyWith(height: 1.0, shadows: sh)),
            if (c.b('home.showDate'))
              Text(
                '${Ar.dayName(t)} · ${Ar.gregorian(t)}${c.b('home.showHijri') ? ' · ${Ar.hijri(t, c.i('misc.hijriOffset'))}' : ''}',
                style: Fonts.body(26, ink.withValues(alpha: 0.8), weight: FontWeight.w300).copyWith(shadows: sh),
              ),
          ]),
        const Spacer(),
        LiquidGlass(
          radius: 999,
          padding: const EdgeInsets.all(8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            navPill('الرئيسية', Lu.house, () => _focusIndex(0), on: true),
            navPill('التطبيقات', Lu.grid, () => Navigator.push(context, fade(const AppsScreen(pickMode: false)))),
            navPill('شاشة السكون', Lu.monitorPlay, () => Navigator.push(context, fade(const SaverGalleryScreen()))),
            navPill('الإعدادات', Lu.settings, () => openThemeSettings(context)),
            const SizedBox(width: 6),
            _QuickButton(onDark: p.night, compact: true),
          ]),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          if (c.b('home.showWeather') && w != null) chip('${Ar.n(w.temp)}°  ${c.s('misc.city').isNotEmpty ? c.s('misc.city') : w.place} · ${w.description}', weatherIcon(w.kind)),
          if (next != null) ...[
            const SizedBox(height: 12),
            chip('${next.name} ${Ar.time(next.time)} · بعد ${remaining(next.time.difference(t))}', Lu.sunset),
          ],
        ]),
      ]),
      const Spacer(),
      // اسم التطبيق المحدد
      ValueListenableBuilder<String?>(
        valueListenable: _focusedApp,
        builder: (context, id, _) {
          final name = id == null ? '' : id == _wx ? 'الطقس' : id == _all ? 'كل التطبيقات' : id == _add ? 'إضافة تطبيق' : s.labelOf(id);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: s.anim(220),
              child: Text(name, key: ValueKey(name), style: Fonts.title(44, ink).copyWith(shadows: sh)),
            ),
            Text('موافق للفتح · ضغطة طويلة للخيارات', style: Fonts.body(22, ink.withValues(alpha: 0.75), weight: FontWeight.w300).copyWith(shadows: sh)),
          ]);
        },
      ),
      const SizedBox(height: 24),
      // الرف الزجاجي
      LiquidGlass(
        radius: 48,
        strength: 1.2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: SizedBox(
          height: m.totalHeight + m.bleed * 2,
          child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.all(m.bleed),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, id) in items.indexed) ...[
                if (i > 0) SizedBox(width: c.d('tile.gap')),
                _tile(id, i, m),
              ],
            ]),
          )),
        ),
      ),
    ]);
  }

  /// «الحديثة» (ترقية ٣٫٤، فيكما صفحة 08): شريط تنقل بالوسط، عمود الوقت يمين، بطاقة بارزة للتطبيق المحدد يسار،
  /// وشريط مربعات ناعمة بالأسفل. بدون أي طبقات تغبيش — أخف ترتيب بالواجهة.
  Widget _modernLayout() {
    final c = s.cfg;
    final p = s.palette;
    final t = s.now;
    final w = s.weather;
    final m = TileMetrics(c.d('tile.size'));
    final items = _items;
    _cols = items.length;
    final next = c.b('home.showNextPrayer') ? Prayers.next(t) : null;
    final glass = p.glass ? p.surface.withValues(alpha: p.night ? 0.55 : 0.72) : p.surface;

    Widget pill(String text, Object icon) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(color: glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.ring.withValues(alpha: 0.38))),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
            AppIcon(icon, color: p.ring, size: 26),
            const SizedBox(width: 12),
            Text(text, style: Fonts.body(21, p.ink)),
          ])),
        );

    Widget navItem(String label, Lu icon, VoidCallback onTap, {bool on = false}) => FocusTap(
          ensureVisible: false,
          onTap: onTap,
          onKey: (e) {
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowDown) {
              _focusIndex(0);
              return KeyEventResult.handled;
            }
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
            return KeyEventResult.ignored;
          },
          builder: (context, f) => AnimatedContainer(
            duration: s.anim(150),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: on ? p.accent : (f ? p.accent.withValues(alpha: 0.16) : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: f ? p.ring : Colors.transparent, width: ringW - 1), boxShadow: royalShadows(p, f),
            ),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIcon(icon, color: on ? p.onAccent : (f ? p.ink : p.muted), size: 22),
              const SizedBox(width: 10),
              Text(label, style: Fonts.body(20, on ? p.onAccent : p.ink, weight: on ? FontWeight.w600 : null)),
            ])),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 72,
        child: Row(children: [
          if (c.b('home.showBrand'))
            BrandTitle(text: c.s('home.brand'), height: 64, color: p.accent, night: p.night),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.ring.withValues(alpha: 0.32))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              navItem('الرئيسية', Lu.house, () => _focusIndex(0), on: true),
              navItem('التطبيقات', Lu.grid, () => Navigator.push(context, fade(const AppsScreen(pickMode: false)))),
              navItem('شاشة السكون', Lu.monitorPlay, () => Navigator.push(context, fade(const SaverGalleryScreen()))),
              navItem('الإعدادات', Lu.settings, () => openThemeSettings(context)),
            ]),
          ),
          const Spacer(),
          _QuickButton(onDark: p.night),
        ]),
      ),
      const SizedBox(height: 28),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // الوقت والمعلومات (يمين)
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.b('home.showGreeting')) Text(Ar.greeting(t), style: Fonts.body(30, p.muted)),
              if (c.b('home.showClock'))
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Ar.time(t, h24: c.b('home.clock24')), style: Fonts.clock(c.d('home.clockSize').clamp(120, 220).toDouble(), p.ink, weight: FontWeight.w400).copyWith(height: 1.05)),
                    if (!c.b('home.clock24')) ...[
                      const SizedBox(width: 16),
                      Padding(padding: const EdgeInsets.only(bottom: 26), child: Text(Ar.period(t), style: Fonts.body(38, p.accent, weight: FontWeight.w600))),
                    ],
                  ]),
                ),
              if (c.b('home.showDate') || c.b('home.showHijri')) ...[
                const SizedBox(height: 6),
                const SizedBox(width: 420, child: RoyalRule()),
                const SizedBox(height: 12),
              ],
              if (c.b('home.showDate')) FitText('${Ar.dayName(t)} ${Ar.gregorian(t)}', style: Fonts.body(32, p.ink)),
              if (c.b('home.showHijri')) FitText(Ar.hijri(t, c.i('misc.hijriOffset')), style: Fonts.body(26, p.muted, weight: FontWeight.w300)),
              const SizedBox(height: 22),
              // الكبسولات بسطر واحد: تصغر بهدوء بدل ما تنزل سطر ثاني
              Row(children: [
                if (c.b('home.showWeather') && w != null)
                  Flexible(child: pill('${Ar.n(w.temp)}° ${c.s('misc.city').isNotEmpty ? c.s('misc.city') : w.place} · ${w.description}', weatherIcon(w.kind))),
                if (c.b('home.showWeather') && w != null && next != null) const SizedBox(width: 14),
                if (next != null) Flexible(child: pill('${next.name} ${Ar.time(next.time)} · بعد ${remaining(next.time.difference(t))}', prayerIcon(next.id))),
              ]),
            ]),
          ),
          const SizedBox(width: 72),
          // البطاقة البارزة (يسار)
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.topCenter,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ValueListenableBuilder<String?>(
                  valueListenable: _focusedApp,
                  builder: (context, id, _) {
                    final art = id == null || id == _all || id == _add || id == _wx ? null : s.artOf(id);
                    const sh = [Shadow(color: Color(0x88000000), blurRadius: 20)];
                    final shape = ContinuousRectangleBorder(borderRadius: BorderRadius.circular(110));
                    return AnimatedSwitcher(
                      duration: s.anim(240),
                      child: Container(
                        key: ValueKey(id),
                        decoration: ShapeDecoration(
                          shape: shape.copyWith(side: BorderSide(color: p.ring.withValues(alpha: 0.5), width: 1.5, strokeAlign: BorderSide.strokeAlignOutside)),
                          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color.lerp(p.accent, Colors.black, 0.25)!, Color.lerp(p.accent, Colors.black, 0.78)!]),
                          shadows: [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.55 : 0.18), blurRadius: 70, offset: const Offset(0, 30))],
                        ),
                        child: ClipPath(
                          clipper: ShapeBorderClipper(shape: shape),
                          child: Stack(fit: StackFit.expand, children: [
                            if (art?.banner != null)
                              Image.memory(art!.banner!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 1100)
                            else if (art?.icon != null)
                              Center(child: Image.memory(art!.icon!, width: 200, height: 200, gaplessPlayback: true, cacheWidth: 300)),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
                                  stops: [0, 0.5, 1],
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              start: 40,
                              end: 40,
                              bottom: 32,
                              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                    FitText(_nameOf(id), style: Fonts.title(56, Colors.white).copyWith(shadows: sh)),
                                    FitText('موافق للفتح · ضغطة مطوّلة للخيارات', style: Fonts.body(20, Colors.white.withValues(alpha: 0.85))),
                                  ]),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                                  child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const AppIcon(Lu.play, color: Color(0xFF13201A), size: 20),
                                    const SizedBox(width: 8),
                                    Text('تشغيل', style: Fonts.body(20, const Color(0xFF13201A), weight: FontWeight.w600)),
                                  ])),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      // عنوان القسم الملكي: معيّن، العنوان، عدد التطبيقات، وخط شعري للحافة
      Row(children: [
        const RoyalDiamond(size: 9),
        const SizedBox(width: 12),
        Flexible(flex: 0, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: FitText(c.s('home.sectionTitle').isEmpty ? 'تطبيقاتك' : c.s('home.sectionTitle'), style: Fonts.body(26, p.ink, weight: FontWeight.w600)))),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: p.accent.withValues(alpha: 0.4))),
          child: Text('${Ar.n(s.favorites.length)} تطبيقات', maxLines: 1, softWrap: false, style: Fonts.body(16, p.ink)),
        ),
        const SizedBox(width: 18),
        Expanded(child: Container(height: 1, color: p.line)),
      ]),
      SizedBox(
        height: m.totalHeight + m.bleed * 2,
        child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: EdgeInsets.all(m.bleed),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, id) in items.indexed) ...[
              if (i > 0) SizedBox(width: c.d('tile.gap')),
              _tile(id, i, m),
            ],
          ]),
        )),
      ),
      if (c.b('home.showHint'))
        Center(child: FitText('أعلى: التنقل · يمين ويسار: التطبيقات · موافق: فتح', alignment: Alignment.center, style: Fonts.body(18, p.muted))),
    ]);
  }

  // ---------- عناصر مشتركة للترتيبات الجديدة ----------
  String _nameOf(String? id) => id == null ? '' : id == _wx ? 'الطقس' : id == _all ? 'كل التطبيقات' : id == _add ? 'إضافة تطبيق' : s.labelOf(id);

  /// زر دائري صغير بالأعلى (الإعدادات، الترتيب...). ▼ منه ينزل لأول تطبيق.
  Widget _roundButton(Lu icon, VoidCallback onTap, {required bool onDark}) {
    final p = s.palette;
    return FocusTap(
      ensureVisible: false,
      onTap: onTap,
      onKey: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowDown) {
          _focusIndex(0);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      builder: (context, f) => AnimatedScale(
        scale: f ? 1.1 : 1,
        duration: s.anim(150),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onDark ? Colors.white.withValues(alpha: f ? 0.95 : 0.14) : p.surface,
            shape: BoxShape.circle,
            border: Border.all(color: f ? p.ring : (onDark ? Colors.white.withValues(alpha: 0.3) : p.line), width: f ? 3 : 1),
          ),
          child: AppIcon(icon, color: onDark ? (f ? Colors.black : Colors.white) : p.ink, size: 28),
        ),
      ),
    );
  }

  /// المواقيت القادمة (للبطاقة البارزة واللوحتين).
  List<PrayerTime> _upcoming(int n) {
    final t = s.now;
    final list = Prayers.forDay(t);
    final after = list.where((x) => x.time.isAfter(t)).toList();
    final tomorrow = Prayers.forDay(t.add(const Duration(days: 1)));
    return [...after, ...tomorrow].take(n).toList();
  }

  Widget _prayerChip(PrayerTime pr, bool next, Color ink, Color accent) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: next ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: next ? accent.withValues(alpha: 0.8) : Colors.transparent, width: 1.5),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(prayerIcon(pr.id), color: next ? accent : ink, size: 26),
          const SizedBox(width: 14),
          Text(pr.name, style: Fonts.body(24, ink.withValues(alpha: 0.85))),
          const SizedBox(width: 14),
          Text(Ar.time(pr.time), style: Fonts.body(24, next ? accent : ink, weight: FontWeight.w500)),
        ])),
      );

  /// «المرسى»: ساعة كبيرة بالوسط، والتطبيقات على شريط زجاجي بالأسفل يكبر عليه المحدد واسمه فوقه.
  Widget _dockLayout() {
    final c = s.cfg;
    final p = s.palette;
    final t = s.now;
    final w = s.weather;
    final m = TileMetrics(132, style: 'icon', labels: 'none');
    final items = _items;
    _cols = items.length;
    final next = c.b('home.showNextPrayer') ? Prayers.next(t) : null;
    final dk = _darkStage;
    final ink = dk ? Colors.white : p.ink;
    final sh = dk ? const [Shadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 2))] : const <Shadow>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        if (c.b('home.showWeather') && w != null) ...[
          Text('${Ar.n(w.temp)}°  ${c.s('misc.city').isNotEmpty ? c.s('misc.city') : w.place}', style: Fonts.body(28, ink).copyWith(shadows: sh)),
          const SizedBox(width: 12),
          AppIcon(weatherIcon(w.kind), color: p.ring, size: 34, shadows: sh),
        ],
        const Spacer(),
        _roundButton(Lu.panelsTopLeft, () => Navigator.push(context, fade(const LayoutGalleryScreen())), onDark: dk),
        const SizedBox(width: 14),
        _roundButton(Lu.grid, () => Navigator.push(context, fade(const AppsScreen(pickMode: false))), onDark: dk),
        const SizedBox(width: 14),
        _roundButton(Lu.settings, () => openThemeSettings(context), onDark: dk),
        const SizedBox(width: 14),
        _QuickButton(onDark: dk),
      ]),
      const Spacer(flex: 2),
      if (c.b('home.showClock'))
        Center(child: Text(Ar.time(t, h24: c.b('home.clock24')), maxLines: 1, softWrap: false, style: Fonts.clock(200, ink, weight: FontWeight.w300).copyWith(height: 1.0, shadows: sh))),
      if (c.b('home.showClock') && c.b('home.showDate')) ...[
        const SizedBox(height: 8),
        const Center(child: SizedBox(width: 400, child: RoyalRule())),
        const SizedBox(height: 14),
      ],
      if (c.b('home.showDate'))
        Center(
          child: FitText(
            '${Ar.dayName(t)} · ${Ar.gregorian(t)}${c.b('home.showHijri') ? ' · ${Ar.hijri(t, c.i('misc.hijriOffset'))}' : ''}',
            alignment: Alignment.center,
            style: Fonts.body(30, ink.withValues(alpha: 0.85), weight: FontWeight.w300).copyWith(shadows: sh),
          ),
        ),
      if (next != null) ...[
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(color: p.glass ? Colors.white.withValues(alpha: 0.10) : p.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.glass ? Colors.white.withValues(alpha: 0.18) : p.line)),
            child: NextPrayerLine(size: 22, font: c.s('font.ui'), ink: ink, accent: p.ring),
          ),
        ),
      ],
      const Spacer(flex: 3),
      ValueListenableBuilder<String?>(
        valueListenable: _focusedApp,
        builder: (context, id, _) => Center(
          child: AnimatedSwitcher(
            duration: s.anim(200),
            child: Text(_nameOf(id), key: ValueKey(id), style: Fonts.body(26, ink, weight: FontWeight.w600).copyWith(shadows: sh)),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1696),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: BackdropFilter(
              enabled: !s.lite && p.glass,
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: p.glass ? Colors.white.withValues(alpha: s.lite ? 0.16 : 0.10) : p.surface,
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: p.glass ? Colors.white.withValues(alpha: 0.22) : p.line, width: 1.5),
                ),
                child: SizedBox(
                  height: m.totalHeight + m.bleed * 2,
                  child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.all(m.bleed),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final (i, id) in items.indexed) ...[
                        if (i > 0) const SizedBox(width: 28),
                        _tile(id, i, m),
                      ],
                    ]),
                  )),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  /// «البطاقة البارزة»: التطبيق المحدد ببطاقة كبيرة يمين، والوقت والمواقيت القادمة يسارها، وصف التطبيقات بالأسفل.
  Widget _heroLayout() {
    final c = s.cfg;
    final p = s.palette;
    final t = s.now;
    final dk = _darkStage;
    final m = TileMetrics(216, style: 'banner', onDark: dk);
    final items = _items;
    _cols = items.length;
    final ups = c.b('home.showPrayers') ? _upcoming(3) : const <PrayerTime>[];
    final nextId = ups.isEmpty ? null : ups.first.id;
    final ink = dk ? Colors.white : p.ink;
    final sh = dk ? const [Shadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 2))] : const <Shadow>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // البطاقة البارزة
          Expanded(
            flex: 3,
            child: ValueListenableBuilder<String?>(
              valueListenable: _focusedApp,
              builder: (context, id, _) {
                final art = id == null ? null : s.artOf(id);
                return AnimatedSwitcher(
                  duration: s.anim(260),
                  child: Container(
                    key: ValueKey(id),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color.lerp(p.accent, Colors.black, 0.25)!, Color.lerp(p.accent, Colors.black, 0.78)!]),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 60, offset: const Offset(0, 26))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Stack(fit: StackFit.expand, children: [
                        if (art?.banner != null)
                          Image.memory(art!.banner!, fit: BoxFit.cover, gaplessPlayback: true)
                        else if (art?.icon != null)
                          Center(child: Image.memory(art!.icon!, width: 220, height: 220, gaplessPlayback: true)),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x00000000), Color(0xAA000000)], stops: [0, 0.45, 1]),
                          ),
                        ),
                        PositionedDirectional(
                          start: 56,
                          end: 56,
                          bottom: 48,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            FitText(_nameOf(id), style: Fonts.title(64, Colors.white).copyWith(shadows: sh)),
                            Text('موافق للفتح · ضغطة طويلة للخيارات', style: Fonts.body(24, Colors.white.withValues(alpha: 0.85), weight: FontWeight.w300)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 72),
          // الوقت والمواقيت
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (c.b('home.showClock'))
                FitText(Ar.time(t, h24: c.b('home.clock24')), alignment: AlignmentDirectional.centerEnd,
                    style: Fonts.clock(150, ink, weight: FontWeight.w300).copyWith(height: 1.0, shadows: sh)),
              if (c.b('home.showDate'))
                Text('${Ar.dayName(t)} ${Ar.gregorian(t)}', style: Fonts.body(30, ink.withValues(alpha: 0.85), weight: FontWeight.w300).copyWith(shadows: sh)),
              const SizedBox(height: 22),
              for (final pr in ups) _prayerChip(pr, pr.id == nextId, ink, p.ring),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _roundButton(Lu.panelsTopLeft, () => Navigator.push(context, fade(const LayoutGalleryScreen())), onDark: dk),
                const SizedBox(width: 14),
                _roundButton(Lu.settings, () => openThemeSettings(context), onDark: dk),
                const SizedBox(width: 14),
                _QuickButton(onDark: dk, compact: true),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: m.totalHeight + m.bleed * 2,
        child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: EdgeInsets.all(m.bleed),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, id) in items.indexed) ...[
              if (i > 0) const SizedBox(width: 30),
              _tile(id, i, m),
            ],
          ]),
        )),
      ),
    ]);
  }

  /// «اللوحتين»: لوحة معلومات ثابتة يمين (الوقت، التاريخان، كل المواقيت، الطقس) وشبكة تطبيقات يسار.
  Widget _splitLayout() {
    final c = s.cfg;
    final p = s.palette;
    final t = s.now;
    final w = s.weather;
    final items = _items;
    const cols = 3;
    _cols = cols;
    final list = c.b('home.showPrayers') ? Prayers.forDay(t) : const <PrayerTime>[];
    final nextId = Prayers.next(t)?.id;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassPanel(
        width: 560,
        radius: BorderRadius.circular(40),
        padding: const EdgeInsets.fromLTRB(44, 44, 44, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (c.b('home.showClock'))
            FitText(Ar.time(t, h24: c.b('home.clock24')), style: Fonts.clock(150, p.ink, weight: FontWeight.w300).copyWith(height: 1.0)),
          if (c.b('home.showClock')) ...[const SizedBox(height: 6), const RoyalRule(), const SizedBox(height: 14)],
          if (c.b('home.showDate')) ...[
            FitText('${Ar.dayName(t)} ${Ar.gregorian(t)}', style: Fonts.body(28, p.ink)),
            if (c.b('home.showHijri')) FitText(Ar.hijri(t, c.i('misc.hijriOffset')), style: Fonts.body(24, p.muted, weight: FontWeight.w300)),
          ],
          const SizedBox(height: 22),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                for (final pr in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: pr.id == nextId ? p.accent.withValues(alpha: 0.14) : Color.lerp(p.surface, p.bg, 0.5),
                      borderRadius: BorderRadius.circular(18 * radiusK),
                      border: Border.all(color: pr.id == nextId ? p.ring.withValues(alpha: 0.7) : p.line),
                    ),
                    child: Row(children: [
                      AppIcon(prayerIcon(pr.id), color: pr.id == nextId ? p.accent : p.muted, size: 24),
                      const SizedBox(width: 14),
                      Expanded(child: FitText(pr.name, style: Fonts.body(24, p.ink, weight: pr.id == nextId ? FontWeight.w600 : null))),
                      Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(Ar.time(pr.time), style: Fonts.body(24, pr.id == nextId ? p.accent : p.ink, weight: FontWeight.w500)))),
                    ]),
                  ),
              ]),
            ),
          ),
          if (c.b('home.showWeather') && w != null)
            Row(children: [
              AppIcon(weatherIcon(w.kind), color: p.ring, size: 30),
              const SizedBox(width: 12),
              Expanded(child: FitText('${Ar.n(w.temp)}° · ${w.description} · ${c.s('misc.city').isNotEmpty ? c.s('misc.city') : w.place}', style: Fonts.body(24, p.ink))),
            ]),
        ]),
      ),
      const SizedBox(width: 64),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const RoyalDiamond(size: 10),
            const SizedBox(width: 14),
            Expanded(child: FitText('تطبيقاتي', style: Fonts.title(44, p.ink))),
            _roundButton(Lu.panelsTopLeft, () => Navigator.push(context, fade(const LayoutGalleryScreen())), onDark: false),
            const SizedBox(width: 14),
            _roundButton(Lu.settings, () => openThemeSettings(context), onDark: false),
            const SizedBox(width: 14),
            const _QuickButton(onDark: false, compact: true),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final m0 = _fitWidth(box.maxWidth, cols);
              final m = TileMetrics(m0.width);
              return AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
                clipBehavior: Clip.none,
                padding: EdgeInsets.all(m.bleed),
                child: Wrap(
                  spacing: c.d('tile.gap'),
                  runSpacing: c.d('tile.gap'),
                  children: [for (final (i, id) in items.indexed) _tile(id, i, m)],
                ),
              ));
            }),
          ),
        ]),
      ),
    ]);
  }

  // صف أفقي واحد تحت الساعة
  Widget _rowLayout() {
    final m = TileMetrics(s.cfg.d('tile.size'));
    final items = _items;
    final center = s.cfg.s('home.align') == 'center';
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        const _TopBar(compact: false),
        // الساعة تاخذ المساحة المتبقية بالضبط، وتصغر تلقائياً إذا ضاقت (بدون قص)
        Expanded(
          child: Align(
            alignment: AlignmentDirectional(center ? 0 : -1, 0.15),
            child: const FittedBox(fit: BoxFit.scaleDown, child: _ClockBlock()),
          ),
        ),
        const SizedBox(height: 12),
        _sectionHeader(),
        SizedBox(
          height: m.totalHeight + m.bleed * 2,
          child: AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.all(m.bleed),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, id) in items.indexed) ...[
                if (i > 0) SizedBox(width: s.cfg.d('tile.gap')),
                _tile(id, i, m),
              ],
            ]),
          )),
        ),
      ],
    );
  }

  // عمود عمودي على جانب، والساعة على الجانب الثاني
  Widget _columnLayout() {
    final m = TileMetrics(s.cfg.d('tile.size'));
    final items = _items;
    return Column(children: [
      const _TopBar(compact: false),
      Expanded(
        child: Row(children: [
          const Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: FittedBox(fit: BoxFit.scaleDown, child: _ClockBlock()))),
          SizedBox(
            width: m.width * m.focusScale + m.bleed * 2 + 60,
            child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
              clipBehavior: Clip.none,
              padding: EdgeInsets.symmetric(vertical: m.bleed + 20, horizontal: m.bleed),
              child: Column(children: [
                for (final (i, id) in items.indexed) ...[
                  if (i > 0) SizedBox(height: s.cfg.d('tile.gap')),
                  _tile(id, i, m),
                ],
              ]),
            )),
          ),
        ]),
      ),
    ]);
  }

  /// يحسب عرض المربع حتى يملأ الأعمدة بالضبط، مع ترك مسافة للتكبير.
  TileMetrics _fitWidth(double available, int cols, {double? maxHeight, int rows = 0}) {
    final gap = s.cfg.d('tile.gap');
    final fs = s.cfg.d('tile.focusScale');
    final ring = s.cfg.d('tile.ringWidth');
    var w = (available - gap * (cols - 1)) / cols;
    final bleed = w * (fs - 1) / 2 + ring + 14;
    w = (available - bleed * 2 - gap * (cols - 1)) / cols;
    var m = TileMetrics(w);
    if (maxHeight != null && rows > 0) {
      final need = rows * m.totalHeight + (rows - 1) * gap + m.bleed * 2;
      if (need > maxHeight) {
        // تصغير متناسب حتى تدخل كل الصفوف بالارتفاع
        final ratio = TileMetrics.ratioFor(m.style);
        final fixed = (rows - 1) * gap + rows * m.labelHeight + m.bleed * 2;
        w = math.max(80.0, (maxHeight - fixed) / (rows * ratio));
        m = TileMetrics(w);
      }
    }
    return m;
  }

  Widget _gridLayout() {
    final cols = s.cfg.i('home.cols').clamp(2, 12);
    _cols = cols;
    final items = _items;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _TopBar(compact: true),
      const SizedBox(height: 28),
      _sectionHeader(),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final m = _fitWidth(box.maxWidth, cols);
          final gap = s.cfg.d('tile.gap');
          return AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
            clipBehavior: Clip.none,
            padding: EdgeInsets.all(m.bleed),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final (i, id) in items.indexed) _tile(id, i, m)],
            ),
          ));
        }),
      ),
    ]);
  }

  Widget _pagesLayout() {
    final cols = s.cfg.i('home.cols').clamp(2, 12);
    final rows = s.cfg.i('home.rows').clamp(1, 6);
    _cols = cols;
    _perPage = cols * rows;
    final items = _items;
    final pageCount = math.max(1, (items.length / _perPage).ceil());
    if (_page >= pageCount) _page = pageCount - 1;
    final p = s.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _TopBar(compact: true),
      const SizedBox(height: 28),
      _sectionHeader(),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final m = _fitWidth(box.maxWidth, cols, maxHeight: box.maxHeight, rows: rows);
          final gap = s.cfg.d('tile.gap');
          return PageView.builder(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pageCount,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, pg) {
              final start = pg * _perPage;
              final end = math.min(start + _perPage, items.length);
              return ExcludeFocus(
                excluding: pg != _page,
                child: Padding(
                  padding: EdgeInsets.all(m.bleed),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [for (var i = start; i < end; i++) _tile(items[i], i, m)],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
      if (pageCount > 1)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < pageCount; i++)
            AnimatedContainer(
              duration: s.anim(220),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: i == _page ? 36 : 12,
              height: 12,
              decoration: BoxDecoration(
                color: i == _page ? p.accent : p.line,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ]),
    ]);
  }
}

// =====================================================================

class _TopBar extends StatelessWidget {
  final bool compact;
  const _TopBar({required this.compact});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: AppState.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final p = s.palette;
    final w = s.weather;
    final t = s.now;
    return Row(children: [
      if (c.b('home.showBrand') && c.s('home.brand').isNotEmpty) BrandTitle(text: c.s('home.brand'), height: 70, color: p.accent, night: p.night),
      if (compact && c.b('home.showClock')) ...[
        if (c.b('home.showBrand')) const SizedBox(width: 40),
        Text(Ar.time(t, h24: c.b('home.clock24')), style: Fonts.clock(72, p.ink)),
        if (!c.b('home.clock24')) ...[
          const SizedBox(width: 12),
          Text(Ar.period(t), style: Fonts.clock(28, p.accent, weight: FontWeight.w400)),
        ],
        if (c.b('home.showDate')) ...[
          const SizedBox(width: 28),
          Flexible(
            child: FitText(
              '${Ar.dayName(t)} ${Ar.gregorian(t)}${c.b('home.showHijri') ? '  ·  ${Ar.hijri(t, c.i('misc.hijriOffset'))}' : ''}',
              style: Fonts.body(24, p.muted),
            ),
          ),
        ],
      ],
      const Spacer(),
      if (compact && c.b('home.showNextPrayer')) ...[
        NextPrayerLine(size: 24, font: c.s('font.ui'), ink: p.ink, accent: p.accent),
        const SizedBox(width: 32),
      ],
      if (c.b('home.showWeather') && w != null) ...[
        AppIcon(weatherIcon(w.kind), color: p.ring, size: 34),
        const SizedBox(width: 12),
        Text('${Ar.n(w.temp)}°', maxLines: 1, softWrap: false, style: Fonts.body(28, p.ink, weight: FontWeight.w600)),
        const SizedBox(width: 12),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: FitText(w.description, style: Fonts.body(24, p.muted))),
        const SizedBox(width: 28),
      ],
      const _QuickButton(onDark: false),
      const SizedBox(width: 16),
      FocusTap(
        ensureVisible: false,
        onTap: () => openThemeSettings(context),
        onLongPress: () => _announceStyle(context, s.cycleStyle()),
        builder: (context, f) => AnimatedContainer(
          duration: s.anim(160),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: royalFill(p, p.surface, f),
            shape: BoxShape.circle,
            border: Border.all(color: f ? p.ring : p.line, width: f ? ringW * 0.62 : 1),
            boxShadow: royalShadows(p, f),
          ),
          child: AppIcon(Lu.settings, color: f ? p.ring : p.ink, size: 32),
        ),
      ),
    ]);
  }
}

class _ClockBlock extends StatelessWidget {
  const _ClockBlock();

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: AppState.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final p = s.palette;
    final t = s.now;
    final center = c.s('home.align') == 'center';
    final dateSize = c.d('home.dateSize');
    final h24 = c.b('home.clock24');
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (c.b('home.showGreeting')) Text(Ar.greeting(t), style: Fonts.body(28, p.muted)),
          if (c.b('home.showClock'))
            FittedBox(
              fit: BoxFit.scaleDown,
              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(Ar.time(t, h24: h24), style: Fonts.clock(c.d('home.clockSize'), p.ink)),
                  if (!h24) ...[
                    SizedBox(width: c.d('home.clockSize') * 0.12),
                    Text(Ar.period(t), style: Fonts.clock(c.d('home.clockSize') * 0.26, p.accent, weight: FontWeight.w400)),
                  ],
                ],
              )),
            ),
          if (c.b('home.showDate')) ...[
            SizedBox(height: dateSize * 0.5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${Ar.dayName(t)} ${Ar.gregorian(t)}', style: Fonts.body(dateSize, p.ink, weight: FontWeight.w500)),
                  if (c.b('home.showHijri'))
                    TextSpan(text: '  ·  ${Ar.hijri(t, c.i('misc.hijriOffset'))}', style: Fonts.body(dateSize * 0.93, p.muted)),
                ]),
                maxLines: 1,
                softWrap: false,
                textAlign: center ? TextAlign.center : TextAlign.start,
              ),
            ),
          ],
          if (c.b('home.showNextPrayer')) ...[
            SizedBox(height: dateSize * 0.7),
            NextPrayerLine(size: dateSize * 0.9, font: c.s('font.ui'), ink: p.ink, accent: p.accent),
          ],
          if (c.b('home.showPrayers')) ...[
            SizedBox(height: dateSize * 0.6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: PrayerStrip(
                size: dateSize * 0.78,
                font: c.s('font.ui'),
                ink: p.ink,
                muted: p.muted,
                accent: p.accent,
                chip: p.surface.withValues(alpha: 0.6),
                alignment: center ? WrapAlignment.center : WrapAlignment.start,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


const _cinemaShadow = [Shadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 2))];

/// تظليل سينمائي: يعتّم الأسفل والأعلى بنعومة حتى تبرز التطبيقات والنصوص فوق أي صورة.
class _CinemaShade extends StatelessWidget {
  const _CinemaShade();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000), Color(0x14000000), Color(0xB3000000)],
              stops: [0.0, 0.24, 0.5, 1.0],
            ),
          ),
          child: SizedBox.expand(),
        ),
      );
}

/// الشريط العلوي السينمائي: الساعة صغيرة وأنيقة بزاوية، والطقس والإعدادات بالزاوية الثانية.
class _CinemaTop extends StatelessWidget {
  const _CinemaTop();

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: AppState.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final t = s.now;
    final w = s.weather;
    final h24 = c.b('home.clock24');
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (c.b('home.showClock')) ...[
        Text(Ar.time(t, h24: h24), style: Fonts.clock(64, Colors.white, weight: FontWeight.w400).copyWith(shadows: _cinemaShadow)),
        if (!h24) ...[
          const SizedBox(width: 10),
          Text(Ar.period(t), style: Fonts.clock(26, Colors.white70, weight: FontWeight.w400).copyWith(shadows: _cinemaShadow)),
        ],
      ],
      const Spacer(),
      if (c.b('home.showWeather') && w != null) ...[
        AppIcon(weatherIcon(w.kind), color: Colors.white, size: 32, shadows: _cinemaShadow),
        const SizedBox(width: 10),
        Text('${Ar.n(w.temp)}°', style: Fonts.body(28, Colors.white, weight: FontWeight.w600).copyWith(shadows: _cinemaShadow)),
        const SizedBox(width: 28),
      ],
      const _QuickButton(onDark: true),
      const SizedBox(width: 16),
      FocusTap(
        ensureVisible: false,
        onTap: () => openThemeSettings(context),
        onLongPress: () => _announceStyle(context, s.cycleStyle()),
        builder: (context, f) => AnimatedScale(
          scale: f ? 1.12 : 1,
          duration: s.anim(160),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: f ? Colors.white : Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: AppIcon(Lu.settings, color: f ? Colors.black : Colors.white, size: 30),
          ),
        ),
      ),
    ]);
  }
}


void _announceStyle(BuildContext context, String style) => toast(
      context,
      switch (style) {
        'glass' => 'نمط الزجاج المغبش',
        'cinema' => 'النمط السينمائي (ترتيب Apple TV)',
        'ribbons' => 'نمط الشرائط العصرية',
        _ => 'النمط الكلاسيكي',
      },
    );


/// زر اللوحة السريعة، مع مؤشر مؤقت الإطفاء إذا كان شغال.
class _QuickButton extends StatelessWidget {
  final bool onDark, compact;
  const _QuickButton({required this.onDark, this.compact = false});

  /// أزرار البحث والتنبيهات والملف وإعدادات الجهاز (فيكما صفحة 11) قبل زر اللوحة السريعة.
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        HomeActions(onDark: onDark, compact: compact),
        const SizedBox(width: 14),
        _quick(context),
      ]);

  Widget _quick(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final left = s.sleepLeft;
    return FocusTap(
      ensureVisible: false,
      onTap: () => showQuickPanel(context),
      builder: (context, f) {
        final fg = onDark ? (f ? Colors.black : Colors.white) : p.ink;
        final bg = onDark ? (f ? Colors.white : Colors.white.withValues(alpha: 0.16)) : p.surface;
        return AnimatedScale(
          scale: f ? 1.1 : 1,
          duration: s.anim(150),
          child: AnimatedContainer(
            duration: s.anim(150),
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: left == null ? 0 : 18),
            constraints: const BoxConstraints(minWidth: 64),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: onDark ? Colors.white.withValues(alpha: 0.35) : (f ? p.ring : p.line), width: !onDark && f ? 4 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              AppIcon(Lu.dashboard, color: fg, size: 30),
              if (left != null) ...[
                const SizedBox(width: 8),
                AppIcon(Lu.moon, color: fg, size: 22),
                const SizedBox(width: 4),
                Text('${Ar.n((left.inSeconds / 60).ceil())} د', style: Fonts.body(20, fg, weight: FontWeight.w600)),
              ],
            ]),
          ),
        );
      },
    );
  }
}


/// الشريط العلوي للشرائط العصرية: الساعة، أزرار تنقل (الرئيسية/التطبيقات/الإعدادات)، والطقس واللوحة السريعة.
class _RibbonTop extends StatelessWidget {
  final VoidCallback onHome;
  const _RibbonTop({required this.onHome});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: AppState.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final p = s.palette;
    final t = s.now;
    final w = s.weather;
    final h24 = c.b('home.clock24');
    Widget pill(String label, VoidCallback onTap, {bool on = false}) => FocusTap(
          ensureVisible: false,
          onTap: onTap,
          builder: (context, f) => AnimatedContainer(
            duration: s.anim(150),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: on ? p.accent : (f ? p.accent.withValues(alpha: 0.14) : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: f ? p.ring : Colors.transparent, width: 3), boxShadow: royalShadows(p, f),
            ),
            child: Text(label, style: Fonts.body(22, on ? p.onAccent : (f ? p.ink : p.muted), weight: on ? FontWeight.w600 : null)),
          ),
        );
    return Row(children: [
      if (c.b('home.showClock')) ...[
        Text(Ar.time(t, h24: h24), style: Fonts.clock(58, p.ink)),
        if (!h24) ...[
          const SizedBox(width: 10),
          Text(Ar.period(t), style: Fonts.clock(24, p.accent, weight: FontWeight.w400)),
        ],
      ],
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.line, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          pill('الرئيسية', onHome, on: true),
          pill('التطبيقات', () => Navigator.push(context, fade(const AppsScreen(pickMode: false)))),
          pill('الإعدادات', () => openThemeSettings(context)),
        ]),
      ),
      const Spacer(),
      if (c.b('home.showWeather') && w != null) ...[
        AppIcon(weatherIcon(w.kind), color: p.ring, size: 30),
        const SizedBox(width: 8),
        Text('${Ar.n(w.temp)}°', style: Fonts.body(26, p.ink, weight: FontWeight.w600)),
        const SizedBox(width: 20),
      ],
      const _QuickButton(onDark: false),
    ]);
  }
}
