import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_tile.dart';
import '../arabic.dart';
import '../config.dart';
import '../lucide.dart';
import '../brand.dart';
import '../palette.dart';
import '../prayer.dart';
import '../prayer_view.dart';
import '../state.dart';
import '../wallpaper_fetcher.dart';
import '../widgets.dart';
import 'layout_gallery.dart';
import 'saver_gallery.dart';
import 'screensaver.dart';

const kAppVersion = '5.0.1';

/// لوحة "معاينة حيّة" يسار الإعدادات — مطابقة لفيكما (٦٠٠×٩٣٦ عند x=48, y=72):
/// شريحة "معاينة حيّة" + اسم القسم، مسرح فيه معاينة حقيقية تتحدث لحظياً،
/// بطاقة بإطار ذهبي تشرح الخيار المحدد، وسطر "يتأثر:".
class SettingsPreview extends StatelessWidget {
  final int section;
  final String title;

  /// الثيم/النمط المحدد بصف البطاقات قبل التطبيق (معاينة بدون تطبيق).
  final ThemePreset? previewPreset;
  final String? previewStyle;

  const SettingsPreview({super.key, required this.section, required this.title, this.previewPreset, this.previewStyle});

  static const _affects = <List<String>>[
    ['الواجهة', 'الإعدادات', 'اللوحة السريعة'],
    ['كل النصوص', 'الساعة', 'شاشة السكون'],
    ['الشاشة الرئيسية'],
    ['الواجهة', 'كل التطبيقات'],
    ['شاشة السكون'],
    ['الواجهة', 'شاشة السكون', 'اللوحة السريعة'],
    ['الواجهة', 'شاشة السكون'],
    ['الواجهة', 'شاشة السكون'],
    ['كل الشاشات'],
    ['كل الشاشات'],
    ['النظام'],
    ['كل الشاشات', 'الواجهة', 'الإعدادات'],
    ['—'],
  ];

