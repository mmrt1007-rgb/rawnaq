import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';
import 'starfield.dart';
import 'state.dart';

/// الخلفيات الفنية المرسومة بالكود: حادة بأي دقة (حتى 4K) وتتلون مع الثيم.
class ArtStyles {
  static const all = [
    ('dunes', 'كثبان'),
    ('orbs', 'هالات'),
    ('stars', 'سماء الليل'),
    ('arches', 'أقواس'),
    ('geo', 'حلقات متشابكة'),
    ('waves', 'أمواج'),
  ];
}

/// خلفية كاملة الشاشة: لون، تدرج، فن، صورة، أو عرض صور متتابع.
class Backdrop extends StatelessWidget {
  final String kind; // stars | black | solid | gradient | art | image | slideshow
  final String art;
  final String image;
  final Color solid;
  final double dim;
  final bool kenBurns;
  final int interval;
  final Palette p;
  final ValueChanged<String>? onImage;

  const Backdrop({
    super.key,
    required this.kind,
    required this.p,
    this.art = 'dunes',
    this.image = '',
    this.solid = Colors.black,
    this.dim = 0.3,
    this.kenBurns = false,
    this.interval = 30,
    this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    Widget base;
    var useDim = false;
    switch (kind) {
      case 'stars':
        base = const Starfield();
      case 'aurora':
        base = CustomPaint(painter: AuroraPainter(p), child: const SizedBox.expand());
      case 'black':
        base = const ColoredBox(color: Colors.black);
      case 'solid':
        base = ColoredBox(color: solid);
      case 'gradient':
        base = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [p.bg, Color.lerp(p.bg, p.accent, p.night ? 0.30 : 0.22)!],
            ),
          ),
        );
      case 'image' when image.isNotEmpty && File(image).existsSync():
        base = WallpaperImage(path: image, kenBurns: kenBurns);
        useDim = true;
      case 'slideshow' when s.wallpapers.isNotEmpty:
        base = Slideshow(paths: s.wallpapers, interval: interval, kenBurns: kenBurns, onImage: onImage);
        useDim = true;
      default:
        base = CustomPaint(painter: ArtPainter(art, p), child: const SizedBox.expand());
    }
    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        base,
        if (useDim && dim > 0) ColoredBox(color: Colors.black.withValues(alpha: dim)),
      ]),
    );
  }
}

/// صورة خلفية تُفك بدقة الشاشة الفعلية بالضبط (لا أكبر ولا أصغر) لسرعة وذاكرة أقل.
class WallpaperImage extends StatefulWidget {
  final String path;
  final bool kenBurns;
  final Duration kenBurnsDuration;
  const WallpaperImage({super.key, required this.path, this.kenBurns = false, this.kenBurnsDuration = const Duration(seconds: 40)});

  static ImageProvider provider(BuildContext context, String path) {
    final mq = MediaQuery.of(context);
    final physical = (mq.size.width * mq.devicePixelRatio).round().clamp(640, 3840);
    return ResizeImage(FileImage(File(path)), width: physical, policy: ResizeImagePolicy.fit);
  }

  @override
  State<WallpaperImage> createState() => _WallpaperImageState();
}

class _WallpaperImageState extends State<WallpaperImage> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.kenBurnsDuration);
    if (widget.kenBurns && !AppState.I.cfg.b('misc.reduceMotion') && !AppState.I.lite) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image(
      image: WallpaperImage.provider(context, widget.path),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      width: double.infinity,
      height: double.infinity,
    );
    if (!widget.kenBurns) return img;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + 0.07 * Curves.easeInOut.transform(_c.value),
          alignment: Alignment(0.3 - 0.6 * _c.value, -0.2 + 0.4 * _c.value),
          child: child,
        ),
        child: img,
      ),
    );
  }
}

/// عرض صور متتابع بتلاشي ناعم، مع تحميل الصورة التالية مسبقاً.
class Slideshow extends StatefulWidget {
  final List<String> paths;
  final int interval;
  final bool kenBurns;
  final bool shuffle;
  final ValueChanged<String>? onImage;
  final ValueChanged<int>? onIndex;
  const Slideshow({super.key, required this.paths, required this.interval, this.kenBurns = true, this.shuffle = false, this.onImage, this.onIndex});

