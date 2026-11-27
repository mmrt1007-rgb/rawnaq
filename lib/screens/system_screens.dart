import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';

import '../arabic.dart';
import '../config.dart';
import '../brand.dart';
import '../lucide.dart';
import '../palette.dart';
import '../platform.dart';
import '../prayer.dart';
import '../state.dart';
import '../system_services.dart';
import '../widgets.dart';
import 'apps_screen.dart';
import 'home.dart';
import 'settings_preview.dart' show kAppVersion;

// ═══════════════════ عناصر مشتركة (فيكما صفحة 10) ═══════════════════

Color _warn(Palette p) => p.night ? const Color(0xFFE5A13A) : const Color(0xFFB7791F);
Color _bad(Palette p) => p.night ? const Color(0xFFE06A6A) : const Color(0xFFB3261E);
Color _s2(Palette p) => p.night ? Color.lerp(p.bg, p.surface, 0.5)! : Color.lerp(p.bg, Colors.black, 0.02)!;

/// هيكل الشاشة: عنوان بأيقونة يمين، عمود يسار (بطاقة) وعمود يمين (صفوف)، ودليل الأزرار بالأسفل.
class SysScaffold extends StatelessWidget {
  final String title, sub;
  final Object icon;
  final Widget? left;
  final List<Widget> right;
  final Widget? bottom;
  const SysScaffold({super.key, required this.title, required this.sub, required this.icon, this.left, required this.right, this.bottom});

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final p = AppState.I.palette;
          return Padding(
            padding: const EdgeInsets.fromLTRB(96, 60, 96, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // رأس الشاشة الملكي (فيكما صفحة ١٧): أيقونة بإطار ذهبي، العنوان، الوصف، وخط زخرفي
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
                  child: AppIcon(icon, color: p.accent, size: 34),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FitText(title, style: Fonts.title(46, p.ink)),
                    const SizedBox(height: 2),
                    FitText(sub, style: Fonts.body(21, p.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              const RoyalRule(),
              const SizedBox(height: 22),
              Expanded(
                child: NavZone(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 904,
                      child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.all(6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (final (i, w) in right.indexed) (w is Flexible || w is Spacer) ? w : RoyalEnter(index: i, child: w),
                        ]),
                      )),
                    ),
                    if (left != null) ...[const SizedBox(width: 64), Expanded(flex: 760, child: left!)],
                  ]),
                ),
              ),
              if (bottom != null) ...[const SizedBox(height: 16), bottom!],
              const SizedBox(height: 12),
              const KeyGuide(),
            ]),
          );
        },
      ),
    );
  }
}

class SysCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool focused;
  const SysCard({super.key, required this.child, this.padding = const EdgeInsets.all(40), this.focused = false});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: p.surface,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(74 * radiusK),
          side: BorderSide(color: focused ? p.ring : p.line, width: focused ? ringW * 0.62 : 1),
        ),
        shadows: [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.40 : 0.10), blurRadius: 44, offset: const Offset(0, 16))],
      ),
      child: child,
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final String kind; // ok | warn | bad | none
  final Object? icon;
  const StatusChip(this.text, {super.key, this.kind = 'ok', this.icon});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final c = switch (kind) { 'ok' => p.accent, 'warn' => _warn(p), 'bad' => _bad(p), _ => p.muted };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.withValues(alpha: 0.6))),
      child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[AppIcon(icon!, color: c, size: 20), const SizedBox(width: 8)],
        Text(text, style: Fonts.body(17, kind == 'none' ? p.ink : c, weight: FontWeight.w600)),
      ])),
    );
  }
}

/// صف بأيقونة: يمين الأيقونة والعنوان، ويسار مفتاح أو قيمة أو سهم.
class SysRow extends StatelessWidget {
  final Object icon;
  final String title;
  final String? sub, value;
  final bool? toggle;
  final bool danger, autofocus;
  final VoidCallback onTap;
  const SysRow({super.key, required this.icon, required this.title, required this.onTap, this.sub, this.value, this.toggle, this.danger = false, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final tint = danger ? _bad(p) : p.accent;
    return FocusTap(
      autofocus: autofocus,
      onTap: onTap,
      builder: (context, f) {
        if (f) announceOption(title, sub);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: RoyalFrame(
          focused: f,
          child: AnimatedContainer(
          duration: AppState.I.anim(180),
          constraints: BoxConstraints(minHeight: sub == null ? 76 : 92),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: ShapeDecoration(
            color: royalFill(p, _s2(p), f),
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(50 * radiusK),
              side: BorderSide(color: f ? p.ring : p.line, width: f ? ringW * 0.62 : 1),
            ),
            shadows: royalShadows(p, f),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: AppIcon(icon, color: tint, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                FitText(title, style: Fonts.body(22, danger ? tint : p.ink, weight: FontWeight.w600)),
                if (sub != null) ...[const SizedBox(height: 2), FitText(sub!, style: Fonts.body(16, p.muted))],
              ]),
            ),
            const SizedBox(width: 16),
            if (toggle != null)
              AnimatedContainer(
                duration: AppState.I.anim(160),
                width: 64,
                height: 36,
                padding: const EdgeInsets.all(4),
                alignment: toggle! ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                decoration: BoxDecoration(color: toggle! ? p.accent : p.line, borderRadius: BorderRadius.circular(999)),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: toggle! ? p.onAccent : p.surface, shape: BoxShape.circle, border: f ? Border.all(color: p.ring, width: 2.5) : null),
                ),
              )
            else ...[
              if (value != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: FitText(value!, style: Fonts.body(19, f ? p.accent : p.muted, weight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
              ],
              AppIcon(Lu.chevronLeft, color: f ? p.ring : p.muted, size: 24),
            ],
          ]),
        )));
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => SectionTitle(text);
}

