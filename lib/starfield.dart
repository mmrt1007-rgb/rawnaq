import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'state.dart';

/// ألوان السماء — نفس لوحات فيكما (زمردي، ذهبي ليلي، فضي، فجر).
class SkyPalette {
  final String id, name;
  final Color mid, deep, warm, cool;
  final double warmRatio;
  final List<Color> nebula;
  const SkyPalette(this.id, this.name, this.mid, this.deep, this.warm, this.cool, this.warmRatio, this.nebula);

  static const all = [
    SkyPalette('emerald', 'زمردي', Color(0xFF0E3226), Color(0xFF020806), Color(0xFFE6C877), Color(0xFFDDF3EA), 0.18,
        [Color(0xFF1F7A5A), Color(0xFFA87A2E), Color(0xFF3DBE8C)]),
    SkyPalette('gold', 'ذهبي ليلي', Color(0xFF101A3A), Color(0xFF03050D), Color(0xFFF1D48A), Color(0xFFE8ECFF), 0.35,
        [Color(0xFF2F4E9E), Color(0xFF7A4FA0), Color(0xFFC9A24A)]),
    SkyPalette('silver', 'فضي', Color(0xFF1A2230), Color(0xFF05070A), Color(0xFFE8ECFF), Color(0xFFFFFFFF), 0.10,
        [Color(0xFF3A4A66), Color(0xFF556070), Color(0xFF2A3550)]),
    SkyPalette('dawn', 'فجر', Color(0xFF3A2A4A), Color(0xFF0D0812), Color(0xFFF2B38A), Color(0xFFFFE9DA), 0.40,
        [Color(0xFF8E4A6E), Color(0xFFE8A87C), Color(0xFF4A3A7A)]),
  ];

  /// ٥٫١: سماء بألوان الثيم الحالي (الليلي): عمق الخلفية، نجوم دافئة بلون الإطار الذهبي، وسديم بلون التمييز.
  static SkyPalette theme() {
    final c = AppState.I.cfg;
    Color k(String x) => c.c('night.$x');
    const black = Color(0xFF000000);
    final bg = k('bg'), sf = k('surface'), ac = k('accent'), ring = k('ring'), ink = k('ink');
    return SkyPalette('theme', 'ألوان الثيم', Color.lerp(sf, ac, 0.16)!, Color.lerp(bg, black, 0.55)!, ring, Color.lerp(ink, ac, 0.12)!, 0.28,
        [Color.lerp(ac, bg, 0.25)!, ring, ac]);
  }

  static List<SkyPalette> get choices => [theme(), ...all];

  static SkyPalette of(String id) => id == 'theme' ? theme() : all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// نجمة واحدة: مكانها نسبي (٠–١) حتى تشتغل على أي دقة شاشة.
class _Star {
  double x, y;
  final double size, alpha, phase, freq;
  final int layer; // ٠ بعيدة، ١ وسطى، ٢ قريبة
  final bool warm, bright;
  _Star(this.x, this.y, this.size, this.alpha, this.phase, this.freq, this.layer, this.warm, this.bright);
}

/// سماء نجوم متحركة: ثلاث طبقات عمق تنجرف بسرعات مختلفة (إحساس بالعمق)،
/// تلألؤ ناعم لكل نجمة، نجوم ساطعة بوهج متقاطع، شهب نادرة، وسديم هادئ ثابت.
///
/// الأداء: الخلفية والسديم يُرسمان مرة وحدة ويُخزّنان (RepaintBoundary)،
/// والنجوم ترسم بدوائر بسيطة بدون تغبيش. بالوضع الخفيف: ٣٠ إطار/ث ونجوم أقل وبدون وهج.
class Starfield extends StatefulWidget {
  final bool preview; // للمعاينة المصغرة: نفس الحركة بنجوم أقل
  const Starfield({super.key, this.preview = false});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  final _rand = math.Random(7);
  List<_Star> _stars = const [];
  String _sig = '';
  Duration _lastTick = Duration.zero;
  double _nextShoot = 8;
  _Shoot? _shoot;

