import 'dart:io';

import 'package:flutter/material.dart';

import '../arabic.dart';
import '../platform.dart';
import '../state.dart';
import '../widgets.dart';
import 'wall_library.dart';
import '../lucide.dart';
import '../brand.dart';

/// إدارة الخلفيات: معاينة، تعيين للواجهة أو لشاشة السكون، حذف، واستيراد من الفلاشة.
/// إذا [pickFor] محدد (مفتاح إعداد) فالضغط على الصورة يختارها مباشرة.
class WallpapersScreen extends StatefulWidget {
  final String? pickFor;
  const WallpapersScreen({super.key, this.pickFor});

  @override
  State<WallpapersScreen> createState() => _WallpapersScreenState();
}

class _WallpapersScreenState extends State<WallpapersScreen> {
  bool _busy = false;
  final _nodes = FocusNodes();

  @override
  void dispose() {
    _nodes.dispose();
    super.dispose();
  }

  AppState get s => AppState.I;

  Future<void> _import() async {
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
    toast(context, n > 0 ? 'تم استيراد ${Ar.n(n)} صورة' : 'ما لكيت صور جديدة بالفلاشة أو الذاكرة');
  }

  void _select(String path, int index) {
    final key = widget.pickFor;
    if (key != null) {
      s.set(key, path);
      s.set(key == 'home.image' ? 'home.bg' : 'saver.bg', 'image');
      Navigator.pop(context);
      return;
    }
    // نفس فيكما: لوحة خيارات صغيرة بالزاوية اليسرى السفلى بدل نافذة بالوسط
    showActions(context, 'صورة ${Ar.n(index + 1)}', align: Alignment.bottomLeft, width: 600, inset: const EdgeInsets.fromLTRB(112, 56, 112, 56), [
      ('تعيين لشاشة السكون', Lu.moon, () {
        s.set('saver.image', path);
        s.set('saver.bg', 'image');
      }, false),
      ('تعيين لخلفية الواجهة', Lu.house, () {
        s.set('home.image', path);
        s.set('home.bg', 'image');
      }, false),
      ('عرض كل الصور بشاشة السكون', Lu.presentation, () => s.set('saver.bg', 'slideshow'), false),
      ('حذف الصورة', Lu.trash, () => s.deleteWallpaper(path), true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = s.palette;
          final walls = s.wallpapers;
          final selected = {s.cfg.s('home.image'), s.cfg.s('saver.image')};
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: s.cfg.d('home.padX'), vertical: s.cfg.d('home.padY')),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.pickFor == null ? 'الخلفيات' : 'اختر صورة', style: Fonts.title(52, p.ink)),
                    const SizedBox(height: 6),
                    FitText(
                      '${Ar.n(walls.length)} صورة · يُفضّل دقة 4K (${Ar.n(3840)}×${Ar.n(2160)}) · تجديد تلقائي ${s.cfg.b('walls.auto') && s.cfg.i('walls.days') > 0 ? 'مفعّل' : 'متوقف'}',
                      style: Fonts.body(24, p.muted, weight: FontWeight.w300),
                    ),
                  ]),
                ),
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const RawnaqLoader(size: 64),
                  ),
                PillButton('المكتبة', icon: Lu.images, onTap: () => Navigator.push(context, fade(const WallLibraryScreen()))),
                const SizedBox(width: 16),
                PillButton('استيراد من الفلاشة', icon: Lu.usb, onTap: _busy ? () {} : _import),
                const SizedBox(width: 16),
                PillButton('تحديث', icon: Lu.refresh, onTap: s.refreshWallpapers),
                const SizedBox(width: 16),
                PillButton('تم', primary: true, onTap: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 28),
              Expanded(
                child: walls.isEmpty
                    ? Center(
                        child: Text(
                          'ما بيه صور بعد.\n'
                          'من الحاسبة: حط الصور بمجلد wallpapers جنب install.bat وشغّله.\n'
                          'أو ركّب فلاشة بيها صور واضغط "استيراد من الفلاشة".',
                          textAlign: TextAlign.center,
                          style: Fonts.body(26, p.muted),
                        ),
                      )
                    : LayoutBuilder(builder: (context, box) {
                        const cols = 4;
                        const gap = 32.0;
                        const bleed = 30.0; // يكفي للتكبير ١٫٠٦ + الإطار الذهبي + الظل بدون قص
                        final w = (box.maxWidth - bleed * 2 - gap * (cols - 1)) / cols;
                        final h = w * 9 / 16;
                        final dpr = MediaQuery.devicePixelRatioOf(context);
                        return SingleChildScrollView(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.all(bleed),
                          child: Wrap(spacing: gap, runSpacing: gap, children: [
                            for (final (i, path) in walls.indexed)
                              FocusTap(
                                key: ValueKey(path),
                                focusNode: _nodes.of(path),
                                autofocus: i == 0,
                                onKey: (e) => gridNav(e, index: i, count: walls.length, cols: cols, focus: (j) => _nodes.focus(walls[j])),
                                onTap: () => _select(path, i),
                                builder: (context, f) => AnimatedScale(
                                  scale: f ? 1.06 : 1,
                                  duration: s.anim(180),
                                  child: Container(
                                    width: w,
                                    height: h,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: f ? p.ring : (selected.contains(path) ? p.accent : Colors.transparent),
                                        width: f ? 5 : 3,
                                        strokeAlign: BorderSide.strokeAlignOutside,
                                      ),
                                      boxShadow: f
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.45 : 0.3), blurRadius: 36, offset: const Offset(0, 16))]
                                          : const [],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: Stack(fit: StackFit.expand, children: [
                                        Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                          cacheWidth: (w * dpr * 1.1).round(),
                                          gaplessPlayback: true,
                                          frameBuilder: brandImageFrame(background: p.surface, size: 64),
                                          errorBuilder: (_, __, ___) => ColoredBox(
                                            color: p.surface,
                                            child: Center(child: AppIcon(Lu.imageOff, color: p.muted, size: 48)),
                                          ),
                                        ),
                                        if (_is4k(path)) Positioned(
                                            top: 14,
                                            right: 14,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 120),
                                              child: _chip('4K', Colors.black.withValues(alpha: 0.38), Colors.white),
                                            ),
                                          ),
                                        if (_usage(path).isNotEmpty)
                                          Positioned(
                                            left: 14,
                                            bottom: 14,
                                            right: 70,
                                            child: Align(
                                              alignment: Alignment.bottomLeft,
                                              child: _chip(_usage(path), p.accent, p.onAccent, icon: Lu.check),
                                            ),
                                          ),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                        );
                      }),
              ),
            ]),
          );
        },
      ),
    );
  }

  /// صور 4K: المسحوبة تلقائياً (٣٨٤٠×٢١٦٠) أو اللي اسمها يدل عليها.
  bool _is4k(String path) {
    final n = path.split('/').last.toLowerCase();
    return n.startsWith('auto-') || n.contains('4k') || n.contains('3840') || n.contains('2160');
  }

  /// وين مستعملة الصورة حالياً.
  String _usage(String path) => [
        if (s.cfg.s('saver.image') == path) 'شاشة السكون',
        if (s.cfg.s('home.image') == path) 'الواجهة',
      ].join(' · ');

  Widget _chip(String text, Color bg, Color fg, {Object? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: FitText(text, style: Fonts.body(16, fg, weight: FontWeight.w600))),
          if (icon != null) ...[const SizedBox(width: 8), AppIcon(icon, color: fg, size: 18)],
        ]),
      );
}