  static const _defaults = <(String, String)>[
    ('الثيم الملكي', 'اختر ثيماً باليمين واليسار وشوف ألوانه هنا قبل ما تطبّقه'),
    ('الخطوط', 'كل خط يظهر هنا بحجمه الحقيقي قبل وبعد التغيير'),
    ('ترتيب الواجهة', 'شكل الشاشة الرئيسية والعناصر الظاهرة فيها'),
    ('المربعات', 'شكل وحجم مربعات التطبيقات والتركيز عليها'),
    ('شاشة السكون', 'المعاينة تتحرك مثل الشاشة الحقيقية'),
    ('مواقيت الصلاة', 'الأوقات تتحدث بكل مكان مع أي تعديل'),
    ('الخلفيات', 'صور 4K حقيقية من ويكيميديا كومنز وصورك الخاصة'),
    ('التاريخ والطقس', 'الميلادي والهجري والطقس كما تظهر بالواجهة'),
    ('الريموت والتنقل', 'أعلى وأسفل للتنقل · موافق للدخول · يمين ويسار للتعديل · رجوع للخروج'),
    ('إمكانية الوصول', 'حجم النص والتباين وإطار التركيز لراحة العين'),
    ('الشاشة والنظام', 'الشاشة المكتشفة تلقائياً وقدرات الجهاز'),
    ('الحركة والسرعة', 'المربعات بالمعاينة تتحرك بنفس أسلوب وسرعة الحركة المختارة'),
    ('حول رونق', 'الإصدار والحقوق والمصادر'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final i = section.clamp(0, _defaults.length - 1);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: p.glass ? p.surface : Color.lerp(p.bg, p.surface, 0.6),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: p.line, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 48,
          child: Row(children: [
            Expanded(child: FitText(title, style: Fonts.title(32, p.ink))),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.line)),
              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('معاينة حيّة', style: Fonts.body(17, p.ink)),
                const SizedBox(width: 8),
                Container(width: 9, height: 9, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
              ])),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        // المسرح
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: p.night ? Colors.black.withValues(alpha: 0.25) : p.bg, borderRadius: BorderRadius.circular(28)),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(22),
            child: ExcludeFocus(
              child: IgnorePointer(
                child: ValueListenableBuilder<String?>(
                  valueListenable: focusedKey,
                  builder: (context, k, _) => Center(child: _keyStage(k) ?? _stage(i, p)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // بطاقة الخيار المحدد
        ValueListenableBuilder<(String, String?)?>(
          valueListenable: focusedOption,
          builder: (context, opt, _) {
            final t = opt?.$1 ?? _defaults[i].$1;
            final sub = opt?.$2 ?? _defaults[i].$2;
            return Container(
              height: 112,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.ring, width: 2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                FitText(t, style: Fonts.body(25, p.ink, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Fonts.body(18, p.muted).copyWith(height: 1.35)),
              ]),
            );
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: Row(children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text('يتأثر:', style: Fonts.body(18, p.muted)))),
            const SizedBox(width: 10),
            for (final a in _affects[i]) ...[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: p.line)),
                  child: FitText(a, style: Fonts.body(16, p.ink)),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ),
      ]),
    );
  }

  /// معاينة خاصة بالخيار المحدد نفسه (لون معيّن، خط معيّن) بدل معاينة القسم العامة.
  Widget? _keyStage(String? k) {
    if (k == null) return null;
    final c = RegExp(r'^(day|night)\.(bg|surface|ink|muted|accent|ring|line)$').firstMatch(k);
    if (c != null) return _ColorKeyStage(mode: c.group(1)!, role: c.group(2)!);
    if (k == 'font.title' || k == 'font.ui' || k == 'font.clock') return _FontsStage(highlight: k);
    return null;
  }

  Widget _stage(int i, Palette p) => switch (i) {
        0 => _Appearance(preset: previewPreset, style: previewStyle),
        1 => const _FontsStage(),
        2 => const _HomeStage(),
        3 => const _TilesStage(),
        4 => const _SaverStage(),
        5 => const _PrayerStage(),
        6 => const _WallsStage(),
        7 => const _DateStage(),
        8 => const _RemoteStage(),
        9 => const _A11yStage(),
        10 => const _SystemStage(),
        11 => const _MotionStage(),
        _ => const _AboutStage(),
      };
}

// ───────────── عناصر مشتركة ─────────────

Widget _pill(String text, Palette p, {Object? icon, bool on = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: on ? p.accent.withValues(alpha: p.night ? 0.22 : 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: on ? p.accent : p.line),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[AppIcon(icon, color: on ? p.accent : p.muted, size: 18), const SizedBox(width: 6)],
        Text(text, style: Fonts.body(16, on ? p.ink : p.muted)),
      ])),
    );

/// مسرح بمقاس ثابت يصغر بدون قص إذا ضاقت المساحة.
// العرض ثابت والارتفاع حسب المحتوى، فإذا كبر النص (إمكانية الوصول) يصغر المسرح كله بدل ما ينقص.
Widget _fit(double w, double h, Widget child) => FittedBox(
      fit: BoxFit.scaleDown,
      child: ConstrainedBox(constraints: BoxConstraints(minHeight: h), child: SizedBox(width: w, child: child)),
    );

// ───────────── المظهر: واجهة مصغّرة بألوان الثيم + المسطرة ─────────────

class _Appearance extends StatelessWidget {
  final ThemePreset? preset;
  final String? style;
  const _Appearance({this.preset, this.style});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final night = p.night;
    Color c(String k) {
      final m = preset == null ? null : (night ? preset!.night : preset!.day);
      if (m != null) return Color(m[k]!);
      return switch (k) {
        'bg' => p.bg,
        'surface' => s.cfg.c('${night ? 'night' : 'day'}.surface'),
        'ink' => p.ink,
        'muted' => p.muted,
        'accent' => p.accent,
        'ring' => p.ring,
        _ => s.cfg.c('${night ? 'night' : 'day'}.line'),
      };
    }

