import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arabic.dart';
import '../lucide.dart';
import '../brand.dart';
import '../state.dart';
import '../weather.dart';
import '../weather_sky.dart';
import '../widgets.dart';
import 'system_screens.dart' show StatusChip;

// ═══════════════════════════════════════════════════════════════════════
//  شاشة الطقس الحية (فيكما صفحة ١٤): الرئيسية بكل حالات الجو، التفاصيل
//  وعشرة أيام، مدني، إضافة مدينة وتحديد الموقع، واختصارات الواجهة والسكون.
// ═══════════════════════════════════════════════════════════════════════

class _Ink {
  final bool n;
  const _Ink(this.n);
  Color get ink => n ? const Color(0xFFEEF4EF) : const Color(0xFF13201A);
  Color get mu => n ? const Color(0xFFAFC2B9) : const Color(0xFF3F4C46);
  Color get gold => n ? const Color(0xFFD8B467) : const Color(0xFF94681F);
  Color get ac => n ? const Color(0xFF3DBE8C) : const Color(0xFF0D5C45);
  Color get blue => n ? const Color(0xFF8FD0FF) : const Color(0xFF1B6797);
  Color get line => n ? Colors.white.withValues(alpha: 0.10) : const Color(0xFF13201A).withValues(alpha: 0.10);
  Color get warnBg => const Color(0xFFF2B43B).withValues(alpha: n ? 0.16 : 0.22);
  Color get warnInk => n ? const Color(0xFFFFE7A0) : const Color(0xFF6E4B00);
}

bool get _rich => AppState.I.cfg.s('weather.motion') == 'full' && !AppState.I.lite;

/// لوح زجاجي فوق المشهد الحي.
class _Glass extends StatelessWidget {
  final bool night;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? width, height;
  final bool focused;
  const _Glass({required this.night, required this.child, this.radius = 30, this.padding = const EdgeInsets.all(32), this.width, this.height, this.focused = false});

  @override
  Widget build(BuildContext context) {
    final i = _Ink(night);
    final box = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.05)] : [Colors.white.withValues(alpha: 0.66), Colors.white.withValues(alpha: 0.46)],
        ),
        border: Border.all(color: focused ? i.gold : (night ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.9)), width: focused ? 3 : 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: night ? 0.28 : 0.08), blurRadius: 44, offset: const Offset(0, 16))],
      ),
      child: child,
    );
    if (!_rich) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: box),
    );
  }
}

Widget _pill(bool night, List<Widget> parts, {Color? fill, Color? border, double h = 44, double pad = 18}) => Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: pad),
      decoration: BoxDecoration(
        color: fill ?? (night ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(h / 2),
        border: Border.all(color: border ?? (night ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.9))),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (k, w) in parts.indexed) ...[if (k > 0) const SizedBox(width: 8), w],
      ]),
    );

/// رقم بدرجة (اتجاه يسار←يمين حتى تبقى ° على يمين الرقم).
Widget _deg(String v, TextStyle st) => Directionality(textDirection: TextDirection.ltr, child: Text('$v°', style: st));
String _n(num v) => Ar.n(v.round());
String _dec(double v) => Ar.n(v.toStringAsFixed(v < 10 ? 1 : 0)).replaceAll('.', '٫');

// ═══════════════════ الشاشة الرئيسية ═══════════════════

class WeatherScreen extends StatefulWidget {
  final int start;
  const WeatherScreen({super.key, this.start = 0});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late int _i = widget.start;
  bool _details = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WeatherHub.rev.addListener(_changed);
    _boot();
  }

  Future<void> _boot() async {
    if (WeatherHub.cities.isEmpty) await WeatherHub.locate();
    final cs = WeatherHub.cities;
    for (final c in cs) {
      unawaited(WeatherHub.load(c));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WeatherHub.rev.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final cs = WeatherHub.cities;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft && cs.isNotEmpty) {
      setState(() => _i = (_i + 1) % cs.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight && cs.isNotEmpty) {
      setState(() => _i = (_i - 1 + cs.length) % cs.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown && !_details) {
      setState(() => _details = true);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp && _details) {
      setState(() => _details = false);
      return KeyEventResult.handled;
    }
    if (isSelectKey(k)) {
      Navigator.push(context, fade(const CitiesScreen())).then((v) {
        if (v is int && mounted) setState(() => _i = v);
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final cs = WeatherHub.cities;
    if (_i >= cs.length) _i = 0;
    final city = cs.isEmpty ? null : cs[_i];
    final f = city == null ? null : WeatherHub.of(city);
    final night = f == null ? AppState.I.palette.night : !f.isDay;
    return PopScope(
      canPop: !_details,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => _details = false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _key,
          child: Stack(fit: StackFit.expand, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1100),
              child: WeatherSky(
                key: ValueKey('${city?.key}-${f?.kind}-$night'),
                kind: f?.kind ?? 'cloudy',
                night: night,
                dir: f?.screenDir ?? 1,
                windK: f?.windK ?? 1,
                intensity: f?.intensity ?? 1,
              ),
            ),
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1920,
                height: 1080,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 520),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c),
                  ),
                  child: city == null
                      ? _WxState(key: const ValueKey('none'), night: night, offline: WeatherHub.offline)
                      : f == null
                          ? _WxState(key: ValueKey('load-${city.key}'), night: night, offline: WeatherHub.offline, city: city.name)
                          : _details
                              ? _Details(key: ValueKey('d-${city.key}'), f: f, cities: cs, index: _i)
                              : _Main(key: ValueKey('m-${city.key}'), f: f, cities: cs, index: _i),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// حالة التحميل أو انقطاع الشبكة.
class _WxState extends StatelessWidget {
  final bool night, offline;
  final String? city;
  const _WxState({super.key, required this.night, required this.offline, this.city});
  @override
  Widget build(BuildContext context) {
    final i = _Ink(night);
    return Center(
      child: _Glass(
        night: night,
        width: 900,
        padding: const EdgeInsets.all(56),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (offline)
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: i.gold.withValues(alpha: 0.16)),
              child: AppIcon(Lu.wifiOff, color: i.gold, size: 56),
            )
          else
            RawnaqLoader(size: 150, night: night),
          const SizedBox(height: 28),
          FitText(offline ? 'الشبكة مقطوعة' : (city == null ? 'جاري تحديد موقعك' : 'جاري جلب طقس $city'), alignment: Alignment.center, style: Fonts.title(44, i.ink)),
          const SizedBox(height: 10),
          FitText(offline ? 'نعرض آخر طقس محفوظ أول ما ترجع الشبكة' : 'من شبكة البيت، بثواني', alignment: Alignment.center, style: Fonts.body(22, i.mu)),
        ]),
      ),
    );
  }
}

