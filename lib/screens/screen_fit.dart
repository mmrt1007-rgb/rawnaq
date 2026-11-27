import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arabic.dart';
import '../lucide.dart';
import '../state.dart';
import '../widgets.dart';

// ═══════════════════ مطابقة الشاشة ═══════════════════
//  فيكما صفحة ١٦ #١٨ «مطابقة الشاشة»: يكشف دقة الشاشة وكثافتها وحدودها الفعلية
//  ويرسم إطار معايرة على حواف اللوحة نفسها — ◀ ▶ للهامش، ▲ ▼ لحجم الواجهة.

/// معلومات الشاشة الفعلية كما يشوفها النظام.
class ScreenFacts {
  final Size physical; // بكسل حقيقي
  final double dpr;
  final double hz;
  const ScreenFacts(this.physical, this.dpr, this.hz);

  static ScreenFacts of(BuildContext context) {
    final v = View.of(context);
    double hz = 60;
    try {
      hz = v.display.refreshRate;
    } catch (_) {}
    return ScreenFacts(v.physicalSize, v.devicePixelRatio, hz);
  }

  Size get logical => physical / dpr;
  int get dpi => (dpr * 160).round();

  String get name {
    final h = math.min(physical.width, physical.height);
    if (h >= 2100) return '4K UHD';
    if (h >= 1400) return 'QHD';
    if (h >= 1000) return 'Full HD';
    if (h >= 700) return 'HD';
    return 'SD';
  }

  /// نسبة العرض للارتفاع بأقرب صيغة معروفة.
  String get ratio {
    final r = physical.width / physical.height;
    const known = [(16 / 9, '16:9'), (16 / 10, '16:10'), (21 / 9, '21:9'), (4 / 3, '4:3'), (32 / 9, '32:9')];
    var best = known.first;
    for (final k in known) {
      if ((k.$1 - r).abs() < (best.$1 - r).abs()) best = k;
    }
    return best.$2;
  }
}

/// حجم لوحة التصميم لكل خيار — نفس منطق DesignCanvas بالضبط.
double designWidthFor(String scale) => switch (scale) { 'small' => 2112.0, 'large' => 1760.0, _ => 1920.0 };

class ScreenFitScreen extends StatefulWidget {
  const ScreenFitScreen({super.key});

  @override
  State<ScreenFitScreen> createState() => _ScreenFitScreenState();
}

class _ScreenFitScreenState extends State<ScreenFitScreen> {
  static const _over = [0, 1, 2, 3, 4, 5, 6, 8];
  static const _scales = ['large', 'medium', 'small'];

  void _over_(int d) {
    final s = AppState.I;
    final cur = s.cfg.i('misc.overscan');
    var i = _over.indexOf(cur);
    if (i < 0) i = 0;
    i = (i + d).clamp(0, _over.length - 1);
    s.set('misc.overscan', _over[i]);
  }