    final clockFont = preset?.clockFont ?? s.cfg.s('font.clock');
    final bodyFont = preset?.bodyFont ?? s.cfg.s('font.ui');
    final name = preset?.name ?? ThemePreset.byId(s.cfg.s('theme.preset')).name;
    final tiles = [
      (Lu.play, const [Color(0xFFB3261E), Color(0xFF3A0A08)], 'يوتيوب'),
      (Lu.film, const [Color(0xFF2F4E7E), Color(0xFF101A2E)], ''),
      (Lu.tv, const [Color(0xFF0D5C45), Color(0xFF05140F)], ''),
      (Lu.house, const [Color(0xFF5E4A8E), Color(0xFF1C1826)], ''),
    ];
    const swatches = [('bg', 'الخلفية'), ('surface', 'الأسطح'), ('ink', 'النص'), ('muted', 'ثانوي'), ('accent', 'التمييز'), ('ring', 'التركيز'), ('line', 'الحدود')];
    return _fit(500, 470, Column(children: [
      Container(
        height: 280,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
        decoration: BoxDecoration(color: c('bg'), borderRadius: BorderRadius.circular(22), border: Border.all(color: c('line'))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('٩:٤٢', style: Fonts.family(clockFont, 54, c('ink'), weight: FontWeight.w700, height: 1.1)),
          Text('${Ar.dayName(s.now)} ${Ar.gregorian(s.now)}', style: Fonts.family(bodyFont, 15, c('muted'))),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (k, t) in tiles.indexed) ...[
              if (k > 0) const SizedBox(width: 14),
              Column(children: [
                Container(
                  width: 86,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: t.$2, begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(10),
                    border: k == 0 ? Border.all(color: c('ring'), width: 3, strokeAlign: BorderSide.strokeAlignOutside) : null,
                  ),
                  child: AppIcon(t.$1, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 6),
                SizedBox(height: 18, child: Text(t.$3, style: Fonts.family(bodyFont, 13, c('ink'), weight: FontWeight.w600))),
              ]),
            ],
          ]),
        ]),
      ),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final (k, label) in swatches)
          Column(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c(k),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: k == 'accent' ? c('ring') : c('line'), width: k == 'accent' ? 2.5 : 1),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: Fonts.body(13, p.muted)),
          ]),
      ]),
      const SizedBox(height: 22),
      _pill('$name · ${night ? 'ليلي' : 'نهاري'}${style != null ? ' · ${AppState.styleName(style!)}' : ''}', p, icon: Lu.crown, on: true),
    ]));
  }
}

// ───────────── الخطوط ─────────────

class _FontsStage extends StatelessWidget {
  final String? highlight;
  const _FontsStage({this.highlight});

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    Widget line(String label, String fam, Widget sample, [String? key]) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: key != null && key == highlight ? p.ring : p.line, width: key != null && key == highlight ? 3 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FitText('$label · ${FontCatalog.label(fam)}', style: Fonts.body(15, p.muted)),
            const SizedBox(height: 6),
            sample,
          ]),
        );
    return _fit(500, 470, Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      line('العناوين', s.cfg.s('font.title'), FitText('رونق', style: Fonts.title(44, p.accent)), 'font.title'),
      line('النصوص', s.cfg.s('font.ui'), FitText('واجهة أنيقة لكل يوم', style: Fonts.body(28, p.ink)), 'font.ui'),
      line('الساعة', s.cfg.s('font.clock'), FitText(Ar.time(s.now), style: Fonts.clock(70, p.ink)), 'font.clock'),
    ]));
  }
}

// ───────────── الواجهة الرئيسية ─────────────