String _when(DateTime t) {
  final now = DateTime.now();
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final day = d == today ? 'اليوم' : (d == today.subtract(const Duration(days: 1)) ? 'أمس' : Ar.gregorian(t));
  return '$day ${Ar.time(t)} ${Ar.period(t)}';
}

String _hm(int mins) {
  final t = DateTime(2000, 1, 1, mins ~/ 60, mins % 60);
  return '${Ar.time(t)} ${Ar.period(t)}';
}

// ═══════════════════ ١. شاشة الإقلاع ═══════════════════

class BootSplash extends StatelessWidget {
  const BootSplash({super.key});

  // نفس لون شاشة أندرويد الأولى (res/values/ic_launcher_colors.xml)
  static const _solidNight = Color(0xFF072019), _solidDay = Color(0xFFF3ECDD);
  // الشعار بنفس مقاس أيقونة البداية بالضبط (١٩٠dp بوسط الشاشة)، مو بمقاس لوحة التصميم
  static const loaderDp = 190.0;

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    // فيكما صفحة ١٥ «انتقال الإقلاع»: أول لقطة = شاشة أندرويد الأولى بالضبط، بعدها كل شي يظهر بهدوء
    final night = !s.bootDay;
    final ink = night ? const Color(0xFFC9C2AE) : const Color(0xFF6B6252);
    final screen = MediaQuery.sizeOf(context);
    final k = math.max(0.1, math.min(screen.width / 1920, screen.height / 1080));
    final half = loaderDp / 2 / k; // نص الشعار بوحدات لوحة ١٩٢٠
    Widget fadeIn(int ms, Widget child, {int delay = 0}) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: ms + delay),
          curve: Interval(delay / (ms + delay), 1, curve: Curves.easeOutCubic),
          builder: (context, v, c) => Opacity(opacity: v, child: c),
          child: child,
        );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: night ? _solidNight : _solidDay),
        // الخلفية تتدرج خلال ٠٫٧ ثانية من اللون الثابت
        fadeIn(
          700,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.9,
                colors: night ? const [Color(0xFF0E4535), Color(0xFF03100C)] : const [Color(0xFFFBF7EE), Color(0xFFEADFC8)],
              ),
            ),
          ),
        ),
        // الحالة والاسم اللاتيني والصلوات بلوحة التصميم، تحت الشعار
        fadeIn(
          600,
          delay: 250,
          FittedBox(
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: ValueListenableBuilder<int>(
                valueListenable: s.bootStep,
                builder: (context, step, _) {
                  final label = switch (step) {
                    0 => 'جاري التشغيل · الإعدادات',
                    1 => 'جاري التشغيل · التطبيقات',
                    2 => 'جاري التشغيل · الخلفيات',
                    _ => 'أهلاً بك',
                  };
                  return Stack(children: [
                    Positioned(
                      top: 540 + half + 38,
                      left: 0,
                      right: 0,
                      child: Column(children: [
                        RawnaqLatin(width: 300, color: night ? BrandColors.goldFlat : const Color(0xFFB08A3A)),
                        const SizedBox(height: 34),
                        Text(label, style: Fonts.body(22, ink)),
                      ]),
                    ),
                    Positioned(
                      bottom: 46,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text('اللّهمّ صلِّ على محمدٍ وآلِ محمد', style: Fonts.body(24, night ? BrandColors.gold : const Color(0xFF9C7A34), weight: FontWeight.w600)),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
        // الشعار نفسه هو التحميل: القلم يكتب «رونق» والحلقة تمشي معه ومع خطوات التشغيل
        Center(
          child: ValueListenableBuilder<int>(
            valueListenable: s.bootStep,
            builder: (context, step, _) => RawnaqLoader(
              size: loaderDp,
              night: night,
              progress: ((step + 1) / 5).clamp(0.0, 1.0),
              onFinished: BootWriting.finish,
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════ ٢. الوضع الآمن ═══════════════════

class SafeModeScreen extends StatefulWidget {
  const SafeModeScreen({super.key});
  @override
  State<SafeModeScreen> createState() => _SafeModeScreenState();
}

class _SafeModeScreenState extends State<SafeModeScreen> {
  List<String> _errors = const [];
  BackupInfo? _last;

  @override
  void initState() {
    super.initState();
    ErrorLog.lastErrors(max: 3).then((v) => mounted ? setState(() => _errors = v) : null);
    Backups.list().then((v) => mounted ? setState(() => _last = v.isEmpty ? null : v.first) : null);
  }

  void _toHome() => Navigator.of(context).pushReplacement(fade(const HomeScreen()));

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final err = _errors.isEmpty ? 'ما انحفظ خطأ — غالباً توقف من النظام' : _errors.first.split('  ').skip(1).join(' ');
    return SysScaffold(
      title: 'الوضع الآمن',
      sub: 'توقف رونق أكثر من مرة — فتحناه بإعدادات آمنة حتى ما تعلك الشاشة',
      icon: Lu.info,
      left: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SysCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _warn(p).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(22)),
                child: AppIcon(Lu.info, color: _warn(p), size: 40),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FitText('توقف رونق ٣ مرات', style: Fonts.body(30, p.ink, weight: FontWeight.w600)),
                  FitText('خلال دقيقتين — بدون حركة ولا زجاج الآن', style: Fonts.body(18, p.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: _s2(p), borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('آخر خطأ', style: Fonts.body(16, p.muted)),
                const SizedBox(height: 6),
                Text(err, maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: Fonts.body(18, p.ink)),
              ]),
            ),
            const SizedBox(height: 18),
            const StatusChip('السجل محفوظ على الشاشة', icon: Lu.circleCheck),
          ]),
        ),
        const SizedBox(height: 22),
        Text('يحصل عادةً بعد تحديث النظام أو امتلاء الذاكرة. الوضع الآمن يرجع طبيعي بعد إعادة التشغيل.', style: Fonts.body(19, p.muted)),
      ]),
      right: [
        SysRow(icon: Lu.power, title: 'تشغيل رونق بالإعدادات الآمنة', sub: 'بدون حركة ولا زجاج — يرجع طبيعي بعد إعادة التشغيل', autofocus: true, onTap: _toHome),
        SysRow(
          icon: Lu.rotateCcw,
          title: 'استعادة آخر نسخة احتياطية',
          sub: _last == null ? 'ما كو نسخة محفوظة بعد' : '${_when(_last!.time)} · ${Ar.n(_last!.keys)} إعداداً',
          onTap: () async {
            if (_last == null) return;
            final ok = await Backups.restore(_last!.file);
            if (!context.mounted) return;
            toast(context, ok ? 'تمت الاستعادة' : 'تعذّرت الاستعادة');
            if (ok) _toHome();
          },
        ),
        const SysRow(icon: Lu.tv, title: 'فتح إعدادات النظام', sub: 'ترجع لرونق بزر الهوم', onTap: NativeBridge.systemSettings),
        SysRow(
          icon: Lu.download,
          title: 'حفظ سجل الأعطال للفلاشة',
          sub: 'ملف نصي صغير تدزه للدعم',
          onTap: () async {
            final f = await ErrorLog.file();
            final usb = await Backups.usb();
            if (!context.mounted) return;
            if (f == null || !f.existsSync() || usb.isEmpty) {
              toast(context, usb.isEmpty ? 'ركّب فلاشة أول' : 'ما كو سجل محفوظ');
              return;
            }
            if (!usb.first.existsSync()) usb.first.createSync(recursive: true);
            await f.copy('${usb.first.path}/rawnaq-errors.log');
            if (context.mounted) toast(context, 'انحفظ السجل على الفلاشة');
          },
        ),
        SysRow(
          icon: Lu.trash,
          title: 'إعادة كل الإعدادات للأصل',
          sub: 'آخر حل — يمسح الترتيب والثيم',
          danger: true,
          onTap: () {
            AppState.I.cfg.resetAll();
            AppState.I.touch();
            _toHome();
          },
        ),
      ],
    );
  }
}

// ═══════════════════ ٣. النسخ الاحتياطي والاستعادة ═══════════════════

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<BackupInfo> _list = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final l = await Backups.list();
    if (mounted) setState(() => _list = l);
  }

  Future<void> _restore(BackupInfo b) async {
    final ok = await Backups.restore(b.file);
    if (!mounted) return;
    toast(context, ok ? 'رجعت الإعدادات لـ ${_when(b.time)}' : 'تعذّرت الاستعادة');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    const parts = [
      ('الثيم والألوان', Lu.palette),
      ('الخطوط', Lu.type),
      ('ترتيب الواجهة', Lu.grid),
      ('التطبيقات وترتيبها', Lu.grid),
      ('أسماء وصور التطبيقات', Lu.image),
      ('شاشة السكون', Lu.monitorPlay),
      ('المواقيت والمدينة', Lu.landmark),
      ('الريموت والحركة', Lu.gamepad),
      ('الأقفال والرمز', Lu.lock),
    ];
    final size = _list.isEmpty ? 0 : _list.first.bytes;
    return SysScaffold(
      title: 'النسخ الاحتياطي والاستعادة',
      sub: 'كل إعداداتك وترتيبك وثيمك محفوظة، وترجع بضغطة',
      icon: Lu.download,
      left: SysCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('شنو تشمل النسخة', style: Fonts.body(26, p.ink, weight: FontWeight.w600)),
          const SizedBox(height: 22),
          Wrap(spacing: 12, runSpacing: 12, children: [for (final (t, i) in parts) StatusChip(t, icon: i)]),
          const SizedBox(height: 24),
          Text('الخلفيات نفسها ما تنحفظ بالنسخة لأن حجمها كبير — تتنزل من جديد تلقائياً من المكتبة.', style: Fonts.body(18, p.muted)),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _s2(p), borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('حجم النسخة', style: Fonts.body(16, p.muted)),
                  FitText(size == 0 ? '—' : '${Ar.n((size / 1024).ceil())} ك.ب', style: Fonts.body(40, p.ink, weight: FontWeight.w600)),
                ]),
              ),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text('تكفي أي فلاشة', style: Fonts.body(16, p.muted)))),
            ]),
          ),
        ]),
      ),
      right: [
        SysRow(
          icon: Lu.calendar,
          title: 'نسخ احتياطي تلقائي يومي',
          sub: 'مرة كل ٢٤ ساعة · يحتفظ بآخر ٧ نسخ',
          toggle: s.cfg.b('backup.auto'),
          autofocus: true,
          onTap: () => s.set('backup.auto', !s.cfg.b('backup.auto')),
        ),
        SysRow(
          icon: Lu.download,
          title: 'نسخة احتياطية الآن',
          onTap: () async {
            final b = await Backups.create();
            await _reload();
            if (context.mounted) toast(context, b == null ? 'تعذّر الحفظ' : 'انحفظت النسخة');
          },
        ),
        SysRow(
          icon: Lu.usb,
          title: 'تصدير للفلاشة',
          onTap: () async {
            final usb = await Backups.usb();
            if (usb.isEmpty) {
              if (context.mounted) toast(context, 'ركّب فلاشة أول');
              return;
            }
            if (!usb.first.existsSync()) usb.first.createSync(recursive: true);
            final b = await Backups.create(into: usb.first);
            if (context.mounted) toast(context, b == null ? 'تعذّر التصدير' : 'انحفظت على الفلاشة: Android/data/…/files');
          },
        ),
        SysRow(
          icon: Lu.upload,
          title: 'استيراد من فلاشة',
          onTap: () async {
            final usb = await Backups.usb();
            final found = <BackupInfo>[for (final d in usb) ...await Backups.list(d)];
            if (!context.mounted) return;
            if (found.isEmpty) {
              toast(context, usb.isEmpty ? 'ركّب فلاشة أول' : 'ما لگيت نسخة بالفلاشة');
              return;
            }
            await _restore(found.first);
          },
        ),
        const _SectionLabel('النسخ المحفوظة'),
        if (_list.isEmpty) Text('ما كو نسخ بعد — اضغط "نسخة احتياطية الآن".', style: Fonts.body(19, p.muted)),
        for (final b in _list.take(7))
          SysRow(
            icon: Lu.rotateCcw,
            title: _when(b.time),
            sub: '${b.auto ? 'تلقائية' : 'يدوية'} · ${Ar.n(b.keys)} إعداداً',
            value: 'استعادة',
            onTap: () => _restore(b),
          ),
      ],
    );
  }
}

