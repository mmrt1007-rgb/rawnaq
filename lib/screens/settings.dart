import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arabic.dart';
import '../backgrounds.dart';
import '../brand.dart' show RawnaqLoader, loaderWriteSeconds;
import 'home_slides.dart';
import '../config.dart';
import '../platform.dart';
import '../prayer.dart';
import '../prayer_view.dart';
import '../wallpaper_fetcher.dart';
import '../app_tile.dart';
import '../state.dart';
import '../widgets.dart';
import 'apps_screen.dart';
import 'layout_gallery.dart';
import 'liquid_settings.dart';
import 'remote_settings.dart';
import 'saver_gallery.dart';
import 'screensaver.dart';
import 'settings_preview.dart';
import 'about.dart';
import 'system_screens.dart';
import 'streamer_screens.dart';
import '../streamer_services.dart';
import 'wall_library.dart';
import 'wallpapers.dart';
import '../lucide.dart';
import '../weather.dart' show WeatherHub;
import 'weather_screens.dart' show WeatherScreen, CitiesScreen, AddCityScreen;
import 'family_screens.dart';

/// الإعدادات: أقسام على اليمين، وكل خيارات القسم على اليسار. كل تغيير يظهر فوراً.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _section = 0;
  bool _inContent = false; // مقفل داخل خيارات القسم
  final _scroll = ScrollController();
  final _sidebar = FocusScopeNode(debugLabel: 'settings-sidebar');
  final _content$ = FocusScopeNode(debugLabel: 'settings-content');
  late final List<FocusNode> _secNodes = [for (var i = 0; i < _sections.length; i++) FocusNode(debugLabel: 'sec$i')];
  final Map<int, FocusNode> _lastFocus = {}; // آخر خيار كنت عليه بكل قسم
  ThemePreset? _peekPreset; // الثيم المحدد بالصف قبل تطبيقه (للمعاينة)
  String? _peekStyle;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_trackFocus);
  }

  void _trackFocus() {
    final f = FocusManager.instance.primaryFocus;
    if (f == null || !_inContent) return;
    for (FocusNode? n = f; n != null; n = n.parent) {
      if (n == _content$) {
        _lastFocus[_section] = f;
        return;
      }
    }
  }

  static const _sections = [
    (Lu.palette, 'المظهر والألوان'),
    (Lu.type, 'الخطوط'),
    (Lu.house, 'الواجهة الرئيسية'),
    (Lu.grid, 'التطبيقات والأيقونات'),
    (Lu.monitorPlay, 'شاشة السكون'),
    (Lu.landmark, 'مواقيت الصلاة'),
    (Lu.images, 'الخلفيات'),
    (Lu.calendar, 'التاريخ والطقس'),
    (Lu.gamepad, 'الريموت والتنقل'),
    (Lu.contrast, 'إمكانية الوصول'),
    (Lu.tv, 'الشاشة والنظام'),
    (Lu.gauge, 'الحركة والسرعة'),
    (Lu.penLine, 'حركة الشعار'),
    (Lu.info, 'حول رونق'),
  ];

  @override
  void dispose() {
    FocusManager.instance.removeListener(_trackFocus);
    _scroll.dispose();
    _sidebar.dispose();
    _content$.dispose();
    for (final n in _secNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ---------------- التنقل ----------------

  /// موافق على قسم: يدخل ويقفل داخل خياراته، ويرجع لآخر خيار كان عليه.
  void _enterContent() {
    focusedOption.value = null;
    focusedKey.value = null;
    setState(() => _inContent = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final last = _lastFocus[_section];
      if (last != null && last.context != null && last.canRequestFocus) {
        last.requestFocus();
        return;
      }
      for (final n in _content$.traversalDescendants) {
        if (n.canRequestFocus && n.context != null) {
          n.requestFocus();
          return;
        }
      }
    });
  }

  /// الرجوع: خيارات ← القسم نفسه ← أول قسم ← الخروج للواجهة.
  void _back() {
    if (_inContent) {
      focusedKey.value = null;
      setState(() => _inContent = false);
      _secNodes[_section].requestFocus();
      return;
    }
    if (_section != 0) {
      _selectSection(0);
      _secNodes[0].requestFocus();
      return;
    }
    if (AppState.I.cfg.b('remote.confirmExit')) {
      _confirmExit();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmExit() async {
    var leave = false;
    await showActions(context, 'تطلع من الإعدادات؟', [
      ('خروج للواجهة', Lu.house, () => leave = true, false),
      ('البقاء بالإعدادات', Lu.settings, () {}, false),
    ]);
    if (leave && mounted) Navigator.of(context).pop();
  }

  void _selectSection(int i) {
    if (_section == i) return;
    focusedOption.value = null;
    focusedKey.value = null;
    setState(() {
      _section = i;
      _peekPreset = null;
      _peekStyle = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  KeyEventResult _sidebarKeys(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (arrowDirection(k) != null && repeatTooFast(e)) return KeyEventResult.handled;
    if (k == LogicalKeyboardKey.arrowDown) {
      final n = (i + 1) % _sections.length;
      _secNodes[n].requestFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      final n = (i - 1 + _sections.length) % _sections.length;
      _secNodes[n].requestFocus();
      return KeyEventResult.handled;
    }
    // اليمين واليسار ما يطلعون من القائمة: الدخول بزر موافق فقط
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ThemedScaffold(
        child: ListenableBuilder(
          listenable: AppState.I,
          builder: (context, _) {
            final s = AppState.I;
            final p = s.palette;
            return Row(children: [
              // ---------- الأقسام ----------
              GlassPanel(
                width: 440,
                radius: BorderRadius.zero,
                border: false,
                padding: const EdgeInsets.fromLTRB(36, 56, 36, 32),
                child: FocusScope(
                  node: _sidebar,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      AppIcon(Lu.settings, color: p.accent, size: 44),
                      const SizedBox(width: 14),
                      Text('الإعدادات', style: Fonts.title(48, p.ink)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_inContent ? 'رجوع: للأقسام' : 'موافق: دخول · رجوع: ${_section == 0 ? 'خروج' : 'أول قسم'}',
                        style: Fonts.body(18, p.muted)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.all(4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (final (i, sec) in _sections.indexed)
                            FocusTap(
                              key: ValueKey('section$i'),
                              focusNode: _secNodes[i],
                              autofocus: i == 0,
                              onFocus: (f) {
                                if (f) _selectSection(i);
                              },
                              onTap: _enterContent,
                              onKey: (e) => _sidebarKeys(i, e),
                              builder: (context, f) {
                                final active = _section == i;
                                return AnimatedContainer(
                                  duration: s.anim(140),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: active ? p.accent.withValues(alpha: _inContent ? 0.22 : 0.12) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: f ? p.ring : Colors.transparent, width: ringW),
                                  ),
                                  child: Row(children: [
                                    AppIcon(sec.$1, color: active ? p.accent : p.muted, size: 28),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: FitText(
                                        sec.$2,
                                        style: Fonts.body(24, active ? p.ink : p.muted, weight: active ? FontWeight.w600 : null),
                                      ),
                                    ),
                                    if (active) AppIcon(_inContent ? Lu.lock : Lu.chevronLeft, color: p.accent, size: 26),
                                  ]),
                                );
                              },
                            ),
                        ]),
                      )),
                    ),
                  ]),
                ),
              ),
              // ---------- الخيارات ----------
              Expanded(
                child: AnimatedOpacity(
                  opacity: _inContent ? 1 : 0.55,
                  duration: s.anim(180),
                  child: Column(children: [
                    Expanded(
                      child: ExcludeFocus(
                        excluding: !_inContent,
                        // التنقل الموحّد: ▲▼ بين الصفوف فقط، ◀▶ لتعديل القيمة بالصف المحدد،
                        // موافق للدخول والتطبيق، ورجوع وحده يطلع — وما يطلع التركيز برا القسم أبداً.
                        child: NavZone(
                          node: _content$,
                          child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
                            controller: _scroll,
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.fromLTRB(52, 64, 52, 32),
                            child: Column(
                              key: ValueKey('content$_section'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _content(context, _section),
                            ),
                          )),
                        ),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.fromLTRB(52, 8, 52, 40), child: KeyGuide()),
                  ]),
                ),
              ),
              // ---------- المعاينة الحيّة ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 72, 48, 72),
                child: SizedBox(
                  width: 600,
                  child: SettingsPreview(
                    section: _section,
                    title: _sections[_section].$2,
                    previewPreset: _peekPreset,
                    previewStyle: _peekStyle,
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, int i) => switch (i) {
        0 => _appearance(context),
        1 => _fonts(),
        2 => _home(context),
        3 => _tiles(context),
        4 => _saver(context),
        5 => _prayers(),
        6 => _walls(context),
        7 => _dateWeather(context),
        8 => _remote(context),
        9 => _a11y(),
        10 => _general(context),
        11 => _motion(),
        12 => _logoMotion(),
        _ => _about(context),
      };

  String _imgName(String path) => path.isEmpty ? 'لم تُختر' : path.split('/').last;

  // ---------------------------------------------------------------
  List<Widget> _appearance(BuildContext context) {
    final s = AppState.I;
    final hours = [for (var h = 0; h < 24; h++) (h, _hour(h))];
    return [
      SectionTitle('الثيم الملكي (ألوان وخطوط)'),
      SelectorRow<ThemePreset>(
        key: const ValueKey('royal-row'),
        title: 'الثيم الملكي',
        values: ThemePreset.all,
        selected: ThemePreset.all.where((x) => x.id == s.cfg.s('theme.preset')).firstOrNull,
        onSelect: (preset) {
          s.cfg.applyPreset(preset);
          s.touch();
          setState(() => _peekPreset = null);
        },
        onHighlight: (v) => setState(() => _peekPreset = v),
        itemBuilder: (context, preset, hi, sel) => _PresetCard(preset: preset, focused: hi, active: sel),
      ),
      ToggleRow(
        title: 'تطبيق الترتيب الملكي مع الثيم',
        subtitle: 'كل ثيم يجي بترتيب واجهته وشكل أيقوناته وخلفيته — أطفيه حتى يتغير اللون والخط فقط',
        value: s.cfg.b('theme.withLayout'),
        onChanged: (v) => s.set('theme.withLayout', v),
      ),
      SectionTitle('نمط الواجهة'),
      _StyleCards(onHighlight: (v) => setState(() => _peekStyle = v)),
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text('التبديل لحظي وكل إعداداتك تبقى. اختصار: ضغطة طويلة على زر الإعدادات بالواجهة.', style: Fonts.body(19, s.palette.muted)),
      ),
      if (s.cfg.s('ui.style') == 'liquid')
        NavRow(
          title: 'تحكم الزجاج السائل',
          subtitle: 'الغواش، الكثافة، لمعة الحواف، التشبّع، والاستدارة — بمعاينة حيّة',
          onTap: () => Navigator.push(context, fade(const LiquidGlassScreen())),
        )
      else if (s.cfg.s('ui.style') != 'classic') ...[
        cStep('قوة التغبيش', 'ui.blur', 0, 60, 2, fmtPx),
        cStep('كثافة الزجاج', 'ui.tint', 0, 1, 0.05, fmtPct),
      ],
      cChoice<String>('وضع الثيم', 'theme.mode', const [('auto', 'مع الشروق والغروب'), ('hours', 'حسب ساعات أحددها'), ('day', 'نهاري دائماً'), ('night', 'ليلي دائماً')],
          sub: s.cfg.s('theme.mode') == 'auto' ? 'النهار من الشروق للغروب الحقيقي بمدينتك، ويتبدل وحده كل يوم' : null),
      if (s.cfg.s('theme.mode') == 'hours') ...[
        cChoice<int>('بداية الثيم النهاري', 'theme.dayStart', hours),
        cChoice<int>('بداية الثيم الليلي', 'theme.nightStart', hours),
      ],
      SectionTitle('ألوان الثيم النهاري'),
      ..._colors('day'),
      SectionTitle('ألوان الثيم الليلي'),
      ..._colors('night'),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة الألوان للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['day.', 'night.', 'theme.preset']);
          s.touch();
        }),
      ]),
    ];
  }

  List<Widget> _colors(String m) => [
        cColor('الخلفية', '$m.bg'),
        cColor('الأسطح (البطاقات)', '$m.surface'),
        cColor('النص الأساسي', '$m.ink'),
        cColor('النص الثانوي', '$m.muted'),
        cColor('لون التمييز', '$m.accent'),
        cColor('إطار التركيز', '$m.ring'),
        cColor('الخطوط والحدود', '$m.line'),
      ];

  // ---------------------------------------------------------------
  List<Widget> _fonts() {
    final s = AppState.I;
    final p = s.palette;
    return [
      Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FitText(Ar.time(s.now), style: Fonts.clock(110, p.ink)),
          const SizedBox(height: 8),
          Text('عنوان بالخط المختار', style: Fonts.title(40, p.accent)),
          const SizedBox(height: 6),
          Text('هذا مثال على نص الواجهة العادي بالحجم الحالي.', style: Fonts.body(26, p.muted)),
        ]),
      ),
      SelectorRow<String>(
        key: const ValueKey('font-pairs'),
        title: 'أزواج خطوط جاهزة',
        values: [for (final f in fontPairs) f.$1],
        selected: fontPairs.where((f) => f.$3 == s.cfg.s('font.title') && f.$4 == s.cfg.s('font.ui') && f.$5 == s.cfg.s('font.clock')).firstOrNull?.$1,
        onSelect: (id) {
          final f = fontPairs.firstWhere((x) => x.$1 == id);
          s.set('font.title', f.$3);
          s.set('font.ui', f.$4);
          s.set('font.clock', f.$5);
          s.set('font.pair', id);
        },
        itemBuilder: (context, id, hi, sel) => _FontPairCard(pair: fontPairs.firstWhere((x) => x.$1 == id), focused: hi, active: sel),
      ),
      cFont('خط الواجهة (النصوص)', 'font.ui'),
      cFont('خط العناوين', 'font.title'),
      cFont('خط الساعة والتاريخ', 'font.clock'),
      cStep('حجم الخط العام', 'font.scale', 0.70, 1.60, 0.05, fmtPct, sub: 'يكبّر أو يصغّر كل النصوص بنفس النسبة'),
      cChoice<int>('سُمك النص', 'font.weight', const [(300, 'خفيف'), (400, 'عادي'), (500, 'متوسط'), (600, 'سميك')]),
      Text('خطوط شاشة السكون مستقلة، تلقاها بقسم شاشة السكون.', style: Fonts.body(20, p.muted)),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة الخطوط للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['font.']);
          s.touch();
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _home(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final layout = c.s('home.layout');
    final bg = c.s('home.bg');
    return [
      _ProfileNote(),
      NavRow(
        title: 'معرض ترتيبات الواجهة',
        subtitle: '${homeLayouts.length} ترتيب بمعاينة: المرسى، البطاقة البارزة، اللوحتين، الزجاج السائل، شبكة التلفاز...',
        value: homeLayouts.firstWhere((x) => x.$1 == layout, orElse: () => homeLayouts.first).$2,
        onTap: () => Navigator.push(context, fade(const LayoutGalleryScreen())),
      ),
      cChoice<String>('تخطيط التطبيقات', 'home.layout', [for (final l in homeLayouts) (l.$1, l.$2)]),
      if (layout == 'grid' || layout == 'pages' || layout == 'tvgrid') cStepInt('عدد الأعمدة', 'home.cols', 2, 12, Ar.n),
      if (layout == 'pages') cStepInt('عدد الصفوف بالصفحة', 'home.rows', 1, 6, Ar.n),
      if (layout == 'row') cChoice<String>('محاذاة الساعة', 'home.align', const [('start', 'بداية السطر'), ('center', 'بالوسط')]),
      SectionTitle('العناصر الظاهرة'),
      cToggle('الاسم أعلى الشاشة', 'home.showBrand'),
      NavRow(
        title: 'نص الاسم',
        value: c.s('home.brand'),
        onTap: () async {
          final v = await promptText(context, title: 'نص الاسم', initial: c.s('home.brand'));
          if (v != null) s.set('home.brand', v);
        },
      ),
      cToggle('التحية (صباح النور...)', 'home.showGreeting'),
      cToggle('الساعة', 'home.showClock'),
      cToggle('التاريخ الميلادي', 'home.showDate'),
      cToggle('التاريخ الهجري', 'home.showHijri'),
      cToggle('الطقس', 'home.showWeather'),
      cToggle('مواقيت الصلاة', 'home.showPrayers'),
      cToggle('الوقت القادم والعد التنازلي', 'home.showNextPrayer'),
      cToggle('سطر التلميح', 'home.showHint'),
      NavRow(
        title: 'عنوان قسم التطبيقات',
        value: c.s('home.sectionTitle').isEmpty ? 'بدون' : c.s('home.sectionTitle'),
        onTap: () async {
          final v = await promptText(context, title: 'عنوان القسم (اتركه فارغاً لإخفائه)', initial: c.s('home.sectionTitle'));
          if (v != null) s.set('home.sectionTitle', v.trim());
        },
      ),
      SectionTitle('الساعة والتاريخ'),
      cChoice<bool>('نظام الساعة', 'home.clock24', const [(false, '١٢ ساعة'), (true, '٢٤ ساعة')]),
      cStep('حجم الساعة', 'home.clockSize', 80, 360, 4, fmtPx),
      cStep('حجم التاريخ', 'home.dateSize', 16, 64, 1, fmtPx),
      SectionTitle('الهوامش'),
      cStep('الهامش الجانبي', 'home.padX', 32, 260, 4, fmtPx),
      cStep('الهامش العلوي والسفلي', 'home.padY', 24, 180, 4, fmtPx),
      SectionTitle('خلفية الواجهة'),
      NavRow(
        title: 'صور الواجهة المتغيرة',
        subtitle: c.b('home.slides') ? 'مفعّلة فوق كل الثيمات، وتتلون مع الثيم' : 'صور تتبدل بهدوء خلف الواجهة، بكل الثيمات',
        value: c.b('home.slides') ? '${Ar.n(HomeSlides.paths().length)} صورة' : 'مطفأة',
        onTap: () => Navigator.push(context, fade(const HomeSlidesScreen())),
      ),
      cChoice<String>('نوع الخلفية', 'home.bg', const [('aurora', 'أورورا ناعمة'), ('solid', 'لون الثيم'), ('gradient', 'تدرج'), ('art', 'فنية'), ('image', 'صورة'), ('slideshow', 'عرض صور متتابع')]),
      if (bg == 'art') cChoice<String>('التصميم الفني', 'home.art', ArtStyles.all),
      if (bg == 'image') ...[
        NavRow(
          title: 'الصورة',
          value: _imgName(c.s('home.image')),
          onTap: () => Navigator.push(context, fade(const WallpapersScreen(pickFor: 'home.image'))),
        ),
        cStep('تعتيم الصورة', 'home.dim', 0, 0.85, 0.05, fmtPct, sub: 'حتى يبقى النص واضح فوق الصورة'),
      ],
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة الواجهة للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['home.']);
          s.touch();
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _tiles(BuildContext context) {
    final s = AppState.I;
    return [
      _ProfileNote(),
      NavRow(
        title: 'اختيار التطبيقات الظاهرة',
        value: '${Ar.n(s.favorites.length)} تطبيق',
        onTap: () => Navigator.push(context, fade(const AppsScreen(pickMode: true))),
      ),
      NavRow(title: 'ترتيب أبجدي للواجهة', value: '', onTap: s.sortFavorites),
      SectionTitle('شكل الأيقونات'),
      _TileOptionRow(
        cfgKey: 'tile.shape',
        title: 'شكل الأيقونات',
        options: const [
          ('sharp', 'حادة', 'زوايا مستقيمة'),
          ('rounded', 'مستديرة', 'حواف ناعمة متوسطة'),
          ('squircle', 'ناعمة', 'منحنى متصل مثل iOS'),
          ('circle', 'دائرية', 'دوائر أو كبسولات'),
          ('pill', 'كبسولة', 'بانر بأطراف دائرية'),
          ('leaf', 'ورقة', 'زاويتان متقابلتان'),
          ('arch', 'محراب', 'قوس علوي ملكي'),
          ('octagon', 'ثُمانية', 'زوايا مشطوفة واسعة'),
          ('cut', 'مشطوفة', 'شطف صغير أنيق'),
        ],
        sample: (id, hi) => _SampleTiles(shape: id, focused: hi),
      ),
      _TileOptionRow(
        cfgKey: 'tile.style',
        title: 'نوع البطاقة',
        options: const [('banner', 'بانر عريض ١٦:٩', 'صورة التطبيق الرسمية'), ('icon', 'أيقونة مربعة', 'أيقونات مرتبة'), ('circle', 'دائرة', 'أيقونات دائرية')],
        sample: (id, hi) => _SampleTiles(style: id, focused: hi),
      ),
      _TileOptionRow(
        cfgKey: 'tile.bg',
        title: 'خلفية الأيقونة',
        options: const [('art', 'الأصلية', 'ألوان التطبيق كما هي'), ('soft', 'هادئة', 'ألوان أخف وأنعم'), ('mono', 'أحادية ذهبية', 'داكنة بلمسة ذهب')],
        sample: (id, hi) => _SampleTiles(bg: id, focused: hi),
      ),
      _TileOptionRow(
        cfgKey: 'tile.focus',
        title: 'تأثير التركيز',
        options: const [('ring', 'تكبير وإطار ذهبي', ''), ('glow', 'توهج ذهبي', ''), ('lift', 'رفع وظل', ''), ('zoom', 'تكبير بلا إطار', '')],
        sample: (id, hi) => _SampleTiles(focus: id, focused: true),
      ),
      SectionTitle('المقاسات'),
      cStep('الحجم', 'tile.size', 120, 440, 4, fmtPx, sub: 'بالشبكة والصفحات يُحسب الحجم تلقائياً من عدد الأعمدة'),
      cStep('استدارة الحواف', 'tile.radius', 0, 90, 1, fmtPx),
      cStep('المسافة بين المربعات', 'tile.gap', 6, 90, 2, fmtPx),
      SectionTitle('التركيز'),
      cStep('التكبير عند التركيز', 'tile.focusScale', 1.0, 1.30, 0.01, fmtX),
      cStep('سُمك إطار التركيز', 'tile.ringWidth', 0, 12, 0.5, (v) => Ar.n(v.toStringAsFixed(1))),
      cToggle('ظل عند التركيز', 'tile.shadow'),
      cToggle('لمعة ضوء عند التركيز', 'tile.glint'),
      SectionTitle('الأسماء'),
      cChoice<String>('إظهار الأسماء', 'tile.labels', const [('all', 'دائماً'), ('focus', 'عند التركيز فقط'), ('none', 'بدون')]),
      cStep('حجم الاسم', 'tile.labelSize', 14, 40, 1, fmtPx),
      SectionTitle('مربعات إضافية'),
      cToggle('مربع "إضافة"', 'tile.showAdd'),
      cToggle('مربع "كل التطبيقات"', 'tile.showAll'),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة المربعات للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['tile.']);
          s.touch();
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _saver(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final bg = c.s('saver.bg');
    return [
      _ProfileNote(),
      cChoice<int>('تشتغل بعد', 'saver.minutes', const [
        (0, 'معطلة'), (1, 'دقيقة'), (2, 'دقيقتين'), (5, '٥ دقائق'), (10, '١٠ دقائق'), (15, '١٥ دقيقة'), (30, '٣٠ دقيقة'), (60, 'ساعة'),
      ]),
      NavRow(
        title: 'معرض أنماط شاشة السكون',
        subtitle: 'النجوم المتحركة، الأنيقة، الشفق، الساعة فقط، عرض الصور — بمعاينة حيّة',
        value: saverStyles.firstWhere((x) => x.$1 == c.s('saver.style'), orElse: () => saverStyles.first).$2,
        onTap: () => Navigator.push(context, fade(const SaverGalleryScreen())),
      ),
      NavRow(
        title: 'محرر ترتيب شاشة السكون',
        subtitle: 'مباشر على الشاشة: اختر أي عنصر وحرّكه بالأسهم، وغيّر حجمه وإظهاره',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreensaverScreen(editing: true))),
      ),
      NavRow(title: 'معاينة شاشة السكون', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreensaverScreen()))),
      cChoice<String>('التخطيط', 'saver.layout', const [
        ('calm', 'هادئ بالوسط'),
        ('elegant', 'أنيق سينمائي'),
        ('minimal', 'الساعة فقط'),
        ('stack', 'مجمّع (كل العناصر بمكان واحد)'),
        ('free', 'حر (كل عنصر بمكانه)'),
      ]),
      SectionTitle('الخلفية'),
      cChoice<String>('نوع الخلفية', 'saver.bg', const [
        ('stars', 'سماء نجوم متحركة'), ('black', 'أسود'), ('solid', 'لون'), ('gradient', 'تدرج الثيم'), ('art', 'فنية'), ('image', 'صورة واحدة'), ('slideshow', 'عرض صور متتابع'),
      ]),
      if (bg == 'stars')
        NavRow(
          title: 'حركة النجوم وألوان السماء',
          subtitle: 'الكثافة، السرعة، التلألؤ، الشهب، العمق، السديم',
          onTap: () => Navigator.push(context, fade(const SaverGalleryScreen())),
        ),
      if (bg == 'solid') cColor('لون الخلفية', 'saver.color'),
      if (bg == 'art') cChoice<String>('التصميم الفني', 'saver.art', ArtStyles.all),
      if (bg == 'image')
        NavRow(
          title: 'الصورة',
          value: _imgName(c.s('saver.image')),
          onTap: () => Navigator.push(context, fade(const WallpapersScreen(pickFor: 'saver.image'))),
        ),
      if (bg == 'slideshow') ...[
        NavRow(
          title: 'الصور',
          value: '${Ar.n(s.wallpapers.length)} صورة',
          onTap: () => Navigator.push(context, fade(const WallpapersScreen())),
        ),
        cStepInt('مدة كل صورة', 'saver.interval', 5, 600, (v) => '${Ar.n(v)} ثانية', step: 5),
      ],
      if (bg == 'image' || bg == 'slideshow') ...[
        cToggle('حركة تقريب بطيئة', 'saver.kenburns', sub: 'الصورة تتقرب وتتحرك ببطء شديد'),
        cStep('تعتيم الصورة', 'saver.dim', 0, 0.85, 0.05, fmtPct),
      ],
      SectionTitle('العناصر'),
      cToggle('اسم اليوم', 'saver.showDay'),
      cToggle('الساعة', 'saver.showClock'),
      cToggle('صباحاً / مساءً', 'saver.showPeriod'),
      cToggle('التاريخ الميلادي', 'saver.showDate'),
      cToggle('التاريخ الهجري', 'saver.showHijri'),
      cToggle('الطقس', 'saver.showWeather'),
      cToggle('مواقيت الصلاة', 'saver.showPrayers'),
      cToggle('الوقت القادم والعد التنازلي', 'saver.showNextPrayer'),
      cToggle('اسم المصوّر ورخصة الصورة', 'saver.showCredit', sub: 'لصور مكتبة ويكيميديا كومنز — صغير بالزاوية السفلى'),
      cToggle('نص خاص (ذكر، دعاء، عبارة)', 'saver.showText'),
      if (c.b('saver.showText'))
        NavRow(
          title: 'النص',
          value: c.s('saver.text'),
          onTap: () async {
            final v = await promptText(context, title: 'النص الظاهر بشاشة السكون', initial: c.s('saver.text'));
            if (v != null) s.set('saver.text', v);
          },
        ),
      cToggle('العد التنازلي لمناسبة', 'saver.showCountdown'),
      if (c.b('saver.showCountdown')) ...[
        NavRow(
          title: 'اسم المناسبة',
          value: c.s('saver.cdTitle'),
          onTap: () async {
            final v = await promptText(context, title: 'اسم المناسبة', initial: c.s('saver.cdTitle'));
            if (v != null && v.trim().isNotEmpty) s.set('saver.cdTitle', v.trim());
          },
        ),
        cStepInt('السنة', 'saver.cdYear', 2026, 2035, Ar.n),
        cChoice<int>('الشهر', 'saver.cdMonth', [for (var m = 1; m <= 12; m++) (m, Ar.months[m - 1])]),
        cStepInt('اليوم', 'saver.cdDay', 1, 31, Ar.n),
        cStepInt('الساعة', 'saver.cdHour', 0, 23, (h) => '${Ar.n(h % 12 == 0 ? 12 : h % 12)} ${h < 12 ? 'صباحاً' : 'مساءً'}'),
      ],
      cChoice<bool>('نظام الساعة', 'saver.clock24', const [(false, '١٢ ساعة'), (true, '٢٤ ساعة')]),
      if (c.s('saver.layout') == 'stack') ...[
        SectionTitle('المكان'),
        cChoice<String>('مكان العناصر', 'saver.position', saverPositions,
            sub: 'التلقائي يحلل الصورة ويختار أهدأ زاوية حتى ما يغطي جمالها'),
        if (c.s('saver.position') == 'custom') ...[
          cStep('الموضع الأفقي', 'saver.posX', -1, 1, 0.05, (v) => v.abs() < 0.01 ? 'الوسط' : (v < 0 ? 'يسار ${fmtPct(-v)}' : 'يمين ${fmtPct(v)}')),
          cStep('الموضع العمودي', 'saver.posY', -1, 1, 0.05, (v) => v.abs() < 0.01 ? 'الوسط' : (v < 0 ? 'أعلى ${fmtPct(-v)}' : 'أسفل ${fmtPct(v)}')),
        ],
      ],
      cChoice<String>('محاذاة الأسطر', 'saver.align', const [('auto', 'تلقائي حسب المكان'), ('start', 'يمين'), ('center', 'وسط'), ('end', 'يسار')]),
      cToggle('تحريك بطيء لحماية الشاشة', 'saver.drift', sub: 'يمنع انطباع الصورة على الشاشة'),
      SectionTitle('الخطوط والأحجام'),
      cFont('خط الساعة والتاريخ', 'saver.font'),
      cFont('خط النصوص', 'saver.textFont'),
      cStep('حجم الساعة', 'saver.clockSize', 120, 520, 4, fmtPx),
      cStep('حجم التاريخ', 'saver.dateSize', 24, 110, 1, fmtPx),
      cStep('حجم النصوص', 'saver.textSize', 16, 60, 1, fmtPx),
      cStep('حجم مواقيت الصلاة', 'saver.prayerSize', 14, 48, 1, fmtPx),
      SectionTitle('الألوان'),
      cChoice<String>('وضع الألوان', 'saver.colorMode', const [('auto', 'تلقائي حسب الخلفية'), ('manual', 'يدوي')],
          sub: 'التلقائي يقيس إضاءة الصورة تحت الساعة ويختار لون يبرز بوضوح'),
      if (c.s('saver.colorMode') == 'manual') ...[
        cColor('لون الساعة', 'saver.clockColor'),
        cColor('لون التاريخ', 'saver.textColor'),
        cColor('لون النصوص الثانوية', 'saver.mutedColor'),
      ],
      cColor('لون التمييز والأيقونات', 'saver.accentColor'),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة شاشة السكون للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['saver.']);
          s.touch();
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _walls(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final c = s.cfg;
    return [
      NavRow(
        title: 'صور الواجهة المتغيرة',
        subtitle: c.b('home.slides') ? 'مفعّلة فوق كل الثيمات، وتتلون مع الثيم' : 'صور تتبدل بهدوء خلف الواجهة، بكل الثيمات',
        value: c.b('home.slides') ? '${Ar.n(HomeSlides.paths().length)} صورة' : 'مطفأة',
        onTap: () => Navigator.push(context, fade(const HomeSlidesScreen())),
      ),
      NavRow(
        autofocus: false,
        title: 'إدارة الخلفيات',
        subtitle: 'معاينة، تعيين، حذف، واستيراد من الفلاشة',
        value: '${Ar.n(s.wallpapers.length)} صورة',
        onTap: () => Navigator.push(context, fade(const WallpapersScreen())),
      ),
      NavRow(
        title: 'مكتبة الخلفيات',
        subtitle: 'صور 4K حقيقية من ويكيميديا كومنز · ١٠ فئات · تتجدد ${s.cfg.i('walls.days') == 7 ? 'أسبوعياً' : 'تلقائياً'} · حتى ١٠٠ صورة',
        value: '${Ar.n(WallpaperFetcher.enabled().length)} فئات',
        onTap: () => Navigator.push(context, fade(const WallLibraryScreen())),
      ),
      const SizedBox(height: 16),
      Text(
        'لأفضل جودة استخدم صور بدقة 4K (٣٨٤٠×٢١٦٠).\n'
        'طرق الإضافة:\n'
        '١. من الحاسبة: حط الصور بمجلد wallpapers جنب install.bat وشغّله.\n'
        '٢. من فلاشة USB: ركّب الفلاشة واضغط "استيراد" بإدارة الخلفيات.',
        style: Fonts.body(22, p.muted),
      ),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _dateWeather(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    return [
      cChoice<int>('تصحيح التاريخ الهجري', 'misc.hijriOffset', const [(-2, '−٢ يوم'), (-1, '−١ يوم'), (0, 'بدون'), (1, '+١ يوم'), (2, '+٢ يوم')],
          sub: 'حتى يطابق رؤية الهلال المعتمدة عندك'),
      NavRow(
        title: 'موقع الطقس',
        value: c.s('misc.city').isEmpty
            ? 'تلقائي${s.weather != null && s.weather!.place.isNotEmpty ? ' (${s.weather!.place})' : ''}'
            : c.s('misc.city'),
        onTap: () async {
          final v = await promptText(context, title: 'المدينة (اتركها فارغة للتحديد التلقائي)', initial: c.s('misc.city'));
          if (v != null) s.set('misc.city', v.trim());
        },
      ),
      cChoice<int>('تحديث الطقس', 'weather.refresh', const [(10, 'كل ١٠ دقائق'), (15, 'كل ربع ساعة'), (30, 'كل نص ساعة'), (60, 'كل ساعة')],
          sub: WeatherHub.lastUpdate == null ? 'الحالة الحية من Open-Meteo' : 'آخر تحديث ${Ar.time(WeatherHub.lastUpdate!)}'),
      NavRow(title: 'تحديث الطقس الآن', onTap: () => WeatherHub.refreshAll()),
      SectionTitle('الطقس الحي'),
      NavRow(title: 'شاشة الطقس الحية', subtitle: 'الساعات والأيام العشرة وكل التفاصيل', onTap: () => Navigator.push(context, fade(const WeatherScreen()))),
      NavRow(title: 'مدني', subtitle: 'ترتيب المدن والتنقل بينها يمين ويسار', value: Ar.n(WeatherHub.cities.length), onTap: () => Navigator.push(context, fade(const CitiesScreen()))),
      NavRow(title: 'إضافة مدينة', subtitle: 'بحث بالاسم بالعربي', onTap: () => Navigator.push(context, fade(const AddCityScreen()))),
      cChoice<String>('حركة المشهد', 'weather.motion', const [('full', 'سينمائية كاملة'), ('light', 'خفيفة'), ('off', 'ثابتة')], sub: 'الغيوم والمطر والبرق تتحرك مع اتجاه الريح'),
      cToggle('قطرات وتكاثف على الزجاج', 'weather.glass', sub: 'وقت المطر والضباب والبرد'),
      cToggle('زر الطقس بأعلى الواجهة', 'weather.homeChip'),
      cToggle('بلاطة الطقس الحية بالمفضلة', 'weather.tile'),
      cToggle('ويدجت الطقس بشاشة السكون', 'weather.saverCard'),
      cToggle('مطر هادئ على شاشة السكون', 'weather.saverRain', sub: 'بس لما تمطر فعلاً'),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _general(BuildContext context) {
    final s = AppState.I;
    return [
      Container(
        key: const ValueKey('screen-info'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: s.palette.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(22), border: Border.all(color: s.palette.line)),
        child: Row(children: [
          AppIcon(Lu.monitor, size: 40, color: s.palette.accent),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الشاشة المكتشفة تلقائياً', style: Fonts.body(22, s.palette.muted)),
              const SizedBox(height: 4),
              FitText(
                '${s.model.isEmpty ? 'شاشة أندرويد' : s.model} · ${Ar.n(s.screenW)}×${Ar.n(s.screenH)} · كثافة ×${Ar.n(s.density.toStringAsFixed(1))}'
                '${s.screenInches != null ? ' · نحو ${Ar.n(s.screenInches!.round())} بوصة' : ''} · أندرويد SDK ${Ar.n(s.sdk)}',
                style: Fonts.body(24, s.palette.ink, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text('كل القياسات تتكيف تلقائياً مع دقة الشاشة ونسبتها، بدون قص أو تداخل.', style: Fonts.body(18, s.palette.muted)),
            ]),
          ),
        ]),
      ),
      SectionTitle('الحماية والاستمرارية'),
      NavRow(title: 'صحة النظام', subtitle: 'الذاكرة، التخزين، الشبكة، السلاسة، والأعطال', onTap: () => Navigator.push(context, fade(const HealthScreen()))),
      NavRow(
        title: 'النسخ الاحتياطي والاستعادة',
        subtitle: 'نسخة يومية تلقائية، وتصدير واستيراد بالفلاشة',
        value: AppState.I.cfg.b('backup.auto') ? 'تلقائي' : 'يدوي',
        onTap: () => Navigator.push(context, fade(const BackupScreen())),
      ),
      NavRow(
        title: 'جدول التشغيل والإطفاء',
        subtitle: 'إطفاء تلقائي وساعات هدوء',
        value: AppState.I.cfg.b('sched.off') ? 'مفعّل' : 'مطفأ',
        onTap: () => Navigator.push(context, fade(const ScheduleScreen())),
      ),
      NavRow(title: 'التحديث التلقائي', subtitle: 'فحص يومي، تثبيت بضغطة، ونسخة احتياطية قبله', value: Updater.available.value != null ? 'متوفر تحديث' : '', onTap: () => Navigator.push(context, fade(const AutoUpdateScreen()))),
      NavRow(title: 'ما الجديد بالإصدار', subtitle: 'الإصدار الحالي وطريقة التحديث بالحاسبة', onTap: () => Navigator.push(context, fade(const UpdatesScreen()))),
      NavRow(title: 'معالج الإعداد الأول', subtitle: 'الثيم، المدينة، التطبيقات، الشبكة', onTap: () => Navigator.push(context, fade(const SetupWizard()))),
      SectionTitle('الستريمر بعد واجهة كوكل'),
      NavRow(title: 'إعدادات الجهاز', subtitle: 'نظام Google TV: الشبكة، الحسابات، التطبيقات', onTap: () => openDeviceSettings(context)),
      NavRow(title: 'حارس الواجهة', subtitle: 'يرجّع رونق إذا طلعت واجهة كوكل', value: s.cfg.b('guard.on') ? 'شغّال' : 'متوقف', onTap: () => Navigator.push(context, fade(const GuardScreen()))),
      NavRow(title: 'مركز التنبيهات', subtitle: 'تنبيهات رونق والتطبيقات', onTap: () => Navigator.push(context, fade(const NotificationsScreen()))),
      NavRow(title: 'البحث', subtitle: 'التطبيقات والبحث الصوتي', onTap: () => Navigator.push(context, fade(const SearchScreen()))),
      NavRow(title: 'ملفات العائلة', subtitle: 'العائلة، الأطفال، الضيف', value: Profiles.name(Profiles.active), onTap: () => Navigator.push(context, fade(const ProfilePicker()))),
      NavRow(title: 'ملف الأطفال', subtitle: 'تطبيقات مختارة، وقت يومي، ووقت نوم', onTap: () => Navigator.push(context, fade(const KidsScreen()))),
      NavRow(title: 'تقرير الأطفال الأسبوعي', subtitle: 'شكد شاهدوا وأكثر التطبيقات', onTap: () => Navigator.push(context, fade(const KidsReportScreen()))),
      NavRow(title: 'الأمان ورمز الأهل', subtitle: 'تغيير الرمز، المحاولات، والقفل المؤقت', onTap: () => Navigator.push(context, fade(const SecurityScreen()))),
      NavRow(title: 'وضع المناسبات', subtitle: 'ترحيب وثيم يتهيأ حسب التقويم الهجري', value: s.cfg.b('occ.mode') ? 'مفعّل' : 'مطفأ', onTap: () => Navigator.push(context, fade(const OccasionsScreen()))),
      NavRow(title: 'وضع رمضان', subtitle: 'الإمساك والإفطار بالواجهة', onTap: () => Navigator.push(context, fade(const RamadanScreen()))),
      NavRow(title: 'الأجهزة والمزامنة', subtitle: 'نسخ الإعدادات بين شاشات البيت', value: s.cfg.b('sync.on') ? 'شغّالة' : 'مطفأة', onTap: () => Navigator.push(context, fade(const DevicesScreen()))),
      NavRow(title: 'سجل النشاط', subtitle: 'كل اللي صار برونق بخط زمني', onTap: () => Navigator.push(context, fade(const ActivityLogScreen()))),
      NavRow(title: 'ربط القابس الذكي', subtitle: 'معالج بثلاث خطوات مع اختبار', onTap: () => Navigator.push(context, fade(const PlugWizard()))),
      NavRow(
        title: 'التلفزيون والطاقة',
        subtitle: 'إطفاء التلفزيون كامل بالـ CEC أو القابس الذكي',
        value: switch (s.cfg.s('power.method')) { 'plug' => 'القابس', 'both' => 'CEC والقابس', _ => 'CEC' },
        onTap: () => Navigator.push(context, fade(const PowerScreen())),
      ),
      NavRow(title: 'العرض والصوت', subtitle: 'الدقة، HDR، مطابقة الإطارات، مخرج الصوت', onTap: () => Navigator.push(context, fade(const DisplaySoundScreen()))),
      NavRow(title: 'زر النجمة والريموت', subtitle: 'شنو يسوي زر النجمة', onTap: () => Navigator.push(context, fade(const StarScreen()))),
      NavRow(title: 'المنزل الذكي', subtitle: 'لوحة Google Home والقابس', onTap: () => Navigator.push(context, fade(const SmartHomeScreen()))),
      NavRow(title: 'التقويم الهجري والمناسبات', subtitle: 'الشهر الهجري وتنبيه المناسبات', onTap: () => Navigator.push(context, fade(const HijriScreen()))),
      NavRow(title: 'المحتوى اليومي', subtitle: 'آية أو حديث أو دعاء كل يوم', onTap: () => Navigator.push(context, fade(const DailyScreen()))),
      NavRow(title: 'الأداء والحجم', subtitle: 'حجم الواجهة ووضع الأداء', onTap: () => Navigator.push(context, fade(const PerformanceScreen()))),
      SectionTitle('أزرار الواجهة'),
      cToggle('زر البحث', 'home.showSearch'),
      cToggle('زر التنبيهات', 'home.showBell'),
      cToggle('زر الملف', 'home.showProfile'),
      cToggle('زر إعدادات الجهاز', 'home.showDevice', sub: 'كبسولة ذهبية تفتح إعدادات Google TV'),
      SectionTitle('الشاشة'),
      cChoice<int>('هامش حواف الشاشة', 'misc.overscan', const [(0, 'بدون'), (2, '٢٪'), (3, '٣٪'), (4, '٤٪'), (5, '٥٪'), (6, '٦٪'), (8, '٨٪')],
          sub: 'إذا الشاشة تقص أطراف الصورة'),
      SectionTitle('التحكم بالنظام'),
      ToggleRow(
        title: 'فرض الوضع العرضي على كل التطبيقات',
        subtitle: 'تطبيقات الهاتف الطولية تفتح بعرض الشاشة',
        value: s.cfg.b('misc.forceLandscape'),
        onChanged: (v) async {
          final r = await NativeBridge.setForceLandscape(v);
          if (r == 'no_permission') {
            if (context.mounted) toast(context, 'يحتاج صلاحية الظهور فوق التطبيقات — شغّل install.bat مرة ثانية يمنحها تلقائياً');
            return;
          }
          s.set('misc.forceLandscape', v);
        },
      ),
      ToggleRow(
        title: 'إيقاف شاشة سكون النظام',
        subtitle: 'حتى تشتغل شاشة سكون رونق فقط',
        value: s.cfg.b('misc.blockSystemSaver'),
        onChanged: (v) async {
          s.set('misc.blockSystemSaver', v);
          if (v && !await NativeBridge.disableSystemSaver() && context.mounted) {
            toast(context, 'يحتاج صلاحية — شغّل install.bat مرة ثانية يمنحها تلقائياً');
          }
        },
      ),
      SectionTitle('الحماية'),
      NavRow(
        title: 'تغيير رمز القفل',
        value: '••••',
        onTap: () async {
          if (!await askPin(context, title: 'الرمز الحالي (الافتراضي ٠٠٠٠)')) return;
          if (!context.mounted) return;
          final v = await promptText(context, title: 'الرمز الجديد (٤ أرقام أو أكثر)', obscure: true, number: true);
          if (v != null && v.length >= 4) s.set('misc.pin', v);
        },
      ),
      SectionTitle('النظام'),
      NavRow(title: 'إعدادات النظام', onTap: NativeBridge.systemSettings),
      NavRow(title: 'الشبكة والواي فاي', onTap: NativeBridge.wifiSettings),
      SectionTitle('إعادة الضبط'),
      Row(children: [
        PillButton('إعادة كل الإعدادات للأصل', danger: true, icon: Lu.rotateCcw, onTap: () {
          showActions(context, 'إعادة كل الإعدادات؟', [
            ('إلغاء', Lu.x, () {}, false),
            ('نعم، أعد كل شي للأصل', Lu.rotateCcw, () {
              s.cfg.resetAll();
              s.touch();
            }, true),
          ]);
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _remote(BuildContext context) => [
        NavRow(
          title: 'شاشة الريموت والتنقل',
          subtitle: 'دليل الأزرار بالرسم، وكل خيارات السرعة والحركة بمعاينة',
          onTap: () => Navigator.push(context, fade(const RemoteSettingsScreen())),
        ),
        cStepInt('سرعة التنقل عند الضغط المستمر', 'remote.repeat', 60, 400, (v) => '${Ar.n(v)} م.ث', step: 10,
            sub: 'أقل رقم = أسرع، والقوائم ما تقلّب أكثر من اللازم'),
        cChoice<int>('مدة الضغطة الطويلة', 'remote.longPress', const [(400, 'قصيرة (٠٫٤ ثانية)'), (550, 'عادية (٠٫٥ ثانية)'), (750, 'طويلة (٠٫٧٥ ثانية)')],
            sub: 'تفتح خيارات التطبيق وتفاصيل بطاقات اللوحة السريعة'),
        cToggle('الالتفاف بنهاية الصف', 'remote.wrap', sub: 'بآخر تطبيق يرجع للأول'),
        cToggle('تأكيد قبل الخروج من الإعدادات', 'remote.confirmExit', sub: 'رجوع بأول قسم يسأل قبل ما يطلع'),
        cChoice<String>('حركة التركيز', 'remote.motion', const [('none', 'بدون'), ('soft', 'ناعمة'), ('full', 'تكبير ولمعة')]),
        cChoice<String>('إطار التركيز', 'remote.ring', const [('thin', 'خط رفيع'), ('gold', 'ذهبي'), ('glow', 'توهج')]),
      ];

  // ---------------------------------------------------------------
  List<Widget> _motion() {
    final s = AppState.I;
    return [
      _TileOptionRow(
        cfgKey: 'motion.style',
        title: 'أسلوب الحركة',
        options: const [
          ('soft', 'ناعمة', '٢٠٠ م.ث · انسيابية'),
          ('spring', 'نابضة', '٢٦٠ م.ث · ارتداد خفيف'),
          ('elegant', 'أنيقة', '٣٤٠ م.ث · أفخم وأبطأ'),
          ('swift', 'سريعة', '١١٠ م.ث · للأجهزة الضعيفة'),
          ('off', 'بدون حركة', 'تنقل فوري'),
        ],
        sample: (id, hi) => _MotionSample(style: id, playing: hi),
      ),
      cStep('سرعة الحركة', 'misc.animSpeed', 0.5, 2.0, 0.1, fmtX, sub: 'يمين ويسار: أبطأ أو أسرع لكل الحركات'),
      cChoice<String>('انتقال الشاشات', 'motion.page', const [('fade', 'تلاشي ناعم'), ('slide', 'انزلاق جانبي'), ('zoom', 'تكبير هادئ')],
          sub: 'شكل دخول الإعدادات وباقي الشاشات'),
      cChoice<String>('الأداء', 'ui.performance', const [('auto', 'تلقائي حسب الجهاز'), ('quality', 'أعلى جودة'), ('fast', 'أعلى سرعة')],
          sub: 'هذا الجهاز: ${s.model.isEmpty ? '—' : s.model} · ذاكرة ${Ar.n((s.ramMb / 1024).toStringAsFixed(1))} GB · ${s.lite ? 'الوضع الخفيف' : 'الجودة الكاملة'}'),
      cToggle('تقليل الحركة', 'misc.reduceMotion', sub: 'يوقف كل الحركات — أخف شي على الجهاز'),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة الحركة للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['motion.']);
          s.set('misc.animSpeed', 1.0);
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  //  حركة الشعار (فيكما صفحة ١٦ رقم ١٣): القلم يكتب «رونق» ثم ينقّط
  int _replay = 0;

  List<Widget> _logoMotion() {
    final s = AppState.I;
    final c = s.cfg;
    final p = s.palette;
    final write = c.b('loader.write');
    String secs(String id) => '${Ar.n(loaderWriteSeconds(id).toStringAsFixed(1))} ث';
    return [
      Container(
        padding: const EdgeInsets.all(26),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line)),
        child: Row(children: [
          Container(
            width: 250,
            height: 250,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: RadialGradient(colors: p.night ? const [Color(0xFF0F4434), Color(0xFF03100C)] : const [Color(0xFFFBF7EE), Color(0xFFEADFC8)]),
            ),
            child: RawnaqLoader(key: ValueKey('logo-$_replay-${c.s('loader.speed')}-$write'), size: 220, done: true),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              FitText('المعاينة الحية', style: Fonts.title(30, p.ink)),
              const SizedBox(height: 10),
              FitText(write ? 'ر ← و ← ن ق ← نقطة النون ← نقطتا القاف' : 'الشعار يظهر كامل والحلقة وحدها تمشي', style: Fonts.body(21, p.muted)),
              const SizedBox(height: 6),
              FitText(write ? 'مدة الكتابة: ${secs(c.s('loader.speed'))} + لمعة الختام' : 'شغّل «الكتابة بخط اليد» حتى تشوف القلم', style: Fonts.body(19, p.muted)),
              const SizedBox(height: 18),
              Row(children: [PillButton('إعادة الكتابة', icon: Lu.rotateCcw, onTap: () => setState(() => _replay++))]),
            ]),
          ),
        ]),
      ),
      cToggle('الكتابة بخط اليد', 'loader.write', sub: 'القلم يكتب اسم رونق حرفاً حرفاً بكل مكان فيه تحميل'),
      _TileOptionRow(
        cfgKey: 'loader.speed',
        title: 'سرعة الكتابة',
        options: [
          ('calm', 'هادئة', secs('calm')),
          ('normal', 'متوازنة', secs('normal')),
          ('brisk', 'رشيقة', secs('brisk')),
        ],
        sample: (id, hi) => _PaceSample(id: id, lit: hi || c.s('loader.speed') == id),
      ),
      cToggle('الحلقة مع التحميل', 'loader.ring', sub: 'تمشي مع القلم وما تسبق نسبة التحميل الحقيقية'),
      cChoice<String>('عند الإقلاع: انتظر الكتابة', 'loader.waitBoot', const [('cold', 'أول تشغيل فقط'), ('always', 'دائماً'), ('off', 'لا تنتظر')], sub: 'أول تشغيل: القلم يكمل الاسم، وبعدها الواجهة تفتح فوراً'),
      cToggle('رأس القلم المضيء', 'loader.pen', sub: 'نقطة نور تمشي مع الريشة، وتتنفس بهدوء إذا التحميل تأخر'),
      cToggle('لمعة الحبر الطري', 'loader.wet', sub: 'الحبر يلمع خلف القلم لحظة ويجف'),
      cToggle('اللمعة الختامية', 'loader.shine', sub: 'لمعة تمر على الاسم بعد آخر نقطة'),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('رجوع للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['loader.']);
          setState(() => _replay++);
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _a11y() {
    final s = AppState.I;
    return [
      cChoice<double>('حجم النص', 'a11y.textScale', const [(1.0, 'عادي ١٠٠٪'), (1.15, 'كبير ١١٥٪'), (1.3, 'كبير جداً ١٣٠٪')],
          sub: 'يكبّر كل النصوص بالواجهة والإعدادات بدون قص'),
      cToggle('تباين عالٍ', 'a11y.contrast', sub: 'نص ثانوي وحدود أوضح على كل الثيمات'),
      cToggle('إطار تركيز سميك', 'a11y.thickRing', sub: 'إطار ذهبي أعرض حتى تلقى مكانك من بعيد'),
      cToggle('تقليل الحركة', 'misc.reduceMotion', sub: 'بدون حركات انتقال، أسرع على الأجهزة الضعيفة'),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة إمكانية الوصول للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['a11y.']);
          s.set('misc.reduceMotion', false);
        }),
      ]),
    ];
  }

  // ---------------------------------------------------------------
  List<Widget> _about(BuildContext context) {
    final s = AppState.I;
    return [
      NavRow(
        title: 'حول رونق',
        subtitle: 'الإصدار، الجهاز، والحقوق والمصادر',
        value: 'الإصدار ${Ar.n(kAppVersion)}',
        onTap: () => Navigator.push(context, fade(const AboutRawnaqScreen())),
      ),
      NavRow(title: 'سجل الإصدارات', subtitle: 'كل تحديث وصل لرونق وشنو جاب', onTap: () => Navigator.push(context, fade(const VersionHistoryScreen()))),
      NavRow(title: 'التفاصيل التقنية', subtitle: 'الجهاز والذاكرة والتراخيص', onTap: () => Navigator.push(context, fade(const AboutScreen()))),
      SectionTitle('الحقوق والمصادر'),
      NavRow(title: 'الأيقونات', value: 'Lucide · ISC', onTap: () => Navigator.push(context, fade(const AboutScreen()))),
      NavRow(title: 'الخطوط', value: 'Google Fonts · OFL', onTap: () => Navigator.push(context, fade(const AboutScreen()))),
      NavRow(title: 'الخلفيات', value: 'ويكيميديا كومنز', onTap: () => Navigator.push(context, fade(const WallLibraryScreen()))),
      NavRow(title: 'مواقيت الصلاة', value: 'حساب فلكي محلي', onTap: () => Navigator.push(context, fade(const AboutScreen()))),
      NavRow(title: 'الجهاز', value: s.model.isEmpty ? 'أندرويد' : s.model, onTap: () => Navigator.push(context, fade(const AboutScreen()))),
    ];
  }

  List<Widget> _prayers() {
    final s = AppState.I;
    final c = s.cfg;
    final p = s.palette;
    final shown = c.s('prayer.shown').split(',').where((e) => e.isNotEmpty).toSet();
    Widget showToggle(String id) => ToggleRow(
          title: Prayers.names[id]!,
          value: shown.contains(id),
          onChanged: (v) {
            final next = {...shown};
            if (v) {
              next.add(id);
            } else {
              next.remove(id);
            }
            const order = ['imsak', 'fajr', 'sunrise', 'dhuhr', 'sunset', 'maghrib', 'midnight'];
            s.set('prayer.shown', order.where(next.contains).join(','));
          },
        );
    String minutes(int v) => v == 0 ? 'بدون' : '${v > 0 ? '+' : '−'}${Ar.n(v.abs())} د';
    return [
      Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('اليوم · ${PrayerCity.byId(c.s('prayer.city')).label}', style: Fonts.title(30, p.ink)),
          const SizedBox(height: 18),
          PrayerStrip(size: 24, font: c.s('font.ui'), ink: p.ink, muted: p.muted, accent: p.accent),
          const SizedBox(height: 16),
          NextPrayerLine(size: 24, font: c.s('font.ui'), ink: p.ink, accent: p.accent),
        ]),
      ),
      cChoice<String>('المدينة (العراق)', 'prayer.city', [(PrayerCity.auto.id, PrayerCity.auto.name), for (final city in PrayerCity.all) (city.id, city.label)], sub: c.s('prayer.city') == 'auto' ? 'حالياً: ${PrayerCity.byId('auto').label}' : null),
      Text(
        'الحساب فلكي ومحلي لأي يوم بالسنة بدون إنترنت. قارن مرة وحدة مع تقويم الأنصاري وعدّل الدقائق تحت حتى يطابقه تماماً.',
        style: Fonts.body(20, p.muted),
      ),
      SectionTitle('تعديل كل وقت بالدقائق'),
      for (final id in ['fajr', 'sunrise', 'dhuhr', 'sunset', 'maghrib', 'midnight'])
        cStepInt(Prayers.names[id]!, 'prayer.adj.$id', -30, 30, minutes),
      cStepInt('الإمساك قبل الفجر', 'prayer.imsakMinutes', 0, 30, (v) => '${Ar.n(v)} دقيقة'),
      SectionTitle('زوايا الحساب (متقدم)'),
      cStep('زاوية الفجر', 'prayer.fajrAngle', 12, 20, 0.25, (v) => '${Ar.n(v.toStringAsFixed(2))}°'),
      cStep('زاوية المغرب', 'prayer.maghribAngle', 1, 7, 0.25, (v) => '${Ar.n(v.toStringAsFixed(2))}°'),
      SectionTitle('الأوقات الظاهرة'),
      for (final id in ['imsak', 'fajr', 'sunrise', 'dhuhr', 'sunset', 'maghrib', 'midnight']) showToggle(id),
      const SizedBox(height: 12),
      Row(children: [
        PillButton('إعادة المواقيت للأصل', icon: Lu.rotateCcw, onTap: () {
          s.cfg.resetPrefix(['prayer.']);
          s.touch();
        }),
      ]),
    ];
  }

  static String _hour(int h) {
    final hh = h % 12 == 0 ? 12 : h % 12;
    return '${Ar.n(hh)} ${h < 12 ? 'صباحاً' : 'مساءً'}';
  }
}