/// مبدّل المدن بأعلى اليسار.
class _Switcher extends StatelessWidget {
  final List<WxCity> cities;
  final int index;
  final bool night;
  const _Switcher({required this.cities, required this.index, required this.night});
  @override
  Widget build(BuildContext context) {
    final i = _Ink(night);
    final show = <int>[for (var k = 0; k < cities.length && k < 5; k++) (index + k) % cities.length];
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: night ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: night ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (k, ci) in show.indexed) ...[
          if (k > 0) const SizedBox(width: 4),
          Builder(builder: (_) {
            final c = cities[ci];
            final f = WeatherHub.of(c);
            final on = ci == index;
            return Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: on ? i.ac.withValues(alpha: night ? 0.3 : 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: on ? Border.all(color: i.ac.withValues(alpha: 0.6)) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (f != null) WxIcon(wxIconName(f.kind, f.isDay), size: 24, night: night, mono: on ? null : i.mu),
                if (f != null) const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(c.name, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: Fonts.body(19, on ? i.ink : i.mu, weight: on ? FontWeight.w600 : null)),
                ),
                if (f != null) ...[const SizedBox(width: 8), _deg(_n(f.temp), Fonts.body(19, on ? i.ink : i.mu, weight: FontWeight.w500))],
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

String _ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'الآن';
  if (m == 1) return 'قبل دقيقة';
  if (m == 2) return 'قبل دقيقتين';
  if (m <= 10) return 'قبل ${Ar.n(m)} دقائق';
  return 'قبل ${Ar.n(m)} دقيقة';
}

String _motionLine(Forecast f) {
  final dir = f.screenDir > 0 ? 'لليمين' : 'لليسار';
  return switch (f.kind) {
    'dust' => 'الغبار يمشي ويا الريح $dir',
    'fog' => 'الضباب يمشي ببطء $dir',
    'clear' => f.isDay ? 'الريح ${f.windFromName}، ${_n(f.wind)} كم/س' : 'النجوم تتلألأ والسماء صافية',
    _ => 'الغيوم تمشي ويا الريح $dir',
  };
}

class _Main extends StatelessWidget {
  final Forecast f;
  final List<WxCity> cities;
  final int index;
  const _Main({super.key, required this.f, required this.cities, required this.index});

  String? get _alert => switch (f.kind) {
        'storm' => 'تنبيه: عاصفة رعدية، ابتعد عن الأماكن المكشوفة',
        'dust' => 'تنبيه: عجاج، الكمامة ضرورية',
        'fog' when f.visKm < 1 => 'تنبيه: ضباب كثيف على الطرق',
        _ when f.gust >= 60 => 'تنبيه: رياح قوية ${_n(f.gust)} كم/س',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final n = !f.isDay;
    final i = _Ink(n);
    final c = f.city;
    final hi = f.days.isEmpty ? f.temp : f.days.first.max, lo = f.days.isEmpty ? f.temp : f.days.first.min;
    final alert = _alert;
    return Stack(children: [
      // العنوان
      Positioned(
        top: 52,
        right: 80,
        child: Row(children: [
          AppIcon(Lu.mapPin, color: i.gold, size: 34),
          const SizedBox(width: 14),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: FitText(c.name, style: Fonts.title(48, i.ink))),
          const SizedBox(width: 24),
          c.auto
              ? _pill(n, [AppIcon(Lu.locate, color: i.ac, size: 18), Text('موقعك الحقيقي', style: Fonts.body(17, i.ac, weight: FontWeight.w500))],
                  fill: i.ac.withValues(alpha: n ? 0.16 : 0.1), border: i.ac.withValues(alpha: 0.45), h: 38, pad: 14)
              : _pill(n, [AppIcon(Lu.pin, color: i.mu, size: 18), Text('مدينة محفوظة', style: Fonts.body(17, i.mu, weight: FontWeight.w500))], h: 38, pad: 14),
        ]),
      ),
      Positioned(
        top: 122,
        right: 80,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: FitText(
              [if (c.region.isNotEmpty) c.region, c.auto ? 'محدّد من شبكة البيت' : 'الساعة ${wxTime(f.local)}'].join('، '),
              style: Fonts.body(20, i.mu)),
        ),
      ),
      Positioned(top: 56, left: 80, child: _Switcher(cities: cities, index: index, night: n)),
      Positioned(
        top: 134,
        left: 84,
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: i.ac, shape: BoxShape.circle, boxShadow: [BoxShadow(color: i.ac, blurRadius: 10)])),
          const SizedBox(width: 10),
          Text('تحديث لحظي، ${_ago(f.fetched)}', style: Fonts.body(17, i.mu)),
          const SizedBox(width: 14),
          Container(width: 4, height: 4, decoration: BoxDecoration(color: i.mu, shape: BoxShape.circle)),
          const SizedBox(width: 14),
          Text(_motionLine(f), style: Fonts.body(17, i.mu)),
        ]),
      ),
      // الحرارة الكبيرة
      Positioned(
        top: 146,
        right: 74,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _deg(_n(f.temp), Fonts.body(232, i.ink, weight: FontWeight.w200).copyWith(height: 1.0, shadows: [Shadow(color: Colors.black.withValues(alpha: n ? 0.3 : 0.06), blurRadius: 30, offset: const Offset(0, 6))])),
          const SizedBox(height: 6),
          Text(f.description, style: Fonts.body(46, i.ink, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(mainAxisSize: MainAxisSize.min, children: [
            AppIcon(Lu.arrowUp, color: i.gold, size: 22),
            const SizedBox(width: 6),
            Text('العظمى', style: Fonts.body(22, i.mu)),
            const SizedBox(width: 8),
            _deg(_n(hi), Fonts.body(26, i.ink, weight: FontWeight.w600)),
            const SizedBox(width: 30),
            AppIcon(Lu.arrowDown, color: i.blue, size: 22),
            const SizedBox(width: 6),
            Text('الصغرى', style: Fonts.body(22, i.mu)),
            const SizedBox(width: 8),
            _deg(_n(lo), Fonts.body(26, i.ink, weight: FontWeight.w600)),
          ]),
          if (alert != null) ...[
            const SizedBox(height: 18),
            _pill(n, [AppIcon(f.kind == 'storm' ? Lu.zap : (f.kind == 'fog' ? Lu.eye : Lu.wind), color: i.warnInk, size: 18), Text(alert, style: Fonts.body(17, i.warnInk, weight: FontWeight.w500))],
                fill: i.warnBg, border: const Color(0xFFF2B43B).withValues(alpha: 0.6), h: 40, pad: 16),
          ],
        ]),
      ),
      Positioned(top: 184, left: 80, child: _LeftCard(f: f)),
      Positioned(left: 80, right: 80, top: 620, child: _HourStrip(f: f)),
      Positioned(
        left: 0,
        right: 0,
        bottom: 36,
        child: Center(
          child: _pill(n, [Text('يمين ويسار: المدن        أسفل: التفاصيل وعشرة أيام        موافق: مدني        رجوع: خروج', style: Fonts.body(17, i.mu))], h: 46, pad: 24),
        ),
      ),
    ]);
  }
}

// ---------- بطاقة اليسار حسب الجو ----------

class _LeftCard extends StatelessWidget {
  final Forecast f;
  const _LeftCard({required this.f});

  @override
  Widget build(BuildContext context) {
    final k = f.kind;
    if (k == 'rain' || k == 'drizzle' || k == 'storm' || k == 'snow') return _precip();
    if (k == 'dust') return _dust();
    if (k == 'fog') return _fog();
    return _SunCard(f: f);
  }

  Widget _precip() {
    final n = !f.isDay, i = _Ink(n);
    final storm = f.kind == 'storm';
    var vals = [for (final v in f.next2h) (v * 4 / 8).clamp(0.0, 1.0)];
    if (vals.isEmpty || vals.every((v) => v < 0.02)) vals = [for (final h in f.hours.take(8)) h.pop / 100];
    final stopAt = f.hours.indexWhere((h) => h.pop < 30);
    final head = storm
        ? 'العاصفة تعبر ${stopAt > 0 ? 'خلال ${Ar.n(stopAt)} ساعات' : 'خلال الساعات الجاية'}'
        : (stopAt > 0 ? 'المطر يخف ${wxHourLabel(f.hours[stopAt].t)}' : (stopAt == 0 ? 'يخف المطر قريباً' : 'المطر يستمر لساعات'));
    final today = f.days.isEmpty ? 0.0 : f.days.first.rain;
    return _BarsCard(
      night: n,
      icon: storm ? 'cloud-lightning' : 'cloud-rain',
      title: storm ? 'البرق والعاصفة' : 'المطر بالساعتين الجاية',
      head: head,
      values: vals,
      colors: (v) => storm ? (v > 0.75 ? const [Color(0xFFC7A6FF), Color(0xFF7B5BD6)] : const [Color(0xFF9DB0FF), Color(0xFF5F74C8)]) : (n ? const [Color(0xFF9AD6FF), Color(0xFF4D8FC0)] : const [Color(0xFF2A86C8), Color(0xFF7FB6DC)]),
      levels: storm ? const ['عالي', 'متوسط', 'قليل'] : const ['غزير', 'متوسط', 'خفيف'],
      axis: const ['الآن', 'نص ساعة', 'ساعة', 'ساعة ونص'],
      chips: [
        (Lu.umbrella, 'احتمال المطر ${Ar.n(f.pop)}٪', i.blue),
        (Lu.droplets, '${_dec(today)} ملم اليوم', i.blue),
        (Lu.wind, 'رياح ${_n(f.wind)} كم/س', i.mu),
      ],
    );
  }

