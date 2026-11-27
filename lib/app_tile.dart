import 'package:flutter/material.dart';

import 'state.dart';
import 'widgets.dart';
import 'lucide.dart';

/// قياسات مربع التطبيق المحسوبة من الإعدادات — مصدر واحد لكل المسافات.
class TileMetrics {
  final double width; // عرض الصورة
  final String style;
  final double radius, focusScale, ring, labelSize;
  final String labels;
  final bool onDark; // الأسماء فوق خلفية غامقة (الستايل السينمائي)

  TileMetrics(this.width, {this.onDark = false, String? labels, String? style})
      : style = style ?? AppState.I.cfg.s('tile.style'),
        radius = AppState.I.cfg.d('tile.radius'),
        focusScale = _scaleFor(AppState.I.cfg.d('tile.focusScale')),
        ring = _ringFor(AppState.I.cfg.d('tile.ringWidth') + (AppState.I.cfg.b('a11y.thickRing') ? 2.5 : 0)),
        labelSize = AppState.I.cfg.d('tile.labelSize'),
        labels = labels ?? AppState.I.cfg.s('tile.labels');

  /// حركة التركيز من إعدادات الريموت: بدون = ما يكبر، ناعمة = تكبير بسيط، كاملة = حسب الإعداد.
  static double _scaleFor(double v) => switch (AppState.I.cfg.s('remote.motion')) {
        'none' => 1.0,
        'soft' => v > 1.05 ? 1.05 : v,
        _ => v,
      };

  /// إطار التركيز: رفيع = ٢ بكسل، ذهبي وتوهج = حسب الإعداد.
  static double _ringFor(double v) => AppState.I.cfg.s('remote.ring') == 'thin' && v > 2 ? 2 : v;

  double get artHeight => style == 'banner' ? width * 9 / 16 : width;

  /// ارتفاع منطقة الاسم (محجوزة حتى لو الاسم يظهر عند التركيز فقط، فلا تزحف العناصر).
  double get labelHeight => labels == 'none' ? 0 : labelSize * Fonts.scale * 1.55 + 24;

  double get totalHeight => artHeight + labelHeight;

  /// المسافة اللازمة حول المربع حتى لا يُقص عند التكبير والإطار والظل.
  double get bleed {
    final c = AppState.I.cfg;
    final fx = c.s('tile.focus');
    final sc = fx == 'zoom' && focusScale < 1.16 ? 1.16 : focusScale;
    return width * (sc - 1) / 2 +
        ring +
        14 +
        (fx == 'lift' ? artHeight * 0.07 : 0) +
        (fx == 'glow' ? 24 : 0) +
        (c.s('motion.style') == 'spring' ? width * 0.015 : 0); // ارتداد "نابضة" يتجاوز التكبير قليلاً
  }

  /// نسبة ارتفاع الصورة للعرض حسب النمط.
  static double ratioFor(String style) => style == 'banner' ? 9 / 16 : 1;
}

/// صورة التطبيق الرسمية حسب النمط.
class AppArtView extends StatelessWidget {
  final String package;
  final TileMetrics m;
  const AppArtView({super.key, required this.package, required this.m});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final art = s.artOf(package);
    final mode = s.artModeOf(package);
    final w = m.width, h = m.artHeight;

    final bannerFill = m.style == 'banner' && art?.banner != null && mode != ArtMode.icon;
    if (bannerFill) {
      return Image.memory(
        art!.banner!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: (w * MediaQuery.devicePixelRatioOf(context) * m.focusScale).round(),
      );
    }

    final useBanner = mode == ArtMode.banner && art?.banner != null;
    final iconSize = (m.style == 'banner' ? h * 0.62 : w * 0.66);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: w,
      height: h,
      color: p.surface,
      alignment: Alignment.center,
      child: useBanner
          ? Image.memory(art!.banner!, width: w * 0.9, fit: BoxFit.contain, gaplessPlayback: true)
          : art?.icon != null
              ? Image.memory(
                  art!.icon!,
                  width: iconSize,
                  height: iconSize,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (iconSize * dpr * m.focusScale).round(),
                )
              : Text(s.labelOf(package).characters.first, style: Fonts.title(iconSize * 0.5, p.muted)),
    );
  }
}

/// مربع تطبيق: يكبر ويتأطر عند التركيز، والاسم تحته.
class AppTile extends StatelessWidget {
  final String package;
  final TileMetrics m;
  final bool focused;
  final bool moving;
  final bool selected;

  const AppTile({super.key, required this.package, required this.m, required this.focused, this.moving = false, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return TileFrame(
      m: m,
      focused: focused,
      moving: moving,
      selected: selected,
      locked: s.locked.contains(package),
      label: s.labelOf(package),
      child: AppArtView(package: package, m: m),
    );
  }
}

/// الإطار المشترك لكل مربع (تطبيق، إضافة، كل التطبيقات).
class TileFrame extends StatelessWidget {
  final TileMetrics m;
  final bool focused, moving, selected, locked;
  final String label;
  final Widget child;
  final bool dashed;

