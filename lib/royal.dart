import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';
import 'state.dart';

// ═══════════════════ النظام الملكي ٤٫٠ (فيكما صفحة ١٧) ═══════════════════
//  لغة تركيز وحدة لكل التطبيق: السطح المحدد يتلوّن خفيف بلون الثيم، حده ذهبي،
//  حوله توهج ذهبي هادئ، علامة ذهبية بحافته اليمنى، ويرتفع شوية.
//  كلها من ألوان الثيم نفسه — ما في نمط يمسح هوية الثيم.

/// إطار التركيز من الإعدادات: thin (خط رفيع بلا توهج) | gold (ملكي) | glow (توهج أقوى).
String get _ring => AppState.I.cfg.s('remote.ring');

/// حركة التركيز: none (ثابت) | soft | full.
bool get royalLift => AppState.I.cfg.s('remote.motion') != 'none';

/// سطح العنصر: المحدد يميل للون التمييز بنسبة خفيفة.
Color royalFill(Palette p, Color base, bool focused) => focused ? Color.lerp(base, p.accent, p.night ? 0.10 : 0.06)! : base;

/// ظلال العنصر: المحدد بتوهج ذهبي + ظل عمق، والعادي بظل هادئ اختياري.
List<BoxShadow>? royalShadows(Palette p, bool focused, {bool resting = false}) {
  if (!focused) {
    return resting ? [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.26 : 0.06), blurRadius: 22, offset: const Offset(0, 8))] : null;
  }
  return [
    if (_ring != 'thin') BoxShadow(color: p.ring.withValues(alpha: _ring == 'glow' ? 0.45 : 0.26), blurRadius: _ring == 'glow' ? 34 : 26),
    BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.34 : 0.10), blurRadius: 30, offset: const Offset(0, 12)),
  ];
}

/// يلف أي عنصر قابل للتركيز: ارتفاع خفيف + علامة ذهبية بالحافة اليمنى (بداية السطر العربي).
class RoyalFrame extends StatelessWidget {
  final bool focused;
  final Widget child;
  final double scale;
  final bool marker;
  const RoyalFrame({super.key, required this.focused, required this.child, this.scale = 1.012, this.marker = true});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    return AnimatedScale(
      scale: focused && royalLift ? scale : 1,
      duration: s.anim(200),
      curve: Curves.easeOutCubic,
      child: Stack(clipBehavior: Clip.none, children: [
        child,
        if (marker)
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedContainer(
                duration: s.anim(220),
                curve: Curves.easeOutCubic,
                width: 4,
                height: focused ? 34 : 0,
                decoration: BoxDecoration(color: p.ring, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// معيّن ذهبي صغير (زخرفة العناوين).
class RoyalDiamond extends StatelessWidget {
  final double size;
  final Color? color;
  const RoyalDiamond({super.key, this.size = 9, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 1.42,
        height: size * 1.42,
        child: Center(
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: size, height: size, color: color ?? AppState.I.palette.ring),
          ),
        ),
      );
}

/// خط شعري ذهبي يتلاشى نحو اليسار، يبدأ بمعيّن من اليمين (تحت عناوين الشاشات).
class RoyalRule extends StatelessWidget {
  final double opacity;
  const RoyalRule({super.key, this.opacity = 0.7});

  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    return SizedBox(
      height: 14,
      child: Row(children: [
        const RoyalDiamond(size: 9),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [p.ring.withValues(alpha: opacity), p.ring.withValues(alpha: opacity * 0.4), p.ring.withValues(alpha: 0)],
                stops: const [0, 0.35, 1],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