/// بطاقة ثيم جاهز: تعرض ألوانه النهارية والليلية.
class _PresetCard extends StatelessWidget {
  final ThemePreset preset;
  final bool focused, active;
  const _PresetCard({required this.preset, required this.focused, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final d = preset.day, n = preset.night;
    Widget half(Map<String, int> c, String clock) => Expanded(
          child: Container(
            color: Color(c['bg']!),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              for (final k in ['accent', 'ring'])
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  decoration: BoxDecoration(color: Color(c[k]!), shape: BoxShape.circle),
                ),
              const Spacer(),
              FitText(clock, style: Fonts.family(preset.clockFont, 30, Color(c['ink']!), weight: FontWeight.w700, height: 1.0)),
            ]),
          ),
        );
    return AnimatedScale(
      scale: focused ? 1.04 : 1,
      duration: AppState.I.anim(150),
      child: AnimatedContainer(
        duration: AppState.I.anim(150),
        width: 300,
        decoration: BoxDecoration(
          color: Color(d['bg']!),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: focused ? p.ring : (active ? Color(d['accent']!) : p.line), width: focused ? ringW : (active ? 3 : 1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AppIcon(Lu.crown, size: 24, color: Color(d['ring']!)),
                const SizedBox(width: 8),
                Expanded(child: FitText(preset.name, style: Fonts.family(preset.titleFont, 28, Color(d['ink']!), weight: FontWeight.w700))),
                if (active) AppIcon(Lu.circleCheck, size: 26, color: Color(d['accent']!)),
              ]),
              const SizedBox(height: 4),
              FitText(preset.sub, style: Fonts.family(preset.bodyFont, 17, Color(d['muted']!))),
            ]),
          ),
          SizedBox(height: 56, child: Row(children: [half(d, '١٠:٥٠'), half(n, '٨:٠٥')])),
        ]),
      ),
    );
  }
}