  Widget _dust() {
    final n = !f.isDay, i = _Ink(n);
    final pm = [for (final h in f.hours.take(12)) (h.pm10 ?? f.pm10 ?? 0)];
    final clearAt = pm.indexWhere((v) => v < 150);
    return _BarsCard(
      night: n,
      icon: 'haze',
      title: 'الغبار بالساعات الجاية',
      head: clearAt > 0 ? 'العجاج يخف ${wxHourLabel(f.hours[clearAt].t)}' : (clearAt == 0 ? 'الغبار خفيف هسه' : 'العجاج مستمر اليوم'),
      values: [for (final v in pm) (v / 400).clamp(0.03, 1.0)],
      colors: (v) => v > 0.7 ? const [Color(0xFFE8823A), Color(0xFFA8502A)] : (v > 0.4 ? const [Color(0xFFE8B44A), Color(0xFFB0782A)] : const [Color(0xFF9CCB7E), Color(0xFF5E9A50)]),
      levels: const ['خطر', 'غير صحي', 'مقبول'],
      axis: [for (final k in [0, 3, 6, 9]) k < f.hours.length ? wxHourLabel(f.hours[k].t, first: k == 0) : ''],
      chips: [
        (Lu.eye, 'الرؤية ${_dec(f.visKm)} كم', i.blue),
        (Lu.wind, 'رياح ${_n(f.wind)} كم/س', i.mu),
        (Lu.house, 'سكّر الشبابيك', i.gold),
      ],
    );
  }

  Widget _fog() {
    final n = !f.isDay, i = _Ink(n);
    final vis = [for (final h in f.hours.take(12)) h.visKm];
    final clearAt = vis.indexWhere((v) => v >= 3);
    return _BarsCard(
      night: n,
      icon: 'cloud-fog',
      title: 'مدى الرؤية',
      head: clearAt > 0 ? 'الضباب ينقشع ${wxHourLabel(f.hours[clearAt].t)}' : (clearAt == 0 ? 'الرؤية تتحسن هسه' : 'الضباب باقي لساعات'),
      values: [for (final v in vis) (v / 10).clamp(0.04, 1.0)],
      colors: (v) => v < 0.3 ? (n ? const [Color(0xFFB9C7C9), Color(0xFF7D8B8D)] : const [Color(0xFF8E9C9E), Color(0xFFB9C4C5)]) : (n ? const [Color(0xFF9AD6FF), Color(0xFF4D8FC0)] : const [Color(0xFF2A86C8), Color(0xFF7FB6DC)]),
      levels: const ['ممتاز', 'جيد', 'ضعيف'],
      axis: [for (final k in [0, 3, 6, 9]) k < f.hours.length ? wxHourLabel(f.hours[k].t, first: k == 0) : ''],
      chips: [
        (Lu.eye, f.visKm < 1 ? 'الرؤية ${Ar.n((f.visKm * 1000).round())} متر' : 'الرؤية ${_dec(f.visKm)} كم', i.blue),
        (Lu.droplets, 'الرطوبة ${Ar.n(f.humidity)}٪', i.blue),
        (Lu.car, 'سوق بحذر', i.gold),
      ],
    );
  }
}

class _BarsCard extends StatelessWidget {
  final bool night;
  final String icon, title, head;
  final List<double> values;
  final List<Color> Function(double v) colors;
  final List<String> levels, axis;
  final List<(Object, String, Color)> chips;
  const _BarsCard({required this.night, required this.icon, required this.title, required this.head, required this.values, required this.colors, required this.levels, required this.axis, required this.chips});

  @override
  Widget build(BuildContext context) {
    final i = _Ink(night);
    return _Glass(
      night: night,
      width: 900,
      height: 404,
      padding: const EdgeInsets.fromLTRB(40, 26, 40, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [WxIcon(icon, size: 26, night: night), const SizedBox(width: 10), Text(title, style: Fonts.body(20, i.mu, weight: FontWeight.w600))]),
        const SizedBox(height: 6),
        FitText(head, style: Fonts.body(30, i.ink, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: CustomPaint(painter: _BarsPainter(values, colors, i.line))),
            const SizedBox(width: 14),
            SizedBox(
              width: 66,
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final l in levels) FitText(l, style: Fonts.body(15, i.mu)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 80),
          child: Row(children: [
            for (final (k, a) in axis.indexed) Expanded(child: Text(a, textAlign: TextAlign.right, style: Fonts.body(16, k == 0 ? i.ink : i.mu, weight: k == 0 ? FontWeight.w600 : null))),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final (k, ch) in chips.indexed) ...[
            if (k > 0) const SizedBox(width: 12),
            Flexible(child: _pill(night, [AppIcon(ch.$1, color: ch.$3, size: 18), Flexible(child: FitText(ch.$2, style: Fonts.body(17, i.ink, weight: FontWeight.w500)))], h: 40, pad: 14)),
          ],
        ]),
      ]),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> v;
  final List<Color> Function(double) colors;
  final Color line;
  _BarsPainter(this.v, this.colors, this.line);

  @override
  void paint(Canvas c, Size s) {
    for (final lv in const [0.9, 0.6, 0.3]) {
      c.drawLine(Offset(0, s.height * (1 - lv)), Offset(s.width, s.height * (1 - lv)), Paint()..color = line..strokeWidth = 1.5);
    }
    if (v.isEmpty) return;
    final step = s.width / v.length;
    final bw = math.min(step * 0.58, 26.0);
    for (var k = 0; k < v.length; k++) {
      final x = s.width - (k + 0.5) * step; // RTL: الآن يمين
      final hgt = math.max(4.0, v[k] * s.height);
      final col = colors(v[k]);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x - bw / 2, s.height - hgt, bw, hgt), Radius.circular(bw / 2));
      if (v[k] > 0.6) c.drawRRect(r.inflate(2), Paint()..color = col[0].withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      c.drawRRect(r, Paint()..shader = ui.Gradient.linear(Offset(0, s.height - hgt), Offset(0, s.height), [col[0], col[1].withValues(alpha: 0.3)]));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter o) => o.v != v;
}

/// بطاقة الشمس (نهاراً) أو الليل والقمر.
class _SunCard extends StatelessWidget {
  final Forecast f;
  const _SunCard({required this.f});

  @override
  Widget build(BuildContext context) {
    final n = !f.isDay, i = _Ink(n);
    final d = f.days.isEmpty ? null : f.days.first;
    final rise = d?.sunrise, set = d?.sunset;
    final now = f.local;
    double prog = 0.5;
    String head = n ? 'ليل صافي' : 'نهار هادئ';
    if (rise != null && set != null) {
      if (!n) {
        prog = (now.difference(rise).inMinutes / math.max(1, set.difference(rise).inMinutes)).clamp(0.0, 1.0);
        final left = set.difference(now);
        head = left.isNegative ? 'الشمس غابت' : 'الشمس تغيب بعد ${_dur(left)}';
      } else {
        final nextRise = f.days.length > 1 && now.isAfter(set) ? f.days[1].sunrise : rise;
        final startN = now.isAfter(set) ? set : set.subtract(const Duration(days: 1));
        if (nextRise != null) {
          prog = (now.difference(startN).inMinutes / math.max(1, nextRise.difference(startN).inMinutes)).clamp(0.0, 1.0);
          head = 'الليل ${f.kind == 'clear' ? 'صافي' : 'هادئ'}، والشروق بعد ${_dur(nextRise.difference(now))}';
        }
      }
    }
    return _Glass(
      night: n,
      width: 900,
      height: 404,
      padding: const EdgeInsets.fromLTRB(40, 26, 40, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [WxIcon(n ? 'moon' : 'sun-medium', size: 26, night: n), const SizedBox(width: 10), Text(n ? 'الليل والقمر' : 'الشمس اليوم', style: Fonts.body(20, i.mu, weight: FontWeight.w600))]),
        const SizedBox(height: 6),
        FitText(head, style: Fonts.body(30, i.ink, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Expanded(child: CustomPaint(painter: _ArcPainter(prog, n))),
        const SizedBox(height: 6),
        Row(children: [
          Text(n ? 'الغروب ${set != null ? wxTime(set) : ''}' : 'الشروق ${rise != null ? wxTime(rise) : ''}', style: Fonts.body(17, i.mu)),
          const Spacer(),
          Text(n ? 'الشروق ${f.days.length > 1 && f.days[1].sunrise != null ? wxTime(f.days[1].sunrise!) : ''}' : 'الغروب ${set != null ? wxTime(set) : ''}', style: Fonts.body(17, i.mu)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _pill(n, [AppIcon(n ? Lu.eye : Lu.sunMedium, color: i.gold, size: 18), Text(n ? 'الرؤية ${Ar.n(f.visKm.round())} كم' : 'الأشعة ${Ar.n(f.uv)} ${_uvName(f.uv)}', style: Fonts.body(17, i.ink, weight: FontWeight.w500))], h: 40, pad: 14),
          const SizedBox(width: 12),
          _pill(n, [AppIcon(Lu.droplets, color: i.blue, size: 18), Text('الرطوبة ${Ar.n(f.humidity)}٪', style: Fonts.body(17, i.ink, weight: FontWeight.w500))], h: 40, pad: 14),
          const SizedBox(width: 12),
          _pill(n, [AppIcon(Lu.wind, color: i.mu, size: 18), Text('رياح ${_n(f.wind)} كم/س', style: Fonts.body(17, i.ink, weight: FontWeight.w500))], h: 40, pad: 14),
        ]),
      ]),
    );
  }
}

String _dur(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  final hs = switch (h) { 0 => '', 1 => 'ساعة', 2 => 'ساعتين', _ => '${Ar.n(h)} ساعات' };
  if (m < 5) return hs.isEmpty ? 'دقائق' : hs;
  final ms = m == 30 ? 'نص' : '${Ar.n(m)} دقيقة';
  return hs.isEmpty ? ms : '$hs و$ms';
}

String _uvName(int uv) => uv <= 2 ? 'منخفضة' : (uv <= 5 ? 'متوسطة' : (uv <= 7 ? 'عالية' : 'عالية جداً'));

class _ArcPainter extends CustomPainter {
  final double t;
  final bool night;
  _ArcPainter(this.t, this.night);

