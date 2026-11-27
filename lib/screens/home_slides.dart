import 'dart:io';

import 'package:flutter/material.dart';

import '../arabic.dart';
import '../backgrounds.dart';
import '../brand.dart';
import '../lucide.dart';
import '../platform.dart';
import '../wallpaper_fetcher.dart';
import '../state.dart';
import '../widgets.dart';
import 'streamer_screens.dart' show live;
import 'system_screens.dart';
import 'wall_library.dart';

// ═══════════════════ صور الواجهة المتغيرة ═══════════════════
//  فيكما صفحة ١٦: ١٥ «صور الواجهة المتغيرة» · ١٦ «اختيار الصور» · ١٧ «بكل الثيمات».

String _secs(int s) => s < 60 ? '${Ar.n(s)} ثانية' : (s < 3600 ? (s == 60 ? 'دقيقة' : '${Ar.n(s ~/ 60)} دقائق') : 'ساعة');

/// الإعدادات مع معاينة حيّة للواجهة نفسها بالثيم الحالي.
class HomeSlidesScreen extends StatelessWidget {
  const HomeSlidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final on = c.b('home.slides');
      final picked = HomeSlides.paths();
      final all = s.wallpapers.length;
      final src = c.s('home.slides.source');
      void pick() => Navigator.push(context, fade(const HomeSlidesPicker()));
      return SysScaffold(
        title: 'صور الواجهة',
        sub: 'صور تتبدل بهدوء خلف الواجهة، وتتلون مع كل ثيم',
        icon: Lu.images,
        left: const _LivePreview(),
        right: [
          SysRow(
            icon: Lu.images,
            title: 'الصور المتغيرة',
            sub: all == 0 ? 'ضيف صور أول، من الفلاشة أو المكتبة' : null,
            toggle: on,
            autofocus: true,
            onTap: () {
              if (!on && all == 0) {
                toast(context, 'ما بيه صور بعد، ضيفها من هنا');
                pick();
                return;
              }
              s.set('home.slides', !on);
            },
          ),
          SysRow(
            icon: Lu.layers,
            title: 'مصدر الصور',
            value: switch (src) { 'library' => 'مكتبة رونق', 'mine' => 'صوري', 'pick' => 'أختارها بنفسي', _ => 'كل الصور' },
            onTap: () => showChoicePicker<String>(context,
                title: 'مصدر صور الواجهة',
                options: const [('all', 'كل الصور'), ('library', 'مكتبة رونق (تتجدد وحدها)'), ('mine', 'صوري فقط'), ('pick', 'أختارها بنفسي')],
                value: src,
                onChanged: (v) => s.set('home.slides.source', v)),
          ),
          if (src == 'library')
            SysRow(
              icon: Lu.grid,
              title: 'فئات المكتبة',
              value: c.s('home.slides.cats').isEmpty ? 'كل الفئات' : '${Ar.n(c.s('home.slides.cats').split(',').where((e) => e.isNotEmpty).length)} فئات',
              onTap: () => Navigator.push(context, fade(const HomeSlidesCats())),
            ),
          SysRow(
            icon: Lu.image,
            title: src == 'pick' ? 'اختيار الصور' : 'الصور',
            value: '${Ar.n(picked.length)} من ${Ar.n(all)} صورة',
            onTap: pick,
          ),
          SysRow(
            icon: Lu.cloudDownload,
            title: 'مكتبة رونق',
            sub: c.b('walls.auto') ? 'تتجدد كل ${c.i('walls.days') == 7 ? 'أسبوع' : '${Ar.n(c.i('walls.days'))} أيام'} · ${Ar.n(WallpaperFetcher.enabled().length)} فئات' : 'التجديد التلقائي متوقف',
            value: '${Ar.n(c.i('walls.count'))} صورة',
            onTap: () => Navigator.push(context, fade(const WallLibraryScreen())),
          ),
          SysRow(
            icon: Lu.timer,
            title: 'المدة بين الصور',
            value: _secs(c.i('home.slides.interval')),
            onTap: () => showChoicePicker<int>(context,
                title: 'المدة بين الصور',
                options: [for (final v in const [15, 30, 60, 120, 300, 600, 1800, 3600]) (v, _secs(v))],
                value: c.i('home.slides.interval'),
                onChanged: (v) => s.set('home.slides.interval', v)),
          ),
          SysRow(
            icon: Lu.sparkles,
            title: 'الانتقال',
            value: c.s('home.slides.motion') == 'fade' ? 'تلاشي ناعم' : 'تلاشي مع حركة بطيئة',
            onTap: () => showChoicePicker<String>(context,
                title: 'الانتقال بين الصور',
                options: const [('fade', 'تلاشي ناعم'), ('kenburns', 'تلاشي مع حركة بطيئة')],
                value: c.s('home.slides.motion'),
                onChanged: (v) => s.set('home.slides.motion', v)),
          ),
          SysRow(icon: Lu.droplets, title: 'لون الثيم فوق الصورة', sub: 'وإلا تعتيم أسود', toggle: c.b('home.slides.tint'), onTap: () => s.set('home.slides.tint', !c.b('home.slides.tint'))),
          SysRow(icon: Lu.shuffle, title: 'ترتيب عشوائي', toggle: c.b('home.slides.shuffle'), onTap: () => s.set('home.slides.shuffle', !c.b('home.slides.shuffle'))),
          SysRow(
            icon: Lu.sunDim,
            title: 'قوة الطبقة',
            sub: 'حتى تبقى الساعة والتطبيقات واضحة',
            value: '${Ar.n((c.d('home.slides.dim') * 100).round())}٪',
            onTap: () => showChoicePicker<double>(context,
                title: 'قوة الطبقة فوق الصورة',
                options: [for (final v in const [0.15, 0.25, 0.35, 0.45, 0.55, 0.65]) (v, '${Ar.n((v * 100).round())}٪')],
                value: c.d('home.slides.dim'),
                onChanged: (v) => s.set('home.slides.dim', v)),
          ),
        ],
      );
    });
  }
}