/// بطاقات نمط الواجهة: كلاسيكي، زجاج مغبش، سينمائي (ستايل Apple TV).
class _StyleCards extends StatelessWidget {
  final ValueChanged<String?>? onHighlight;
  const _StyleCards({this.onHighlight});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final current = s.cfg.s('ui.style');
    Widget card(String id, String name, String sub, Widget preview, bool f) {
      final on = current == id;
      return AnimatedContainer(
        duration: s.anim(160),
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: on ? p.accent.withValues(alpha: 0.14) : p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: f ? p.ring : (on ? p.accent : p.line), width: f ? ringW : (on ? 2.5 : 1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(height: 150, child: preview)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FitText(name, style: Fonts.body(23, p.ink, weight: FontWeight.w600))),
            if (on) AppIcon(Lu.circleCheck, color: p.accent, size: 28),
          ]),
          const SizedBox(height: 2),
          FitText(sub, style: Fonts.body(17, p.muted)),
        ]),
      );
    }

    Widget tiles(Color c, {double opacity = 1}) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: i == 1 ? 50 : 42,
              height: i == 1 ? 30 : 24,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: c.withValues(alpha: i == 1 ? opacity : opacity * 0.5), borderRadius: BorderRadius.circular(6)),
            ),
        ]);

    final cards = <(String, String, String, Widget)>[
      (
        'soft',
        'الناعم العصري',
        'حواف متصلة وظلال هادئة وأورورا',
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: const Alignment(0.7, -0.8), radius: 1.2, colors: [Color.lerp(p.bg, p.accent, 0.35)!, p.bg]),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              height: 64,
              decoration: ShapeDecoration(
                shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(34)),
                color: p.surface,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.4 : 0.12), blurRadius: 24, offset: const Offset(0, 10))],
              ),
            ),
            const Spacer(),
            tiles(p.accent),
          ]),
        ),
      ),
      (
        'modern',
        'الحديث',
        'بطاقة بارزة ومربعات ناعمة',
        Container(
          color: p.night ? const Color(0xFF05100C) : const Color(0xFFF7F4EE),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Row(children: [
                Expanded(child: Text('٩:٤٢', style: Fonts.clock(34, p.night ? Colors.white : const Color(0xFF13201A)))),
                Container(
                  width: 120,
                  decoration: ShapeDecoration(
                    shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    gradient: const LinearGradient(colors: [Color(0xFFC4302B), Color(0xFF3A0A08)]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            tiles(p.accent),
          ]),
        ),
      ),
      (
        'classic',
        'كلاسيكي أنيق',
        'ألوان الثيم الصافية',
        Container(
          color: const Color(0xFFF4EFE6),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('١٠:٥٠', style: Fonts.clock(40, const Color(0xFF1E2A2B))),
            const Spacer(),
            tiles(const Color(0xFF0F6E6A)),
          ]),
        ),
      ),
      (
        'glass',
        'زجاج مغبش',
        'ألواح شفافة فوق الخلفية',
        Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF3A5C8C), Color(0xFF8A4F7D), Color(0xFFD9925A)]),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            bottom: 12,
            width: 110,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ]),
      ),
      (
        'cinema',
        'سينمائي',
        'ترتيب Apple TV',
        Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF243B55), Color(0xFF141E30), Color(0xFF05070D)],
              ),
            ),
          ),
          Positioned(top: 10, right: 12, child: Text('١٠:٥٠', style: Fonts.clock(22, Colors.white))),
          Positioned(left: 0, right: 0, bottom: 14, child: tiles(Colors.white, opacity: 0.95)),
        ]),
      ),
      (
        'ribbons',
        'شرائط عصرية',
        'بطاقة بارزة + شرائط تطبيقات',
        Container(
          color: const Color(0xFFF7F4EE),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [Color(0xFF2F4E7E), Color(0xFF0D5C45)]),
              ),
            ),
            const SizedBox(height: 10),
            tiles(const Color(0xFF0D5C45)),
            const SizedBox(height: 8),
            tiles(const Color(0xFF56635C), opacity: 0.6),
          ]),
        ),
      ),
      (
        'liquid',
        'الزجاج السائل',
        'زجاج حي بلمعة وانكسار',
        Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1F7A5A), Color(0xFF2F4E7E), Color(0xFFA87A2E)],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 60,
            right: 60,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
              ),
              child: tiles(Colors.white, opacity: 0.9),
            ),
          ),
        ]),
      ),
      (
        'minimal',
        'البسيط الهادئ',
        'مرسى أيقونات بلا أسماء',
        Container(
          color: const Color(0xFF0B0C0F),
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            const Spacer(),
            Text('١٠:٥٠', style: Fonts.clock(38, const Color(0xFFEEF0F4))),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: i == 2 ? 30 : 24,
                  height: i == 2 ? 30 : 24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9D3E3).withValues(alpha: i == 2 ? 0.95 : 0.35),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
            ]),
          ]),
        ),
      ),
      (
        'magazine',
        'المجلة',
        'بطاقة بارزة بعنوان كبير',
        Container(
          color: const Color(0xFFFBF4EA),
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(10),
                alignment: AlignmentDirectional.bottomStart,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [Color(0xFFB5600E), Color(0xFF8E2430)]),
                ),
                child: Text('رونق', style: Fonts.title(20, Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFFB5600E).withValues(alpha: 0.25 + i * 0.15), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    ];
    return SelectorRow<String>(
      key: const ValueKey('style-row'),
      title: 'نمط الواجهة',
      values: [for (final c in cards) c.$1],
      selected: current,
      onSelect: s.setStyle,
      onHighlight: onHighlight,
      itemBuilder: (context, id, hi, sel) {
        final c = cards.firstWhere((x) => x.$1 == id);
        return card(c.$1, c.$2, c.$3, c.$4, hi);
      },
    );
  }
}


