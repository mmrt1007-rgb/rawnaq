import 'dart:io';

import 'package:flutter/material.dart';

import '../arabic.dart';
import '../lucide.dart';
import '../brand.dart';
import '../platform.dart';
import '../state.dart';
import '../wallpaper_fetcher.dart';
import '../widgets.dart';
import 'wallpapers.dart';

/// مكتبة الخلفيات — تصميم فيكما "مكتبة الخلفيات":
/// يمين: التحديث والعدد والتجديد التلقائي + ١٠ فئات تتفعل وتنطفي.
/// يسار: معاينة لآخر الصور مع فئاتها، وبطاقات (التحديث القادم، صورك الخاصة، المصدر).
class WallLibraryScreen extends StatelessWidget {
  const WallLibraryScreen({super.key});

  static String _ago(DateTime t) {
    if (t.millisecondsSinceEpoch == 0) return 'لم يتحدث بعد';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return 'الآن';
    if (d.inHours < 1) return 'قبل ${Ar.n(d.inMinutes)} دقيقة';
    if (d.inDays < 1) return 'قبل ${Ar.n(d.inHours)} ساعة';
    return 'قبل ${Ar.n(d.inDays)} يوم';
  }

  static String _until(DateTime? t) {
    if (t == null) return 'متوقف';
    final d = t.difference(DateTime.now());
    if (d.isNegative) return 'قريباً';
    if (d.inDays >= 1) return 'بعد ${Ar.n(d.inDays)} يوم';
    return 'بعد ${Ar.n(d.inHours)} ساعة';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge([s, WallpaperFetcher.status, WallpaperFetcher.progress]),
        builder: (context, _) {
          final p = s.palette;
          final c = s.cfg;
          final cats = WallpaperFetcher.enabled().map((e) => e.id).toSet();
          final autos = s.wallpapers.where((w) => w.split('/').last.startsWith('auto-')).toList().reversed.toList();
          final own = s.wallpapers.length - autos.length;
          final busy = WallpaperFetcher.status.value;
          return Padding(
            padding: const EdgeInsets.fromLTRB(112, 64, 112, 56),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text('مكتبة الخلفيات', style: Fonts.title(52, p.ink)))),
                if (busy.isNotEmpty) ...[const SizedBox(width: 22), RawnaqLoader(size: 72, progress: WallpaperFetcher.progress.value)],
              ]),
              const SizedBox(height: 6),
              FitText('صور حقيقية مختارة من ويكيميديا كومنز بدقة 4K · تتجدد ${c.i('walls.days') == 7 ? 'أسبوعياً' : 'تلقائياً'} · حتى ١٠٠ صورة',
                  style: Fonts.body(24, p.muted, weight: FontWeight.w300)),
              const SizedBox(height: 32),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // ---------- اللوحة (يمين) ----------
                  SizedBox(
                    width: 620,
                    child: GlassPanel(
                      radius: BorderRadius.circular(32),
                      padding: const EdgeInsets.all(22),
                      child: NavZone(
                        child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.all(5),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            NavRow(
                              autofocus: true,
                              title: busy.isEmpty ? 'تحديث الآن' : 'جاري التحديث…',
                              subtitle: busy.isEmpty ? 'آخر تحديث ${_ago(WallpaperFetcher.lastUpdate)}' : busy,
                              onTap: () {
                                if (WallpaperFetcher.running) return;
                                WallpaperFetcher.run(force: true);
                                toast(context, 'بدأ التحديث بالخلفية، الصور تنضاف وحدة وحدة');
                              },
                            ),
                            cStepInt('عدد الصور', 'walls.count', 10, 100, (v) => '${Ar.n(v)} من ١٠٠', step: 5),
                            cChoice<int>('التجديد التلقائي', 'walls.days', const [(0, 'متوقف'), (1, 'يومياً'), (3, 'كل ٣ أيام'), (7, 'أسبوعياً'), (14, 'كل أسبوعين'), (30, 'شهرياً')]),
                            SectionTitle('الفئات'),
                            for (final cat in WallCategory.all)
                              _CatRow(
                                cat: cat,
                                on: cats.contains(cat.id),
                                count: WallCredits.countFor(cat.id),
                                onTap: () {
                                  final next = {...cats};
                                  if (!next.remove(cat.id)) next.add(cat.id);
                                  if (next.isEmpty) {
                                    toast(context, 'لازم تبقى فئة وحدة على الأقل');
                                    return;
                                  }
                                  s.set('walls.cats', WallCategory.all.where((x) => next.contains(x.id)).map((x) => x.id).join(','));
                                },
                              ),
                            SectionTitle('صورك الخاصة'),
                            NavRow(
                              title: 'إدارة الصور',
                              subtitle: 'تعيين للواجهة أو لشاشة السكون، حذف، واستيراد',
                              value: '${Ar.n(s.wallpapers.length)} صورة',
                              onTap: () => Navigator.push(context, fade(const WallpapersScreen())),
                            ),
                            NavRow(
                              title: 'استيراد من الفلاشة',
                              subtitle: 'ينسخ كل الصور من الفلاشة أو ذاكرة الجهاز',
                              onTap: () async {
                                if (!await NativeBridge.requestStorage()) {
                                  if (context.mounted) toast(context, 'لازم توافق على صلاحية الوصول للملفات');
                                  return;
                                }
                                final n = await NativeBridge.importImages();
                                await s.refreshWallpapers();
                                if (context.mounted) toast(context, n > 0 ? 'تم استيراد ${Ar.n(n)} صورة' : 'ما لكيت صور جديدة');
                              },
                            ),
                          ]),
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                  // ---------- المعاينة (يسار) ----------
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _Mosaic(paths: autos.take(6).toList())),
                      const SizedBox(height: 28),
                      Row(children: [
                        Expanded(child: _Stat(value: _until(WallpaperFetcher.nextUpdate), label: 'التحديث القادم')),
                        const SizedBox(width: 20),
                        Expanded(child: _Stat(value: '${Ar.n(own)} صورة', label: 'صورك الخاصة')),
                        const SizedBox(width: 20),
                        const Expanded(child: _Stat(value: 'ويكيميديا كومنز', label: 'المصدر')),
                      ]),
                      const SizedBox(height: 14),
                      FitText('كل صورة تظهر مع اسم المصوّر ورخصتها — صور مختارة (Featured pictures) بدون علامات مائية',
                          style: Fonts.body(18, p.muted, weight: FontWeight.w300)),
                    ]),
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

