import 'package:flutter/material.dart';

import '../arabic.dart';
import '../lucide.dart';
import '../starfield.dart';
import '../state.dart';
import '../widgets.dart';
import 'screensaver.dart';

/// أنماط شاشة السكون الجاهزة: المعرّف، الاسم، الأيقونة، لونا البطاقة.
const saverStyles = <(String, String, Lu, Color, Color)>[
  ('stars', 'النجوم', Lu.moon, Color(0xFF0E3226), Color(0xFF020806)),
  ('elegant', 'الأنيقة', Lu.image, Color(0xFF3D6F99), Color(0xFF0E1F2E)),
  ('aurora', 'الشفق', Lu.sun, Color(0xFF7E4A8E), Color(0xFF1B0F2E)),
  ('clock', 'الساعة فقط', Lu.clock, Color(0xFF1A1A1A), Color(0xFF000000)),
  ('photos', 'عرض الصور', Lu.images, Color(0xFFA87A2E), Color(0xFF2A1A08)),
];

/// يطبّق نمط شاشة سكون جاهز (الخلفية + التخطيط) بضغطة.
void applySaverStyle(String id) {
  final s = AppState.I;
  final walls = s.wallpapers.isNotEmpty;
  final (bg, layout, art) = switch (id) {
    'elegant' => (walls ? 'slideshow' : 'art', 'elegant', 'dunes'),
    'aurora' => ('art', 'calm', 'orbs'),
    'clock' => ('black', 'minimal', s.cfg.s('saver.art')),
    'photos' => (walls ? 'slideshow' : 'art', 'stack', 'waves'),
    _ => ('stars', 'calm', s.cfg.s('saver.art')),
  };
  s.cfg.set('saver.bg', bg);
  s.cfg.set('saver.layout', layout);
  s.cfg.set('saver.art', art);
  s.set('saver.style', id);
}

/// معرض شاشات السكون — تصميم فيكما "معرض شاشات السكون":
/// معاينة حيّة كبيرة يسار، ولوحة تحكم يمين أولها صف الأنماط.
/// التنقل موحّد: ▲▼ بين الصفوف، ◀▶ لاختيار النمط أو تعديل القيمة، موافق يطبّق، رجوع يطلع.
class SaverGalleryScreen extends StatefulWidget {
  const SaverGalleryScreen({super.key});

  @override
  State<SaverGalleryScreen> createState() => _SaverGalleryScreenState();
}

class _SaverGalleryScreenState extends State<SaverGalleryScreen> {
  final _panel = FocusScopeNode(debugLabel: 'saver-panel');

  @override
  void dispose() {
    _panel.dispose();
    super.dispose();
  }