/// تنبيه: ترتيب هذا القسم محفوظ للنمط الحالي فقط، مع زر إرجاعه للأصل.
class _ProfileNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    return Container(
      key: const ValueKey('profile-note'),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.accent.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        AppIcon(Lu.palette, color: p.accent, size: 30),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'هذا الترتيب خاص بنمط: ${AppState.styleName(s.cfg.s('ui.style'))}. كل نمط يحفظ ترتيبه للتطبيقات وشاشة السكون لحاله.',
            style: Fonts.body(20, p.ink),
          ),
        ),
        const SizedBox(width: 16),
        PillButton('ترتيب النمط الأصلي', icon: Lu.rotateCcw, onTap: s.resetStyleArrangement),
      ]),
    );
  }
}


/// أزواج الخطوط الجاهزة (من فيكما: الخطوط · أزواج جاهزة).
const fontPairs = <(String, String, String, String, String, String)>[
  ('royal', 'ملكي', 'Reem Kufi', 'Readex Pro', 'Aref Ruqaa', 'ريم كوفي · ريدكس · رقعة عارف'),
  ('classic', 'تراثي', 'Amiri', 'Almarai', 'El Messiri', 'الأميري · المراعي · المسيري'),
  ('modern', 'عصري', 'Changa', 'Cairo', 'Changa', 'شانغا · القاهرة'),
  ('calm', 'هادئ', 'Markazi Text', 'Tajawal', 'Amiri', 'المركزي · تجوال · الأميري'),
  ('bold', 'حادّ', 'Kufam', 'Mada', 'Rakkas', 'كوفام · مدى · رقّاص'),
  ('naskh', 'نسخي', 'Scheherazade New', 'Readex Pro', 'Lateef', 'شهرزاد · ريدكس · لطيف'),
];