class _HomeStage extends StatelessWidget {
  const _HomeStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final c = s.cfg;
    final layout = c.s('home.layout');
    final name = homeLayouts.firstWhere((x) => x.$1 == layout, orElse: () => homeLayouts.first).$2;
    final shown = [
      ('الاسم أعلى الشاشة', 'home.showBrand'),
      ('الساعة', 'home.showClock'),
      ('التاريخ الهجري', 'home.showHijri'),
      ('الطقس', 'home.showWeather'),
      ('مواقيت الصلاة', 'home.showPrayers'),
    ];
    return _fit(500, 470, Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(width: 500, height: 281, child: CustomPaint(painter: LayoutSketch(layout, p.night))),
      ),
      const SizedBox(height: 18),
      FitText('ترتيب الواجهة: $name', alignment: Alignment.center, style: Fonts.body(20, p.ink, weight: FontWeight.w600)),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        for (final (t, k) in shown) _pill(t, p, icon: c.b(k) ? Lu.eye : Lu.eyeOff, on: c.b(k)),
      ]),
    ]));
  }
}

// ───────────── المربعات: مربعات حقيقية بإعداداتك ─────────────

class _TilesStage extends StatelessWidget {
  const _TilesStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final c = s.cfg;
    final pkgs = s.favorites.take(3).toList();
    final m = TileMetrics(c.s('tile.style') == 'banner' ? 250 : 170);
    final labels = switch (c.s('tile.labels')) { 'focus' => 'عند التركيز', 'none' => 'بدون', _ => 'دائماً' };
    return _fit(820, 560, Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (pkgs.isEmpty)
        Text('اختر تطبيقات للواجهة حتى تظهر هنا', style: Fonts.body(26, p.muted))
      else
        Padding(
          padding: EdgeInsets.all(m.bleed),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, pkg) in pkgs.indexed) ...[
              if (i > 0) SizedBox(width: c.d('tile.gap') + m.bleed),
              AppTile(package: pkg, m: m, focused: i == (pkgs.length > 1 ? 1 : 0)),
            ],
          ]),
        ),
      const SizedBox(height: 28),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        _pill('الحجم ${Ar.n(c.d('tile.size').round())}', p),
        _pill('الاستدارة ${Ar.n(c.d('tile.radius').round())}', p),
        _pill('التكبير ${Ar.n((c.d('tile.focusScale') * 100).round())}٪', p),
        _pill('الأسماء: $labels', p),
      ]),
    ]));
  }
}

// ───────────── شاشة السكون الحقيقية مصغّرة ─────────────

class _SaverStage extends StatelessWidget {
  const _SaverStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final style = saverStyles.firstWhere((x) => x.$1 == s.cfg.s('saver.style'), orElse: () => saverStyles.first).$2;
    return _fit(500, 400, Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          width: 500,
          height: 281,
          child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 1920, height: 1080, child: ScreensaverScreen(preview: true))),
        ),
      ),
      const SizedBox(height: 22),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _pill('النمط: $style', p, icon: Lu.monitorPlay, on: true),
        _pill(s.cfg.i('saver.minutes') == 0 ? 'معطلة' : 'بعد ${Ar.n(s.cfg.i('saver.minutes'))} د', p, icon: Lu.timer),
      ]),
    ]));
  }
}

// ───────────── المواقيت ─────────────

class _PrayerStage extends StatelessWidget {
  const _PrayerStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final c = s.cfg;
    return _fit(520, 380, Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FitText('${PrayerCity.byId(c.s('prayer.city')).label} · ${Ar.dayName(s.now)} ${Ar.hijri(s.now, c.i('misc.hijriOffset'))}',
          alignment: Alignment.center, style: Fonts.body(18, p.muted)),
      const SizedBox(height: 24),
      PrayerStrip(size: 22, font: c.s('font.ui'), ink: p.ink, muted: p.muted, accent: p.accent, chip: p.surface, alignment: WrapAlignment.center),
      const SizedBox(height: 26),
      Center(child: NextPrayerLine(size: 24, font: c.s('font.ui'), ink: p.ink, accent: p.accent)),
    ]));
  }
}