  Offset _bz(List<Offset> p, double t) {
    final u = 1 - t;
    return p[0] * (u * u * u) + p[1] * (3 * u * u * t) + p[2] * (3 * u * t * t) + p[3] * (t * t * t);
  }

  @override
  void paint(Canvas c, Size s) {
    final p = [Offset(s.width - 20, s.height - 4), Offset(s.width - 20, -s.height * 0.35), Offset(20, -s.height * 0.35), Offset(20, s.height - 4)];
    final line = night ? Colors.white : const Color(0xFF13201A);
    c.drawLine(Offset(0, s.height - 4), Offset(s.width, s.height - 4), Paint()..color = line.withValues(alpha: 0.18)..strokeWidth = 1.5);
    final dash = Paint()
      ..color = line.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    for (var k = 0.0; k < 1; k += 0.02) {
      if ((k * 50).round().isEven) c.drawLine(_bz(p, k), _bz(p, k + 0.012), dash);
    }
    final done = Path()..moveTo(p[0].dx, p[0].dy);
    for (var k = 0.0; k <= t; k += 0.01) {
      final q = _bz(p, k);
      done.lineTo(q.dx, q.dy);
    }
    c.drawPath(
        done,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(p[0], p[3], night ? const [Color(0xFF8FB8FF), Color(0xFFF3E7C2)] : const [Color(0xFFFFB547), Color(0xFFFFD98A)]));
    final o = _bz(p, t);
    c.drawCircle(o, 38, Paint()..shader = ui.Gradient.radial(o, 38, [(night ? const Color(0xFFF3E7C2) : const Color(0xFFFFC65C)).withValues(alpha: 0.7), Colors.transparent]));
    c.drawCircle(o, 15, Paint()..color = night ? const Color(0xFFF6EED6) : const Color(0xFFFFC34D));
    c.drawCircle(o, 15, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _ArcPainter o) => o.t != t || o.night != night;
}

// ---------- شريط الساعات ----------

class _HourStrip extends StatelessWidget {
  final Forecast f;
  const _HourStrip({required this.f});

  String _sub(WxHour h) {
    final k = f.kind;
    if (k == 'fog') return h.visKm < 1 ? '${Ar.n((h.visKm * 1000).round())} م' : (h.visKm < 9 ? '${Ar.n(h.visKm.round())} كم' : '');
    if (k == 'dust') {
      final v = h.pm10 ?? 0;
      return v > 250 ? 'عالي' : (v > 150 ? 'متوسط' : (v > 80 ? 'خفيف' : ''));
    }
    return h.pop >= 20 ? '${Ar.n(h.pop)}٪' : '';
  }

