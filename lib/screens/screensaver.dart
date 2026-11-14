import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arabic.dart';
import '../backgrounds.dart';
import '../image_analysis.dart';
import '../platform.dart';
import '../prayer_view.dart';
import '../starfield.dart';
import '../wallpaper_fetcher.dart';
import '../state.dart';
import '../widgets.dart';
import '../lucide.dart';
import '../streamer_services.dart' show Daily;
import 'streamer_screens.dart' show DailySaverLine;
import 'weather_screens.dart' show WeatherSaverCard, WeatherScreen;
import '../weather_sky.dart' show WeatherSky;

/// المواضع الجاهزة لعناصر شاشة السكون (بالتخطيط المجمّع).
final saverPositions = <(String, String)>[
  ('auto', 'تلقائي (أهدأ مكان بالصورة)'),
  ('bottomRight', 'أسفل اليمين'),
  ('bottomLeft', 'أسفل اليسار'),
  ('bottomCenter', 'أسفل الوسط'),
  ('topRight', 'أعلى اليمين'),
  ('topLeft', 'أعلى اليسار'),
  ('topCenter', 'أعلى الوسط'),
  ('centerRight', 'وسط اليمين'),
  ('centerLeft', 'وسط اليسار'),
  ('center', 'الوسط'),
  ('custom', 'مخصص (تحديد دقيق)'),
];

const _alignments = {
  'center': Alignment.center,
  'topLeft': Alignment.topLeft,
  'topCenter': Alignment.topCenter,
  'topRight': Alignment.topRight,
  'centerLeft': Alignment.centerLeft,
  'centerRight': Alignment.centerRight,
  'bottomLeft': Alignment.bottomLeft,
  'bottomCenter': Alignment.bottomCenter,
  'bottomRight': Alignment.bottomRight,
  'bottomStart': Alignment.bottomRight,
  'bottomEnd': Alignment.bottomLeft,
  'topStart': Alignment.topRight,
  'topEnd': Alignment.topLeft,
};

/// عناصر شاشة السكون: المعرّف، الاسم، مفتاح الإظهار.
const saverElements = <(String, String, String)>[
  ('clock', 'الساعة', 'saver.showClock'),
  ('day', 'اسم اليوم', 'saver.showDay'),
  ('date', 'التاريخ الميلادي', 'saver.showDate'),
  ('hijri', 'التاريخ الهجري', 'saver.showHijri'),
  ('next', 'الوقت القادم للصلاة', 'saver.showNextPrayer'),
  ('prayers', 'مواقيت الصلاة', 'saver.showPrayers'),
  ('weather', 'الطقس', 'saver.showWeather'),
  ('countdown', 'العد التنازلي', 'saver.showCountdown'),
  ('text', 'النص الخاص', 'saver.showText'),
];

/// ألوان عنصر حسب الخلفية تحته.
class _Ink {
  final Color clock, text, muted, accent, chip;
  final bool bright;
  final List<Shadow> shadow;
  const _Ink(this.clock, this.text, this.muted, this.accent, this.chip, this.bright, this.shadow);
}

/// شاشة السكون. مع [editing] تصير محرر ترتيب مباشر: تختار عنصر وتحركه بالأسهم.
class ScreensaverScreen extends StatefulWidget {
  final bool editing;
  /// معاينة مصغّرة داخل الإعدادات: بدون تركيز ولا لمس ولا إبقاء الشاشة شغالة.
  final bool preview;
  const ScreensaverScreen({super.key, this.editing = false, this.preview = false});

  /// عدد شاشات السكون المفتوحة (حتى ما تنفتح وحدة فوق الثانية).
  static int open = 0;

  @override
  State<ScreensaverScreen> createState() => _ScreensaverScreenState();
}

class _ScreensaverScreenState extends State<ScreensaverScreen> {
  final _rand = Random();
  Offset _drift = Offset.zero;
  Timer? _timer;
  bool _closing = false;
  ImageStats? _stats;
  String? _analyzed;

  // ---- المحرر ----
  int _sel = 0;
  double _stepSize = 0.02;
  DateTime? _down;
  bool _longFired = false;
  bool _dialogOpen = false;

  AppState get s => AppState.I;
  String get _layout => widget.editing ? 'free' : s.cfg.s('saver.layout');