class _FontPairCard extends StatelessWidget {
  final (String, String, String, String, String, String) pair;
  final bool focused, active;
  const _FontPairCard({required this.pair, required this.focused, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return AnimatedScale(
      scale: focused ? 1.04 : 1,
      duration: AppState.I.anim(150),
      curve: AppState.I.curve,
      child: AnimatedContainer(
        duration: AppState.I.anim(150),
        width: 320,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        decoration: BoxDecoration(
          color: active ? p.accent.withValues(alpha: 0.12) : p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: focused ? p.ring : (active ? p.accent : p.line), width: focused ? ringW : (active ? 2.5 : 1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: FitText('رونق', style: Fonts.family(pair.$3, 36, p.accent, weight: FontWeight.w700))),
            const SizedBox(width: 10),
            FitText('٩:٤٢', style: Fonts.family(pair.$5, 40, p.ink, weight: FontWeight.w700, height: 1.0)),
          ]),
          FitText('واجهة أنيقة لكل يوم', style: Fonts.family(pair.$4, 20, p.ink)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FitText(pair.$2, style: Fonts.body(20, p.ink, weight: FontWeight.w600))),
            if (active) AppIcon(Lu.circleCheck, color: p.accent, size: 24),
          ]),
          FitText(pair.$6, style: Fonts.body(15, p.muted)),
        ]),
      ),
    );
  }
}