// ═══════════════════ ٤. صحة النظام ═══════════════════

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  Map<String, dynamic> _st = const {};
  int _crashes = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final st = await NativeBridge.systemStatus();
    final c = await ErrorLog.weekCount();
    if (mounted) {
      setState(() {
        _st = st;
        _crashes = c;
      });
    }
  }

  int _i(String k) => (_st[k] as int?) ?? 0;
  String _gb(int mb) => mb >= 1024 ? '${Ar.n((mb / 1024).toStringAsFixed(1))} GB' : '${Ar.n(mb)} MB';

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final ramT = _i('ramTotal'), ramF = _i('ramFree'), stT = _i('storageTotal'), stF = _i('storageFree');
    final ramUsed = ramT > 0 ? 1 - ramF / ramT : 0.0, stUsed = stT > 0 ? 1 - stF / stT : 0.0;
    final net = (_st['net'] as String?) ?? '';
    final fps = SystemWatch.I.fps;
    final walls = s.wallpapers.length, want = s.cfg.i('walls.count');
    final cards = [
      ('الذاكرة', Lu.memory, ramT > 0 ? 'متاح ${_gb(ramF)} من ${_gb(ramT)}' : '…', ramUsed, ramUsed > 0.9 ? 'warn' : 'ok', ramUsed > 0.9 ? 'ممتلئة' : 'سليمة'),
      ('التخزين', Lu.drive, stT > 0 ? 'متاح ${_gb(stF)} من ${_gb(stT)}' : '…', stUsed, stUsed > 0.92 ? 'warn' : 'ok', stUsed > 0.92 ? 'قليل' : 'سليم'),
      ('الشبكة', Lu.wifi, switch (net) { 'wifi' => 'واي فاي متصل', 'ethernet' => 'كيبل متصل', 'none' => 'غير متصل', '' => '…', _ => 'متصل' }, net == 'none' ? 0.0 : 1.0, net == 'none' ? 'bad' : 'ok', net == 'none' ? 'مقطوعة' : 'متصلة'),
      ('سلاسة الواجهة', Lu.gauge, '${Ar.n(fps.round())} إطاراً بالثانية', fps / 60, fps < 40 ? 'warn' : 'ok', fps < 40 ? 'بطيئة' : 'سلسة'),
      ('الأعطال', Lu.info, '${Ar.n(_crashes)} هذا الأسبوع', -1.0, _crashes > 3 ? 'warn' : 'ok', _crashes > 3 ? 'انتبه' : 'سليم'),
      ('الخلفيات', Lu.images, '${Ar.n(walls)} من ${Ar.n(want)} صورة', want > 0 ? walls / want : 1.0, walls < want ? 'warn' : 'ok', walls < want ? 'تكمل تلقائياً' : 'كاملة'),
    ];
    Widget card(int i) {
      final (t, ic, sub, v, kind, st) = cards[i];
      final c = kind == 'ok' ? p.accent : (kind == 'warn' ? _warn(p) : _bad(p));
      return SysCard(
        padding: const EdgeInsets.all(28),
        child: SizedBox(
          height: 190,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                child: AppIcon(ic, color: c, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(child: FitText(t, style: Fonts.body(26, p.ink, weight: FontWeight.w600))),
              StatusChip(st, kind: kind),
            ]),
            const Spacer(),
            FitText(sub, style: Fonts.body(19, p.muted)),
            const SizedBox(height: 16),
            if (v >= 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: v.clamp(0.0, 1.0).toDouble(), minHeight: 10, backgroundColor: p.line, valueColor: AlwaysStoppedAnimation(c)),
              )
            else
              const SizedBox(height: 10),
          ]),
        ),
      );
    }

    return ThemedScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(96, 60, 96, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: AppIcon(Lu.gauge, color: p.accent, size: 34),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FitText('صحة النظام', style: Fonts.title(44, p.ink)),
                FitText('فحص سريع للذاكرة والتخزين والشبكة والسلاسة والأعطال', style: Fonts.body(21, p.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 36),
          for (final r in [0, 3]) ...[
            Row(children: [
              for (final c in [0, 1, 2]) ...[if (c > 0) const SizedBox(width: 28), Expanded(child: card(r + c))],
            ]),
            const SizedBox(height: 28),
          ],
          const Spacer(),
          ActionRow([
            Act('تنظيف ذكي', () async {
              final freed = await NativeBridge.cleanMemory();
              await _check();
              if (context.mounted) toast(context, freed > 0 ? 'تم تحرير ${_gb(freed)}' : 'الذاكرة نظيفة أصلاً');
            }, icon: Lu.memory, primary: true),
            Act('حفظ تقرير', () async {
              final usb = await Backups.usb();
              if (usb.isEmpty) {
                if (context.mounted) toast(context, 'ركّب فلاشة أول');
                return;
              }
              if (!usb.first.existsSync()) usb.first.createSync(recursive: true);
              final lines = [for (final c in cards) '${c.$1}: ${c.$3} (${c.$6})', 'الإصدار: $kAppVersion', 'الجهاز: ${s.model} SDK ${s.sdk}'];
              await File('${usb.first.path}/rawnaq-report.txt').writeAsString(lines.join('\n'), flush: true);
              if (context.mounted) toast(context, 'انحفظ التقرير على الفلاشة');
            }, icon: Lu.download),
            Act('فحص الآن', _check, icon: Lu.rotateCcw),
          ]),
          const SizedBox(height: 12),
          const KeyGuide(),
        ]),
      ),
    );
  }
}

