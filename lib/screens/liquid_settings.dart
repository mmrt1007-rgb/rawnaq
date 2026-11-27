import 'package:flutter/material.dart';

import '../arabic.dart';
import '../liquid_glass.dart';
import '../lucide.dart';
import '../state.dart';
import '../widgets.dart';

/// تحكم الزجاج السائل — تصميم فيكما "إعدادات الزجاج السائل":
/// معاينة حيّة يسار (شريط + بطاقة + تطبيقات فوق خلفية ملونة)، ولوحة تحكم يمين أولها الإعدادات الجاهزة.
class LiquidGlassScreen extends StatefulWidget {
  const LiquidGlassScreen({super.key});

  @override
  State<LiquidGlassScreen> createState() => _LiquidGlassScreenState();
}

class _LiquidGlassScreenState extends State<LiquidGlassScreen> {
  final _panel = FocusScopeNode(debugLabel: 'liquid-panel');

  @override
  void dispose() {
    _panel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = s.palette;
          final current = currentLiquidPreset();
          return Padding(
            padding: const EdgeInsets.fromLTRB(112, 64, 112, 56),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الزجاج السائل', style: Fonts.title(52, p.ink)),
              const SizedBox(height: 6),
              FitText('تحكم كامل بالغواش واللمعة والانكسار — المعاينة تتغير مباشرة', style: Fonts.body(24, p.muted, weight: FontWeight.w300)),
              const SizedBox(height: 32),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 600,
                    child: GlassPanel(
                      radius: BorderRadius.circular(32),
                      padding: const EdgeInsets.all(28),
                      child: NavZone(
                        node: _panel,
                        child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.all(5),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            SelectorRow<String>(
                              key: const ValueKey('liquid-presets'),
                              autofocus: true,
                              title: 'إعداد جاهز',
                              values: [for (final x in liquidPresets) x.$1],
                              selected: current,
                              onSelect: applyLiquidPreset,
                              spacing: 12,
                              itemBuilder: (context, id, hi, sel) => AnimatedContainer(
                                duration: s.anim(150),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                decoration: BoxDecoration(
                                  color: sel ? p.accent : p.bg.withValues(alpha: p.glass ? 0.3 : 1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: hi ? p.ring : (sel ? p.accent : p.line), width: hi ? ringW : 1),
                                ),
                                child: Text(liquidPresets.firstWhere((x) => x.$1 == id).$2,
                                    style: Fonts.body(21, sel ? p.onAccent : p.ink, weight: FontWeight.w600)),
                              ),
                            ),
                            SectionTitle('الزجاج'),
                            cStep('الغواش (التغبيش)', 'liquid.blur', 0, 60, 2, fmtPx),
                            cStep('كثافة الزجاج', 'liquid.tint', 0, 0.6, 0.02, fmtPct),
                            cStep('لمعة الحواف', 'liquid.edge', 0, 1, 0.05, fmtPct),
                            cStep('تشبّع الألوان خلف الزجاج', 'liquid.sat', 1, 2, 0.05, fmtPct),
                            cStep('استدارة الزوايا', 'liquid.radius', 12, 64, 2, fmtPx),
                            cChoice<String>('لون الزجاج', 'liquid.tone', const [('light', 'فاتح'), ('dark', 'داكن')]),
                            cToggle('يتكيف مع الخلفية', 'liquid.adaptive', sub: 'يفتّح الزجاج بالنهار حتى يبقى النص واضح'),
                            if (s.lite)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('الجهاز بالوضع الخفيف: الزجاج يظهر بدون تغبيش حي حتى تبقى الواجهة سريعة.',
                                    style: Fonts.body(18, p.muted)),
                              ),
                          ]),
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final h = (box.maxHeight - 40).clamp(240.0, box.maxWidth * 0.64);
                      final w = h / 0.64;
                      return Align(alignment: AlignmentDirectional.topEnd, child: SizedBox(width: w, height: h, child: const _Preview()));
                    }),
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

/// المعاينة: خلفية ملونة ناعمة وفوقها نفس عناصر الواجهة بالزجاج السائل.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final t = s.now;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 50, offset: const Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(child: CustomPaint(painter: _Blobs())),
          LayoutBuilder(builder: (context, box) {
            final k = box.maxWidth / 1000; // المعاينة مصممة على عرض ١٠٠٠
            return Stack(children: [
              Positioned(
                top: 48 * k,
                left: 0,
                right: 0,
                child: Center(
                  child: LiquidGlass(force: true, 
                    radius: 999,
                    padding: EdgeInsets.all(7 * k),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final (l, ic, on) in const [('الرئيسية', Lu.house, true), ('التطبيقات', Lu.grid, false), ('الإعدادات', Lu.settings, false)])
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 18 * k, vertical: 10 * k),
                          decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: 0.22) : null, borderRadius: BorderRadius.circular(999)),
                          child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
                            AppIcon(ic, color: Colors.white, size: 20 * k),
                            SizedBox(width: 8 * k),
                            Text(l, style: Fonts.body(18 * k, Colors.white, weight: on ? FontWeight.w600 : null)),
                          ])),
                        ),
                    ]),
                  ),
                ),
              ),
              Positioned(
                top: 200 * k,
                left: 240 * k,
                width: 520 * k,
                height: 250 * k,
                child: LiquidGlass(force: true, 
                  strength: 1.2,
                  radius: AppState.I.cfg.d('liquid.radius') * k,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(Ar.time(t), style: Fonts.clock(96 * k, Colors.white, weight: FontWeight.w400).copyWith(height: 1.1)),
                    SizedBox(height: 8 * k),
                    Text(Ar.dayName(t), style: Fonts.body(22 * k, Colors.white.withValues(alpha: 0.85), weight: FontWeight.w300)),
                  ]),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48 * k,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  for (final (col, ic, foc) in const [(Color(0xFF1F6F5C), Lu.tv, false), (Color(0xFF2F4E7E), Lu.film, false), (Color(0xFFC0392B), Lu.play, true)])
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 11 * k),
                      width: (foc ? 190 : 170) * k,
                      height: (foc ? 107 : 96) * k,
                      decoration: BoxDecoration(
                        color: col,
                        borderRadius: BorderRadius.circular(24 * k),
                        border: Border.all(color: Colors.white.withValues(alpha: foc ? 0.9 : 0.4), width: foc ? 3 : 1.5),
                        boxShadow: foc ? [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 36, offset: const Offset(0, 18))] : null,
                      ),
                      child: Center(child: AppIcon(ic, color: Colors.white, size: 36 * k)),
                    ),
                ]),
              ),
            ]);
          }),
        ]),
      ),
    );
  }
}

class _Blobs extends CustomPainter {
  const _Blobs();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF06120E));
    final w = size.width, h = size.height;
    for (final (cx, cy, bw, bh, col) in const [
      (0.25, 0.27, 0.70, 0.72, Color(0xB31F7A5A)),
      (0.80, 0.31, 0.56, 0.62, Color(0x80A87A2E)),
      (0.52, 0.73, 0.80, 0.52, Color(0x8C2F4E7E)),
      (0.88, 0.88, 0.40, 0.40, Color(0x593DBE8C)),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * cx, h * cy), width: w * bw, height: h * bh),
        Paint()
          ..color = col
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(_Blobs old) => false;
}