  @override
  Widget build(BuildContext context) {
    final n = !f.isDay, i = _Ink(n);
    final hs = f.hours.take(12).toList();
    final next = hs.indexWhere((h) => h.pop < 20);
    final note = switch (f.kind) {
      'rain' || 'drizzle' => next > 0 ? 'المطر يستمر لحد ${wxHourLabel(hs[next].t)}' : 'أمطار متقطعة',
      'storm' => 'تهدأ تدريجياً',
      'fog' => 'ينقشع ويصير صافي',
      'dust' => 'الغبار يخف تدريجياً',
      'cloudy' => 'غيوم بدون مطر',
      _ => n ? 'صافي طول الليل' : 'صافي لآخر النهار',
    };
    final subCol = f.kind == 'dust' ? (n ? const Color(0xFFE0B36A) : const Color(0xFF8A5A16)) : (f.kind == 'fog' ? (n ? const Color(0xFFB9C7C9) : const Color(0xFF56646A)) : i.blue);
    return _Glass(
      night: n,
      height: 346,
      padding: const EdgeInsets.fromLTRB(40, 22, 40, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AppIcon(Lu.clock, color: i.mu, size: 22),
          const SizedBox(width: 10),
          Text('توقعات الساعات الجاية', style: Fonts.body(20, i.mu, weight: FontWeight.w600)),
          const Spacer(),
          Text(note, style: Fonts.body(19, i.mu)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(builder: (context, cons) {
            final cw = cons.maxWidth / 12;
            final temps = [for (final h in hs) h.temp];
            final mn = temps.isEmpty ? 0 : temps.reduce(math.min), mx = temps.isEmpty ? 1 : temps.reduce(math.max);
            return Stack(children: [
              Positioned(right: 0, top: 0, bottom: 0, width: cw, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: i.ac.withValues(alpha: n ? 0.16 : 0.09)))),
              Positioned.fill(top: 150, bottom: 44, child: CustomPaint(painter: _CurvePainter(temps, mn, mx, n, i.gold))),
              Row(children: [
                for (final (k, h) in hs.indexed)
                  SizedBox(
                    width: cw,
                    child: Column(children: [
                      const SizedBox(height: 8),
                      Text(wxHourLabel(h.t, first: k == 0), style: Fonts.body(20, k == 0 ? i.ink : i.mu, weight: k == 0 ? FontWeight.w600 : null)),
                      const SizedBox(height: 12),
                      WxIcon(wxIconName(wxKind(h.code, null), h.day), size: 38, night: n),
                      const SizedBox(height: 8),
                      SizedBox(height: 24, child: Text(_sub(h), style: Fonts.body(17, subCol, weight: FontWeight.w500))),
                      const Spacer(),
                      _deg(Ar.n(h.temp), Fonts.body(24, i.ink, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                    ]),
                  ),
              ]),
            ]);
          }),
        ),
      ]),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final List<int> t;
  final int mn, mx;
  final bool night;
  final Color gold;
  _CurvePainter(this.t, this.mn, this.mx, this.night, this.gold);

  @override
  void paint(Canvas c, Size s) {
    if (t.isEmpty) return;
    final cw = s.width / 12;
    Offset at(int k) => Offset(s.width - (k + 0.5) * cw, s.height - 6 - (t[k] - mn) / math.max(1, mx - mn) * (s.height - 16));
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var k = 1; k < t.length; k++) {
      final a = at(k - 1), b = at(k), mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..shader = ui.Gradient.linear(Offset(0, 0), Offset(s.width, 0), [night ? const Color(0xFF7CC8FF) : const Color(0xFF1F7BC0), gold]));
    final ink = night ? const Color(0xFFEEF4EF) : const Color(0xFF13201A);
    for (var k = 0; k < t.length; k++) {
      c.drawCircle(at(k), k == 0 ? 9 : 6, Paint()..color = k == 0 ? gold : ink);
      if (k == 0) c.drawCircle(at(k), 9, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = night ? const Color(0xFF06120E) : Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter o) => o.t != t;
}

// ═══════════════════ التفاصيل وعشرة أيام ═══════════════════

class _Details extends StatelessWidget {
  final Forecast f;
  final List<WxCity> cities;
  final int index;
  const _Details({super.key, required this.f, required this.cities, required this.index});

  @override
  Widget build(BuildContext context) {
    final n = !f.isDay, i = _Ink(n);
    return Stack(children: [
      Positioned(
        top: 50,
        right: 80,
        child: Row(children: [
          AppIcon(Lu.mapPin, color: i.gold, size: 30),
          const SizedBox(width: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: FitText(f.city.name, style: Fonts.title(40, i.ink))),
          const SizedBox(width: 20),
          _pill(n, [WxIcon(wxIconName(f.kind, f.isDay), size: 22, night: n), _deg(_n(f.temp), Fonts.body(19, i.ink, weight: FontWeight.w600)), Text(f.description, style: Fonts.body(18, i.mu))], h: 40, pad: 14),
        ]),
      ),
      Positioned(
        top: 66,
        left: 84,
        child: Row(children: [
          for (var k = 0; k < cities.length && k < 8; k++) ...[
            if (k > 0) const SizedBox(width: 10),
            AnimatedContainer(duration: const Duration(milliseconds: 300), width: k == index ? 32 : 10, height: 10, decoration: BoxDecoration(color: k == index ? i.ac : i.mu.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(5))),
          ],
        ]),
      ),
      Positioned(top: 140, left: 80, width: 860, height: 830, child: _TenDays(f: f)),
      Positioned(top: 140, right: 80, width: 860, height: 830, child: _Tiles(f: f)),
      Positioned(
        left: 0,
        right: 0,
        bottom: 30,
        child: Center(child: _pill(n, [Text('أعلى: رجوع للطقس الحالي        يمين ويسار: المدن        رجوع: خروج', style: Fonts.body(17, i.mu))], h: 46, pad: 24)),
      ),
    ]);
  }
}

class _TenDays extends StatelessWidget {
  final Forecast f;
  const _TenDays({required this.f});

  @override
  Widget build(BuildContext context) {
    final n = !f.isDay, i = _Ink(n);
    final days = f.days.take(10).toList();
    final lo = days.isEmpty ? 0 : days.map((d) => d.min).reduce(math.min), hi = days.isEmpty ? 1 : days.map((d) => d.max).reduce(math.max);
    return _Glass(
      night: n,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [AppIcon(Lu.calendarDays, color: i.mu, size: 22), const SizedBox(width: 10), Text('توقعات عشرة أيام', style: Fonts.body(20, i.mu, weight: FontWeight.w600))]),
        ),
        const SizedBox(height: 10),
        for (final (k, d) in days.indexed)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: k == 0 ? i.ac.withValues(alpha: n ? 0.18 : 0.1) : null,
                borderRadius: BorderRadius.circular(18),
                border: k > 1 || k == 0 ? null : Border(top: BorderSide(color: i.line)),
              ),
              child: Row(children: [
                SizedBox(width: 130, child: Text(k == 0 ? 'اليوم' : Ar.dayName(d.d), style: Fonts.body(22, i.ink, weight: k == 0 ? FontWeight.w600 : null))),
                WxIcon(wxIconName(wxKind(d.code, null), true), size: 36, night: n),
                const SizedBox(width: 10),
                SizedBox(width: 64, child: Text(d.pop >= 20 ? '${Ar.n(d.pop)}٪' : '', style: Fonts.body(17, i.blue, weight: FontWeight.w500))),
                SizedBox(width: 58, child: _deg(Ar.n(d.min), Fonts.body(22, i.mu))),
                const SizedBox(width: 10),
                Expanded(child: CustomPaint(size: const Size(double.infinity, 8), painter: _RangePainter(d.min, d.max, lo, hi, k == 0 ? f.temp : null, n))),
                const SizedBox(width: 14),
                SizedBox(width: 58, child: _deg(Ar.n(d.max), Fonts.body(22, i.ink, weight: FontWeight.w600))),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _RangePainter extends CustomPainter {
  final int a, b, lo, hi;
  final int? now;
  final bool night;
  _RangePainter(this.a, this.b, this.lo, this.hi, this.now, this.night);

  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    double x(int t) => s.width - (t - lo) / math.max(1, hi - lo) * s.width; // RTL: البارد يمين
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(0, y - 3, s.width, y + 3), const Radius.circular(3)), Paint()..color = (night ? Colors.white : const Color(0xFF13201A)).withValues(alpha: 0.12));
    final r = Rect.fromLTRB(x(b), y - 3, x(a), y + 3);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..shader = ui.Gradient.linear(r.centerLeft, r.centerRight, const [Color(0xFFF2A93B), Color(0xFF7CC4F0)]));
    if (now != null) {
      c.drawCircle(Offset(x(now!.clamp(a, b)), y), 7, Paint()..color = Colors.white);
      c.drawCircle(Offset(x(now!.clamp(a, b)), y), 7, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x9913201A));
    }
  }

  @override
  bool shouldRepaint(covariant _RangePainter o) => false;
}

class _Tiles extends StatelessWidget {
  final Forecast f;
  const _Tiles({required this.f});

  @override
  Widget build(BuildContext context) {
    final n = !f.isDay, i = _Ink(n);
    final d = f.days.isEmpty ? null : f.days.first;
    final aqi = f.aqi;
    final tiles = <(String, String, String, String, String, Widget)>[
      ('thermometer-sun', 'الإحساس الحراري', '${Ar.n(f.feels)}°', '', f.feels < f.temp - 1 ? 'أبرد بسبب الرياح' : (f.feels > f.temp + 1 ? 'أحر بسبب الرطوبة' : 'نفس الحرارة تقريباً'), _bar(f.feels.clamp(-5, 50) / 50, const [Color(0xFF7CC4F0), Color(0xFFF2A93B)], n)),
      ('droplets', 'الرطوبة', '${Ar.n(f.humidity)}٪', '', f.humidity > 75 ? 'الجو رطب هسه' : (f.humidity < 30 ? 'الجو جاف' : 'رطوبة معتدلة'), _bar(f.humidity / 100, const [Color(0xFF1B6797), Color(0xFF7CC4F0)], n)),
      ('wind', 'الرياح', _n(f.wind), 'كم/س', 'هبات لحد ${_n(f.gust)}', _Compass(f.windFrom, f.windFromName, n)),
      ('umbrella', 'المطر', _dec(d?.rain ?? 0), 'ملم', 'احتمال اليوم ${Ar.n(d?.pop ?? 0)}٪', _Mini([for (final h in f.hours.take(7)) h.pop / 100], n)),
      ('sun-medium', 'الأشعة فوق البنفسجية', Ar.n(f.uv), _uvName(f.uv), f.uv <= 2 ? 'ما تحتاج حماية' : 'استخدم واقي الشمس', _scale(f.uv / 11, const [Color(0xFF3DBE8C), Color(0xFFF2A93B), Color(0xFFE5484D), Color(0xFF8E5BD8)], n)),
      ('gauge', 'الضغط الجوي', Ar.n(f.pressure), 'ملي بار', f.pressure < 1005 ? 'منخفض' : (f.pressure > 1020 ? 'مرتفع' : 'طبيعي'), _Gauge(((f.pressure - 980) / 60).clamp(0.0, 1.0), n)),
      ('eye', 'مدى الرؤية', f.visKm < 1 ? Ar.n((f.visKm * 1000).round()) : Ar.n(f.visKm.round()), f.visKm < 1 ? 'متر' : 'كم', f.visKm < 2 ? 'رؤية ضعيفة' : (f.visKm < 8 ? 'رؤية متوسطة' : 'رؤية واضحة'), _Vis(f.visKm, n)),
      ('sunrise', 'الشروق والغروب', d?.sunrise != null ? Ar.time(d!.sunrise!) : '—', d?.sunrise != null ? (d!.sunrise!.hour < 12 ? 'ص' : 'م') : '', d?.sunset != null ? 'الغروب ${wxTime(d!.sunset!)}' : '', _SunMini(f, n)),
      ('haze', 'جودة الهواء والغبار', aqi == null ? '—' : Ar.n(aqi), aqi == null ? '' : (aqi <= 50 ? 'جيدة' : (aqi <= 100 ? 'مقبولة' : (aqi <= 150 ? 'حساسة' : 'غير صحية'))), (f.dust ?? 0) > 150 ? 'عجاج بالجو' : 'الغبار قليل اليوم', _scale(((aqi ?? 40) / 300).clamp(0.0, 1.0), const [Color(0xFF3DBE8C), Color(0xFFF2C14E), Color(0xFFE5484D), Color(0xFF7E3FA0)], n)),
    ];
    return Column(children: [
      for (var r = 0; r < 3; r++) ...[
        if (r > 0) const SizedBox(height: 20),
        Expanded(
          child: Row(children: [
            for (var c = 0; c < 3; c++) ...[
              if (c > 0) const SizedBox(width: 20),
              Expanded(child: _tile(tiles[r * 3 + c], i, n)),
            ],
          ]),
        ),
      ],
    ]);
  }