/// المعاينة: نفس خلفية الواجهة الحقيقية مصغرة، وفوقها الساعة والتطبيقات، وتحتها شريط الصور.
class _LivePreview extends StatelessWidget {
  const _LivePreview();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final paths = HomeSlides.paths();
    return SysCard(
      padding: const EdgeInsets.all(30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        FitText('المعاينة الحية', style: Fonts.body(24, p.ink, weight: FontWeight.w600)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(fit: StackFit.expand, children: [
              paths.isEmpty ? ColoredBox(color: p.bg, child: Center(child: AppIcon(Lu.imageOff, color: p.muted, size: 56))) : HomeSlidesBackdrop(paths: paths),
              // الواجهة مصغرة على لوحة ١٩٢٠×١٠٨٠ حتى تطابق الحقيقية بالضبط
              IgnorePointer(
                child: FittedBox(
                  child: SizedBox(
                    width: 1920,
                    height: 1080,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(112, 64, 112, 72),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(Ar.time(s.now), style: Fonts.clock(200, p.ink, weight: FontWeight.w300)),
                        Text(Ar.gregorian(s.now), style: Fonts.body(32, p.muted)),
                        const Spacer(),
                        Row(children: [
                          for (var i = 0; i < 5; i++) ...[
                            if (i > 0) const SizedBox(width: 28),
                            Container(
                              width: 240,
                              height: 135,
                              decoration: BoxDecoration(
                                color: p.surface.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(22),
                                border: i == 0 ? Border.all(color: p.ring, width: 6) : null,
                              ),
                            ),
                          ],
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (paths.isNotEmpty)
          ValueListenableBuilder<int>(
            valueListenable: HomeSlides.index,
            builder: (context, i, _) {
              final cur = i % paths.length;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                FitText('الصورة ${Ar.n(cur + 1)} من ${Ar.n(paths.length)} · تتبدل كل ${_secs(s.cfg.i('home.slides.interval'))}', style: Fonts.body(18, p.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  for (var k = 0; k < 5; k++) ...[
                    if (k > 0) const SizedBox(width: 14),
                    Expanded(child: _Thumb(path: paths[(cur + k) % paths.length], current: k == 0)),
                  ],
                ]),
              ]);
            },
          ),
      ]),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;
  final bool current;
  const _Thumb({required this.path, required this.current});

  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: current ? p.ring : Colors.transparent, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            Image.file(File(path), fit: BoxFit.cover, cacheWidth: 320, gaplessPlayback: true, errorBuilder: (_, __, ___) => ColoredBox(color: p.surface)),
            if (!current) ColoredBox(color: (p.night ? Colors.black : Colors.white).withValues(alpha: 0.35)),
          ]),
        ),
      ),
    );
  }
}