  const TileFrame({
    super.key,
    required this.m,
    required this.focused,
    required this.label,
    required this.child,
    this.moving = false,
    this.selected = false,
    this.locked = false,
    this.dashed = false,
  });

  /// شكل المربع من إعداد "شكل الأيقونات" (فيكما: الأيقونات والمربعات).
  static OutlinedBorder shapeFor(TileMetrics m) => border(AppState.I.cfg.s('tile.shape'), m.style, m.width, m.artHeight, m.radius);

  static OutlinedBorder border(String shapeId, String style, double w, double h, double radius) {
    final m = (radius: radius);
    if (style == 'circle') return const CircleBorder();
    return switch (shapeId) {
      'sharp' => RoundedRectangleBorder(borderRadius: BorderRadius.circular(w * 0.03 < 4 ? 4 : w * 0.03)),
      'squircle' => ContinuousRectangleBorder(borderRadius: BorderRadius.circular((w < h ? w : h) * 0.55)),
      'circle' => h == w ? const CircleBorder() : const StadiumBorder(),
      'pill' => const StadiumBorder(),
      // المحراب: قوس علوي كامل وقاعدة شبه مستقيمة
      'arch' => RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular((w < h ? w : h) * 0.5),
            bottom: Radius.circular((w < h ? w : h) * 0.1),
          ),
        ),
      // ثُمانية: زوايا مشطوفة واسعة مثل النجمة الإسلامية
      'octagon' => BeveledRectangleBorder(borderRadius: BorderRadius.circular((w < h ? w : h) * 0.3)),
      // مشطوفة: شطف صغير أنيق
      'cut' => BeveledRectangleBorder(borderRadius: BorderRadius.circular((w < h ? w : h) * 0.18)),
      'leaf' => RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular((w < h ? w : h) * 0.08),
            topRight: Radius.circular((w < h ? w : h) * 0.42),
            bottomLeft: Radius.circular((w < h ? w : h) * 0.42),
            bottomRight: Radius.circular((w < h ? w : h) * 0.08),
          ),
        ),
      _ => RoundedRectangleBorder(borderRadius: BorderRadius.circular(m.radius)),
    };
  }

  /// خلفية الأيقونة: الأصلية، هادئة (ألوان أخف)، أو أحادية ذهبية.
  static Widget tint(Widget child, [String? bg]) => switch (bg ?? AppState.I.cfg.s('tile.bg')) {
        'soft' => ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.66, 0.30, 0.04, 0, 0, //
              0.10, 0.86, 0.04, 0, 0,
              0.10, 0.30, 0.60, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: child,
          ),
        'mono' => ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.30, 0.59, 0.11, 0, 6, //
              0.25, 0.50, 0.09, 0, 2,
              0.16, 0.33, 0.06, 0, -6,
              0, 0, 0, 1, 0,
            ]),
            child: child,
          ),
        _ => child,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final shape = shapeFor(m);
    final fx = s.cfg.s('tile.focus');
    final ring = focused && m.ring > 0 && fx == 'ring';
    final scale = !focused
        ? 1.0
        : switch (fx) {
            'glow' => m.focusScale < 1.06 ? m.focusScale : 1.06,
            'lift' => m.focusScale < 1.04 ? m.focusScale : 1.04,
            'zoom' => m.focusScale > 1.16 ? m.focusScale : 1.16,
            _ => m.focusScale,
          };
    final showLabel = m.labels == 'all' || (m.labels == 'focus' && focused);

    return SizedBox(
      width: m.width,
      height: m.totalHeight,
      child: Column(children: [
        AnimatedSlide(
          offset: moving ? const Offset(0, -0.10) : (focused && fx == 'lift' ? const Offset(0, -0.07) : Offset.zero),
          duration: s.anim(200),
          curve: s.curve,
          child: AnimatedScale(
            scale: scale,
            duration: s.anim(200),
            curve: s.curve,
            child: Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: s.anim(200),
                width: m.width,
                height: m.artHeight,
                foregroundDecoration: ShapeDecoration(
                  shape: shape.copyWith(
                    // ٤٫٠: المربع العادي بخط شعري يفصله عن الخلفية (تباين حقيقي حتى للأيقونات الفاتحة)،
                    // والمحدد بإطار ذهبي
                    side: BorderSide(
                      color: ring ? p.ring : (dashed ? p.line : (m.onDark ? Colors.white.withValues(alpha: 0.14) : p.line.withValues(alpha: 0.9))),
                      width: ring ? m.ring : (dashed ? 2 : 1),
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                ),
                decoration: ShapeDecoration(
                  shape: shape,
                  shadows: [
                    if (focused && (s.cfg.b('tile.shadow') || fx == 'lift'))
                      BoxShadow(
                        color: Colors.black.withValues(alpha: p.night ? (fx == 'lift' ? 0.6 : 0.45) : 0.25),
                        blurRadius: fx == 'lift' ? 46 : 34,
                        offset: Offset(0, fx == 'lift' ? 26 : 16),
                      ),
                    // توهج ذهبي حول المربع (هادئ بالإطار الذهبي، أقوى بالتوهج)
                    if (focused && (fx == 'glow' || s.cfg.s('remote.ring') == 'glow'))
                      BoxShadow(color: p.ring.withValues(alpha: 0.6), blurRadius: 32, spreadRadius: 2)
                    else if (focused && s.cfg.s('remote.ring') == 'gold')
                      BoxShadow(color: p.ring.withValues(alpha: 0.32), blurRadius: 26, spreadRadius: 1),
                  ],
                ),
                child: ClipPath(
                  clipper: ShapeBorderClipper(shape: shape, textDirection: Directionality.maybeOf(context)),
                  child: Stack(fit: StackFit.passthrough, children: [
                    RepaintBoundary(child: tint(child)),
                    if (s.cfg.b('tile.glint') && s.cfg.s('remote.motion') == 'full') Positioned.fill(child: Glint(active: focused)),
                  ]),
                ),
              ),
              if (locked) PositionedDirectional(top: -12, end: -12, child: _badge(Lu.lock, p.ink, p.surface)),
              if (selected) PositionedDirectional(top: -14, end: -14, child: _badge(Lu.check, p.onAccent, p.accent)),
              if (moving) ...[
                PositionedDirectional(start: -52, top: m.artHeight / 2 - 22, child: AppIcon(Lu.chevronRight, color: p.ring, size: 44)),
                PositionedDirectional(end: -52, top: m.artHeight / 2 - 22, child: AppIcon(Lu.chevronLeft, color: p.ring, size: 44)),
              ],
            ]),
          ),
        ),
        if (m.labels != 'none')
          SizedBox(
            height: m.labelHeight,
            width: m.width * m.focusScale,
            child: AnimatedOpacity(
              opacity: showLabel ? 1 : 0,
              duration: s.anim(160),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: FitText(
                    label,
                    alignment: Alignment.center,
                    style: Fonts.body(m.labelSize, m.onDark ? Colors.white : (focused ? p.ink : p.muted), weight: focused ? FontWeight.w600 : null)
                        .copyWith(shadows: m.onDark ? const [Shadow(color: Color(0x99000000), blurRadius: 16)] : null),
                  ),
                ),
                // خط ذهبي صغير تحت اسم المحدد (فيكما صفحة ١٧)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: s.anim(220),
                      width: focused ? 28 : 0,
                      height: 3,
                      decoration: BoxDecoration(color: p.ring, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _badge(Object icon, Color fg, Color bg) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: pal.bg, width: 4)),
        child: AppIcon(icon, color: fg, size: 22),
      );
}