// ═══════════════════ ٥. التحديثات ═══════════════════

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: AppState.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final notes = [
      'الاسم الجديد: رونق، وإعداداتك وترتيبك تنتقل وحدها',
      'شعار رونق الجديد بشاشة الإقلاع والأيقونة والبانر',
      'الشعار نفسه صار حركة التحميل بالإقلاع والصور والتحديث',
      'شاشة الطقس الحية بمشاهد سينمائية وقطرات حقيقية على الزجاج',
      'مدن متعددة تتنقل بينها يمين ويسار، وتحديد موقعك من شبكة البيت',
      'رمز الأهل بلوحة أرقام، وواجهة أطفال خاصة وتقرير أسبوعي',
      'وضع المناسبات ورمضان، والعد قبل الإطفاء، والتحديث الجاهز',
      'الأجهزة والمزامنة، وسجل النشاط، وسجل الإصدارات',
    ];
    final updated = s.updatedAt > 0 ? DateTime.fromMillisecondsSinceEpoch(s.updatedAt) : null;
    return SysScaffold(
      title: 'التحديثات',
      sub: 'التحديث من حاسبتك بـ install.bat — إعداداتك وترتيبك يبقون مثل ما هم',
      icon: Lu.download,
      left: SysCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الإصدار الحالي', style: Fonts.body(18, p.muted)),
                FitText(Ar.n(s.version.isEmpty ? kAppVersion : s.version), style: Fonts.title(64, p.ink)),
              ]),
            ),
            if (updated != null) StatusChip('آخر تحديث ${Ar.gregorian(updated)}', icon: Lu.circleCheck),
          ]),
          const SizedBox(height: 26),
          Text('شنو الجديد', style: Fonts.body(24, p.ink, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                AppIcon(Lu.circleCheck, color: p.accent, size: 24),
                const SizedBox(width: 14),
                Expanded(child: FitText(n, style: Fonts.body(21, p.ink))),
              ]),
            ),
        ]),
      ),
      right: [
        SysRow(
          icon: Lu.download,
          title: 'نسخة احتياطية قبل التحديث',
          sub: 'احتياط إضافي — التحديث أصلاً ما يمس إعداداتك',
          autofocus: true,
          onTap: () async {
            final b = await Backups.create();
            if (context.mounted) toast(context, b == null ? 'تعذّر الحفظ' : 'انحفظت النسخة');
          },
        ),
        SysRow(icon: Lu.info, title: 'طريقة التحديث', sub: 'شغّل install.bat بالحاسبة واختر هاي الشاشة', value: 'من الحاسبة', onTap: () {}),
        SysRow(icon: Lu.tv, title: 'معلومات الجهاز', sub: '${s.model.isEmpty ? 'أندرويد TV' : s.model} · SDK ${Ar.n(s.sdk)}', onTap: () {}),
      ],
    );
  }
}