// ───────────── الخلفيات: صورك الحقيقية ─────────────

class _WallsStage extends StatelessWidget {
  const _WallsStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final imgs = s.wallpapers.take(6).toList();
    final cats = WallpaperFetcher.enabled();
    return _fit(500, 440, Column(children: [
      SizedBox(
        height: 300,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 16 / 9,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 6; i++)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: i < imgs.length
                    ? Image.file(File(imgs[i]), fit: BoxFit.cover, cacheWidth: 320, frameBuilder: brandImageFrame(size: 40), errorBuilder: (_, __, ___) => ColoredBox(color: p.surface))
                    : DecoratedBox(
                        decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.line)),
                        child: Center(child: AppIcon(Lu.image, color: p.muted, size: 26)),
                      ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _pill('${Ar.n(s.wallpapers.length)} صورة', p, icon: Lu.images, on: true),
        _pill('${Ar.n(cats.length)} فئات · ويكيميديا كومنز', p, icon: Lu.globe),
        _pill(s.cfg.b('walls.auto') ? 'تجديد تلقائي' : 'التجديد متوقف', p, icon: Lu.calendar),
      ]),
    ]));
  }
}

// ───────────── التاريخ والطقس ─────────────

class _DateStage extends StatelessWidget {
  const _DateStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final w = s.weather;
    final t = s.now;
    return _fit(480, 380, Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FitText(Ar.dayName(t), alignment: Alignment.center, style: Fonts.title(44, p.accent)),
      FitText(Ar.gregorian(t), alignment: Alignment.center, style: Fonts.clock(38, p.ink)),
      FitText(Ar.hijri(t, s.cfg.i('misc.hijriOffset')), alignment: Alignment.center, style: Fonts.body(24, p.muted)),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
        child: Row(children: [
          AppIcon(w == null ? Lu.cloudSun : weatherIcon(w.kind), color: p.ring, size: 46),
          const SizedBox(width: 16),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(w == null ? '—' : '${Ar.n(w.temp)}°', style: Fonts.clock(44, p.ink)))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FitText(s.cfg.s('misc.city').isNotEmpty ? s.cfg.s('misc.city') : (w?.place ?? 'تلقائي'), style: Fonts.body(20, p.ink, weight: FontWeight.w600)),
              FitText(w == null ? 'بانتظار التحديث' : '${w.description} · العظمى ${Ar.n(w.max)} · الصغرى ${Ar.n(w.min)}', style: Fonts.body(16, p.muted)),
            ]),
          ),
        ]),
      ),
    ]));
  }
}

// ───────────── الريموت ─────────────

class _RemoteStage extends StatelessWidget {
  const _RemoteStage();

  @override
  Widget build(BuildContext context) {
    final p = pal;
    Widget key(Object icon) => Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.line, width: 1.5)),
          child: AppIcon(icon, color: p.ink, size: 32),
        );
    Widget legend(Object k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 92,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: p.ring, width: 1.5)),
              child: k is String
                  ? Text(k, style: Fonts.body(16, p.ink, weight: FontWeight.w600))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final ic in k as List<Lu>) AppIcon(ic, color: p.ink, size: 22),
                    ]),
            ),
            const SizedBox(width: 14),
            Expanded(child: FitText(v, style: Fonts.body(18, p.muted))),
          ]),
        );
    return _fit(480, 470, Column(children: [
      SizedBox(
        width: 260,
        height: 260,
        child: Stack(alignment: Alignment.center, children: [
          Align(alignment: Alignment.topCenter, child: key(Lu.chevronUp)),
          Align(alignment: Alignment.bottomCenter, child: key(Lu.chevronDown)),
          Align(alignment: Alignment.centerLeft, child: key(Lu.chevronLeft)),
          Align(alignment: Alignment.centerRight, child: key(Lu.chevronRight)),
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle, border: Border.all(color: p.ring, width: 3)),
            child: Text('موافق', style: Fonts.body(20, p.onAccent, weight: FontWeight.w600)),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      legend(const [Lu.chevronUp, Lu.chevronDown], 'التنقل بين الصفوف فقط'),
      legend('موافق', 'الدخول والتطبيق · مطوّلة للخيارات'),
      legend(const [Lu.chevronLeft, Lu.chevronRight], 'تعديل الأشرطة والاختيار بالصف'),
      legend('رجوع', 'الخروج خطوة وحدة'),
    ]));
  }
}

