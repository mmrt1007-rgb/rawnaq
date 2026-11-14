import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_tile.dart';
import '../arabic.dart';
import '../lucide.dart';
import '../platform.dart';
import '../state.dart';
import '../widgets.dart';

/// تخصيص تطبيق واحد — نفس تصميم فيكما "تخصيص التطبيق":
/// لوحة خيارات عائمة يسار الشاشة (٨٦٠) + معاينة مكبّرة للبطاقة يمينها تتحدث مباشرة.
class AppEditScreen extends StatelessWidget {
  final String package;
  const AppEditScreen({super.key, required this.package});

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) => LayoutBuilder(builder: (context, box) {
          final s = AppState.I;
          const side = 112.0, gap = 96.0, panelW = 860.0;
          final previewW = math.max(320.0, box.maxWidth - side * 2 - gap - panelW);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: side, vertical: 40),
            // اتجاه الواجهة عربي: أول عنصر يمين (المعاينة)، والثاني يسار (اللوحة) — مثل فيكما
            child: Row(children: [
              SizedBox(width: previewW, child: _Preview(package: package, width: previewW)),
              const SizedBox(width: gap),
              _Panel(package: package, width: panelW, maxHeight: box.maxHeight - 80, s: s),
            ]),
          );
        }),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String package;
  final double width, maxHeight;
  final AppState s;
  const _Panel({required this.package, required this.width, required this.maxHeight, required this.s});

  @override
  Widget build(BuildContext context) {
    final p = s.palette;
    final hasBanner = s.artOf(package)?.banner != null;
    final pos = s.favorites.indexOf(package);
    final artOptions = <(ArtMode, String)>[
      (ArtMode.auto, 'الرسمية (تلقائي)'),
      (ArtMode.icon, 'الأيقونة فقط'),
      if (hasBanner) (ArtMode.banner, 'بانر التلفزيون'),
    ];
    final art = s.artModeOf(package);
    final artLabel = artOptions.firstWhere((o) => o.$1 == art, orElse: () => artOptions.first).$2;
    final locked = s.locked.contains(package);
    final fav = s.isFavorite(package);

    final panel = GlassPanel(
      width: width,
      radius: BorderRadius.circular(36),
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight - 84),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FitText('تخصيص ${s.labelOf(package)}', style: Fonts.title(44, p.ink)),
          const SizedBox(height: 6),
          FitText(package, style: Fonts.body(20, p.muted, weight: FontWeight.w300)),
          const SizedBox(height: 24),
          Flexible(
            child: NavZone(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.all(5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _EditRow(
                  autofocus: true,
                  icon: Lu.type,
                  title: 'الاسم الظاهر',
                  value: s.labelOf(package),
                  onTap: () async {
                    final v = await promptText(context, title: 'الاسم الظاهر', initial: s.labelOf(package));
                    if (v != null && v.trim().isNotEmpty) s.customize(package, label: v.trim());
                  },
                ),
                _EditRow(
                  icon: Lu.image,
                  title: 'الصورة',
                  value: artLabel,
                  onTap: () => showChoicePicker<ArtMode>(
                    context,
                    title: 'الصورة',
                    options: artOptions,
                    value: art,
                    onChanged: (v) => s.customize(package, art: v),
                  ),
                ),
                _EditRow(
                  icon: Lu.lock,
                  title: 'قفل برمز (للأطفال)',
                  value: locked ? 'مفعّل' : 'مطفأ',
                  onTap: () async {
                    if (locked && !await askPin(context, title: 'أدخل الرمز لفك القفل')) return;
                    s.customize(package, lock: !locked);
                  },
                ),
                _EditRow(
                  icon: Lu.house,
                  title: 'يظهر بالواجهة',
                  value: fav ? 'نعم' : 'لا',
                  onTap: () => s.toggleFavorite(package),
                ),
                if (pos >= 0)
                  _EditRow(
                    icon: Lu.move,
                    title: 'الموضع بالواجهة',
                    value: '${Ar.n(pos + 1)} من ${Ar.n(s.favorites.length)}',
                    onTap: () => showStepEditor(
                      context,
                      title: 'الموضع بالواجهة',
                      value: pos.toDouble(),
                      min: 0,
                      max: math.max(0.0, (s.favorites.length - 1).toDouble()),
                      step: 1,
                      format: (v) => '${Ar.n(v.round() + 1)} من ${Ar.n(s.favorites.length)}',
                      onChanged: (v) {
                        final now = s.favorites.indexOf(package);
                        if (now >= 0) s.move(package, v.round() - now);
                      },
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          // صف الإجراءات: ◀▶ تختار الزر، موافق ينفّذه
          ActionRow([
            Act('حفظ', () => Navigator.pop(context), primary: true),
            Act('إعادة للأصل', () => s.resetApp(package), icon: Lu.rotateCcw),
            Act('معلومات التطبيق', () => NativeBridge.appInfo(package), icon: Lu.info),
            Act('إلغاء التثبيت', () => NativeBridge.uninstall(package), icon: Lu.trash, danger: true),
          ]),
              ]),
            ),
          ),
        ]),
      ),
    );
    if (p.glass) return panel;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.35 : 0.12), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: panel,
    );
  }
}

