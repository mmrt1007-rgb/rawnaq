import 'package:flutter/material.dart';

import 'arabic.dart';
import 'prayer.dart';
import 'state.dart';
import 'widgets.dart';
import 'lucide.dart';

Object prayerIcon(String id) => switch (id) {
      'imsak' => Lu.moon,
      'fajr' => Lu.sunrise,
      'sunrise' => Lu.sun,
      'dhuhr' => Lu.sun,
      'sunset' => Lu.sunrise,
      'maghrib' => Lu.moon,
      _ => Lu.moon,
    };

String remaining(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '${Ar.n(m == 0 ? 1 : m)} دقيقة';
  if (m == 0) return '${Ar.n(h)} ساعة';
  return '${Ar.n(h)} س و${Ar.n(m)} د';
}

/// شريط مواقيت الصلاة: كل وقت بأيقونته، والوقت القادم مميز.
class PrayerStrip extends StatelessWidget {
  final double size;
  final String font;
  final Color ink, muted, accent;
  final Color? chip;
  final bool shadows;
  final WrapAlignment alignment;

  const PrayerStrip({
    super.key,
    required this.size,
    required this.font,
    required this.ink,
    required this.muted,
    required this.accent,
    this.chip,
    this.shadows = false,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final now = AppState.I.now;
    final list = Prayers.forDay(now);
    final next = Prayers.next(now);
    final shadow = shadows ? [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 18)] : null;
    return Wrap(
      alignment: alignment,
      spacing: size * 0.7,
      runSpacing: size * 0.5,
      children: [
        for (final p in list)
          Builder(builder: (_) {
            final isNext = next != null && next.id == p.id && next.time.day == p.time.day;
            final fg = isNext ? accent : ink;
            return AnimatedContainer(
              duration: AppState.I.anim(300),
              padding: EdgeInsets.symmetric(horizontal: size * 0.7, vertical: size * 0.35),
              decoration: BoxDecoration(
                color: isNext ? accent.withValues(alpha: 0.16) : (chip ?? Colors.transparent),
                borderRadius: BorderRadius.circular(size * 2),
                border: Border.all(color: isNext ? accent.withValues(alpha: 0.7) : muted.withValues(alpha: 0.25)),
              ),
              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
                AppIcon(prayerIcon(p.id), size: size * 1.05, color: isNext ? accent : muted, shadows: shadow),
                SizedBox(width: size * 0.35),
                Text(p.name, style: Fonts.family(font, size * 0.82, isNext ? fg : muted).copyWith(shadows: shadow)),
                SizedBox(width: size * 0.35),
                Text(Ar.time(p.time),
                    style: Fonts.family(font, size, fg, weight: FontWeight.w700).copyWith(shadows: shadow)),
              ])),
            );
          }),
      ],
    );
  }
}

/// سطر "الوقت القادم بعد كذا".
class NextPrayerLine extends StatelessWidget {
  final double size;
  final String font;
  final Color ink, accent;
  final bool shadows;
  const NextPrayerLine({super.key, required this.size, required this.font, required this.ink, required this.accent, this.shadows = false});

  @override
  Widget build(BuildContext context) {
    final now = AppState.I.now;
    final next = Prayers.next(now);
    if (next == null) return const SizedBox.shrink();
    final shadow = shadows ? [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 18)] : null;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AppIcon(prayerIcon(next.id), color: accent, size: size * 1.1, shadows: shadow),
      SizedBox(width: size * 0.4),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: next.name, style: Fonts.family(font, size, accent, weight: FontWeight.w700)),
          TextSpan(text: ' بعد ${remaining(next.time.difference(now))}', style: Fonts.family(font, size, ink)),
        ]),
        style: TextStyle(shadows: shadow),
      ),
    ]);
  }
}

/// خط زمني أنيق للمواقيت: كل وقت عمود (أيقونة، اسم، وقت) يربطها خط رفيع،
/// والوقت القادم يتوهج بلون التمييز ويظهر تحته الوقت المتبقي.
class PrayerTimeline extends StatelessWidget {
  final double size;
  final String font;
  final Color ink, muted, accent;
  const PrayerTimeline({super.key, required this.size, required this.font, required this.ink, required this.muted, required this.accent});

  @override
  Widget build(BuildContext context) {
    final now = AppState.I.now;
    final list = Prayers.forDay(now);
    final next = Prayers.next(now);
    if (list.isEmpty) return const SizedBox.shrink();
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 20)];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (i, p) in list.indexed) ...[
        if (i > 0)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: size * 0.62),
              child: Container(height: 1.2, color: muted.withValues(alpha: 0.35)),
            ),
          ),
        Builder(builder: (_) {
          final isNext = next != null && next.id == p.id && next.time.day == p.time.day;
          final past = p.time.isBefore(now) && !isNext;
          final col = isNext ? accent : (past ? muted.withValues(alpha: 0.7) : ink);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: AppState.I.anim(400),
              width: size * 1.25,
              height: size * 1.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNext ? accent.withValues(alpha: 0.18) : Colors.transparent,
                border: Border.all(color: isNext ? accent : muted.withValues(alpha: 0.45), width: isNext ? 2 : 1.2),
                boxShadow: isNext ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: size)] : null,
              ),
              child: AppIcon(prayerIcon(p.id), size: size * 0.7, color: col),
            ),
            SizedBox(height: size * 0.35),
            Text(p.name, style: Fonts.family(font, size * 0.72, isNext ? accent : muted).copyWith(shadows: shadow)),
            Text(Ar.time(p.time),
                style: Fonts.family(font, size * 1.05, col, weight: isNext ? FontWeight.w700 : FontWeight.w400).copyWith(shadows: shadow)),
            SizedBox(
              height: size * 0.95,
              child: isNext
                  ? Text('بعد ${remaining(p.time.difference(now))}',
                      style: Fonts.family(font, size * 0.62, accent).copyWith(shadows: shadow))
                  : null,
            ),
          ]);
        }),
      ],
    ]);
  }
}