// ───────────── إمكانية الوصول ─────────────

class _A11yStage extends StatelessWidget {
  const _A11yStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final c = s.cfg;
    return _fit(480, 440, Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.ring, width: ringW),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FitText('مواقيت الصلاة', style: Fonts.title(32, p.ink)),
          const SizedBox(height: 6),
          FitText('المغرب بعد ٢٣ دقيقة', style: Fonts.body(24, p.accent, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          FitText('نص ثانوي بلون أخف للمقارنة', style: Fonts.body(20, p.muted)),
        ]),
      ),
      const SizedBox(height: 24),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _pill('حجم النص ${Ar.n((c.d('a11y.textScale') * 100).round())}٪', p, icon: Lu.type, on: c.d('a11y.textScale') > 1),
        _pill('تباين عالٍ', p, icon: Lu.contrast, on: c.b('a11y.contrast')),
        _pill('إطار سميك', p, icon: Lu.frame, on: c.b('a11y.thickRing')),
        _pill('تقليل الحركة', p, icon: Lu.eyeOff, on: c.b('misc.reduceMotion')),
      ]),
    ]));
  }
}

// ───────────── الشاشة والنظام ─────────────

class _SystemStage extends StatelessWidget {
  const _SystemStage();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final inch = s.screenInches;
    return _fit(480, 420, Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 360,
        height: 202,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line, width: 6)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${Ar.n(s.screenW)} × ${Ar.n(s.screenH)}', style: Fonts.clock(34, Colors.white)),
          Text('${inch != null ? '${Ar.n(inch.round())} بوصة · ' : ''}١٦:٩', style: Fonts.body(18, Colors.white70)),
        ]),
      ),
      Container(width: 90, height: 14, color: p.line),
      const SizedBox(height: 28),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _pill(s.model.isEmpty ? 'أندرويد' : s.model, p, icon: Lu.tv, on: true),
        _pill('SDK ${Ar.n(s.sdk)}', p, icon: Lu.cpu),
        _pill('ذاكرة ${Ar.n((s.ramMb / 1024).toStringAsFixed(1))} GB', p, icon: Lu.memory),
        _pill(s.lite ? 'الوضع الخفيف' : 'الجودة الكاملة', p),
      ]),
    ]));
  }
}

// ───────────── حول ─────────────

class _AboutStage extends StatelessWidget {
  const _AboutStage();

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return _fit(460, 400, Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      RawnaqLockup(markSize: 140, night: p.night, stacked: true),
      const SizedBox(height: 8),
      Text('الإصدار ${Ar.n(kAppVersion.substring(0, 3)).replaceAll('.', '٫')}', style: Fonts.body(22, p.accent, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('واجهة رئيسية عربية أنيقة لشاشات أندرويد TV', style: Fonts.body(18, p.muted)),
    ]));
  }
}


// ───────────── الحركة: مربعات حقيقية والتركيز يتنقل بينها تلقائياً ─────────────

class _MotionStage extends StatefulWidget {
  const _MotionStage();

  @override
  State<_MotionStage> createState() => _MotionStageState();
}