/// اختيار الصور: شبكة بتحديد متعدد، موافق يحدد أو يلغي.
class HomeSlidesPicker extends StatefulWidget {
  const HomeSlidesPicker({super.key});
  @override
  State<HomeSlidesPicker> createState() => _HomeSlidesPickerState();
}

class _HomeSlidesPickerState extends State<HomeSlidesPicker> {
  final _nodes = FocusNodes();
  bool _busy = false;

  @override
  void dispose() {
    _nodes.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final s = AppState.I;
    setState(() => _busy = true);
    final ok = await NativeBridge.requestStorage();
    if (!ok) {
      if (mounted) toast(context, 'لازم توافق على صلاحية الوصول للملفات حتى نستورد الصور');
      setState(() => _busy = false);
      return;
    }
    final n = await NativeBridge.importImages();
    await s.refreshWallpapers();
    if (!mounted) return;
    setState(() => _busy = false);
    toast(context, n > 0 ? 'تم استيراد ${Ar.n(n)} صورة' : 'ما لگيت صور جديدة بالفلاشة');
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final p = s.palette;
          final walls = s.wallpapers;
          final picked = HomeSlides.paths().toSet();
          final allOn = walls.isNotEmpty && picked.length == walls.length;
          return Padding(
            padding: const EdgeInsets.fromLTRB(96, 60, 96, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: AppIcon(Lu.images, color: p.accent, size: 34),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FitText('اختيار الصور', style: Fonts.title(44, p.ink)),
                    FitText('${Ar.n(picked.length)} من ${Ar.n(walls.length)} صورة مختارة · موافق للتحديد والإلغاء', style: Fonts.body(21, p.muted)),
                  ]),
                ),
                if (_busy) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: RawnaqLoader(size: 56)),
                PillButton(allOn ? 'إلغاء الكل' : 'تحديد الكل', icon: Lu.circleCheck, onTap: () => HomeSlides.setAll(!allOn)),
                const SizedBox(width: 16),
                PillButton('من الفلاشة', icon: Lu.usb, onTap: _busy ? () {} : _import),
                const SizedBox(width: 16),
                PillButton('المكتبة', icon: Lu.images, onTap: () => Navigator.push(context, fade(const WallLibraryScreen()))),
                const SizedBox(width: 16),
                PillButton('تم', primary: true, onTap: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 28),
              Expanded(
                child: walls.isEmpty
                    ? Center(
                        child: FitText('ما بيه صور بعد. ضيفها من الفلاشة أو من المكتبة', alignment: Alignment.center, style: Fonts.body(26, p.muted)),
                      )
                    : LayoutBuilder(builder: (context, box) {
                        const cols = 4, gap = 32.0, bleed = 30.0;
                        final w = (box.maxWidth - bleed * 2 - gap * (cols - 1)) / cols;
                        final h = w * 9 / 16;
                        final dpr = MediaQuery.devicePixelRatioOf(context);
                        return AxisClip(
                          axis: Axis.vertical,
                          child: SingleChildScrollView(
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.all(bleed),
                            child: Wrap(spacing: gap, runSpacing: gap, children: [
                              for (final (i, path) in walls.indexed)
                                FocusTap(
                                  key: ValueKey(path),
                                  focusNode: _nodes.of(path),
                                  autofocus: i == 0,
                                  onKey: (e) => gridNav(e, index: i, count: walls.length, cols: cols, focus: (j) => _nodes.focus(walls[j])),
                                  onTap: () => HomeSlides.toggle(path),
                                  builder: (context, f) {
                                    final on = picked.contains(path);
                                    return AnimatedScale(
                                      scale: f ? 1.05 : 1,
                                      duration: s.anim(180),
                                      child: Container(
                                        width: w,
                                        height: h,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(color: f ? p.ring : p.line, width: f ? 4 : 1, strokeAlign: BorderSide.strokeAlignOutside),
                                          boxShadow: royalShadows(p, f) ?? const [],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(22),
                                          child: Stack(fit: StackFit.expand, children: [
                                            Image.file(
                                              File(path),
                                              fit: BoxFit.cover,
                                              cacheWidth: (w * dpr * 1.1).round(),
                                              gaplessPlayback: true,
                                              frameBuilder: brandImageFrame(background: p.surface, size: 56),
                                              errorBuilder: (_, __, ___) => ColoredBox(color: p.surface, child: Center(child: AppIcon(Lu.imageOff, color: p.muted, size: 44))),
                                            ),
                                            if (!on) ColoredBox(color: (p.night ? Colors.black : Colors.white).withValues(alpha: 0.5)),
                                            Positioned(
                                              top: 16,
                                              right: 16,
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: on ? p.ring : Colors.black.withValues(alpha: 0.25),
                                                  border: on ? null : Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                                                ),
                                                child: on ? AppIcon(Lu.check, color: p.night ? const Color(0xFF1E1606) : Colors.white, size: 26) : null,
                                              ),
                                            ),
                                          ]),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ]),
                          ),
                        );
                      }),
              ),
              const SizedBox(height: 12),
              const KeyGuide(),
            ]),
          );
        },
      ),
    );
  }
}


