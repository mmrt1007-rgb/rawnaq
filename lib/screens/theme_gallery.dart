import 'package:flutter/material.dart';

import '../arabic.dart';
import '../config.dart';
import '../lucide.dart';
import '../state.dart';
import '../widgets.dart';

/// معرض الثيمات (فيكما صفحة ١٩ «ثيمات المعصومين (ع) والزينبي والعباسي»):
/// شبكة ٤ أعمدة، كل بطاقة بلون ثيمها الحقيقي (نهاري أو ليلي حسب الوقت الحالي)،
/// رقمها، اسمها ولقبها، زر تشغيل وحلقة تحديد، وشريط ألوانه السبعة.
/// ▲▼◀▶ للتنقل، موافق للتطبيق، وزر القائمة (أو ضغطة طويلة) يقلب المعاينة نهاري/ليلي.
class ThemeGalleryScreen extends StatefulWidget {
  const ThemeGalleryScreen({super.key});
  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  bool? _night; // null = حسب الوقت

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final p = s.palette;
          final night = _night ?? p.night;
          final current = s.cfg.s('theme.preset');
          return Padding(
            padding: const EdgeInsets.fromLTRB(96, 56, 96, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20 * radiusK),
                    border: Border.all(color: p.ring.withValues(alpha: 0.45)),
                  ),
                  child: AppIcon(Lu.palette, color: p.accent, size: 34),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FitText('ثيمات المعصومين (ع) والزينبي والعباسي', style: Fonts.title(44, p.ink)),
                    FitText('${Ar.n(ThemePreset.all.length)} ثيم · موافق للتطبيق · ضغطة طويلة تقلب المعاينة ${night ? 'للنهاري' : 'لليلي'}',
                        style: Fonts.body(20, p.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              const RoyalRule(),
              const SizedBox(height: 18),
              Expanded(
                child: NavZone(
                  child: AxisClip(
                    axis: Axis.vertical,
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.all(10),
                      child: LayoutBuilder(builder: (context, box) {
                        const gap = 22.0;
                        final w = (box.maxWidth - gap * 3) / 4;
                        return Wrap(spacing: gap, runSpacing: gap, children: [
                          for (final (i, t) in ThemePreset.all.indexed)
                            SizedBox(
                              width: w,
                              child: _GalleryCard(
                                preset: t,
                                index: i,
                                night: night,
                                active: t.id == current,
                                autofocus: t.id == current || (i == 0 && !ThemePreset.all.any((x) => x.id == current)),
                                onTap: () {
                                  s.applyTheme(t);
                                  toast(context, 'تفعّل ثيم ${t.name}');
                                },
                                onLongPress: () => setState(() => _night = !night),
                              ),
                            ),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const KeyGuide(),
            ]),
          );
        },
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final ThemePreset preset;
  final int index;
  final bool night, active, autofocus;
  final VoidCallback onTap, onLongPress;
  const _GalleryCard({required this.preset, required this.index, required this.night, required this.active, required this.autofocus, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final m = night ? preset.night : preset.day;
    Color k(String x) => Color(m[x]!);
    final bg = k('bg'), sf = k('surface'), ink = k('ink'), muted = k('muted'), accent = k('accent'), ring = k('ring'), line = k('line');
    final onAccent = accent.computeLuminance() > 0.32 ? const Color(0xFF111111) : Colors.white;
    final shell = pal;
    return FocusTap(
      autofocus: autofocus,
      onTap: onTap,
      onLongPress: onLongPress,
      builder: (context, f) => AnimatedScale(
        scale: f ? 1.035 : 1,
        duration: AppState.I.anim(150),
        child: AnimatedContainer(
          duration: AppState.I.anim(150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(26 * radiusK),
            border: Border.all(color: f ? shell.ring : (active ? accent : line), width: f ? ringW : (active ? 3 : 1)),
            boxShadow: royalShadows(shell, f),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: BoxDecoration(color: sf, borderRadius: BorderRadius.circular(18 * radiusK), border: Border.all(color: line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: FitText(preset.name, style: Fonts.family(preset.titleFont, 30, ink, weight: FontWeight.w600, height: 1.2))),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: ring, width: 1.5)),
                    child: active
                        ? AppIcon(Lu.check, size: 20, color: accent)
                        : FitText(Ar.n(index + 1), style: Fonts.family(preset.bodyFont, 17, ink, weight: FontWeight.w500, height: 1)),
                  ),
                ]),
                const SizedBox(height: 4),
                FitText(preset.sub, style: Fonts.family(preset.bodyFont, 16, muted)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                      child: FitText(active ? 'مفعّل' : 'تشغيل', style: Fonts.family(preset.bodyFont, 18, onAccent, weight: FontWeight.w600, height: 1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: sf, borderRadius: BorderRadius.circular(999), border: Border.all(color: ring, width: 2.5)),
                      child: FitText('محدد', style: Fonts.family(preset.bodyFont, 18, ink, weight: FontWeight.w600, height: 1)),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              for (final c in [bg, sf, ink, muted, accent, ring, line])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: line))),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            FitText('${preset.titleFont} · ${preset.bodyFont}', style: Fonts.body(14, muted)),
          ]),
        ),
      ),
    );
  }
}