/// صف بطاقات بمعاينة حقيقية لخيار من إعدادات الأيقونات أو الحركة.
class _TileOptionRow extends StatelessWidget {
  final String cfgKey, title;
  final List<(String, String, String)> options;
  final Widget Function(String id, bool highlighted) sample;
  const _TileOptionRow({required this.cfgKey, required this.title, required this.options, required this.sample});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    return SelectorRow<String>(
      key: ValueKey('opt-$cfgKey'),
      title: title,
      values: [for (final o in options) o.$1],
      selected: s.cfg.s(cfgKey),
      onSelect: (v) => s.set(cfgKey, v),
      itemBuilder: (context, id, hi, sel) {
        final o = options.firstWhere((x) => x.$1 == id);
        return AnimatedContainer(
          duration: s.anim(150),
          width: 250,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: sel ? p.accent.withValues(alpha: 0.12) : p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: hi ? p.ring : (sel ? p.accent : p.line), width: hi ? ringW : (sel ? 2.5 : 1)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 120, child: Center(child: sample(id, hi))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FitText(o.$2, style: Fonts.body(21, p.ink, weight: FontWeight.w600))),
              if (sel) AppIcon(Lu.circleCheck, color: p.accent, size: 24),
            ]),
            if (o.$3.isNotEmpty) FitText(o.$3, style: Fonts.body(15, p.muted)),
          ]),
        );
      },
    );
  }
}