  @override
  void initState() {
    super.initState();
    if (!widget.preview) {
      ScreensaverScreen.open++;
      NativeBridge.keepScreenOn(true);
    }
    if (widget.editing && s.cfg.s('saver.layout') != 'free') {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.set('saver.layout', 'free'));
    }
    _timer = Timer.periodic(const Duration(seconds: 50), (_) {
      if (widget.editing || !s.cfg.b('saver.drift')) return;
      setState(() => _drift = Offset((_rand.nextDouble() - 0.5) * 0.05, (_rand.nextDouble() - 0.5) * 0.05));
    });
    if (s.cfg.s('saver.bg') == 'image' && s.cfg.s('saver.image').isNotEmpty) _onImage(s.cfg.s('saver.image'));
    final vis = _visible();
    if (vis.isNotEmpty) _sel = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!widget.preview) {
      ScreensaverScreen.open--;
      if (ScreensaverScreen.open == 0) NativeBridge.keepScreenOn(false);
    }
    super.dispose();
  }

  String? _current; // الصورة الظاهرة الآن (لسطر الحقوق)

  Future<void> _onImage(String path) async {
    if (_current != path) {
      _current = path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    if (_analyzed == path) return;
    _analyzed = path;
    final stats = await ImageAnalyzer.analyze(path);
    if (!mounted || stats == null) return;
    setState(() => _stats = stats);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  List<String> _visible() => [
        for (final e in saverElements)
          if (s.cfg.b(e.$3) && _available(e.$1)) e.$1,
      ];

  bool _available(String id) => switch (id) {
        'weather' => s.weather != null,
        'text' => s.cfg.s('saver.text').trim().isNotEmpty,
        _ => true,
      };

  // ---------------------------------------------------------------
  //  المواضع والألوان
  // ---------------------------------------------------------------
  Alignment _stackAlign() {
    final pos = s.cfg.s('saver.position');
    final bg = s.cfg.s('saver.bg');
    if (pos == 'auto') {
      return (bg == 'image' || bg == 'slideshow') ? (_stats?.bestPosition() ?? Alignment.bottomRight) : Alignment.center;
    }
    if (pos == 'custom') return Alignment(s.cfg.d('saver.posX'), s.cfg.d('saver.posY'));
    return _alignments[pos] ?? Alignment.center;
  }

  Alignment _elAlign(String id) => Alignment(s.cfg.d('saver.el.$id.x'), s.cfg.d('saver.el.$id.y'));

  double _lumAt(Alignment a) {
    final c = s.cfg;
    switch (c.s('saver.bg')) {
      case 'black':
        return 0;
      case 'solid':
        return c.c('saver.color').computeLuminance();
      case 'image':
      case 'slideshow':
        return (_stats?.lumAt(a) ?? 0.3) * (1 - c.d('saver.dim'));
      default:
        return s.palette.bg.computeLuminance();
    }
  }

  _Ink _inkAt(Alignment a) {
    final c = s.cfg;
    final bright = _lumAt(a) > 0.5;
    final shadow = [Shadow(color: (bright ? Colors.white : Colors.black).withValues(alpha: 0.45), blurRadius: 26)];
    final chip = (bright ? Colors.white : Colors.black).withValues(alpha: 0.16);
    if (c.s('saver.colorMode') == 'manual') {
      return _Ink(c.c('saver.clockColor'), c.c('saver.textColor'), c.c('saver.mutedColor'), c.c('saver.accentColor'), chip, bright, shadow);
    }
    if (bright) {
      return _Ink(const Color(0xFF111418), const Color(0xFF1A1E24), const Color(0xFF3B424C), const Color(0xFF7A4B00), chip, true, shadow);
    }
    return _Ink(Colors.white, const Color(0xFFF4F1EA), const Color(0xFFD6D2C8), c.c('saver.accentColor'), chip, false, shadow);
  }

  // ---------------------------------------------------------------
  //  المحرر: المفاتيح
  // ---------------------------------------------------------------
  KeyEventResult _editKeys(KeyEvent e) {
    final vis = _visible();
    final k = e.logicalKey;
    if (isBackKey(k)) {
      if (e is KeyDownEvent) _close();
      return KeyEventResult.handled;
    }
    if (isSelectKey(k)) {
      if (e is KeyDownEvent) {
        _down = DateTime.now();
        _longFired = false;
      } else if (e is KeyRepeatEvent) {
        if (!_longFired && _down != null && DateTime.now().difference(_down!) > const Duration(milliseconds: 550)) {
          _longFired = true;
          _options();
        }
      } else if (e is KeyUpEvent) {
        if (_down != null && !_longFired && vis.isNotEmpty) setState(() => _sel = (_sel + 1) % vis.length);
        _down = null;
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.contextMenu && e is KeyDownEvent) {
      _options();
      return KeyEventResult.handled;
    }
    if ((e is KeyDownEvent || e is KeyRepeatEvent) && vis.isNotEmpty) {
      final id = vis[_sel % vis.length];
      var dx = 0.0, dy = 0.0;
      if (k == LogicalKeyboardKey.arrowLeft) dx = -_stepSize;
      if (k == LogicalKeyboardKey.arrowRight) dx = _stepSize;
      if (k == LogicalKeyboardKey.arrowUp) dy = -_stepSize;
      if (k == LogicalKeyboardKey.arrowDown) dy = _stepSize;
      if (dx != 0 || dy != 0) {
        double r(double v) => double.parse(v.clamp(-1.0, 1.0).toStringAsFixed(3));
        s.set('saver.el.$id.x', r(s.cfg.d('saver.el.$id.x') + dx));
        s.set('saver.el.$id.y', r(s.cfg.d('saver.el.$id.y') + dy));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.handled;
  }

  Future<void> _options() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final vis = _visible();
    final id = vis.isEmpty ? null : vis[_sel % vis.length];
    final name = id == null ? '' : saverElements.firstWhere((e) => e.$1 == id).$2;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(112, 40, 40, 40),
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => themedDialog(
                width: 640,
                inset: EdgeInsets.zero,
                padding: const EdgeInsets.all(30),
                // الارتفاع يتبع الشاشة الفعلية فما تنقص النافذة على أي شاشة
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height - 140),
                  child: NavZone(child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    FitText(id == null ? 'ترتيب شاشة السكون' : name, style: Fonts.title(32, pal.ink)),
                    const SizedBox(height: 16),
                    ActionRow(autofocus: true, [
                      Act('تم', () => Navigator.pop(ctx), primary: true),
                      Act('إعادة المواضع للأصل', () {
                        s.cfg.resetPrefix(['saver.el.']);
                        s.touch();
                      }, icon: Lu.rotateCcw),
                      Act('التخطيط المجمّع', () {
                        s.set('saver.layout', 'stack');
                        Navigator.pop(ctx);
                        _close();
                      }, icon: Lu.rows),
                    ]),
                    const SizedBox(height: 20),
                    if (id != null) ...[
                      cStep('الحجم', 'saver.el.$id.scale', 0.4, 2.5, 0.05, fmtPct),
                      cStep('الموضع الأفقي', 'saver.el.$id.x', -1, 1, 0.01, _fmtX),
                      cStep('الموضع العمودي', 'saver.el.$id.y', -1, 1, 0.01, _fmtY),
                      ToggleRow(
                        key: const ValueKey('hide-selected'),
                        title: 'إخفاء هذا العنصر',
                        value: false,
                        onChanged: (_) {
                          final key = saverElements.firstWhere((e) => e.$1 == id).$3;
                          s.set(key, false);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                    ChoiceRow<double>(
                      key: const ValueKey('step'),
                      title: 'خطوة التحريك بالأسهم',
                      value: _stepSize,
                      options: const [(0.005, 'دقيقة جداً'), (0.01, 'دقيقة'), (0.02, 'عادية'), (0.05, 'سريعة')],
                      onChanged: (v) => setState(() => _stepSize = v),
                    ),
                    SectionTitle('العناصر الظاهرة'),
                    for (final e in saverElements) cToggle(e.$2, e.$3),
                    SectionTitle('الشكل'),
                    cFont('خط الساعة والتاريخ', 'saver.font'),
                    cFont('خط النصوص', 'saver.textFont'),
                    cChoice<String>('وضع الألوان', 'saver.colorMode', const [('auto', 'تلقائي حسب الخلفية'), ('manual', 'يدوي')]),
                    if (s.cfg.s('saver.colorMode') == 'manual') cColor('لون الساعة', 'saver.clockColor'),
                  ]),
                )),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _dialogOpen = false;
    final now = _visible();
    if (mounted && now.isNotEmpty) setState(() => _sel = _sel % now.length);
  }

  static String _fmtX(double v) => v.abs() < 0.005 ? 'الوسط' : (v < 0 ? 'يسار ${fmtPct(-v)}' : 'يمين ${fmtPct(v)}');
  static String _fmtY(double v) => v.abs() < 0.005 ? 'الوسط' : (v < 0 ? 'أعلى ${fmtPct(-v)}' : 'أسفل ${fmtPct(v)}');

  // ---------------------------------------------------------------
  //  البناء
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (widget.preview) {
      return IgnorePointer(
        child: ExcludeFocus(
          child: Material(
            color: Colors.black,
            child: ListenableBuilder(listenable: s, builder: (context, _) => Stack(fit: StackFit.expand, children: _scene())),
          ),
        ),
      );
    }
    return Material(
      color: Colors.black,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (widget.editing) return _editKeys(e);
          // أسفل: يفتح شاشة الطقس الكاملة مباشرة
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowDown && s.weather != null && s.cfg.b('weather.saverCard')) {
            final nav = Navigator.of(context);
            _close();
            nav.push(fade(const WeatherScreen()));
            return KeyEventResult.handled;
          }
          _close();
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onTap: widget.editing ? () => setState(() => _sel++) : _close,
          onLongPress: widget.editing ? _options : null,
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) {
              return Stack(fit: StackFit.expand, children: [
                ..._scene(),
                if (widget.editing) _hud(),
              ]);
            },
          ),
        ),
      ),
    );
  }

  /// الخلفية + التخطيط المختار (مشترك بين الشاشة الحقيقية والمعاينة).
  List<Widget> _scene() {
    final c = s.cfg;
    return [
                Backdrop(
                  kind: c.s('saver.bg'),
                  art: c.s('saver.art'),
                  image: c.s('saver.image'),
                  solid: c.c('saver.color'),
                  dim: c.d('saver.dim'),
                  kenBurns: c.b('saver.kenburns'),
                  interval: c.i('saver.interval'),
                  p: s.palette,
                  onImage: _onImage,
                ),
                // مطر هادئ وقطرات على الزجاج وقت المطر (فيكما صفحة ١٤)
                if (!widget.editing && !widget.preview && c.b('weather.saverRain') && s.weather != null && const {'rain', 'drizzle', 'storm', 'snow'}.contains(s.weather!.sky))
                  IgnorePointer(child: WeatherSky(kind: s.weather!.sky, night: true, overlay: true)),
                if (widget.editing) const IgnorePointer(child: CustomPaint(painter: _Guides(), child: SizedBox.expand())),
                ...switch (_layout) {
                  'elegant' => _elegantLayout(),
                  'calm' => _calmLayout(minimal: false),
                  'minimal' => _calmLayout(minimal: true),
                  'free' => _freeLayout(),
                  _ => [_stackLayout()],
                },
                if (!widget.editing && _credit() != null) _credit()!,
                // المحتوى اليومي (فيكما صفحة 11)
                if (!widget.editing && Daily.onSaver) const DailySaverLine(),
    ];
  }

  /// اسم المصوّر ورخصة الصورة (صور مكتبة ويكيميديا كومنز) — صغير وهادئ بالزاوية السفلى.
  Widget? _credit() {
    final c = s.cfg;
    if (!c.b('saver.showCredit')) return null;
    final bg = c.s('saver.bg');
    final path = bg == 'image' ? c.s('saver.image') : (bg == 'slideshow' ? _current : null);
    final cr = path == null ? null : WallCredits.of(path);
    if (cr == null) return null;
    return Positioned(
      left: 40,
      bottom: 28,
      child: Text(cr.line, style: Fonts.body(16, Colors.white.withValues(alpha: 0.55), weight: FontWeight.w300).copyWith(shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 10)])),
    );
  }

  /// التخطيط الهادئ (تصميم فيكما "النجوم"): كل شي بالوسط تحت، ساعة رفيعة كبيرة بوهج خفيف،
  /// خط ذهبي متلاشي، التاريخان بسطر واحد، وكبسولة الوقت القادم. والطقس بالزاوية العليا.
  /// [minimal]: الساعة والتاريخ فقط.
  List<Widget> _calmLayout({required bool minimal}) {
    final c = s.cfg;
    final t = s.now;
    final w = s.weather;
    final manual = c.s('saver.colorMode') == 'manual';
    final stars = c.s('saver.bg') == 'stars';
    final warm = stars ? SkyPalette.of(c.s('saver.stars.palette')).warm : c.c('saver.accentColor');
    final ink = manual ? c.c('saver.textColor') : Colors.white;
    final clockCol = manual ? c.c('saver.clockColor') : Colors.white;
    final clockFont = c.s('saver.font'), textFont = c.s('saver.textFont');
    final ts = c.d('saver.textSize');
    final h24 = c.b('saver.clock24');
    const sh = [Shadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 2))];
    final drift = c.b('saver.drift') ? _drift * 0.3 : Offset.zero;
    TextStyle txt(String f, double size, Color col, {FontWeight w = FontWeight.w400, double h = 1.3}) =>
        Fonts.family(f, size, col, weight: w, height: h).copyWith(shadows: sh);
    final dateLine = [
      if (c.b('saver.showDay')) Ar.dayName(t),
      if (c.b('saver.showDate')) Ar.gregorian(t),
      if (c.b('saver.showHijri') && !minimal) Ar.hijri(t, c.i('misc.hijriOffset')),
    ].join('   ·   ');
    return [
      if (!minimal && c.b('saver.showWeather') && w != null && c.b('weather.saverCard'))
        Positioned(top: 60, right: 90, child: WeatherSaverCard(ink: ink, muted: ink.withValues(alpha: 0.62)))
      else if (!minimal && c.b('saver.showWeather') && w != null)
        Positioned(
          top: 76,
          right: 110,
          child: Text(
            '${c.s('misc.city').isNotEmpty ? c.s('misc.city') : w.place}  ${Ar.n(w.temp)}°  ·  ${w.description}',
            style: Fonts.family(textFont, ts * 0.86, ink.withValues(alpha: 0.62), weight: FontWeight.w300).copyWith(shadows: sh),
          ),
        ),
      if (!minimal && c.b('saver.showText') && c.s('saver.text').trim().isNotEmpty)
        Positioned(
          top: 76,
          left: 110,
          right: 110,
          child: Center(child: FitText(c.s('saver.text'), alignment: Alignment.center, style: Fonts.family(clockFont, ts * 1.05, ink.withValues(alpha: 0.8)).copyWith(shadows: sh))),
        ),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(110, 140, 110, 120),
          child: AnimatedSlide(
            offset: drift,
            duration: s.anim(9000),
            curve: Curves.easeInOut,
            child: Align(
              alignment: minimal ? Alignment.center : Alignment.bottomCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (c.b('saver.showClock'))
                    Text(
                      Ar.time(t, h24: h24),
                      style: Fonts.family(clockFont, c.d('saver.clockSize') * (minimal ? 0.9 : 0.7), clockCol.withValues(alpha: 0.96), height: 1.05)
                          .copyWith(shadows: [Shadow(color: warm.withValues(alpha: 0.35), blurRadius: 40), ...sh]),
                    ),
                  if (dateLine.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: 220,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [warm.withValues(alpha: 0), warm.withValues(alpha: 0.9), warm.withValues(alpha: 0)]),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(dateLine, style: Fonts.family(textFont, ts * 1.07, ink.withValues(alpha: 0.82), weight: FontWeight.w300).copyWith(shadows: sh)),
                  ],
                  if (!minimal && c.b('saver.showCountdown')) ...[
                    const SizedBox(height: 18),
                    _countdown(_Ink(clockCol, ink, ink.withValues(alpha: 0.7), warm, Colors.white.withValues(alpha: 0.06), false, sh),
                        txt, textFont, clockFont, ts * 0.8),
                  ],
                  if (!minimal && (c.b('saver.showNextPrayer') || c.b('saver.showPrayers'))) ...[
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: NextPrayerLine(size: ts * 0.86, font: textFont, ink: ink.withValues(alpha: 0.75), accent: warm),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// التخطيط الأنيق السينمائي: تظليل ناعم، ساعة كبيرة رفيعة بالزاوية، خط فاصل،
  /// التاريخان بسطر واحد، والمواقيت خط زمني يمتد على عرض الشاشة.
  List<Widget> _elegantLayout() {
    final c = s.cfg;
    final t = s.now;
    final w = s.weather;
    final manual = c.s('saver.colorMode') == 'manual';
    final ink = manual ? c.c('saver.textColor') : Colors.white;
    final clockCol = manual ? c.c('saver.clockColor') : Colors.white;
    final muted = manual ? c.c('saver.mutedColor') : const Color(0xCCFFFFFF);
    final accent = c.c('saver.accentColor');
    final clockFont = c.s('saver.font'), textFont = c.s('saver.textFont');
    final ts = c.d('saver.textSize');
    final clockSize = c.d('saver.clockSize') * 0.82;
    final h24 = c.b('saver.clock24');
    const sh = [Shadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 3))];
    TextStyle txt(String f, double size, Color col, {FontWeight w = FontWeight.w400, double h = 1.3}) =>
        Fonts.family(f, size, col, weight: w, height: h).copyWith(shadows: sh);
    final drift = c.b('saver.drift') ? _drift * 0.4 : Offset.zero;

    final dateLine = [
      if (c.b('saver.showDay')) Ar.dayName(t),
      if (c.b('saver.showDate')) Ar.gregorian(t),
      if (c.b('saver.showHijri')) Ar.hijri(t, c.i('misc.hijriOffset')),
    ].join('   ·   ');

    return [
      // تظليل سينمائي يضمن وضوح النص فوق أي صورة
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x59000000), Color(0x00000000), Color(0x00000000), Color(0xC7000000)],
              stops: [0.0, 0.22, 0.42, 1.0],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(110, 70, 110, 64),
        child: AnimatedSlide(
          offset: drift,
          duration: s.anim(9000),
          curve: Curves.easeInOut,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // الأعلى: الطقس بزاوية، والنص الخاص أو العد التنازلي بالزاوية الثانية
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.b('saver.showCountdown'))
                _countdown(_Ink(clockCol, ink, muted, accent, Colors.black.withValues(alpha: 0.22), false, sh), txt, textFont, clockFont, ts * 0.8)
              else if (c.b('saver.showText') && c.s('saver.text').trim().isNotEmpty)
                Flexible(child: Text(c.s('saver.text'), style: txt(clockFont, ts * 1.1, ink))),
              const Spacer(),
              if (c.b('saver.showWeather') && w != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${Ar.n(w.temp)}°', style: txt(textFont, ts * 2.0, ink, w: FontWeight.w300, h: 1.0)),
                    SizedBox(width: ts * 0.5),
                    AppIcon(weatherIcon(w.kind), color: ink, size: ts * 1.7, shadows: sh),
                  ]),
                  Text(
                    '${w.description}  ·  ${Ar.n(w.max)}° / ${Ar.n(w.min)}°${(c.s('misc.city').isNotEmpty || w.place.isNotEmpty) ? '  ·  ${c.s('misc.city').isNotEmpty ? c.s('misc.city') : w.place}' : ''}',
                    style: txt(textFont, ts * 0.8, muted),
                  ),
                ]),
            ]),
            const Spacer(),
            // الساعة والتاريخ
            if (c.b('saver.showClock'))
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(Ar.time(t, h24: h24), style: txt(clockFont, clockSize, clockCol, h: 1.0)),
                    if (!h24 && c.b('saver.showPeriod')) ...[
                      SizedBox(width: clockSize * 0.08),
                      Text(Ar.period(t), style: txt(clockFont, clockSize * 0.2, muted, h: 1.0)),
                    ],
                  ],
                ),
              ),
            if (dateLine.isNotEmpty) ...[
              SizedBox(height: ts * 0.5),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(width: 560, height: 1.5, color: Colors.white.withValues(alpha: 0.35)),
              ),
              SizedBox(height: ts * 0.6),
              Text(dateLine, style: txt(textFont, ts * 1.05, muted)),
            ],
            if (c.b('saver.showPrayers')) ...[
              SizedBox(height: ts * 1.8),
              PrayerTimeline(size: c.d('saver.prayerSize'), font: textFont, ink: ink, muted: muted, accent: accent),
            ] else if (c.b('saver.showNextPrayer')) ...[
              SizedBox(height: ts * 1.2),
              NextPrayerLine(size: ts * 1.05, font: textFont, ink: ink, accent: accent, shadows: true),
            ],
          ]),
        ),
      ),
    ];
  }

  /// التخطيط المجمّع: كل العناصر بعمود واحد بمكان واحد.
  Widget _stackLayout() {
    final c = s.cfg;
    final align = _stackAlign();
    final ink = _inkAt(align);
    final lineAlign = switch (c.s('saver.align')) {
      'start' => 1.0,
      'end' => -1.0,
      'center' => 0.0,
      _ => align.x < -0.3 ? -1.0 : (align.x > 0.3 ? 1.0 : 0.0),
    };
    final cross = lineAlign > 0 ? CrossAxisAlignment.start : (lineAlign < 0 ? CrossAxisAlignment.end : CrossAxisAlignment.center);
    final wrap = lineAlign > 0 ? WrapAlignment.start : (lineAlign < 0 ? WrapAlignment.end : WrapAlignment.center);
    final ts = c.d('saver.textSize');
    final gaps = {'day': 0.0, 'clock': 0.0, 'date': c.d('saver.dateSize') * 0.35, 'hijri': ts * 0.3, 'text': ts * 0.9, 'countdown': ts * 1.1, 'next': ts * 1.2, 'prayers': ts * 0.9, 'weather': ts * 1.2};
    final order = ['day', 'clock', 'date', 'hijri', 'text', 'countdown', 'next', 'prayers', 'weather'];
    final vis = _visible();
    final children = <Widget>[];
    for (final id in order) {
      if (!vis.contains(id)) continue;
      if (children.isNotEmpty) children.add(SizedBox(height: gaps[id]));
      children.add(_element(id, ink, wrap));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 90),
      child: AnimatedAlign(
        alignment: align,
        duration: s.anim(1400),
        curve: Curves.easeInOutCubic,
        child: AnimatedSlide(
          offset: c.b('saver.drift') ? _drift : Offset.zero,
          duration: s.anim(9000),
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1680, maxHeight: 900),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: cross, children: children),
            ),
          ),
        ),
      ),
    );
  }

  /// التخطيط الحر: كل عنصر بمكانه وحجمه الخاص.
  List<Widget> _freeLayout() {
    final vis = _visible();
    final selId = widget.editing && vis.isNotEmpty ? vis[_sel % vis.length] : null;
    final drift = !widget.editing && s.cfg.b('saver.drift') ? _drift : Offset.zero;
    return [
      for (final id in vis)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 90, vertical: 64),
            child: AnimatedSlide(
              offset: drift,
              duration: s.anim(9000),
              curve: Curves.easeInOut,
              child: AnimatedAlign(
                alignment: _elAlign(id),
                duration: s.anim(widget.editing ? 90 : 600),
                curve: Curves.easeOutCubic,
                child: Builder(builder: (_) {
                  final a = _elAlign(id);
                  final ink = _inkAt(a);
                  final wrap = a.x > 0.3 ? WrapAlignment.start : (a.x < -0.3 ? WrapAlignment.end : WrapAlignment.center);
                  final scale = s.cfg.d('saver.el.$id.scale');
                  Widget w = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1700),
                    child: _element(id, ink, wrap),
                  );
                  // بالمحرر: كل عنصر بإطار (الذهبي للمحدد والمتقطع للباقي) بنفس الحشوة،
                  // فما يتزحزح شي لما تتنقل بين العناصر.
                  if (widget.editing) w = _frame(w, id, id == selId, scale);
                  return Transform.scale(scale: scale, alignment: a, child: w);
                }),
              ),
            ),
          ),
        ),
    ];
  }

  /// إطار عنصر بالمحرر. الإطار يُرسم داخل التكبير، فنقسم سمكه على النسبة
  /// حتى يبقى ثابت الشكل مهما كبّرت أو صغّرت العنصر.
  Widget _frame(Widget child, String id, bool selected, double scale) {
    final p = s.palette;
    final k = 1 / scale;
    final r = BorderRadius.circular(18 * k);
    final body = Padding(padding: EdgeInsets.symmetric(horizontal: 20 * k, vertical: 14 * k), child: child);
    if (!selected) {
      return CustomPaint(
        foregroundPainter: _DashedFrame(color: Colors.white.withValues(alpha: 0.32), width: 1.5 * k, radius: 18 * k, dash: 10 * k, gap: 8 * k),
        child: body,
      );
    }
    final name = saverElements.firstWhere((e) => e.$1 == id).$2;
    final chipFg = p.ring.computeLuminance() > 0.45 ? const Color(0xFF13201A) : Colors.white;
    return Stack(clipBehavior: Clip.none, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          color: Colors.black.withValues(alpha: 0.18),
          border: Border.all(color: p.ring, width: 4 * k),
        ),
        child: body,
      ),
      PositionedDirectional(
        top: -44 * k,
        start: 0,
        child: Transform.scale(
          scale: k,
          alignment: AlignmentDirectional.bottomStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: p.ring, borderRadius: BorderRadius.circular(999)),
            child: Text('$name · ${fmtPct(scale)}', style: Fonts.body(18, chipFg, weight: FontWeight.w600)),
          ),
        ),
      ),
    ]);
  }

  /// شريط التعليمات. إذا العنصر المحدد فوق، الشريط ينزل للأسفل حتى ما يغطيه.
  Widget _hud() {
    final p = s.palette;
    final vis = _visible();
    final selY = vis.isEmpty ? 0.0 : _elAlign(vis[_sel % vis.length]).y;
    final atBottom = selY < -0.5;
    Text t(String v, {bool lead = false}) => Text(v,
        style: Fonts.body(20, lead ? p.ring : Colors.white.withValues(alpha: 0.85), weight: lead ? FontWeight.w600 : null));
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 44),
          child: AnimatedAlign(
        duration: s.anim(220),
        curve: Curves.easeOutCubic,
        alignment: atBottom ? Alignment.bottomCenter : Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              t('تحرير حر', lead: true),
              const SizedBox(width: 26),
              t('الأسهم: تحريك'),
              const SizedBox(width: 26),
              t('موافق: العنصر التالي'),
              const SizedBox(width: 26),
              t('ضغطة طويلة: الحجم والخيارات'),
              const SizedBox(width: 26),
              t('رجوع: حفظ وخروج'),
            ]),
          ),
        ),
      ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  //  العناصر
  // ---------------------------------------------------------------
  Widget _element(String id, _Ink ink, WrapAlignment wrap) {
    final c = s.cfg;
    final t = s.now;
    final clockFont = c.s('saver.font'), textFont = c.s('saver.textFont');
    final clockSize = c.d('saver.clockSize'), dateSize = c.d('saver.dateSize'), ts = c.d('saver.textSize');
    final h24 = c.b('saver.clock24');
    TextStyle txt(String fam, double size, Color col, {FontWeight w = FontWeight.w400, double h = 1.3}) =>
        Fonts.family(fam, size, col, weight: w, height: h).copyWith(shadows: ink.shadow);

    switch (id) {
      case 'day':
        return Text(Ar.dayName(t), style: txt(textFont, ts * 1.1, ink.muted));
      case 'clock':
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(Ar.time(t, h24: h24), style: txt(clockFont, clockSize, ink.clock, w: FontWeight.w700, h: 1.0)),
            if (!h24 && c.b('saver.showPeriod')) ...[
              SizedBox(width: clockSize * 0.09),
              Text(Ar.period(t), style: txt(clockFont, clockSize * 0.2, ink.muted, h: 1.0)),
            ],
          ],
        );
      case 'date':
        return Text(Ar.gregorian(t), style: txt(clockFont, dateSize, ink.text));
      case 'hijri':
        return Text(Ar.hijri(t, c.i('misc.hijriOffset')), style: txt(textFont, ts, ink.muted));
      case 'text':
        return Text(c.s('saver.text'), style: txt(clockFont, ts * 1.15, ink.text), textAlign: TextAlign.center);
      case 'next':
        return NextPrayerLine(size: ts * 1.05, font: textFont, ink: ink.text, accent: ink.accent, shadows: true);
      case 'prayers':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: PrayerStrip(
            size: c.d('saver.prayerSize'),
            font: textFont,
            ink: ink.text,
            muted: ink.muted,
            accent: ink.accent,
            chip: ink.chip,
            shadows: true,
            alignment: wrap,
          ),
        );
      case 'countdown':
        return _countdown(ink, txt, textFont, clockFont, ts);
      case 'weather':
        final w = s.weather!;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: ts * 1.4, vertical: ts * 0.6),
          decoration: BoxDecoration(
            color: ink.chip,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ink.muted.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AppIcon(weatherIcon(w.kind), color: ink.accent, size: ts * 1.4, shadows: ink.shadow),
            SizedBox(width: ts * 0.5),
            Text('${Ar.n(w.temp)}°', style: txt(textFont, ts * 1.4, ink.text)),
            SizedBox(width: ts * 0.5),
            Text(w.description, style: txt(textFont, ts, ink.muted)),
            _divider(ink.muted, ts),
            Text('العظمى ${Ar.n(w.max)}° · الصغرى ${Ar.n(w.min)}°', style: txt(textFont, ts, ink.muted)),
            if (c.s('misc.city').isNotEmpty || w.place.isNotEmpty) ...[
              _divider(ink.muted, ts),
              Text(c.s('misc.city').isNotEmpty ? c.s('misc.city') : w.place, style: txt(textFont, ts, ink.muted)),
            ],
          ]),
        );
    }
    return const SizedBox.shrink();
  }

  Widget _countdown(_Ink ink, TextStyle Function(String, double, Color, {FontWeight w, double h}) txt, String textFont, String clockFont, double ts) {
    final c = s.cfg;
    final now = s.now;
    final target = DateTime(c.i('saver.cdYear'), c.i('saver.cdMonth'), c.i('saver.cdDay'), c.i('saver.cdHour'));
    final diff = target.difference(now);
    String big, small;
    if (diff.inMinutes >= 0 && diff.inDays >= 1) {
      big = Ar.n(diff.inDays);
      small = diff.inDays == 1 ? 'يوم' : 'يوم و${Ar.n(diff.inHours % 24)} ساعة';
    } else if (diff.inMinutes >= 0) {
      big = '${Ar.n(diff.inHours)}:${Ar.n((diff.inMinutes % 60).toString().padLeft(2, '0'))}';
      small = 'ساعة';
    } else if (diff.inDays > -1) {
      big = 'اليوم';
      small = '';
    } else {
      big = Ar.n(-diff.inDays);
      small = 'يوم مضى';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts * 1.2, vertical: ts * 0.7),
      decoration: BoxDecoration(
        color: ink.chip,
        borderRadius: BorderRadius.circular(ts),
        border: Border.all(color: ink.accent.withValues(alpha: 0.45)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(Lu.hourglass, color: ink.accent, size: ts * 1.1, shadows: ink.shadow),
          SizedBox(width: ts * 0.4),
          Text(c.s('saver.cdTitle'), style: txt(textFont, ts, ink.text)),
        ]),
        SizedBox(height: ts * 0.3),
        Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(big, style: txt(clockFont, ts * 2.6, ink.accent, w: FontWeight.w700, h: 1.0)),
          if (small.isNotEmpty) ...[
            SizedBox(width: ts * 0.4),
            Text(small, style: txt(textFont, ts, ink.muted)),
          ],
        ]),
      ]),
    );
  }

  Widget _divider(Color c, double size) => Container(
        width: 1,
        height: size * 1.3,
        margin: EdgeInsets.symmetric(horizontal: size * 1.0),
        color: c.withValues(alpha: 0.35),
      );
}

/// خطوط إرشاد خفيفة بالمحرر (أرباع أفقياً وأثلاث عمودياً) تسهّل المحاذاة.
class _Guides extends CustomPainter {
  const _Guides();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_Guides old) => false;
}

/// إطار متقطع بزوايا مدورة للعناصر غير المحددة.
class _DashedFrame extends CustomPainter {
  final Color color;
  final double width, radius, dash, gap;
  const _DashedFrame({required this.color, required this.width, required this.radius, required this.dash, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFrame old) =>
      old.color != color || old.width != width || old.radius != radius || old.dash != dash || old.gap != gap;
}