  Widget _tile((String, String, String, String, String, Widget) t, _Ink i, bool n) => _Glass(
        night: n,
        radius: 26,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [WxIcon(t.$1, size: 22, night: n), const SizedBox(width: 8), Expanded(child: FitText(t.$2, style: Fonts.body(16, i.mu, weight: FontWeight.w500)))]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Directionality(textDirection: TextDirection.ltr, child: Text(t.$3, style: Fonts.body(44, i.ink, weight: FontWeight.w600))),
            if (t.$4.isNotEmpty) ...[const SizedBox(width: 8), Flexible(child: FitText(t.$4, style: Fonts.body(20, i.mu, weight: FontWeight.w500)))],
          ]),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: t.$6)),
          FitText(t.$5, style: Fonts.body(16, i.mu)),
        ]),
      );

  Widget _bar(double v, List<Color> cols, bool n) => Center(
        child: LayoutBuilder(
          builder: (_, c) => Stack(children: [
            Container(height: 8, decoration: BoxDecoration(color: (n ? Colors.white : const Color(0xFF13201A)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4))),
            Align(
              alignment: Alignment.centerRight,
              child: Container(width: c.maxWidth * v.clamp(0.04, 1.0), height: 8, decoration: BoxDecoration(gradient: LinearGradient(colors: cols), borderRadius: BorderRadius.circular(4))),
            ),
          ]),
        ),
      );

  Widget _scale(double v, List<Color> cols, bool n) => Center(
        child: LayoutBuilder(
          builder: (_, c) => SizedBox(
            height: 18,
            child: Stack(children: [
              Positioned(left: 0, right: 0, top: 5, child: Container(height: 8, decoration: BoxDecoration(gradient: LinearGradient(colors: cols), borderRadius: BorderRadius.circular(4)))),
              Positioned(
                right: (c.maxWidth - 18) * v.clamp(0.0, 1.0),
                top: 0,
                child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0x8013201A), width: 2))),
              ),
            ]),
          ),
        ),
      );
}

class _Compass extends StatelessWidget {
  final double from;
  final String name;
  final bool n;
  const _Compass(this.from, this.name, this.n);
  @override
  Widget build(BuildContext context) {
    final i = _Ink(n);
    return Row(children: [
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: (n ? Colors.white : const Color(0xFF13201A)).withValues(alpha: 0.25), width: 2)),
          alignment: Alignment.center,
          child: Transform.rotate(angle: (from + 180) * math.pi / 180 - math.pi / 4, child: AppIcon(Lu.navigation, color: i.ink, size: 26)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: FitText('ريح $name', style: Fonts.body(15, i.mu))),
    ]);
  }
}

class _Mini extends StatelessWidget {
  final List<double> v;
  final bool n;
  const _Mini(this.v, this.n);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final x in v.reversed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: FractionallySizedBox(
                heightFactor: x.clamp(0.06, 1.0),
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: n ? const [Color(0xFF9AD6FF), Color(0x554D8FC0)] : const [Color(0xFF2A86C8), Color(0x557FB6DC)]),
                  ),
                ),
              ),
            ),
          ),
      ]);
}

class _Gauge extends StatelessWidget {
  final double v;
  final bool n;
  const _Gauge(this.v, this.n);
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GaugePainter(v, n));
}

class _GaugePainter extends CustomPainter {
  final double v;
  final bool n;
  _GaugePainter(this.v, this.n);
  @override
  void paint(Canvas c, Size s) {
    final r = math.min(s.width / 2, s.height) - 6;
    final o = Offset(s.width / 2, s.height - 2);
    final rect = Rect.fromCircle(center: o, radius: r);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    c.drawArc(rect, math.pi, math.pi, false, p..color = (n ? Colors.white : const Color(0xFF13201A)).withValues(alpha: 0.14));
    c.drawArc(rect, math.pi, math.pi * v, false, p..color = n ? const Color(0xFFD8B467) : const Color(0xFF94681F));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter o) => o.v != v;
}

class _Vis extends StatelessWidget {
  final double km;
  final bool n;
  const _Vis(this.km, this.n);
  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (var j = 0; j < 4; j++)
          FractionallySizedBox(
            widthFactor: (1 - j * 0.18) * (km / 10).clamp(0.3, 1.0),
            alignment: Alignment.centerRight,
            child: Container(height: 4, decoration: BoxDecoration(color: (n ? Colors.white : const Color(0xFF13201A)).withValues(alpha: 0.05 + 0.18 * (1 - j * 0.25)), borderRadius: BorderRadius.circular(2))),
          ),
      ]);
}

class _SunMini extends StatelessWidget {
  final Forecast f;
  final bool n;
  const _SunMini(this.f, this.n);
  @override
  Widget build(BuildContext context) {
    final d = f.days.isEmpty ? null : f.days.first;
    var t = 0.5;
    if (d?.sunrise != null && d?.sunset != null) {
      t = (f.local.difference(d!.sunrise!).inMinutes / math.max(1, d.sunset!.difference(d.sunrise!).inMinutes)).clamp(0.0, 1.0);
    }
    return CustomPaint(painter: _ArcPainter(t, n));
  }
}

// ═══════════════════ مدني ═══════════════════

class CitiesScreen extends StatefulWidget {
  const CitiesScreen({super.key});
  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  final _nodes = FocusNodes();

  @override
  void initState() {
    super.initState();
    WeatherHub.rev.addListener(_ch);
    for (final c in WeatherHub.cities) {
      unawaited(WeatherHub.load(c));
    }
  }