/// صف خيار: مربع أيقونة بلون الثيم + العنوان + القيمة بكبسولة.
/// الإطار الذهبي يُرسم برا الصف فما يتحرك أي شي عند التركيز.
class _EditRow extends StatelessWidget {
  final Object icon;
  final String title, value;
  final VoidCallback onTap;
  final bool autofocus;
  const _EditRow({required this.icon, required this.title, required this.value, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return FocusTap(
      autofocus: autofocus,
      onTap: onTap,
      builder: (context, f) => AnimatedContainer(
        duration: AppState.I.anim(160),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        decoration: BoxDecoration(
          color: p.glass ? Colors.black.withValues(alpha: p.night ? 0.18 : 0.05) : p.bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.line, width: 1.5),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: f ? p.ring : Colors.transparent,
            width: 4,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(14)),
            child: AppIcon(icon, color: p.onAccent, size: 26),
          ),
          const SizedBox(width: 18),
          Expanded(child: FitText(title, style: Fonts.body(24, p.ink))),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: p.glass ? Colors.white.withValues(alpha: p.night ? 0.06 : 0.4) : p.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.line),
              ),
              child: FitText(value, style: Fonts.body(20, p.accent, weight: FontWeight.w500)),
            ),
          ),
          const SizedBox(width: 10),
          AppIcon(Lu.chevronLeft, color: f ? p.accent : p.muted, size: 26),
        ]),
      ),
    );
  }
}

/// المعاينة: البطاقة مكبّرة ومحددة بالإطار الذهبي، واسمها تحتها بخط العناوين.
class _Preview extends StatelessWidget {
  final String package;
  final double width;
  const _Preview({required this.package, required this.width});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final pos = s.favorites.indexOf(package);
    final ratio = TileMetrics.ratioFor(s.cfg.s('tile.style'));
    // البطاقة بأقصى حجم يدخل بدون قص: عرض ٧٢٠ للبانر، و٤٠٥ للمربع والدائرة
    final fs = s.cfg.d('tile.focusScale');
    var w = math.min(720.0, width / fs - 40);
    if (ratio == 1) w = math.min(w, 405.0);
    final m = TileMetrics(w, labels: 'none');
    final kicker = pos < 0 ? 'غير موجود بالواجهة' : (pos == 0 ? 'الأول بالواجهة' : 'رقم ${Ar.n(pos + 1)} بالواجهة');
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(kicker, style: Fonts.body(22, p.accent, weight: FontWeight.w500)),
      SizedBox(height: 28 + m.bleed),
      AppTile(package: package, m: m, focused: true),
      SizedBox(height: 28 + m.bleed),
      SizedBox(width: width, child: FitText(s.labelOf(package), alignment: Alignment.center, style: Fonts.title(40, p.ink))),
      const SizedBox(height: 10),
      SizedBox(
        width: width,
        child: FitText('معاينة مباشرة — أي تغيير يظهر هنا فوراً',
            alignment: Alignment.center, style: Fonts.body(22, p.muted, weight: FontWeight.w300)),
      ),
    ]);
  }
}