// ═══════════════════ ٦. تنبيه الإطفاء (طبقة فوق الواجهة) ═══════════════════
//  مواقيت الصلاة توقيت فقط: ماكو أي تنبيه أذان. هذي الطبقة بس لتنبيه الإطفاء المجدول.

class PowerNoticeBanner extends StatefulWidget {
  const PowerNoticeBanner({super.key});
  @override
  State<PowerNoticeBanner> createState() => _PowerNoticeBannerState();
}

class _PowerNoticeBannerState extends State<PowerNoticeBanner> {
  Timer? _hide;
  String? _notice;

  @override
  void initState() {
    super.initState();
    SystemWatch.I.notice.addListener(_onNotice);
  }

  @override
  void dispose() {
    SystemWatch.I.notice.removeListener(_onNotice);
    _hide?.cancel();
    super.dispose();
  }

  void _onNotice() {
    final n = SystemWatch.I.notice.value;
    if (n == null) return;
    setState(() => _notice = n);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 25), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final n = _notice;
    if (n == null) return const IgnorePointer(child: SizedBox(width: 1100, height: 1));
    return TweenAnimationBuilder<double>(
      key: ValueKey(n),
      tween: Tween(begin: 0, end: 1),
      duration: AppState.I.anim(460),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, -70 * (1 - v)), child: child)),
      child: IgnorePointer(
        child: Container(
          width: 1100,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: ShapeDecoration(
            color: p.surface,
            shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(92), side: BorderSide(color: p.ring, width: 2)),
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.5 : 0.16), blurRadius: 50, offset: const Offset(0, 18))],
          ),
          child: Row(children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.ring.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(28)),
              child: AppIcon(Lu.power, color: p.ring, size: 50),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                FitText('إطفاء الشاشة بعد دقيقة', style: Fonts.title(36, p.ink)),
                const SizedBox(height: 6),
                FitText(n, style: Fonts.body(19, p.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════ ٧. جدول التشغيل والإطفاء ═══════════════════

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: AppState.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = AppState.I;
    final c = s.cfg;
    final p = s.palette;
    final times = [for (var m = 0; m < 1440; m += 30) (m, _hm(m))];
    Widget timeline() {
      const days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
      final off = c.b('sched.off') ? c.i('sched.offAt') : null;
      final q = c.b('sched.quiet') ? (c.i('sched.quietFrom'), c.i('sched.quietTo')) : null;
      return SysCard(
        padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text('اليوم', style: Fonts.body(24, p.ink, weight: FontWeight.w600)))),
            const Spacer(),
            if (q != null) ...[const StatusChip('ساعات الهدوء', kind: 'warn'), const SizedBox(width: 12)],
            if (off != null) StatusChip('إطفاء ${_hm(off)}', icon: Lu.power),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            double x(int m) => w * m / 1440; // يمين = منتصف الليل (اتجاه عربي)
            final now = DateTime.now();
            final nm = now.hour * 60 + now.minute;
            Widget seg(int a, int b, Color col) => PositionedDirectional(start: x(a), width: (x(b) - x(a)).clamp(2.0, w), top: 0, bottom: 0, child: Container(decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8))));
            return SizedBox(
              height: 60,
              child: Stack(children: [
                Positioned(left: 0, right: 0, top: 6, height: 18, child: Container(decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(9)))),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 6,
                  height: 18,
                  child: Stack(children: [
                    if (q != null) ...[
                      if (q.$1 <= q.$2) seg(q.$1, q.$2, _warn(p).withValues(alpha: 0.85)) else ...[seg(q.$1, 1440, _warn(p).withValues(alpha: 0.85)), seg(0, q.$2, _warn(p).withValues(alpha: 0.85))],
                    ],
                    if (off != null) seg(off, (off + 10).clamp(0, 1440), p.accent),
                  ]),
                ),
                PositionedDirectional(start: x(nm) - 2, top: 0, width: 4, height: 30, child: Container(color: p.ring)),
                for (final (m, l) in const [(0, '١٢ ص'), (360, '٦ ص'), (720, '١٢ م'), (1080, '٦ م')])
                  PositionedDirectional(start: (x(m) - 20).clamp(0.0, w - 60), top: 34, child: Text(l, style: Fonts.body(15, p.muted))),
              ]),
            );
          }),
          const SizedBox(height: 6),
          FitText('${days[(DateTime.now().weekday + 1) % 7]} · الخط الذهبي هو الوقت الحالي', style: Fonts.body(16, p.muted)),
        ]),
      );
    }

    return SysScaffold(
      title: 'جدول التشغيل والإطفاء',
      sub: 'الشاشة تطفي بوقتها، وساعات هدوء بلا شاشة سكون ولا تنبيهات',
      icon: Lu.calendar,
      left: timeline(),
      right: [
        SysRow(icon: Lu.power, title: 'إطفاء تلقائي', sub: 'كل يوم بنفس الوقت', toggle: c.b('sched.off'), autofocus: true, onTap: () => s.set('sched.off', !c.b('sched.off'))),
        SysRow(
          icon: Lu.timer,
          title: 'وقت الإطفاء',
          value: _hm(c.i('sched.offAt')),
          onTap: () => showChoicePicker<int>(context, title: 'وقت الإطفاء', options: times, value: c.i('sched.offAt'), onChanged: (v) => s.set('sched.offAt', v)),
        ),
        SysRow(icon: Lu.bell, title: 'تنبيه قبل الإطفاء بدقيقة', toggle: c.b('sched.warn'), onTap: () => s.set('sched.warn', !c.b('sched.warn'))),
        SysRow(icon: Lu.play, title: 'لا تطفي أثناء الفيديو', sub: 'إذا تطبيق ثاني شغّال ينتظر لحد ساعتين', toggle: c.b('sched.waitVideo'), onTap: () => s.set('sched.waitVideo', !c.b('sched.waitVideo'))),
        const _SectionLabel('ساعات الهدوء'),
        SysRow(icon: Lu.moon, title: 'ساعات الهدوء', sub: 'بدون شاشة سكون ولا تنبيهات', toggle: c.b('sched.quiet'), onTap: () => s.set('sched.quiet', !c.b('sched.quiet'))),
        SysRow(
          icon: Lu.moon,
          title: 'من',
          value: _hm(c.i('sched.quietFrom')),
          onTap: () => showChoicePicker<int>(context, title: 'بداية الهدوء', options: times, value: c.i('sched.quietFrom'), onChanged: (v) => s.set('sched.quietFrom', v)),
        ),
        SysRow(
          icon: Lu.sunrise,
          title: 'إلى',
          value: _hm(c.i('sched.quietTo')),
          onTap: () => showChoicePicker<int>(context, title: 'نهاية الهدوء', options: times, value: c.i('sched.quietTo'), onChanged: (v) => s.set('sched.quietTo', v)),
        ),
      ],
    );
  }
}

