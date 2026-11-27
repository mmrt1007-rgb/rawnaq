import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'state.dart';

/// إعدادات الزجاج السائل الجاهزة: الاسم، الغواش، الكثافة، لمعة الحواف، التشبّع، اللون.
const liquidPresets = <(String, String, double, double, double, double, String)>[
  ('balanced', 'متوازن', 24, 0.12, 0.70, 1.4, 'light'),
  ('clear', 'صافٍ', 12, 0.05, 0.85, 1.6, 'light'),
  ('frost', 'ثلجي', 40, 0.28, 0.60, 1.1, 'light'),
  ('dark', 'داكن', 28, 0.22, 0.50, 1.3, 'dark'),
];

void applyLiquidPreset(String id) {
  final s = AppState.I;
  final p = liquidPresets.firstWhere((x) => x.$1 == id);
  s.cfg.set('liquid.blur', p.$3);
  s.cfg.set('liquid.tint', p.$4);
  s.cfg.set('liquid.edge', p.$5);
  s.cfg.set('liquid.sat', p.$6);
  s.set('liquid.tone', p.$7);
}

/// الإعداد الجاهز المطابق للقيم الحالية (أو null إذا معدّل يدوياً).
String? currentLiquidPreset() {
  final c = AppState.I.cfg;
  for (final p in liquidPresets) {
    if ((c.d('liquid.blur') - p.$3).abs() < 0.01 &&
        (c.d('liquid.tint') - p.$4).abs() < 0.001 &&
        (c.d('liquid.edge') - p.$5).abs() < 0.001 &&
        (c.d('liquid.sat') - p.$6).abs() < 0.001 &&
        c.s('liquid.tone') == p.$7) {
      return p.$1;
    }
  }
  return null;
}

/// مصفوفة تشبّع الألوان: ١ = طبيعي، أكبر = ألوان أغنى خلف الزجاج (مثل Liquid Glass).
List<double> _saturation(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final i = 1 - s;
  return [
    r * i + s, g * i, b * i, 0, 0,
    r * i, g * i + s, b * i, 0, 0,
    r * i, g * i, b * i + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// لوح زجاج سائل: تغبيش حقيقي لما وراه + تشبّع ألوان + طبقة لون خفيفة +
/// حافة لامعة (ساطعة أعلى اليمين ومنعكسة أسفل اليسار) + لمعة علوية + ظل ناعم.
/// كل شي يتحكم به من إعدادات "الزجاج السائل". بالوضع الخفيف: بدون تغبيش حي (سطح شبه معتم بنفس الشكل).
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final double? width, height;
  final bool shadow;
  final double strength; // ١ = عادي، أكبر لعناصر أكبر (لمعة أوضح)
  /// يرسم زجاج حتى لو النمط صلب (لمعاينة إعدادات الزجاج فقط).
  final bool force;

  const LiquidGlass({super.key, required this.child, this.radius, this.padding, this.width, this.height, this.shadow = true, this.strength = 1, this.force = false});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final night = s.palette.night;
    final r = radius ?? c.d('liquid.radius');
    final br = BorderRadius.circular(r);
    if (!force && !s.palette.glass) {
      // النمط صلب (الثيمات الملكية): سطح معتم بلون الثيم بدل الزجاج — ما يصير كلشي شفاف
      final p = s.palette;
      return Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: br,
          border: Border.all(color: p.line),
          boxShadow: shadow ? [BoxShadow(color: Colors.black.withValues(alpha: night ? 0.30 : 0.08), blurRadius: 30, offset: const Offset(0, 12))] : null,
        ),
        child: child,
      );
    }
    final edge = (c.d('liquid.edge') * strength).clamp(0.0, 1.0);
    final dark = c.s('liquid.tone') == 'dark';
    var tint = c.d('liquid.tint');
    if (c.b('liquid.adaptive') && !night && !dark) tint += 0.15; // بالنهار يحتاج الزجاج يكون أفتح شوي حتى يقرا النص الغامق
    final lite = s.lite;
    // ٤٫٠: الزجاج مصبوغ بلون الثيم (أخضر الزمرد، عقيق الحسيني...) حتى الثيم يبقى واضح ويه الزجاج
    final base = Color.lerp(dark ? Colors.black : Colors.white, s.palette.accent, dark ? 0.18 : (night ? 0.14 : 0.06))!;
    final fill = lite ? Color.lerp(s.palette.bg, base, dark ? 0.35 : (night ? 0.10 : 0.55))!.withValues(alpha: 0.88) : base.withValues(alpha: tint.clamp(0.0, 0.9));

    Widget body = CustomPaint(
      foregroundPainter: _Rim(r, edge),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: fill, borderRadius: br),
        // اللمعة العلوية طبقة منفصلة (اللون والتدرج ما يجتمعون بنفس الصندوق)
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Colors.white.withValues(alpha: 0.10 * edge), Colors.white.withValues(alpha: 0)],
            ),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
    if (!lite) {
      final blur = c.d('liquid.blur');
      final sat = c.d('liquid.sat');
      body = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: ColorFilter.matrix(_saturation(sat)),
            inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.mirror),
          ),
          child: body,
        ),
      );
    } else {
      body = ClipRRect(borderRadius: br, child: body);
    }
    if (!shadow) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: night ? 0.35 : 0.14), blurRadius: 44, offset: const Offset(0, 18))],
      ),
      child: body,
    );
  }
}

/// الحافة اللامعة: خط رفيع متدرج يحاكي انعكاس الضوء على حافة الزجاج.
class _Rim extends CustomPainter {
  final double radius, edge;
  const _Rim(this.radius, this.edge);

  @override
  void paint(Canvas canvas, Size size) {
    if (edge <= 0) return;
    final rect = (Offset.zero & size).deflate(0.75);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = ui.Gradient.linear(
        rect.topRight,
        rect.bottomLeft,
        [
          Colors.white.withValues(alpha: 0.85 * edge),
          Colors.white.withValues(alpha: 0.12 * edge),
          Colors.white.withValues(alpha: 0.45 * edge),
        ],
        const [0, 0.45, 1],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
  }

  @override
  bool shouldRepaint(_Rim old) => old.radius != radius || old.edge != edge;
}