  @override
  State<Slideshow> createState() => _SlideshowState();
}

class _SlideshowState extends State<Slideshow> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _i = math.Random().nextInt(widget.paths.length);
    _t = Timer.periodic(Duration(seconds: widget.interval.clamp(5, 3600)), (_) => _next());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precache();
      widget.onImage?.call(widget.paths[_i % widget.paths.length]);
      widget.onIndex?.call(_i % widget.paths.length);
    });
  }

  /// الصورة الجاية: بالترتيب، أو عشوائية بدون ما تتكرر نفس الصورة مرتين ورا بعض.
  int get _nextIndex {
    final n = widget.paths.length;
    if (!widget.shuffle || n < 3) return (_i + 1) % n;
    var j = _rand.nextInt(n - 1);
    if (j >= _i % n) j++;
    return j;
  }

  final _rand = math.Random();
  int? _queued;

  void _precache() {
    if (!mounted || widget.paths.length < 2) return;
    _queued = _nextIndex;
    precacheImage(WallpaperImage.provider(context, widget.paths[_queued!]), context);
  }

  void _next() {
    if (!mounted || widget.paths.isEmpty) return;
    setState(() => _i = (_queued ?? _nextIndex) % widget.paths.length);
    widget.onImage?.call(widget.paths[_i]);
    widget.onIndex?.call(_i);
    _precache();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paths.isEmpty) return const SizedBox.shrink();
    final path = widget.paths[_i % widget.paths.length];
    return AnimatedSwitcher(
      duration: AppState.I.anim(1800),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
      child: WallpaperImage(
        key: ValueKey(path),
        path: path,
        kenBurns: widget.kenBurns,
        kenBurnsDuration: Duration(seconds: widget.interval.clamp(5, 3600) + 4),
      ),
    );
  }
}

/// رسام الخلفيات الفنية (تصاميم أصلية، تتلون بألوان الثيم).
class ArtPainter extends CustomPainter {
  final String kind;
  final Palette p;
  ArtPainter(this.kind, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);

    switch (kind) {
      case 'orbs':
        void orb(Offset c, double r, Color col, double a) {
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..shader = RadialGradient(colors: [col.withValues(alpha: a), col.withValues(alpha: 0)])
                  .createShader(Rect.fromCircle(center: c, radius: r)),
          );
        }
        orb(Offset(w * 0.15, h * 0.2), h * 0.75, p.accent, p.night ? 0.22 : 0.14);
        orb(Offset(w * 0.85, h * 0.85), h * 0.65, p.ring, p.night ? 0.16 : 0.12);
        orb(Offset(w * 0.55, h * 0.1), h * 0.45, p.ink, 0.05);