  void _ch() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WeatherHub.rev.removeListener(_ch);
    _nodes.dispose();
    super.dispose();
  }

  void _options(WxCity c, int idx) {
    final saved = WeatherHub.saved;
    final si = saved.indexWhere((x) => x.key == c.key);
    showActions(context, c.name, [
      ('فتح الطقس', Lu.cloudSun, () => Navigator.pop(context, idx), false),
      if (si > 0)
        ('تقديم بالترتيب', Lu.chevronRight, () {
          final l = [...saved]..removeAt(si);
          l.insert(si - 1, c);
          WeatherHub.setSaved(l);
        }, false),
      if (si >= 0 && si < saved.length - 1)
        ('تأخير بالترتيب', Lu.chevronLeft, () {
          final l = [...saved]..removeAt(si);
          l.insert(si + 1, c);
          WeatherHub.setSaved(l);
        }, false),
      if (si >= 0) ('حذف المدينة', Lu.trash, () => WeatherHub.setSaved([...saved]..removeAt(si)), true),
      if (c.auto) ('إيقاف الموقع الحالي', Lu.locate, () => AppState.I.set('weather.auto', false), true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final p = AppState.I.palette;
          final cs = WeatherHub.cities;
          final count = cs.length + 1;
          return Padding(
            padding: const EdgeInsets.fromLTRB(80, 56, 80, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                AppIcon(Lu.mapPinned, color: p.ring, size: 40),
                const SizedBox(width: 16),
                Text('مدني', style: Fonts.title(48, p.ink)),
                const SizedBox(width: 20),
                StatusChip('${Ar.n(cs.length)} ${cs.length > 2 && cs.length < 11 ? 'مدن' : 'مدينة'}', kind: 'none'),
                const Spacer(),
                Text('كل مدينة بطقسها الحي، تنتقل بيناتها بيمين ويسار', style: Fonts.body(21, p.muted)),
              ]),
              const SizedBox(height: 34),
              Expanded(
                child: GridView.builder(
                  clipBehavior: Clip.none,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 28, crossAxisSpacing: 24, childAspectRatio: 422 / 330),
                  itemCount: count,
                  itemBuilder: (context, k) {
                    final add = k == cs.length;
                    return FocusTap(
                      focusNode: _nodes.of('c$k'),
                      autofocus: k == 0,
                      onTap: () => add ? Navigator.push(context, fade(const AddCityScreen())) : Navigator.pop(context, k),
                      onLongPress: add ? null : () => _options(cs[k], k),
                      onKey: (e) => gridNav(e, index: k, count: count, cols: 4, focus: (t) => _nodes.focus('c$t')),
                      builder: (context, f) => AnimatedScale(
                        scale: f ? 1.04 : 1,
                        duration: AppState.I.anim(160),
                        child: add ? _AddCard(focused: f) : _CityCard(city: cs[k], focused: f),
                      ),
                    );
                  },
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.line)),
                  child: Text('الأسهم: تنقل        موافق: فتح الطقس        ضغطة طويلة: ترتيب أو حذف        رجوع: خروج', style: Fonts.body(17, p.muted)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _CityCard extends StatelessWidget {
  final WxCity city;
  final bool focused;
  const _CityCard({required this.city, required this.focused});
  @override
  Widget build(BuildContext context) {
    final f = WeatherHub.of(city);
    final night = f == null ? AppState.I.palette.night : !f.isDay;
    final p = AppState.I.palette;
    const light = Color(0xFFF4F7F4);
    final ink = night ? light : const Color(0xFF13201A), mu = night ? const Color(0xFFC9D6CF) : const Color(0xFF3E4B45);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: focused ? p.ring : Colors.white.withValues(alpha: night ? 0.12 : 0.8), width: focused ? 4 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: night ? 0.35 : 0.14), blurRadius: 36, offset: const Offset(0, 16))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(fit: StackFit.expand, children: [
          if (f != null) WeatherSky(kind: f.kind, night: night, dir: f.screenDir, windK: f.windK, intensity: f.intensity, compact: true) else ColoredBox(color: p.surface),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.4, 1], colors: [Colors.transparent, (night ? Colors.black : Colors.white).withValues(alpha: 0.4)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FitText(city.name, style: Fonts.body(26, ink, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    city.auto
                        ? Row(children: [AppIcon(Lu.locate, color: night ? const Color(0xFF7FE0B6) : p.accent, size: 16), const SizedBox(width: 6), Text('موقعك الحالي', style: Fonts.body(16, night ? const Color(0xFF7FE0B6) : p.accent, weight: FontWeight.w500))])
                        : Text(f == null ? '' : 'الساعة ${wxTime(f.local)}', style: Fonts.body(16, mu)),
                  ]),
                ),
                if (f != null) WxIcon(wxIconName(f.kind, f.isDay), size: 44, night: night),
              ]),
              const Spacer(),
              if (f == null)
                const Center(child: RawnaqLoader(size: 64))
              else ...[
                Align(alignment: Alignment.centerRight, child: _deg(_n(f.temp), Fonts.body(92, ink, weight: FontWeight.w300).copyWith(height: 1.05))),
                Row(children: [
                  Expanded(child: FitText(f.description, style: Fonts.body(19, ink, weight: FontWeight.w500))),
                  AppIcon(Lu.arrowUp, color: mu, size: 16),
                  const SizedBox(width: 4),
                  _deg(_n(f.days.isEmpty ? f.temp : f.days.first.max), Fonts.body(18, ink, weight: FontWeight.w500)),
                  const SizedBox(width: 14),
                  AppIcon(Lu.arrowDown, color: mu, size: 16),
                  const SizedBox(width: 4),
                  _deg(_n(f.days.isEmpty ? f.temp : f.days.first.min), Fonts.body(18, ink, weight: FontWeight.w500)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final bool focused;
  const _AddCard({required this.focused});
  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: focused ? p.ring : p.ring.withValues(alpha: 0.5), width: focused ? 4 : 2),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: p.ring.withValues(alpha: 0.14)), child: AppIcon(Lu.plus, color: p.ring, size: 40)),
        const SizedBox(height: 18),
        Text('إضافة مدينة', style: Fonts.body(24, p.ink, weight: FontWeight.w600)),
        Text('بالبحث أو من موقعك', style: Fonts.body(17, p.muted)),
      ]),
    );
  }
}

// ═══════════════════ إضافة مدينة وتحديد الموقع ═══════════════════

class AddCityScreen extends StatefulWidget {
  const AddCityScreen({super.key});
  @override
  State<AddCityScreen> createState() => _AddCityScreenState();
}

class _AddCityScreenState extends State<AddCityScreen> with SingleTickerProviderStateMixin {
  final _q = TextEditingController();
  late final AnimationController _radar = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  Timer? _deb;
  List<WxCity> _res = [];
  bool _busy = false, _locating = false;

  @override
  void initState() {
    super.initState();
    if (WeatherHub.here == null) _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    await WeatherHub.locate();
    if (mounted) setState(() => _locating = false);
  }