  AppState get s => AppState.I;

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = s.palette;
          final c = s.cfg;
          final current = c.s('saver.style');
          return Padding(
            padding: const EdgeInsets.fromLTRB(112, 64, 112, 56),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('شاشة السكون', style: Fonts.title(52, p.ink)),
              const SizedBox(height: 6),
              FitText('اختر النمط وعدّل حركته — المعاينة حيّة وتتغير مع كل خيار',
                  style: Fonts.body(24, p.muted, weight: FontWeight.w300)),
              const SizedBox(height: 32),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // ---------- لوحة التحكم (يمين) ----------
                  SizedBox(
                    width: 600,
                    child: GlassPanel(
                      radius: BorderRadius.circular(32),
                      padding: const EdgeInsets.all(28),
                      child: NavZone(
                        node: _panel,
                        child: SingleChildScrollView(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.all(5),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _controls(context, current)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                  // ---------- المعاينة (يسار) ----------
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final h = (box.maxHeight - 120).clamp(200.0, box.maxWidth * 9 / 16);
                      final w = h * 16 / 9;
                      final st = saverStyles.firstWhere((x) => x.$1 == current, orElse: () => saverStyles.first);
                      return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        _preview(w, h),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: w,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(st.$2, style: Fonts.title(34, p.ink)),
                            const SizedBox(height: 4),
                            FitText(_describe(st.$1), style: Fonts.body(21, p.muted, weight: FontWeight.w300)),
                          ]),
                        ),
                      ]);
                    }),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  static String _describe(String id) => switch (id) {
        'elegant' => 'صورة كاملة بتظليل سينمائي، والساعة بالزاوية والمواقيت خط زمني',
        'aurora' => 'ألوان ناعمة تتحرك ببطء، والساعة بالوسط',
        'clock' => 'شاشة سوداء وساعة فقط — أهدأ نمط وأوفر للطاقة',
        'photos' => 'صور المكتبة تتبدل كل فترة تختارها (من ٥ ثواني)',
        _ => 'سماء نجوم حيّة بثلاث طبقات عمق، والساعة بالوسط',
      };

  Widget _preview(double w, double h) {
    final p = s.palette;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.line, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 50, offset: const Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(fit: StackFit.expand, children: [
          const FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: 1920, height: 1080, child: ScreensaverScreen(preview: true)),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF3DBE8C), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('معاينة مباشرة', style: Fonts.body(18, Colors.white, weight: FontWeight.w500)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _controls(BuildContext context, String current) {
    final p = s.palette;
    final c = s.cfg;
    final stars = c.s('saver.bg') == 'stars';
    return [
      SelectorRow<String>(
        key: const ValueKey('saver-styles'),
        autofocus: true,
        title: 'النمط',
        values: [for (final x in saverStyles) x.$1],
        selected: current,
        onSelect: applySaverStyle,
        spacing: 12,
        itemBuilder: (context, id, hi, sel) => _StyleCard(style: saverStyles.firstWhere((x) => x.$1 == id), selected: sel, focused: hi, width: 96),
      ),
      SectionTitle(stars ? 'حركة النجوم' : 'الخيارات'),
      if (stars) ...[
        cStepInt('الكثافة', 'saver.stars.density', 80, 500, (v) => '${Ar.n(v)} نجمة', step: 20),
        cStep('سرعة الانجراف', 'saver.stars.speed', 0, 1, 0.05, (v) => v < 0.15 ? 'ساكنة تقريباً' : v < 0.35 ? 'هادئة جداً' : v < 0.6 ? 'هادئة' : v < 0.85 ? 'متوسطة' : 'سريعة'),
        cStep('التلألؤ', 'saver.stars.twinkle', 0, 1, 0.05, (v) => v < 0.05 ? 'بدون' : v < 0.35 ? 'خفيف' : v < 0.7 ? 'ناعم' : 'واضح'),
        cChoice<int>('الشهب', 'saver.stars.shooting', const [(0, 'بدون'), (30, 'كل نص دقيقة تقريباً'), (60, 'كل دقيقة تقريباً'), (180, 'نادرة')]),
        cChoice<int>('عمق الطبقات', 'saver.stars.layers', const [(1, 'طبقة وحدة'), (2, 'طبقتين'), (3, '٣ طبقات')]),
        cStep('توهج السديم', 'saver.stars.nebula', 0, 0.5, 0.05, fmtPct),
        ChoiceRow<String>(
          key: const ValueKey('sky'),
          title: 'ألوان السماء',
          value: c.s('saver.stars.palette'),
          options: [for (final sp in SkyPalette.all) (sp.id, sp.name)],
          onChanged: (v) => s.set('saver.stars.palette', v),
        ),
      ] else ...[
        if (c.s('saver.bg') == 'image' || c.s('saver.bg') == 'slideshow') ...[
          cStep('تعتيم الصورة', 'saver.dim', 0, 0.85, 0.05, fmtPct),
        cStepInt('مدة كل صورة بالعرض', 'saver.interval', 5, 600, (v) => v < 60 ? '${Ar.n(v)} ثانية' : '${Ar.n(v ~/ 60)} د ${v % 60 == 0 ? '' : '${Ar.n(v % 60)} ث'}', step: 5),
          cToggle('حركة تقريب بطيئة', 'saver.kenburns'),
        ],
        cFont('خط الساعة', 'saver.font'),
        cStep('حجم الساعة', 'saver.clockSize', 120, 520, 4, fmtPx),
      ],
      SectionTitle('العناصر'),
      cToggle('التاريخ الهجري', 'saver.showHijri'),
      cToggle('الطقس', 'saver.showWeather'),
      cToggle('الوقت القادم للصلاة', 'saver.showNextPrayer'),
      cChoice<int>('تشتغل بعد', 'saver.minutes', const [(0, 'معطلة'), (1, 'دقيقة'), (2, 'دقيقتين'), (5, '٥ دقائق'), (10, '١٠ دقائق'), (15, '١٥ دقيقة'), (30, '٣٠ دقيقة'), (60, 'ساعة')]),
      const SizedBox(height: 8),
      PillButton('تشغيل الآن', icon: Lu.play, primary: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreensaverScreen()))),
    ];
  }
}

class _StyleCard extends StatelessWidget {
  final (String, String, Lu, Color, Color) style;
  final bool selected, focused;
  final double width;
  const _StyleCard({required this.style, required this.selected, required this.focused, required this.width});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final h = width * 104 / 184;
    return SizedBox(
      width: width,
      child: Column(children: [
        AnimatedScale(
          scale: focused ? 1.06 : 1,
          duration: AppState.I.anim(160),
          child: Container(
            width: width,
            height: h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [style.$4, style.$5]),
              border: Border.all(
                color: focused ? p.ring : (selected ? p.accent : Colors.white.withValues(alpha: 0.08)),
                width: focused ? ringW : (selected ? 3 : 1),
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              boxShadow: focused ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))] : const [],
            ),
            child: AppIcon(style.$3, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 12),
        FitText(style.$2,
            alignment: Alignment.center,
            style: Fonts.body(20, selected || focused ? p.ink : p.muted, weight: selected ? FontWeight.w600 : null)),
      ]),
    );
  }
}