  AppState get s => AppState.I;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final lite = s.lite || s.cfg.b('misc.reduceMotion');
    // بالوضع الخفيف: نصف عدد الإطارات يكفي لحركة هادئة بهالبطء
    if (lite && (now - _lastTick).inMilliseconds < 32) return;
    final dt = ((now - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = now;
    final t = _time.value + dt;

    // انجراف الطبقات
    final speed = s.cfg.d('saver.stars.speed');
    final base = 0.004 + 0.03 * speed; // نسبة من عرض الشاشة بالثانية
    for (final st in _stars) {
      final f = const [0.2, 0.5, 1.0][st.layer];
      st.x -= base * f * dt;
      st.y -= base * f * dt * 0.28;
      if (st.x < -0.02) st.x += 1.04;
      if (st.y < -0.02) st.y += 1.04;
    }

    // الشهب
    final every = s.cfg.i('saver.stars.shooting');
    if (every > 0 && !lite) {
      if (_shoot == null && t > _nextShoot) {
        _shoot = _Shoot(0.35 + _rand.nextDouble() * 0.6, 0.05 + _rand.nextDouble() * 0.3, t);
        _nextShoot = t + every * (0.6 + _rand.nextDouble() * 0.8);
      }
      if (_shoot != null && t - _shoot!.start > _Shoot.life) _shoot = null;
    } else {
      _shoot = null;
    }
    _time.value = t;
  }

  void _build(int count, int layers) {
    final pal = SkyPalette.of(s.cfg.s('saver.stars.palette'));
    final shares = layers >= 3 ? const [0.62, 0.29, 0.09] : (layers == 2 ? const [0.7, 0.3, 0.0] : const [1.0, 0.0, 0.0]);
    const sizes = [(0.8, 1.6), (1.6, 2.6), (2.6, 4.0)];
    const alphas = [(0.25, 0.55), (0.45, 0.8), (0.7, 1.0)];
    final list = <_Star>[];
    for (var layer = 0; layer < 3; layer++) {
      final n = (count * shares[layer]).round();
      for (var i = 0; i < n; i++) {
        final sz = sizes[layer].$1 + (sizes[layer].$2 - sizes[layer].$1) * _rand.nextDouble();
        final a = alphas[layer].$1 + (alphas[layer].$2 - alphas[layer].$1) * _rand.nextDouble();
        list.add(_Star(_rand.nextDouble(), _rand.nextDouble(), sz, a, _rand.nextDouble() * math.pi * 2,
            0.4 + _rand.nextDouble() * 1.4, layer, _rand.nextDouble() < pal.warmRatio, false));
      }
    }
    // نجوم ساطعة قليلة بوهج متقاطع
    for (var i = 0; i < (layers >= 2 ? 4 : 2); i++) {
      list.add(_Star(_rand.nextDouble(), _rand.nextDouble() * 0.6, 4 + _rand.nextDouble() * 2, 1, _rand.nextDouble() * 6, 0.25, 2, true, true));
    }
    _stars = list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final c = s.cfg;
        final lite = s.lite;
        var count = c.i('saver.stars.density').clamp(60, 600).toInt();
        if (lite) count = (count * 0.6).round();
        if (widget.preview) count = (count * 0.7).round();
        final layers = c.i('saver.stars.layers').clamp(1, 3).toInt();
        final sig = '$count|$layers|${c.s('saver.stars.palette')}|${c.i('night.accent')}|${c.i('night.ring')}';
        if (sig != _sig) {
          _sig = sig;
          _build(count, layers);
        }
        final pal = SkyPalette.of(c.s('saver.stars.palette'));
        return Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: CustomPaint(painter: _SkyPainter(pal, c.d('saver.stars.nebula')))),
          RepaintBoundary(
            child: CustomPaint(
              painter: _StarPainter(
                stars: _stars,
                time: _time,
                pal: pal,
                twinkle: c.d('saver.stars.twinkle'),
                glow: !lite,
                shoot: () => _shoot,
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _Shoot {
  static const life = 1.2;
  final double x, y, start;
  _Shoot(this.x, this.y, this.start);
}

/// الخلفية: تدرج شعاعي + سديم ناعم. تُرسم مرة وحدة (ما تتغير مع الوقت).
class _SkyPainter extends CustomPainter {
  final SkyPalette pal;
  final double nebula;
  const _SkyPainter(this.pal, this.nebula);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.35),
          size.longestSide * 0.75,
          [pal.mid, pal.deep],
        ),
    );
    if (nebula > 0) {
      final blobs = [
        (0.27, 0.28, 0.47, 0.39, pal.nebula[0], 1.1),
        (0.77, 0.48, 0.40, 0.35, pal.nebula[1], 0.5),
        (0.51, 0.15, 0.31, 0.24, pal.nebula[2], 0.4),
      ];
      for (final (cx, cy, w, h, col, k) in blobs) {
        final r = Rect.fromCenter(center: Offset(size.width * cx, size.height * cy), width: size.width * w, height: size.height * h);
        canvas.drawOval(
          r,
          Paint()
            ..color = col.withValues(alpha: (nebula * k).clamp(0.0, 0.6))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.07),
        );
      }
    }
    // تظليل سفلي يضمن وضوح الساعة والنص
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.52, size.width, size.height * 0.48),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.52),
          Offset(0, size.height),
          [pal.deep.withValues(alpha: 0), pal.deep.withValues(alpha: 0.75)],
        ),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.pal.id != pal.id || old.nebula != nebula;
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final ValueNotifier<double> time;
  final SkyPalette pal;
  final double twinkle;
  final bool glow;
  final _Shoot? Function() shoot;

  _StarPainter({required this.stars, required this.time, required this.pal, required this.twinkle, required this.glow, required this.shoot})
      : super(repaint: time);

  final _p = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final scale = size.width / 1920; // الأحجام مصممة على 1920
    for (final st in stars) {
      final tw = 1 - twinkle * 0.55 * (0.5 + 0.5 * math.sin(t * st.freq + st.phase));
      final a = (st.alpha * tw).clamp(0.0, 1.0);
      final col = st.warm ? pal.warm : pal.cool;
      final o = Offset(st.x * size.width, st.y * size.height);
      final r = st.size * scale / 2;
      if (st.bright) {
        // نجمة ساطعة: قلب أبيض + هالة + وهج متقاطع يتنفس ببطء
        final breath = 0.75 + 0.25 * math.sin(t * 0.6 + st.phase);
        if (glow) {
          _p.color = col.withValues(alpha: 0.16 * breath);
          canvas.drawCircle(o, r * 5, _p);
        }
        final len = r * 9 * breath;
        final line = Paint()
          ..strokeWidth = 1.2 * scale
          ..shader = ui.Gradient.linear(o - Offset(len, 0), o + Offset(len, 0),
              [const Color(0x00FFFFFF), Color.fromRGBO(255, 255, 255, 0.85 * breath), const Color(0x00FFFFFF)], const [0, 0.5, 1]);
        canvas.drawLine(o - Offset(len, 0), o + Offset(len, 0), line);
        line.shader = ui.Gradient.linear(o - Offset(0, len), o + Offset(0, len),
            [const Color(0x00FFFFFF), Color.fromRGBO(255, 255, 255, 0.85 * breath), const Color(0x00FFFFFF)], const [0, 0.5, 1]);
        canvas.drawLine(o - Offset(0, len), o + Offset(0, len), line);
        _p.color = const Color(0xFFFFFFFF);
        canvas.drawCircle(o, r, _p);
        continue;
      }
      if (glow && st.layer == 2) {
        _p.color = col.withValues(alpha: a * 0.22);
        canvas.drawCircle(o, r * 2.6, _p);
      }
      _p.color = col.withValues(alpha: a);
      canvas.drawCircle(o, r, _p);
    }

    final sh = shoot();
    if (sh != null) {
      final k = ((t - sh.start) / _Shoot.life).clamp(0.0, 1.0);
      final fade = math.sin(k * math.pi); // يظهر ويختفي بنعومة
      final dir = Offset(-math.cos(0.42), math.sin(0.42));
      final head = Offset(sh.x * size.width, sh.y * size.height) + dir * (k * size.width * 0.32);
      final tail = head - dir * (size.width * 0.17);
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 2 * scale
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, head, [const Color(0x00FFFFFF), Color.fromRGBO(255, 255, 255, 0.95 * fade)]),
      );
      _p.color = pal.warm.withValues(alpha: 0.5 * fade);
      canvas.drawCircle(head, 3 * scale, _p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.stars != stars || old.pal.id != pal.id || old.twinkle != twinkle || old.glow != glow;
}