class _CatRow extends StatelessWidget {
  final WallCategory cat;
  final bool on;
  final int count;
  final VoidCallback onTap;
  const _CatRow({required this.cat, required this.on, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return FocusTap(
      key: ValueKey('cat-${cat.id}'),
      onTap: onTap,
      builder: (context, f) => AnimatedContainer(
        duration: AppState.I.anim(140),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: p.glass ? Colors.black.withValues(alpha: p.night ? 0.15 : 0.04) : p.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: f ? p.ring : p.line, width: f ? ringW : 1),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(12)),
            child: AppIcon(cat.icon, color: p.onAccent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(child: FitText(cat.name, style: Fonts.body(22, p.ink))),
          if (on && count > 0) ...[
            Text('${Ar.n(count)} صورة', style: Fonts.body(18, p.accent, weight: FontWeight.w500)),
            const SizedBox(width: 14),
          ],
          AnimatedContainer(
            duration: AppState.I.anim(160),
            width: 60,
            height: 34,
            padding: const EdgeInsets.all(4),
            alignment: on ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            decoration: BoxDecoration(color: on ? p.accent : p.line, borderRadius: BorderRadius.circular(999)),
            child: Container(width: 26, height: 26, decoration: BoxDecoration(color: on ? p.onAccent : p.surface, shape: BoxShape.circle)),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FitText(value, style: Fonts.body(24, p.ink, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(label, style: Fonts.body(18, p.muted, weight: FontWeight.w300)),
      ]),
    );
  }
}

/// فسيفساء آخر الصور: صورة كبيرة + خمس صغار، وعلى كل وحدة اسم فئتها.
class _Mosaic extends StatelessWidget {
  final List<String> paths;
  const _Mosaic({required this.paths});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      const g = 24.0;
      final bigW = (w - g) * 0.64, smallW = w - g - bigW;
      final topH = (h - g) * 0.6, botH = h - g - topH;
      final rects = <Rect>[
        Rect.fromLTWH(w - bigW, 0, bigW, topH),
        Rect.fromLTWH(0, 0, smallW, (topH - g) / 2),
        Rect.fromLTWH(0, (topH + g) / 2, smallW, (topH - g) / 2),
        Rect.fromLTWH(w - (w - 2 * g) / 3, topH + g, (w - 2 * g) / 3, botH),
        Rect.fromLTWH((w - 2 * g) / 3 + g, topH + g, (w - 2 * g) / 3, botH),
        Rect.fromLTWH(0, topH + g, (w - 2 * g) / 3, botH),
      ];
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return Stack(children: [
        for (final (i, r) in rects.indexed)
          Positioned.fromRect(
            rect: r,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(fit: StackFit.expand, children: [
                if (i < paths.length)
                  Image.file(File(paths[i]), fit: BoxFit.cover, cacheWidth: (r.width * dpr).round(), gaplessPlayback: true,
                      frameBuilder: brandImageFrame(background: p.surface, size: 72),
                      errorBuilder: (_, __, ___) => ColoredBox(color: p.surface))
                else
                  ColoredBox(color: p.surface, child: Center(child: AppIcon(Lu.image, color: p.line, size: 48))),
                if (i < paths.length && WallCredits.of(paths[i]) != null)
                  PositionedDirectional(
                    start: 14,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                      child: Text(WallCategory.of(WallCredits.of(paths[i])!.category)?.name ?? '',
                          style: Fonts.body(16, Colors.white, weight: FontWeight.w500)),
                    ),
                  ),
              ]),
            ),
          ),
      ]);
    });
  }
}