/// فئات مكتبة رونق اللي تطلع بالواجهة.
class HomeSlidesCats extends StatelessWidget {
  const HomeSlidesCats({super.key});

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final raw = s.cfg.s('home.slides.cats').split(',').where((e) => e.isNotEmpty).toSet();
      final enabled = WallpaperFetcher.enabled();
      final chosen = raw.isEmpty ? enabled.map((e) => e.id).toSet() : raw;
      void flip(String id) {
        final next = {...chosen};
        if (!next.remove(id)) next.add(id);
        final all = enabled.every((e) => next.contains(e.id));
        s.set('home.slides.cats', all ? '' : WallCategory.all.where((x) => next.contains(x.id)).map((x) => x.id).join(','));
      }

      return SysScaffold(
        title: 'فئات صور الواجهة',
        sub: 'من مكتبة رونق، والصور الجديدة تنضاف وحدها لما تتجدد',
        icon: Lu.grid,
        // عمودين حتى تبين الفئات العشرة بلا تمرير (فيكما)
        right: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final col in [0, 1]) ...[
              if (col == 1) const SizedBox(width: 28),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, cat) in enabled.indexed)
                    if ((i < (enabled.length + 1) ~/ 2) == (col == 0))
                      SysRow(
                        icon: cat.icon,
                        title: cat.name,
                        sub: '${Ar.n(HomeSlides.countIn(cat.id))} صورة',
                        toggle: chosen.contains(cat.id),
                        autofocus: i == 0,
                        onTap: () => flip(cat.id),
                      ),
                ]),
              ),
            ],
          ]),
          if (enabled.length < WallCategory.all.length)
            SysRow(icon: Lu.plus, title: 'فئات ثانية', sub: 'تتفعل من مكتبة رونق', onTap: () => Navigator.push(context, fade(const WallLibraryScreen()))),
        ],
      );
    });
  }
}