      case 'stars':
        final r = math.Random(42);
        final star = Paint();
        for (var i = 0; i < 260; i++) {
          final o = Offset(r.nextDouble() * w, r.nextDouble() * h);
          star.color = p.ink.withValues(alpha: 0.12 + r.nextDouble() * 0.5);
          canvas.drawCircle(o, 0.6 + r.nextDouble() * 1.8, star);
        }
        final c = Offset(w * 0.16, h * 0.24), rad = h * 0.11;
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: rad)),
          Path()..addOval(Rect.fromCircle(center: c + Offset(rad * 0.42, -rad * 0.22), radius: rad * 0.92)),
        );
        canvas.drawPath(moon, Paint()..color = p.ring.withValues(alpha: 0.9));

      case 'arches':
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.0018
          ..color = p.line.withValues(alpha: p.night ? 0.9 : 1);
        const n = 7;
        final aw = w / n, base = h * 0.98, top = h * 0.40;
        for (var i = 0; i < n; i++) {
          for (final inset in [0.0, aw * 0.08]) {
            final l = i * aw + aw * 0.08 + inset, rr = (i + 1) * aw - aw * 0.08 - inset;
            final mid = (l + rr) / 2, t = top + inset * 1.4;
            final path = Path()
              ..moveTo(l, base)
              ..lineTo(l, t + (rr - l) * 0.55)
              ..quadraticBezierTo(l, t + (rr - l) * 0.12, mid, t)
              ..quadraticBezierTo(rr, t + (rr - l) * 0.12, rr, t + (rr - l) * 0.55)
              ..lineTo(rr, base);
            canvas.drawPath(path, line);
          }
        }

      case 'geo':
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.0012
          ..color = p.line.withValues(alpha: p.night ? 0.8 : 0.9);
        // حلقات متشابكة بنقش هادئ (لغة شعار رونق)، بدل النجمة
        final step = h / 5.5, r = step * 0.5;
        var row = 0;
        for (var y = 0.0; y <= h + step; y += step * 0.866, row++) {
          for (var x = row.isOdd ? step / 2 : 0.0; x <= w + step; x += step) {
            canvas.drawCircle(Offset(x, y), r, line);
          }
        }

      case 'waves':
        final c = Offset(w * 1.05, h * 1.1);
        for (var i = 1; i <= 18; i++) {
          canvas.drawCircle(
            c,
            h * 0.12 * i,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = h * 0.0016
              ..color = p.accent.withValues(alpha: (0.30 - i * 0.014).clamp(0.04, 0.3)),
          );
        }

      default: // dunes
        for (var i = 0; i < 4; i++) {
          final y = h * (0.58 + i * 0.11);
          final path = Path()
            ..moveTo(0, y)
            ..cubicTo(w * 0.25, y - h * (0.12 - i * 0.02), w * 0.55, y + h * 0.08, w, y - h * (0.06 + i * 0.015))
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close();
          canvas.drawPath(path, Paint()..color = Color.lerp(p.bg, p.accent, 0.05 + i * 0.06)!);
        }
        canvas.drawCircle(
          Offset(w * 0.14, h * 0.2),
          h * 0.12,
          Paint()..color = Color.lerp(p.bg, p.ring, p.night ? 0.85 : 0.35)!,
        );
    }
  }

  @override
  bool shouldRepaint(ArtPainter old) =>
      old.kind != kind || old.p.bg != p.bg || old.p.accent != p.accent || old.p.ring != p.ring || old.p.line != p.line || old.p.ink != p.ink;
}

// ═══════════════════ صور الواجهة المتغيرة ═══════════════════
//  فيكما صفحة ١٦: ١٥ (الإعدادات والمعاينة) · ١٦ (اختيار الصور) · ١٧ (بكل الثيمات).
//  الصور نفسها تبقى لما يتغير الثيم؛ الثيم يتحكم بالطبقة اللي فوقها بس.

class HomeSlides {
  static final index = ValueNotifier<int>(0);
  static String _name(String path) => path.split('/').last;

  static bool _auto(String path) => _name(path).startsWith('auto-');
  static String _cat(String path) => _name(path).split('-').elementAtOrNull(1) ?? '';

  /// الصور حسب المصدر: كل الصور، مكتبة رونق (تتجدد وحدها حتى ١٠٠ صورة)، صوري، أو اللي أختارها.
  /// صور المكتبة الجديدة تنضاف وحدها لما تتجدد، بدون ما تسوي شي.
  static List<String> paths() {
    final s = AppState.I;
    final c = s.cfg;
    final walls = s.wallpapers;
    switch (c.s('home.slides.source')) {
      case 'library':
        final cats = c.s('home.slides.cats').split(',').where((e) => e.isNotEmpty).toSet();
        return [for (final p in walls) if (_auto(p) && (cats.isEmpty || cats.contains(_cat(p)))) p];
      case 'mine':
        return [for (final p in walls) if (!_auto(p)) p];
      case 'pick':
        final set = c.s('home.slides.set');
        if (set == 'none') return const [];
        if (set.isEmpty) return walls;
        final names = set.split('|').toSet();
        return [for (final p in walls) if (names.contains(_name(p))) p];
      default:
        return walls;
    }
  }

  static bool get active => AppState.I.cfg.b('home.slides') && paths().isNotEmpty;

  static bool isOn(String path) => paths().contains(path);

  /// التحديد اليدوي يحوّل المصدر لـ «أختارها».
  static void toggle(String path) {
    final all = AppState.I.wallpapers;
    final on = paths().toSet();
    if (!on.remove(path)) on.add(path);
    _save([for (final p in all) if (on.contains(p)) p], all.length);
  }