/// مربعات نموذجية (يوتيوب، نتفلكس، شاهد) بالشكل/النوع/الخلفية/التأثير المطلوب — نفس رسم فيكما.
class _SampleTiles extends StatelessWidget {
  final String? shape, style, bg, focus;
  final bool focused;
  const _SampleTiles({this.shape, this.style, this.bg, this.focus, this.focused = false});

  static const apps = [
    (Lu.play, Color(0xFFC4302B), Color(0xFF3A0A08)),
    (Lu.film, Color(0xFFB20710), Color(0xFF1A0204)),
    (Lu.tv, Color(0xFF2E7D5B), Color(0xFF05140F)),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final st = style ?? s.cfg.s('tile.style');
    final sh = shape ?? s.cfg.s('tile.shape');
    final b = bg ?? s.cfg.s('tile.bg');
    final fx = focus ?? s.cfg.s('tile.focus');
    final banner = st == 'banner';
    final count = shape != null || focus != null ? 1 : 3;
    final w = count == 1 ? (banner ? 150.0 : 92.0) : (banner ? 64.0 : 46.0);
    final h = banner ? w * 9 / 16 : w;
    Widget one(int i, bool f) {
      final border = TileFrame.border(sh, st, w, h, w * 0.1);
      final ring = f && fx == 'ring';
      final scale = !f ? 1.0 : (fx == 'zoom' ? 1.16 : fx == 'glow' ? 1.06 : fx == 'lift' ? 1.04 : 1.1);
      return Transform.translate(
        offset: Offset(0, f && fx == 'lift' ? -h * 0.08 : 0),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: w,
            height: h,
            decoration: ShapeDecoration(
              shape: border.copyWith(side: ring ? BorderSide(color: p.ring, width: 3, strokeAlign: BorderSide.strokeAlignOutside) : BorderSide.none),
              shadows: [
                if (f && fx == 'glow') BoxShadow(color: p.ring.withValues(alpha: 0.7), blurRadius: 18, spreadRadius: 1),
                if (f && fx == 'lift') BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: border),
              child: TileFrame.tint(
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [apps[i].$2, apps[i].$3]),
                  ),
                  child: Center(child: AppIcon(apps[i].$1, color: Colors.white, size: h * 0.4)),
                ),
                b,
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) SizedBox(width: w * 0.22),
        one(i, focused && i == 0),
      ],
    ]);
  }
}

