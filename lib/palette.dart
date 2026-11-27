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
      // ٤٫٠: الزجاج يحمل لون الثيم نفسه (مو أبيض/أسود مجرد) حتى ما ينسى الثيم أصله
      final hue = c.c('$m.accent');
      final rim = c.c('$m.ring');
      surface = dark
          ? Color.lerp(Colors.black, solid, 0.35)!.withValues(alpha: 0.22 + lt)
          : Color.lerp(Colors.white, hue, night ? 0.16 : 0.06)!.withValues(alpha: night ? 0.08 + lt * 0.6 : 0.34 + lt);
      line = Color.lerp(Colors.white, rim, 0.3)!.withValues(alpha: (night ? 0.16 : 0.5) + 0.2 * c.d('liquid.edge'));
    } else {
      // الزجاج المغبش: أسطح شفافة بلون الثيم + حدود فاتحة رفيعة
      surface = glass
          ? Color.lerp(solid, Colors.white, night ? 0.08 : 0.35)!.withValues(alpha: night ? 0.10 + 0.22 * tint : 0.28 + 0.40 * tint)
          : solid;
      line = glass ? Color.lerp(Colors.white, c.c('$m.ring'), 0.3)!.withValues(alpha: night ? 0.18 : 0.55) : c.c('$m.line');
    }
    // إمكانية الوصول: تباين عالٍ يقرّب النص الثانوي والحدود من النص الأساسي
    var muted = c.c('$m.muted');
    if (c.b('a11y.contrast')) {
      muted = Color.lerp(muted, c.c('$m.ink'), 0.5)!;
      line = Color.lerp(line, c.c('$m.ink'), 0.35)!;
      if (glass) surface = surface.withValues(alpha: (surface.a + 0.25).clamp(0.0, 1.0));
    }
    // ٤٫٠: ضمان التباين الحقيقي مهما كانت الألوان (ثيم ملكي، ألوان يدوية، أو زجاج شفاف):
    // النص الأساسي ≥ ٧، الثانوي ≥ ٤٫٥، إطار التركيز ولون التمييز ≥ ٣ — على الخلفية وعلى السطح الفعلي.
    final bg = c.c('$m.bg');
    final eff = Color.alphaBlend(surface, bg);
    final pole = night ? Colors.white : Colors.black;
    final ink = readable(c.c('$m.ink'), [bg, eff], 7, pole);
    muted = readable(muted, [bg, eff], 4.5, ink);
    final accent = readable(c.c('$m.accent'), [bg, eff], 3, pole);
    final ring = readable(c.c('$m.ring'), [bg, eff], 3, pole);
    return Palette(
      night: night,
      glass: glass,
      liquid: liquid,
      smooth: style == 'soft',
      blur: liquid ? c.d('liquid.blur') : c.d('ui.blur'),
      bg: bg,
      surface: surface,
      ink: ink,
      muted: muted,
      accent: accent,
      ring: ring,
      line: line,
    );
  }

  /// نسبة التباين (WCAG) بين لونين معتمين.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  /// يقرّب [fg] تدريجياً من [toward] لحد ما يحقق [min] على كل الخلفيات — بأقل تغيير ممكن حتى يبقى لون الثيم.
  static Color readable(Color fg, List<Color> bgs, double min, Color toward) {
    var c = fg.withValues(alpha: 1);
    for (var i = 0; i < 20; i++) {
      if (bgs.every((b) => contrast(c, b.withValues(alpha: 1)) >= min)) return c;
      c = Color.lerp(c, toward, 0.08)!;
    }
    return c;
  }

  /// لون نص مقروء فوق لون التمييز.
  Color get onAccent => accent.computeLuminance() > 0.45 ? const Color(0xFF111111) : Colors.white;
}