  static void setAll(bool on) {
    AppState.I.set('home.slides.set', on ? '' : 'none');
    AppState.I.set('home.slides.source', on ? 'all' : 'pick');
  }

  static void _save(List<String> picked, int total) {
    final v = picked.isEmpty ? 'none' : (picked.length == total ? '' : picked.map(_name).join('|'));
    AppState.I.set('home.slides.set', v);
    AppState.I.set('home.slides.source', 'pick');
  }

  /// عدد صور المكتبة لكل فئة (للشاشة).
  static int countIn(String cat) => AppState.I.wallpapers.where((p) => _auto(p) && _cat(p) == cat).length;
}

/// الصور المتغيرة مع طبقة الثيم: لون خلفية الثيم بتدرج، أخف بالنص وأقوى تحت عند التطبيقات.
class HomeSlidesBackdrop extends StatelessWidget {
  final List<String>? paths;
  const HomeSlidesBackdrop({super.key, this.paths});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final list = paths ?? HomeSlides.paths();
    if (list.isEmpty) return ColoredBox(color: s.palette.bg);
    final dim = c.d('home.slides.dim').clamp(0.0, 0.9);
    final tint = c.b('home.slides.tint') ? s.palette.bg : Colors.black;
    final interval = c.i('home.slides.interval');
    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        Slideshow(
          key: ValueKey('${list.length}:${list.first}:$interval:${c.b('home.slides.shuffle')}'),
          paths: list,
          interval: interval,
          kenBurns: c.s('home.slides.motion') == 'kenburns',
          shuffle: c.b('home.slides.shuffle'),
          onIndex: (i) => HomeSlides.index.value = i,
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tint.withValues(alpha: math.min(0.9, dim * 1.45)),
                  tint.withValues(alpha: dim * 0.9),
                  tint.withValues(alpha: math.min(0.92, dim * 2.4)),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// خلفية الواجهة (وخلف شاشات الإعدادات بنمط الزجاج).
/// بنمط الزجاج إذا الخلفية لون سادة نستخدم الهالات، لأن الزجاج يحتاج شي وراه حتى يبان.
Widget homeBackdrop() {
  final s = AppState.I;
  final c = s.cfg;
  final p = s.palette;
  // الصور المتغيرة فوق أي ثيم (إذا مفعّلة وبيها صور)
  if (HomeSlides.active) return const HomeSlidesBackdrop();
  var kind = c.s('home.bg');
  var art = c.s('home.art');
  if (p.glass && kind == 'solid') {
    kind = 'art';
    art = 'orbs';
  }
  return Backdrop(kind: kind, art: art, image: c.s('home.image'), dim: c.d('home.dim'), solid: p.bg, p: p);
}


/// «أورورا»: ثلاث هالات ضوء ناعمة بألوان الثيم — تُرسم مرة وحدة (بدون صور ولا تغبيش)، فخفيفة جداً.
class AuroraPainter extends CustomPainter {
  final Palette p;
  const AuroraPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);
    void glow(Offset c, double r, Color col, double a) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(colors: [col.withValues(alpha: a), col.withValues(alpha: 0)], stops: const [0, 1]).createShader(rect),
      );
    }

    final w = size.width, h = size.height;
    final n = p.night;
    glow(Offset(w * 0.88, h * 0.08), w * 0.42, n ? Color.lerp(p.accent, Colors.black, 0.35)! : Color.lerp(p.bg, p.accent, 0.35)!, n ? 0.55 : 0.75);
    glow(Offset(w * 0.08, h * 0.95), w * 0.36, n ? Color.lerp(p.ring, Colors.black, 0.4)! : Color.lerp(p.bg, p.ring, 0.45)!, n ? 0.35 : 0.65);
    glow(Offset(w * 0.30, h * 0.40), w * 0.30, n ? const Color(0xFF2F4E7E) : const Color(0xFFD6E0EA), n ? 0.28 : 0.6);
  }

  @override
  bool shouldRepaint(AuroraPainter old) => old.p.bg != p.bg || old.p.accent != p.accent || old.p.ring != p.ring || old.p.night != p.night;
}