/// إيقاع سرعة الكتابة: خمس نقاط بمسافات أوسع للهادئة وأضيق للرشيقة.
class _PaceSample extends StatelessWidget {
  final String id;
  final bool lit;
  const _PaceSample({required this.id, required this.lit});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final gap = switch (id) { 'calm' => 30.0, 'brisk' => 14.0, _ => 21.0 };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.ring.withValues(alpha: lit ? 0.35 + 0.15 * i : 0.25)),
        ),
      ],
    ]);
  }
}

/// معاينة حيّة لأسلوب الحركة: المربع يتكبر ويرجع بنفس المنحنى والمدة، بشكل متكرر.
class _MotionSample extends StatefulWidget {
  final String style;
  final bool playing;
  const _MotionSample({required this.style, required this.playing});

  @override
  State<_MotionSample> createState() => _MotionSampleState();
}

class _MotionSampleState extends State<_MotionSample> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _up = false;

  (Curve, int) get _spec => switch (widget.style) {
        'spring' => (Curves.easeOutBack, 260),
        'elegant' => (Curves.easeInOutCubic, 340),
        'swift' => (Curves.easeOutQuad, 110),
        'off' => (Curves.linear, 0),
        _ => (Curves.easeOutCubic, 200),
      };

  @override
  void initState() {
    super.initState();
    _loop();
  }

  Future<void> _loop() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _up = !_up;
      final ms = (_spec.$2 / AppState.I.cfg.d('misc.animSpeed')).round();
      if (ms == 0) {
        _c.value = _up ? 1 : 0;
      } else {
        _c.duration = Duration(milliseconds: ms);
        _up ? _c.forward(from: 0) : _c.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _spec.$1.transform(_c.value.clamp(0.0, 1.0));
        final scale = 1 + 0.14 * t;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Transform.scale(
            scale: scale,
            child: Container(
              width: 96,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFC4302B), Color(0xFF3A0A08)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _c.value > 0.5 ? p.ring : Colors.transparent, width: 3),
              ),
              child: const Center(child: AppIcon(Lu.play, color: Colors.white, size: 24)),
            ),
          ),
          const SizedBox(width: 18),
          Container(
            width: 70,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2E7D5B), Color(0xFF05140F)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: AppIcon(Lu.tv, color: Colors.white, size: 18)),
          ),
        ]);
      },
    );
  }
}