/// مربع "إضافة" أو "كل التطبيقات".
class ActionArt extends StatelessWidget {
  final Object icon;
  final TileMetrics m;
  final bool focused;
  final bool dashed;
  const ActionArt({super.key, required this.icon, required this.m, required this.focused, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      width: m.width,
      height: m.artHeight,
      color: dashed ? p.bg.withValues(alpha: 0.4) : p.surface,
      alignment: Alignment.center,
      child: AppIcon(icon, color: focused ? p.ink : p.muted, size: m.artHeight * 0.36),
    );
  }
}


/// لمعة ضوء تمر على المربع لحظة التركيز، ثم توهج خفيف جداً يتنفس.
class Glint extends StatefulWidget {
  final bool active;
  const Glint({super.key, required this.active});

  @override
  State<Glint> createState() => _GlintState();
}

class _GlintState extends State<Glint> with TickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  void _start() {
    if (AppState.I.cfg.b('misc.reduceMotion')) return;
    _sweep.forward(from: 0);
    if (!AppState.I.lite) _breath.forward(from: 0);
  }

  @override
  void didUpdateWidget(Glint old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _start();
    if (!widget.active && old.active) {
      _sweep.stop();
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_sweep, _breath]),
        builder: (_, __) {
          final t = Curves.easeInOutCubic.transform(_sweep.value);
          final x = -1.6 + 3.2 * t;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(x - 0.6, -1),
                end: Alignment(x + 0.6, 1),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: _sweep.isAnimating ? 0.28 : 0),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.06 + 0.06 * _breath.value), Colors.white.withValues(alpha: 0)],
                  stops: const [0, 0.55],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