  void _scale_(int d) {
    final s = AppState.I;
    var i = _scales.indexOf(s.cfg.s('ui.scale'));
    if (i < 0) i = 1;
    i = (i + d).clamp(0, _scales.length - 1);
    s.set('ui.scale', _scales[i]);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
        final k = e.logicalKey;
        // الواجهة RTL: السهم اليمين يزيد الهامش (الإطار يدخل للداخل)
        if (k == LogicalKeyboardKey.arrowRight) {
          _over_(1);
        } else if (k == LogicalKeyboardKey.arrowLeft) {
          _over_(-1);
        } else if (k == LogicalKeyboardKey.arrowUp) {
          _scale_(1);
        } else if (k == LogicalKeyboardKey.arrowDown) {
          _scale_(-1);
        } else if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
          Navigator.maybePop(context);
        } else if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.keyR) {
          AppState.I.set('misc.overscan', 0);
          AppState.I.set('ui.scale', 'medium');
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final p = s.palette;
          final f = ScreenFacts.of(context);
          final over = s.cfg.i('misc.overscan');
          final scale = s.cfg.s('ui.scale');
          final design = MediaQuery.sizeOf(context); // حجم اللوحة بعد DesignCanvas
          final safe = 1 - over / 100;
          final k = math.min(f.logical.width * safe / design.width, f.logical.height * safe / design.height);
          final pxPerDesign = k * f.dpr; // كم بكسل حقيقي لكل وحدة تصميم
          return Scaffold(
            backgroundColor: p.bg,
            body: Stack(fit: StackFit.expand, children: [
              CustomPaint(painter: _FramePainter(p.accent, p.ring, p.line)),
              Center(
                child: SizedBox(
                  width: 1080,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(48, 40, 48, 36),
                    decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(36), border: Border.all(color: p.line)),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Container(
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
                          child: AppIcon(Lu.scan, color: p.accent, size: 32),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            FitText('مطابقة الشاشة', style: Fonts.title(36, p.ink)),
                            FitText('لازم تشوف الأسهم الأربعة والإطار الذهبي كامل على حواف الشاشة', style: Fonts.body(20, p.muted)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 28),
                      Row(children: [
                        Expanded(child: _Fact('الدقة الفعلية', '${f.physical.width.round()}×${f.physical.height.round()}', f.name)),
                        const SizedBox(width: 16),
                        Expanded(child: _Fact('الكثافة', '${Ar.n(f.dpi)} dpi', 'نسبة ${f.dpr.toStringAsFixed(2)}')),
                        const SizedBox(width: 16),
                        Expanded(child: _Fact('النسبة', f.ratio, '${Ar.n(f.hz.round())} هرتز')),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _Fact('لوحة التصميم', '${design.width.round()}×${design.height.round()}', 'مطابقة لفيكما ١٩٢٠×١٠٨٠')),
                        const SizedBox(width: 16),
                        Expanded(child: _Fact('التكبير', '×${k.toStringAsFixed(3)}', '${pxPerDesign.toStringAsFixed(2)} بكسل لكل نقطة')),
                        const SizedBox(width: 16),
                        Expanded(child: _Fact('هامش الحواف', over == 0 ? 'بدون' : '${Ar.n(over)}٪', 'حجم: ${switch (scale) { 'small' => 'صغير', 'large' => 'كبير', _ => 'مطابق' }}')),
                      ]),
                      const SizedBox(height: 28),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _Key(Lu.arrowLeftRight, 'هامش الحواف'),
                        const SizedBox(width: 28),
                        _Key(Lu.arrowUpDown, 'حجم الواجهة'),
                        const SizedBox(width: 28),
                        _Key(Lu.circleCheck, 'حفظ وخروج'),
                      ]),
                    ]),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label, value, sub;
  const _Fact(this.label, this.value, this.sub);

  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    return Container(
      height: 128,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(color: Color.lerp(p.surface, p.accent, 0.06), borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        FitText(label, style: Fonts.body(18, p.muted)),
        const SizedBox(height: 4),
        FitText(value, style: Fonts.body(30, p.ink, weight: FontWeight.w600)),
        FitText(sub, style: Fonts.body(17, p.muted)),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  final Object icon;
  final String label;
  const _Key(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
        AppIcon(icon, color: p.accent, size: 24),
        const SizedBox(width: 10),
        Text(label, maxLines: 1, softWrap: false, style: Fonts.body(20, p.ink)),
      ])),
    );
  }
}

/// إطار المعايرة: خط ذهبي على حافة اللوحة + أسهم بالزوايا + شبكة ١٠٪ خفيفة.
class _FramePainter extends CustomPainter {
  final Color accent, ring, line;
  const _FramePainter(this.accent, this.ring, this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      canvas.drawLine(Offset(w * i / 10, 0), Offset(w * i / 10, h), grid);
      canvas.drawLine(Offset(0, h * i / 10), Offset(w, h * i / 10), grid);
    }
    final edge = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRect((Offset.zero & size).deflate(3), edge);
    // أسهم الزوايا تأشر للخارج: إذا ما تبين كاملة، الشاشة تقص — زيد الهامش
    final arrow = Paint()..color = accent;
    void corner(Offset o, double dx, double dy) {
      final path = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + dx * 90, o.dy)
        ..lineTo(o.dx + dx * 60, o.dy + dy * 30)
        ..lineTo(o.dx + dx * 30, o.dy + dy * 60)
        ..lineTo(o.dx, o.dy + dy * 90)
        ..close();
      canvas.drawPath(path, arrow);
    }

    corner(const Offset(10, 10), 1, 1);
    corner(Offset(w - 10, 10), -1, 1);
    corner(Offset(10, h - 10), 1, -1);
    corner(Offset(w - 10, h - 10), -1, -1);
    // علامات منتصف الحواف
    final mid = Paint()..color = accent;
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, 10), width: 120, height: 8), mid);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h - 10), width: 120, height: 8), mid);
    canvas.drawRect(Rect.fromCenter(center: Offset(10, h / 2), width: 8, height: 120), mid);
    canvas.drawRect(Rect.fromCenter(center: Offset(w - 10, h / 2), width: 8, height: 120), mid);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.accent != accent || old.ring != ring || old.line != line;
}