// ═══════════════════ ٨. معالج الإعداد الأول ═══════════════════

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});
  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _step = 0;
  static const _steps = ['الثيم', 'المدينة', 'التطبيقات', 'الشبكة', 'تم'];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _finish() {
    AppState.I.set('setup.done', true);
    Navigator.of(context).pushReplacement(fade(const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: ThemedScaffold(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final p = s.palette;
            return Padding(
              padding: const EdgeInsets.fromLTRB(96, 60, 96, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  RawnaqMark(size: 76, style: MarkStyle.of(p.night)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FitText('أهلاً بك برونق', style: Fonts.title(44, p.ink)),
                      FitText('خمس خطوات وتصير الشاشة جاهزة', style: Fonts.body(21, p.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 28),
                // شريط الخطوات
                Row(children: [
                  for (final (i, t) in _steps.indexed) ...[
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: s.anim(200),
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i <= _step ? p.accent : p.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: i <= _step ? p.accent : p.line, width: 2),
                        ),
                        child: i < _step
                            ? AppIcon(Lu.check, color: p.onAccent, size: 26)
                            : Text(Ar.n(i + 1), style: Fonts.body(22, i == _step ? p.onAccent : p.muted, weight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      Text(t, style: Fonts.body(18, i == _step ? p.ink : p.muted, weight: i == _step ? FontWeight.w600 : null)),
                    ]),
                    if (i < _steps.length - 1)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 34, left: 12, right: 12),
                          child: Container(height: 4, decoration: BoxDecoration(color: i < _step ? p.accent : p.line, borderRadius: BorderRadius.circular(2))),
                        ),
                      ),
                  ],
                ]),
                const SizedBox(height: 28),
                Expanded(child: NavZone(child: KeyedSubtree(key: ValueKey(_step), child: _body(context, p)))),
                const SizedBox(height: 16),
                ActionRow([
                  Act(_step == _steps.length - 1 ? 'ابدأ' : 'التالي', _next, icon: Lu.chevronLeft, primary: true),
                  Act('تخطي الإعداد', _finish),
                ]),
                const SizedBox(height: 12),
                const KeyGuide(),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Palette p) {
    final s = AppState.I;
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FitText('اختر ثيمك الملكي', style: Fonts.title(34, p.ink)),
          FitText('يمين ويسار للتنقل وموافق للتطبيق — يجي معه ترتيب واجهته وخطوطه، وتقدر تغيّره بأي وقت', style: Fonts.body(20, p.muted)),
          const SizedBox(height: 20),
          SelectorRow<ThemePreset>(
            autofocus: true,
            values: ThemePreset.all,
            selected: ThemePreset.all.where((x) => x.id == s.cfg.s('theme.preset')).firstOrNull,
            onSelect: (t) {
              s.applyTheme(t);
            },
            itemBuilder: (context, t, hi, sel) => _ThemeTile(preset: t, focused: hi, active: sel),
          ),
        ]);
      case 1:
        return AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.all(6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FitText('مدينتك لمواقيت الصلاة', style: Fonts.title(34, p.ink)),
            const SizedBox(height: 16),
            for (final (i, c) in [PrayerCity.auto, ...PrayerCity.all].indexed)
              SysRow(
                icon: c.id == 'auto' ? Lu.locate : Lu.landmark,
                title: c.id == 'auto' ? c.name : c.label,
                sub: c.id == 'auto' ? 'حسب موقع الشاشة: ${PrayerCity.byId('auto').label}' : null,
                toggle: s.cfg.s('prayer.city') == c.id,
                autofocus: s.cfg.s('prayer.city') == c.id || (i == 0 && s.cfg.s('prayer.city').isEmpty),
                onTap: () => s.set('prayer.city', c.id),
              ),
          ]),
        ));
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FitText('تطبيقاتك بالواجهة', style: Fonts.title(34, p.ink)),
          FitText('اخترنا لك الأشهر تلقائياً — تقدر تضيف وتشيل', style: Fonts.body(20, p.muted)),
          const SizedBox(height: 20),
          SysRow(
            icon: Lu.grid,
            title: 'اختيار التطبيقات الظاهرة',
            value: '${Ar.n(s.favorites.length)} تطبيق',
            autofocus: true,
            onTap: () => Navigator.push(context, fade(const AppsScreen(pickMode: true))),
          ),
        ]);
      case 3:
        return FutureBuilder<Map<String, dynamic>>(
          future: NativeBridge.systemStatus(),
          builder: (context, snap) {
            final net = (snap.data?['net'] as String?) ?? '';
            final ok = net.isNotEmpty && net != 'none';
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FitText('الشبكة', style: Fonts.title(34, p.ink)),
              const SizedBox(height: 20),
              Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(ok ? 'متصل بالإنترنت' : 'غير متصل', kind: ok ? 'ok' : 'warn', icon: ok ? Lu.wifi : Lu.wifiOff)),
              const SizedBox(height: 20),
              const SysRow(icon: Lu.wifi, title: 'إعدادات الشبكة بالنظام', sub: 'الطقس والخلفيات تحتاج إنترنت — الباقي يشتغل بدونه', autofocus: true, onTap: NativeBridge.wifiSettings),
            ]);
          },
        );
      default:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppIcon(Lu.circleCheck, color: p.accent, size: 96),
            const SizedBox(height: 20),
            Text('جاهزة!', style: Fonts.title(56, p.ink)),
            Text('اضغط "ابدأ" وتنتقل للواجهة', style: Fonts.body(22, p.muted)),
          ]),
        );
    }
  }
}

class _ThemeTile extends StatelessWidget {
  final ThemePreset preset;
  final bool focused, active;
  const _ThemeTile({required this.preset, required this.focused, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final d = preset.day, n = preset.night;
    final cols = [d['bg']!, d['accent']!, d['ring']!, n['bg']!, n['accent']!, n['ring']!];
    return AnimatedScale(
      scale: focused ? 1.04 : 1,
      duration: AppState.I.anim(150),
      child: Container(
        width: 330,
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(
          color: p.surface,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(64),
            side: BorderSide(color: focused ? p.ring : (active ? p.accent : p.line), width: focused ? ringW : (active ? 2.5 : 1)),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in cols) Container(width: 86, height: 56, decoration: BoxDecoration(color: Color(c), borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: FitText(preset.name, style: Fonts.family(preset.titleFont, 28, p.ink, weight: FontWeight.w700))),
            if (active) AppIcon(Lu.circleCheck, color: p.accent, size: 28),
          ]),
          FitText(preset.sub, style: Fonts.body(16, p.muted)),
        ]),
      ),
    );
  }
}
