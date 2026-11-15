import 'package:flutter/material.dart';

import 'config.dart';

/// ألوان الثيم الحالي، تُقرأ من الإعدادات (كلها قابلة للتعديل).
class Palette {
  final bool night;
  final bool glass;
  final bool liquid; // الزجاج السائل
  final bool smooth; // الناعم العصري: حواف متصلة وظلال أنعم
  final double blur;
  final Color bg, surface, ink, muted, accent, ring, line;

  const Palette({
    required this.night,
    this.glass = false,
    this.liquid = false,
    this.smooth = false,
    this.blur = 0,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.ring,
    required this.line,
  });

  factory Palette.from(Config c, bool night) {
    final m = night ? 'night' : 'day';
    final style = c.s('ui.style');
    final liquid = style == 'liquid';
    final glass = style == 'glass' || style == 'cinema' || liquid;
    final tint = c.d('ui.tint').clamp(0.0, 1.0);
    final solid = c.c('$m.surface');
    Color surface;
    Color line;
    if (liquid) {
      // الزجاج السائل: أسطح الصفوف والأزرار زجاج خفيف بنفس لون الطبقة، وحدود من الضوء
      final dark = c.s('liquid.tone') == 'dark';
      final lt = c.d('liquid.tint');
      surface = dark
          ? Colors.black.withValues(alpha: 0.18 + lt)
          : Colors.white.withValues(alpha: night ? 0.06 + lt * 0.6 : 0.30 + lt);
      line = Colors.white.withValues(alpha: (night ? 0.14 : 0.5) + 0.2 * c.d('liquid.edge'));
    } else {
      // الزجاج المغبش: أسطح شفافة بلون الثيم + حدود فاتحة رفيعة
      surface = glass
          ? Color.lerp(solid, Colors.white, night ? 0.08 : 0.35)!.withValues(alpha: night ? 0.10 + 0.22 * tint : 0.28 + 0.40 * tint)
          : solid;
      line = glass ? Colors.white.withValues(alpha: night ? 0.16 : 0.55) : c.c('$m.line');
    }
    // إمكانية الوصول: تباين عالٍ يقرّب النص الثانوي والحدود من النص الأساسي
    var muted = c.c('$m.muted');
    if (c.b('a11y.contrast')) {
      muted = Color.lerp(muted, c.c('$m.ink'), 0.5)!;
      line = Color.lerp(line, c.c('$m.ink'), 0.35)!;
      if (glass) surface = surface.withValues(alpha: (surface.a + 0.25).clamp(0.0, 1.0));
    }
    return Palette(
      night: night,
      glass: glass,
      liquid: liquid,
      smooth: style == 'soft',
      blur: liquid ? c.d('liquid.blur') : c.d('ui.blur'),
      bg: c.c('$m.bg'),
      surface: surface,
      ink: c.c('$m.ink'),
      muted: muted,
      accent: c.c('$m.accent'),
      ring: c.c('$m.ring'),
      line: line,
    );
  }

  /// لون نص مقروء فوق لون التمييز.
  Color get onAccent => accent.computeLuminance() > 0.45 ? const Color(0xFF111111) : Colors.white;
}