  void _search(String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _busy = true);
      final r = await WeatherHub.search(v);
      if (mounted) {
        setState(() {
          _res = r;
          _busy = false;
        });
      }
    });
  }

  void _add(WxCity c) {
    final l = WeatherHub.saved;
    if (!l.any((x) => x.key == c.key)) l.add(c);
    WeatherHub.setSaved(l);
    unawaited(WeatherHub.load(c));
    toast(context, 'انضافت ${c.name}');
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _q.dispose();
    _radar.dispose();
    _deb?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final p = AppState.I.palette;
          final here = WeatherHub.here;
          return Padding(
            padding: const EdgeInsets.fromLTRB(80, 56, 80, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                AppIcon(Lu.plus, color: p.ring, size: 36),
                const SizedBox(width: 14),
                Text('إضافة مدينة', style: Fonts.title(48, p.ink)),
                const Spacer(),
                Text('ابحث باسم المدينة، أو خلّ رونق يحدد موقعك', style: Fonts.body(21, p.muted)),
              ]),
              const SizedBox(height: 30),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // البحث (يمين)
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextField(
                          controller: _q,
                          autofocus: true,
                          onChanged: _search,
                          style: Fonts.body(30, p.ink, weight: FontWeight.w600),
                          cursorColor: p.ring,
                          decoration: InputDecoration(
                            hintText: 'اسم المدينة',
                            hintStyle: Fonts.body(26, p.muted),
                            prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: AppIcon(Lu.search, color: p.ring, size: 28)),
                            suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(8), child: RawnaqLoader(size: 44)) : null,
                            filled: true,
                            fillColor: p.surface,
                            contentPadding: const EdgeInsets.symmetric(vertical: 22),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.ring, width: 2.5)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: _res.isEmpty
                              ? Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    AppIcon(_q.text.trim().length >= 2 && !_busy ? Lu.searchX : Lu.search, color: p.muted, size: 56),
                                    const SizedBox(height: 14),
                                    Text(_q.text.trim().length >= 2 && !_busy ? (WeatherHub.offline ? 'الشبكة مقطوعة' : 'ما لگينا مدينة بهذا الاسم') : 'اكتب حرفين أو أكثر', style: Fonts.body(22, p.muted)),
                                  ]),
                                )
                              : ListView(clipBehavior: Clip.none, children: [
                                  for (final c in _res)
                                    SysRowLite(icon: Lu.mapPin, title: c.name, sub: c.region, onTap: () => _add(c)),
                                ]),
                        ),
                      ]),
                  ),
                  const SizedBox(width: 40),
                  // تحديد الموقع (يسار)
                  SizedBox(
                    width: 820,
                    child: Container(
                      padding: const EdgeInsets.all(34),
                      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(32), border: Border.all(color: p.line)),
                      child: Column(children: [
                        Row(children: [
                          AppIcon(Lu.wifi, color: p.muted, size: 18),
                          const SizedBox(width: 8),
                          Text('الموقع من شبكة البيت، بدقة تقريبية', style: Fonts.body(16, p.muted)),
                          const Spacer(),
                          AppIcon(Lu.shieldCheck, color: p.accent, size: 18),
                          const SizedBox(width: 8),
                          Text('يبقى على جهازك', style: Fonts.body(16, p.accent)),
                        ]),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _radar,
                            builder: (_, __) => CustomPaint(painter: _RadarPainter(_radar.value, p.accent, p.ring, _locating), child: Center(child: Container(
                              width: 88,
                              height: 88,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: p.ring, boxShadow: [BoxShadow(color: p.ring.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 4)]),
                              child: AppIcon(Lu.locate, color: p.night ? const Color(0xFF06120E) : Colors.white, size: 44),
                            ))),
                          ),
                        ),
                        Text(_locating ? 'جاري تحديد موقعك' : (here == null ? 'ما گدرنا نحدد الموقع' : 'حددنا موقعك'), style: Fonts.body(18, p.accent, weight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        FitText(here == null ? '—' : [here.name, if (here.region.isNotEmpty) here.region.split('، ').first].join('، '), alignment: Alignment.center, style: Fonts.title(42, p.ink)),
                        if (here != null)
                          Text('${Ar.n(here.lat.abs().toStringAsFixed(2)).replaceAll('.', '٫')} ${here.lat >= 0 ? 'شمالاً' : 'جنوباً'}، ${Ar.n(here.lon.abs().toStringAsFixed(2)).replaceAll('.', '٫')} ${here.lon >= 0 ? 'شرقاً' : 'غرباً'}',
                              style: Fonts.body(18, p.muted)),
                        const SizedBox(height: 22),
                        ActionRow([
                          Act('استخدم موقعي', () {
                            AppState.I.set('weather.auto', true);
                            WeatherHub.rev.value++;
                            Navigator.pop(context);
                          }, icon: Lu.navigation, primary: true),
                          Act('إعادة التحديد', _locate, icon: Lu.refresh),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// صف نتيجة بحث بسيط.
class SysRowLite extends StatelessWidget {
  final Object icon;
  final String title, sub;
  final VoidCallback onTap;
  const SysRowLite({super.key, required this.icon, required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    return FocusTap(
      onTap: onTap,
      builder: (_, f) => AnimatedContainer(
        duration: AppState.I.anim(140),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: f ? p.ring.withValues(alpha: 0.12) : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: f ? p.ring : p.line, width: f ? 2.5 : 1),
        ),
        child: Row(children: [
          AppIcon(icon, color: f ? p.ring : p.muted, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FitText(title, style: Fonts.body(23, p.ink, weight: FontWeight.w600)),
              if (sub.isNotEmpty) FitText(sub, style: Fonts.body(16, p.muted)),
            ]),
          ),
          AppIcon(Lu.plus, color: f ? p.ring : p.muted, size: 24),
        ]),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color ac, gold;
  final bool busy;
  _RadarPainter(this.t, this.ac, this.gold, this.busy);
  @override
  void paint(Canvas c, Size s) {
    final o = s.center(Offset.zero);
    final R = math.min(s.width, s.height) / 2 - 10;
    for (var k = 0; k < 4; k++) {
      final r = R * (1 - k * 0.25);
      c.drawCircle(o, r, Paint()..color = ac.withValues(alpha: 0.02 + k * 0.025));
      c.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = ac.withValues(alpha: 0.18 + k * 0.1));
    }
    final a = t * math.pi * 2;
    c.drawArc(Rect.fromCircle(center: o, radius: R), a - 0.7, 0.7, true,
        Paint()..shader = ui.Gradient.sweep(o, [ac.withValues(alpha: 0), ac.withValues(alpha: busy ? 0.5 : 0.35)], const [0, 1], TileMode.clamp, a - 0.7, a));
    for (final q in const [(0.55, 0.9), (0.75, 3.4), (0.42, 4.8)]) {
      final pp = o + Offset(math.cos(q.$2), math.sin(q.$2)) * R * q.$1;
      final pulse = (math.sin(t * math.pi * 2 + q.$2) + 1) / 2;
      c.drawCircle(pp, 10 + pulse * 6, Paint()..color = gold.withValues(alpha: 0.2 * (1 - pulse * 0.5)));
      c.drawCircle(pp, 5, Paint()..color = gold);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter o) => true;
}

// ═══════════════════ اختصارات: زر الواجهة، بلاطة التطبيق، شاشة السكون ═══════════════════

/// زر الطقس الحي بأعلى الواجهة: دائرة بمشهد حي صغير + الحرارة + الحالة.
class WeatherPill extends StatelessWidget {
  final bool onDark;
  const WeatherPill({super.key, required this.onDark});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final w = s.weather;
    if (w == null || !s.cfg.b('weather.homeChip')) return const SizedBox.shrink();
    final p = s.palette;
    return FocusTap(
      ensureVisible: false,
      onTap: () => Navigator.push(context, fade(const WeatherScreen())),
      builder: (_, f) {
        if (f) announceOption('الطقس: ${Ar.n(w.temp)}° ${w.description}', 'موافق يفتح شاشة الطقس');
        final fg = onDark ? Colors.white : p.ink;
        return AnimatedScale(
          scale: f ? 1.06 : 1,
          duration: s.anim(150),
          child: AnimatedContainer(
            duration: s.anim(150),
            height: 64,
            padding: const EdgeInsetsDirectional.only(start: 8, end: 20),
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withValues(alpha: 0.14) : p.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: f ? p.ring : (onDark ? Colors.white.withValues(alpha: 0.3) : p.line), width: f ? 3 : 1),
              boxShadow: f ? [BoxShadow(color: p.ring.withValues(alpha: 0.35), blurRadius: 22)] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(fit: StackFit.expand, children: [
                    WeatherSky(kind: w.sky, night: !w.isDay, compact: true, glass: false),
                    Center(child: WxIcon(wxIconName(w.sky, w.isDay), size: 28, night: true, mono: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              _deg(Ar.n(w.temp), Fonts.body(26, fg, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(w.description, style: Fonts.body(19, onDark ? Colors.white70 : p.muted)),
              const SizedBox(width: 10),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
            ]),
          ),
        );
      },
    );
  }
}

/// صورة بلاطة «الطقس» بالمفضلة: مشهد حي بحالة الجو + الحرارة.
class WeatherTileArt extends StatelessWidget {
  final double width, height;
  const WeatherTileArt({super.key, required this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    final w = AppState.I.weather;
    final night = w == null ? AppState.I.palette.night : !w.isDay;
    const light = Color(0xFFF4F7F4);
    final ink = night ? light : const Color(0xFF13201A);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        WeatherSky(kind: w?.sky ?? 'cloudy', night: night, compact: true),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.45, 1], colors: [Colors.transparent, (night ? Colors.black : Colors.white).withValues(alpha: 0.4)]),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(height * 0.1),
          child: w == null
              ? Center(child: AppIcon(Lu.cloudSun, color: ink, size: height * 0.36))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    WxIcon(wxIconName(w.sky, w.isDay), size: height * 0.22, night: night),
                    const Spacer(),
                    Flexible(child: FitText(w.place, style: Fonts.body(height * 0.1, ink.withValues(alpha: 0.85), weight: FontWeight.w500))),
                  ]),
                  const Spacer(),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: FitText(w.description, style: Fonts.body(height * 0.105, ink, weight: FontWeight.w500))),
                    _deg(Ar.n(w.temp), Fonts.body(height * 0.34, ink, weight: FontWeight.w300).copyWith(height: 1)),
                  ]),
                ]),
        ),
      ]),
    );
  }
}

/// ويدجت الطقس بشاشة السكون.
class WeatherSaverCard extends StatelessWidget {
  final Color ink, muted;
  const WeatherSaverCard({super.key, required this.ink, required this.muted});
  @override
  Widget build(BuildContext context) {
    final w = AppState.I.weather;
    if (w == null) return const SizedBox.shrink();
    final city = WeatherHub.cities.isEmpty ? null : WeatherHub.cities.first;
    final f = city == null ? null : WeatherHub.of(city);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 430,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ClipOval(
              child: SizedBox(
                width: 80,
                height: 80,
                child: Stack(fit: StackFit.expand, children: [
                  WeatherSky(kind: w.sky, night: !w.isDay, compact: true, glass: false),
                  Center(child: WxIcon(wxIconName(w.sky, w.isDay), size: 44, night: true, mono: Colors.white)),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            _deg(Ar.n(w.temp), Fonts.body(64, ink, weight: FontWeight.w300).copyWith(height: 1.1)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FitText(w.description, style: Fonts.body(22, ink, weight: FontWeight.w600)),
                FitText(w.place, style: Fonts.body(15, muted)),
              ]),
            ),
          ]),
          if (f != null && f.hours.length >= 5) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 10),
            Row(children: [
              for (final h in f.hours.skip(1).take(4))
                Expanded(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(wxHourLabel(h.t), style: Fonts.body(15, muted)),
                    const SizedBox(width: 6),
                    WxIcon(wxIconName(wxKind(h.code, null), h.day), size: 18, night: true),
                    const SizedBox(width: 6),
                    _deg(Ar.n(h.temp), Fonts.body(15, ink, weight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Row(mainAxisSize: MainAxisSize.min, children: [AppIcon(Lu.chevronDown, color: muted, size: 16), const SizedBox(width: 6), Text('أسفل: الطقس الكامل', style: Fonts.body(15, muted))]),
    ]);
  }
}