class _MotionStageState extends State<_MotionStage> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted) setState(() => _i = (_i + 1) % 3);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final pkgs = s.favorites.take(3).toList();
    final m = TileMetrics(s.cfg.s('tile.style') == 'banner' ? 230 : 160);
    final style = switch (s.cfg.s('motion.style')) { 'spring' => 'نابضة', 'elegant' => 'أنيقة', 'swift' => 'سريعة', 'off' => 'بدون حركة', _ => 'ناعمة' };
    return _fit(820, 520, Column(mainAxisSize: MainAxisSize.min, children: [
      if (pkgs.isEmpty)
        Text('اختر تطبيقات للواجهة حتى تظهر الحركة هنا', style: Fonts.body(26, p.muted))
      else
        Padding(
          padding: EdgeInsets.all(m.bleed),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, pkg) in pkgs.indexed) ...[
              if (i > 0) SizedBox(width: s.cfg.d('tile.gap') + m.bleed),
              AppTile(package: pkg, m: m, focused: i == _i % pkgs.length),
            ],
          ]),
        ),
      const SizedBox(height: 28),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        _pill('الأسلوب: $style', p, icon: Lu.gauge, on: true),
        _pill('السرعة ×${Ar.n(s.cfg.d('misc.animSpeed').toStringAsFixed(1))}', p, icon: Lu.timerReset),
        _pill(switch (s.cfg.s('motion.page')) { 'slide' => 'انزلاق جانبي', 'zoom' => 'تكبير هادئ', _ => 'تلاشي ناعم' }, p, icon: Lu.layers),
      ]),
    ]));
  }
}


// ───────────── لون محدد: الواجهة المصغّرة بنفس الوضع + اللون نفسه كبير مع أين يستخدم ─────────────

class _ColorKeyStage extends StatelessWidget {
  final String mode, role;
  const _ColorKeyStage({required this.mode, required this.role});

  static const _names = {
    'bg': ('الخلفية', 'لون الشاشة خلف كل شي'),
    'surface': ('الأسطح', 'البطاقات والقوائم واللوحات'),
    'ink': ('النص الأساسي', 'الساعة والعناوين والنصوص'),
    'muted': ('النص الثانوي', 'التاريخ والوصف والتلميحات'),
    'accent': ('لون التمييز', 'الأزرار المفعّلة ومربعات الأيقونات والأشرطة'),
    'ring': ('إطار التركيز', 'الإطار الذهبي حول العنصر المحدد'),
    'line': ('الخطوط والحدود', 'حدود البطاقات والفواصل'),
  };

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    Color c(String k) => s.cfg.c('$mode.$k');
    final n = _names[role]!;
    return _fit(500, 470, Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 480,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
        decoration: BoxDecoration(color: c('bg'), borderRadius: BorderRadius.circular(22), border: Border.all(color: c('line'), width: role == 'line' ? 3 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Ar.time(s.now), style: Fonts.clock(54, c('ink'))),
          Text('${Ar.dayName(s.now)} ${Ar.gregorian(s.now)}', style: Fonts.body(15, c('muted'))),
          const SizedBox(height: 18),
          Row(children: [
            Container(
              width: 120,
              height: 64,
              decoration: BoxDecoration(color: c('surface'), borderRadius: BorderRadius.circular(14), border: Border.all(color: c('ring'), width: 3)),
              alignment: Alignment.center,
              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c('accent'), shape: BoxShape.circle), child: const AppIcon(Lu.play, color: Colors.white, size: 20)),
            ),
            const SizedBox(width: 14),
            Container(width: 120, height: 64, decoration: BoxDecoration(color: c('surface'), borderRadius: BorderRadius.circular(14), border: Border.all(color: c('line')))),
          ]),
        ]),
      ),
      const SizedBox(height: 22),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: c(role), borderRadius: BorderRadius.circular(20), border: Border.all(color: p.ring, width: 3))),
        const SizedBox(width: 18),
        SizedBox(
          width: 360,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FitText('${n.$1} · ${mode == 'day' ? 'نهاري' : 'ليلي'}', style: Fonts.body(24, p.ink, weight: FontWeight.w600)),
            FitText(n.$2, style: Fonts.body(17, p.muted)),
          ]),
        ),
      ]),
    ]));
  }
}
