import 'package:flutter/material.dart';

import '../app_tile.dart';
import '../arabic.dart';
import '../platform.dart';
import '../state.dart';
import '../widgets.dart';
import 'app_edit.dart';
import '../lucide.dart';

/// كل التطبيقات المثبتة.
/// [pickMode] = true: الضغط يضيف أو يشيل من الواجهة.
/// [pickMode] = false: الضغط يفتح التطبيق، والضغطة الطويلة للخيارات.
class AppsScreen extends StatefulWidget {
  final bool pickMode;
  const AppsScreen({super.key, required this.pickMode});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _nodes = FocusNodes();
  bool get pickMode => widget.pickMode;

  @override
  void dispose() {
    _nodes.dispose();
    super.dispose();
  }

  Future<void> _open(BuildContext context, String pkg) async {
    final s = AppState.I;
    if (s.locked.contains(pkg) && !await askPin(context, title: 'هذا التطبيق مقفل')) return;
    await NativeBridge.launch(pkg);
  }

  void _options(BuildContext context, String pkg) {
    final s = AppState.I;
    showActions(context, s.labelOf(pkg), [
      ('فتح', Lu.play, () => _open(context, pkg), false),
      (
        s.isFavorite(pkg) ? 'إزالة من الواجهة' : 'إضافة إلى الواجهة',
        s.isFavorite(pkg) ? Lu.circleMinus : Lu.pin,
        () => s.toggleFavorite(pkg),
        false
      ),
      ('تخصيص', Lu.sliders, () => Navigator.push(context, fade(AppEditScreen(package: pkg))), false),
      ('معلومات التطبيق', Lu.info, () => NativeBridge.appInfo(pkg), false),
      ('إلغاء التثبيت', Lu.trash, () => NativeBridge.uninstall(pkg), true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final p = s.palette;
          final apps = s.installed;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: s.cfg.d('home.padX'), vertical: s.cfg.d('home.padY')),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pickMode ? 'إضافة إلى الواجهة' : 'كل التطبيقات', style: Fonts.title(52, p.ink)),
                    const SizedBox(height: 8),
                    FitText(
                      pickMode ? 'موافق يضيف التطبيق للواجهة أو يشيله · ضغطة طويلة للخيارات' : 'موافق للفتح · ضغطة طويلة للخيارات',
                      style: Fonts.body(24, p.muted),
                    ),
                  ]),
                ),
                Text('${Ar.n(s.favorites.length)} بالواجهة · ${Ar.n(apps.length)} مثبت', style: Fonts.body(22, p.muted)),
                const SizedBox(width: 24),
                if (pickMode) ...[
                  PillButton('ترتيب أبجدي', icon: Lu.sortAz, onTap: s.sortFavorites),
                  const SizedBox(width: 16),
                ],
                PillButton('تم', primary: true, onTap: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  const cols = 6;
                  final gap = s.cfg.d('tile.gap');
                  final fs = s.cfg.d('tile.focusScale');
                  var w = (box.maxWidth - gap * (cols - 1)) / cols;
                  final bleed = w * (fs - 1) / 2 + s.cfg.d('tile.ringWidth') + 14;
                  w = (box.maxWidth - bleed * 2 - gap * (cols - 1)) / cols;
                  final m = TileMetrics(w);
                  return SingleChildScrollView(
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.all(m.bleed),
                    child: Wrap(spacing: gap, runSpacing: gap, children: [
                      for (final (i, a) in apps.indexed)
                        FocusTap(
                          key: ValueKey(a.package),
                          focusNode: _nodes.of(a.package),
                          autofocus: i == 0,
                          onKey: (e) => gridNav(e, index: i, count: apps.length, cols: cols, focus: (j) => _nodes.focus(apps[j].package)),
                          onTap: () {
                            if (pickMode) {
                              s.toggleFavorite(a.package);
                            } else {
                              _open(context, a.package);
                            }
                          },
                          onLongPress: () => _options(context, a.package),
                          // بوضع الاختيار: الموجود بالواجهة واضح وعليه ✓، والباقي شفاف لحد ما يتحدد
                          builder: (context, f) => AnimatedOpacity(
                            opacity: pickMode && !f && !s.isFavorite(a.package) ? 0.62 : 1,
                            duration: s.anim(160),
                            child: AppTile(
                              package: a.package,
                              m: m,
                              focused: f,
                              selected: pickMode && s.isFavorite(a.package),
                            ),
                          ),
                        ),
                    ]),
                  );
                }),
              ),
              if (pickMode)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Text('علامة ✓: ظاهر بالواجهة', style: Fonts.body(20, p.muted, weight: FontWeight.w300)),
                    const SizedBox(width: 28),
                    Text('الشفاف: غير موجود بالواجهة', style: Fonts.body(20, p.muted, weight: FontWeight.w300)),
                  ]),
                ),
            ]),
          );
        },
      ),
    );
  }
}
