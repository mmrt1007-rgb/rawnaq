import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tile.dart';
import '../arabic.dart';
import '../family_services.dart';
import '../lucide.dart';
import '../brand.dart';
import '../palette.dart';
import '../platform.dart';
import '../state.dart';
import '../streamer_services.dart';
import '../system_services.dart';
import '../weather_sky.dart' show WeatherSky;
import '../widgets.dart';
import 'streamer_screens.dart' show ProfilePicker, KidsScreen, live;
import 'system_screens.dart';

// ═══════════════════════════════════════════════════════════════════════
//  فيكما صفحة ١٢ (شاشات مكملة) وصفحة ١٣ (الإصدار القادم):
//  رمز الأهل، قفل وواجهة الأطفال، التحديث الجاهز، العد قبل الإطفاء، الضيف،
//  الأمان، معالج الأطفال، القابس، عن رونق، الحالات الفارغة، المناسبات،
//  رمضان، التقرير الأسبوعي، الأجهزة، سجل النشاط، وسجل الإصدارات.
// ═══════════════════════════════════════════════════════════════════════

Color _warn(Palette p) => p.night ? const Color(0xFFE5A13A) : const Color(0xFFB7791F);

/// ميدالية بحلقة مزدوجة وقطرتي نور (لغة شعار رونق) وأيقونة بالوسط.
class Medallion extends StatelessWidget {
  final Object icon;
  final double size;
  final Color color;
  final Color? onColor;
  const Medallion({super.key, required this.icon, this.size = 200, required this.color, this.onColor});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter2(color),
          child: Center(
            child: Container(
              width: size * 0.5,
              height: size * 0.5,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, 0.25)!, color]),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: size * 0.16)],
              ),
              child: AppIcon(icon, color: onColor ?? (color.computeLuminance() > 0.45 ? const Color(0xFF1B1206) : Colors.white), size: size * 0.24),
            ),
          ),
        ),
      );
}

class _RingPainter2 extends CustomPainter {
  final Color c;
  _RingPainter2(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    // نفس لغة شعار رونق: حلقة مزدوجة وقطرتا نور فوق وجوّه
    final o = s.center(Offset.zero);
    final r = s.width / 2 * 0.86;
    canvas.drawCircle(o, r * 1.12, Paint()..shader = RadialGradient(colors: [c.withValues(alpha: 0.2), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r * 1.12)));
    canvas.drawCircle(o, r, Paint()..color = c.withValues(alpha: 0.08));
    canvas.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.6, s.width * 0.012)..color = c.withValues(alpha: 0.85));
    canvas.drawCircle(o, r * 0.92, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = c.withValues(alpha: 0.5));
    final d = s.width * 0.035;
    for (final sign in [-1.0, 1.0]) {
      final tip = o + Offset(0, sign * (r + d * 2.2));
      final base = o + Offset(0, sign * (r - d * 0.2));
      final p = Path()
        ..moveTo(tip.dx, tip.dy)
        ..cubicTo(tip.dx + d, tip.dy - sign * d * 1.2, base.dx + d, base.dy + sign * d * 1.2, base.dx, base.dy)
        ..cubicTo(base.dx - d, base.dy + sign * d * 1.2, tip.dx - d, tip.dy - sign * d * 1.2, tip.dx, tip.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = c.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter2 o) => o.c != c;
}

/// حالة فارغة أنيقة (بحث بلا نتائج، ما بيه بيانات…).
class EmptyState extends StatelessWidget {
  final Object icon;
  final String title, sub;
  final bool row;
  const EmptyState({super.key, required this.icon, required this.title, required this.sub, this.row = false});
  @override
  Widget build(BuildContext context) {
    final p = pal;
    if (row) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Medallion(icon: icon, size: 140, color: p.muted, onColor: p.bg),
          const SizedBox(width: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              FitText(title, style: Fonts.title(34, p.ink)),
              const SizedBox(height: 6),
              FitText(sub, style: Fonts.body(20, p.muted)),
            ]),
          ),
        ]),
      );
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Medallion(icon: icon, size: 150, color: p.muted.withValues(alpha: 0.9), onColor: p.bg),
        const SizedBox(height: 16),
        FitText(title, alignment: Alignment.center, style: Fonts.title(34, p.ink)),
        const SizedBox(height: 6),
        FitText(sub, alignment: Alignment.center, style: Fonts.body(20, p.muted)),
      ]),
    );
  }
}

// ═══════════════════ رمز الأهل: لوحة أرقام ═══════════════════

Future<bool> showPinPad(BuildContext context, {String title = 'رمز الأهل', String? sub}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: _PinPad(title: title, sub: sub)),
  );
  return r == true;
}

class _PinPad extends StatefulWidget {
  final String title;
  final String? sub;
  const _PinPad({required this.title, this.sub});
  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> with SingleTickerProviderStateMixin {
  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'del', '0', 'ok'];
  final _nodes = FocusNodes();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  String _code = '';
  String? _err;
  Timer? _tick;

  int get _len => math.max(4, AppState.I.cfg.s('misc.pin').length);

  @override
  void initState() {
    super.initState();
    if (PinGuard.locked) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!PinGuard.locked) {
        _tick?.cancel();
        _err = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nodes.dispose();
    _shake.dispose();
    _tick?.cancel();
    super.dispose();
  }

  void _press(String k) {
    if (PinGuard.locked) return;
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (k == 'ok') {
        _submit();
      } else if (_code.length < 8) {
        _code += k;
        _err = null;
        if (_code.length == AppState.I.cfg.s('misc.pin').length) _submit();
      }
    });
  }

  void _submit() {
    if (_code.isEmpty) return;
    if (PinGuard.verify(_code)) {
      Navigator.pop(context, true);
      return;
    }
    _code = '';
    _shake.forward(from: 0);
    if (PinGuard.locked) {
      _err = 'انقفل الرمز مؤقتاً';
      _startTick();
    } else {
      final left = PinGuard.attemptsLeft;
      _err = 'رمز غلط، باقي ${Ar.n(left)} ${left == 1 ? 'محاولة' : 'محاولات'}';
    }
  }

  KeyEventResult _keys2(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final l = e.logicalKey.keyLabel;
    final d = int.tryParse(l.replaceAll('Numpad ', '').trim());
    if (d != null && l.length <= 9) {
      _press('$d');
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace || e.logicalKey == LogicalKeyboardKey.delete) {
      _press('del');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _nav(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    int? to;
    // اللوحة مرتبة مثل لوحة التلفون (١ يسار) فالأسهم بنفس اتجاهها
    if (k == LogicalKeyboardKey.arrowLeft && i % 3 > 0) to = i - 1;
    if (k == LogicalKeyboardKey.arrowRight && i % 3 < 2) to = i + 1;
    if (k == LogicalKeyboardKey.arrowUp && i >= 3) to = i - 3;
    if (k == LogicalKeyboardKey.arrowDown && i < 9) to = i + 3;
    if (to == null) return arrowDirection(k) != null ? KeyEventResult.handled : KeyEventResult.ignored;
    _nodes.focus('k$to');
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final until = PinGuard.lockedUntil;
    final locked = until != null;
    final secs = locked ? until.difference(DateTime.now()).inSeconds : 0;
    return Focus(
      onKeyEvent: _keys2,
      child: themedDialog(
        width: 640,
        padding: const EdgeInsets.fromLTRB(44, 36, 44, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Medallion(icon: locked ? Lu.lock : Lu.key, size: 132, color: locked ? _warn(p) : p.ring),
          const SizedBox(height: 10),
          FitText(widget.title, alignment: Alignment.center, style: Fonts.title(36, p.ink)),
          FitText(widget.sub ?? 'الأرقام من الريموت تشتغل هم', alignment: Alignment.center, style: Fonts.body(18, p.muted)),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 14 * (1 - _shake.value), 0), child: child),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var k = 0; k < _len; k++)
                  AnimatedContainer(
                    duration: AppState.I.anim(140),
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k < _code.length ? p.ring : Colors.transparent,
                      border: Border.all(color: _err != null ? _warn(p) : p.ring, width: 2.5),
                    ),
                  ),
              ]),
            ),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                locked ? 'جرّب بعد ${Ar.n(secs ~/ 60)}:${Ar.n((secs % 60).toString().padLeft(2, '0'))}' : (_err ?? ''),
                style: Fonts.body(19, _warn(p), weight: FontWeight.w600),
              ),
            ),
          ),
          Opacity(
            opacity: locked ? 0.4 : 1,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(children: [
                for (var r = 0; r < 4; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var c = 0; c < 3; c++) ...[
                        if (c > 0) const SizedBox(width: 16),
                        Builder(builder: (_) {
                          final i = r * 3 + c;
                          final k = _keys[i];
                          return FocusTap(
                            focusNode: _nodes.of('k$i'),
                            autofocus: i == 4,
                            ensureVisible: false,
                            onTap: () => _press(k),
                            onKey: (e) => _nav(i, e),
                            builder: (_, f) => AnimatedContainer(
                              duration: AppState.I.anim(120),
                              width: 150,
                              height: 78,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: k == 'ok' ? p.accent : (f ? p.ring.withValues(alpha: 0.16) : p.bg.withValues(alpha: p.glass ? 0.3 : 1)),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: f ? p.ring : p.line, width: f ? ringW : 1),
                              ),
                              child: k == 'del'
                                  ? AppIcon(Lu.backspace, color: p.ink, size: 30)
                                  : (k == 'ok' ? AppIcon(Lu.check, color: p.onAccent, size: 32) : Text(Ar.n(k), style: Fonts.body(34, p.ink, weight: FontWeight.w600))),
                            ),
                          );
                        }),
                      ],
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════ قفل الأطفال (انتهى الوقت / وقت النوم) ═══════════════════

String kidsDur(int mins) {
  if (mins <= 0) return 'بلا حد';
  final h = mins ~/ 60, m = mins % 60;
  final hs = switch (h) { 0 => '', 1 => 'ساعة', 2 => 'ساعتين', _ => '${Ar.n(h)} ساعات' };
  if (m == 0) return hs;
  final ms = m == 30 ? 'نص' : '${Ar.n(m)} دقيقة';
  return hs.isEmpty ? ms : '$hs و$ms';
}

class KidsLockScreen extends StatelessWidget {
  const KidsLockScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<String?>(
          valueListenable: Profiles.lock,
          builder: (_, reason, __) {
            final c = AppState.I.cfg;
            final bed = reason == 'bed';
            final name = c.s('kids.name');
            final ink = bed ? const Color(0xFFF4EEDD) : const Color(0xFF5A3410);
            final mu = bed ? const Color(0xFFC9C2AE) : const Color(0xFF8A5A2E);
            final gold = bed ? const Color(0xFFE8C77A) : const Color(0xFFE0973A);
            final step = c.i('kids.step');
            return Stack(fit: StackFit.expand, children: [
              if (bed)
                const WeatherSky(kind: 'clear', night: true, glass: false)
              else
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFCE9C8), Color(0xFFF3CF9E)]))),
              FittedBox(
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: NavZone(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Medallion(icon: bed ? Lu.moonStar : Lu.hourglass, size: 260, color: gold),
                        const SizedBox(height: 26),
                        Text(bed ? 'تصبحون على خير يا $name' : 'خلص وقت المشاهدة لليوم', style: Fonts.title(64, ink)),
                        const SizedBox(height: 10),
                        Text(bed ? 'نشوفكم باچر الصبح بإذن الله' : 'أحسنتم يا $name! باچر نكمل', style: Fonts.body(28, mu)),
                        const SizedBox(height: 28),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _chip(Lu.timer, 'شاهدتوا اليوم ${kidsDur(Profiles.usedToday)}', ink, gold),
                          const SizedBox(width: 14),
                          _chip(bed ? Lu.sunMedium : Lu.calendarDays, bed ? 'الواجهة ترجع الساعة ٦ الصبح' : 'باچر ${kidsDur(KidsLog.limitFor(DateTime.now().add(const Duration(days: 1))))}', ink, gold),
                        ]),
                        const SizedBox(height: 44),
                        ActionRow([
                          if (!bed)
                            Act('${kidsDur(step)} زيادة (رمز الأهل)', () async {
                              if (await showPinPad(context, title: 'تمديد وقت الأطفال')) {
                                Profiles.extend(step);
                                if (context.mounted) Navigator.of(context).pop();
                              }
                            }, icon: Lu.timer, primary: true),
                          Act('ملف العائلة (رمز الأهل)', () async {
                            if (await showPinPad(context, title: 'الخروج لملف العائلة')) {
                              AppState.I.set('profile.active', 'family');
                              Profiles.lock.value = null;
                              ActivityLog.add('users', 'تحوّل لملف العائلة', 'من شاشة قفل الأطفال', kind: 'profile');
                              if (context.mounted) Navigator.of(context).pop();
                            }
                          }, icon: Lu.users),
                        ], autofocus: true),
                      ]),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _chip(Object icon, String t, Color ink, Color gold) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(color: gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: gold.withValues(alpha: 0.6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [AppIcon(icon, color: gold, size: 22), const SizedBox(width: 10), Text(t, style: Fonts.body(21, ink, weight: FontWeight.w600))]),
      );
}

// ═══════════════════ واجهة الأطفال ═══════════════════

(List<Color>, Color, Color) kidsLook(String style) => switch (style) {
      'sky' => (const [Color(0xFFD7ECFF), Color(0xFFAFD3F4)], const Color(0xFF173A5E), const Color(0xFF2F7EC8)),
      'mint' => (const [Color(0xFFDDF5E8), Color(0xFFAEE3C8)], const Color(0xFF16402E), const Color(0xFF2E8A6A)),
      _ => (const [Color(0xFFFCE9C8), Color(0xFFF6D7B0)], const Color(0xFF5A3410), const Color(0xFFE0973A)),
    };

class KidsHome extends StatelessWidget {
  const KidsHome({super.key});

  static const _tileColors = [Color(0xFFE4572E), Color(0xFF2E8A6A), Color(0xFF7A5AC8), Color(0xFF2F7EC8), Color(0xFFE0973A), Color(0xFFC8457A)];

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final (bg, ink, accent) = kidsLook(c.s('kids.style'));
      final apps = Profiles.kidsApps.isEmpty ? s.favorites.take(4).toList() : Profiles.kidsApps.take(6).toList();
      final allowed = Profiles.allowedToday, used = Profiles.usedToday;
      final left = allowed > 0 ? (allowed - used).clamp(0, 9999) : 0;
      return DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(110, 70, 110, 60),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: FitText('أهلاً يا ${c.s('kids.name')}', style: Fonts.title(76, ink))),
              Text('${Ar.time(s.now)} ${s.now.hour < 12 ? 'ص' : 'م'}', style: Fonts.body(40, ink, weight: FontWeight.w600)),
              const SizedBox(width: 28),
              FocusTap(
                onTap: () => Navigator.push(context, fade(const ProfilePicker())),
                builder: (_, f) => AnimatedContainer(
                  duration: s.anim(150),
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: f ? 0.95 : 0.6), shape: BoxShape.circle, border: Border.all(color: f ? accent : Colors.transparent, width: 4)),
                  child: AppIcon(Lu.lock, color: ink, size: 32),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('اختاروا شنو تحبون تشوفون', style: Fonts.body(28, ink.withValues(alpha: 0.75))),
            const Spacer(),
            SizedBox(
              height: 340,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final (i, pkg) in apps.indexed) ...[
                  if (i > 0) const SizedBox(width: 34),
                  FocusTap(
                    autofocus: i == 0,
                    onTap: () => NativeBridge.launch(pkg),
                    builder: (_, f) => AnimatedScale(
                      scale: f ? 1.1 : 1,
                      duration: s.anim(180),
                      child: Column(children: [
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: _tileColors[i % _tileColors.length],
                            borderRadius: BorderRadius.circular(64),
                            border: Border.all(color: f ? Colors.white : Colors.transparent, width: 7),
                            boxShadow: [BoxShadow(color: _tileColors[i % _tileColors.length].withValues(alpha: f ? 0.6 : 0.3), blurRadius: f ? 40 : 18, offset: const Offset(0, 12))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(58),
                            child: Center(child: SizedBox(width: 180, child: AppArtView(package: pkg, m: TileMetrics(180, style: 'icon')))),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(width: 250, child: FitText(s.labelOf(pkg), alignment: Alignment.center, style: Fonts.body(26, ink, weight: FontWeight.w600))),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
            const Spacer(),
            if (allowed > 0) ...[
              Row(children: [
                AppIcon(Lu.timer, color: ink, size: 28),
                const SizedBox(width: 12),
                Text('باقي ${kidsDur(left)}', style: Fonts.body(28, ink, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: (left / allowed).clamp(0.0, 1.0), minHeight: 18, color: accent, backgroundColor: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ]),
        ),
      );
    });
  }
}

/// اختيار تطبيقات الأطفال كشبكة مربعات.
class KidsAppsGrid extends StatefulWidget {
  final bool embedded;
  const KidsAppsGrid({super.key, this.embedded = false});
  @override
  State<KidsAppsGrid> createState() => _KidsAppsGridState();
}

class _KidsAppsGridState extends State<KidsAppsGrid> {
  final nodes = FocusNodes();

  @override
  void dispose() {
    nodes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = live(() {
      final s = AppState.I;
      final p = s.palette;
      final chosen = Profiles.kidsApps;
      final all = [...s.installed]..sort((a, b) => s.labelOf(a.package).compareTo(s.labelOf(b.package)));
      final m = TileMetrics(250, style: 'banner');
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          StatusChip('${Ar.n(chosen.length)} مختارة', icon: Lu.circleCheck),
          const SizedBox(width: 14),
          Text('موافق يضيف أو يشيل التطبيق', style: Fonts.body(19, p.muted)),
        ]),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            clipBehavior: Clip.none,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 26, crossAxisSpacing: 26, childAspectRatio: 250 / (m.artHeight + 60)),
            itemCount: all.length,
            itemBuilder: (_, i) {
              final pkg = all[i].package;
              final on = chosen.contains(pkg);
              return FocusTap(
                focusNode: nodes.of('a$i'),
                autofocus: i == 0,
                onTap: () {
                  final l = [...chosen];
                  if (!l.remove(pkg)) l.add(pkg);
                  Profiles.setKidsApps(l);
                },
                onKey: (e) => gridNav(e, index: i, count: all.length, cols: 5, focus: (t) => nodes.focus('a$t')),
                builder: (_, f) => Stack(clipBehavior: Clip.none, children: [
                  Opacity(opacity: on || f ? 1 : 0.55, child: AppTile(package: pkg, m: m, focused: f, selected: on)),
                  if (on)
                    PositionedDirectional(
                      top: -8,
                      end: -8,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 3)),
                        child: AppIcon(Lu.check, color: p.onAccent, size: 22),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      ]);
    });
    if (widget.embedded) return body;
    return ThemedScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(96, 60, 96, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            AppIcon(Lu.grid, color: pal.ring, size: 40),
            const SizedBox(width: 16),
            Text('تطبيقات الأطفال', style: Fonts.title(48, pal.ink)),
          ]),
          const SizedBox(height: 24),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

// ═══════════════════ تحديث جاهز ═══════════════════

Future<void> showUpdateReady(BuildContext context, UpdateInfo u) => showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: ValueListenableBuilder<double?>(
          valueListenable: Updater.progress,
          builder: (_, prog, __) {
            final p = pal;
            return themedDialog(
              width: 860,
              child: NavZone(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Medallion(icon: Lu.cloudDownload, size: 150, color: p.ring),
                    const SizedBox(width: 26),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        StatusChip(prog == null ? 'تحديث جاهز' : 'جاري التنزيل', icon: prog == null ? Lu.sparkles : Lu.download),
                        const SizedBox(height: 10),
                        FitText('الإصدار ${Ar.n(u.version)}', style: Fonts.title(52, p.ink)),
                        FitText(u.size > 0 ? 'الحجم ${Ar.n((u.size / 1048576).toStringAsFixed(1)).replaceAll('.', '٫')} م.ب، ونسختك الاحتياطية تنحفظ قبل التثبيت' : 'نسختك الاحتياطية تنحفظ قبل التثبيت',
                            style: Fonts.body(18, p.muted)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  for (final n in u.notes.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(width: 9, height: 9, decoration: BoxDecoration(color: p.ring, shape: BoxShape.circle)),
                        const SizedBox(width: 14),
                        Expanded(child: FitText(n, style: Fonts.body(21, p.ink))),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  if (prog != null) ...[
                    Row(children: [
                      RawnaqLoader(size: 96, progress: prog),
                      const SizedBox(width: 22),
                      Expanded(child: FitText('جاري التنزيل ${Ar.n((prog * 100).round())}٪', style: Fonts.body(24, p.ink, weight: FontWeight.w600))),
                    ]),
                  ] else
                    ActionRow([
                      Act('تثبيت الآن', () async {
                        final ok = await Updater.downloadAndInstall(u);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          toast(context, ok ? 'وافق على التثبيت بالشاشة اللي تطلع' : Updater.lastError);
                        }
                      }, icon: Lu.download, primary: true),
                      Act('بعدين', () => Navigator.pop(ctx), icon: Lu.clock),
                    ], autofocus: true),
                ]),
              ),
            );
          },
        ),
      ),
    );

// ═══════════════════ عد تنازلي قبل الإطفاء ═══════════════════

Future<void> showPowerCountdown(BuildContext context, DateTime at) => showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: _Countdown(at: at)),
    );

class _Countdown extends StatefulWidget {
  final DateTime at;
  const _Countdown({required this.at});
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _t;
  late final int _total = math.max(1, widget.at.difference(DateTime.now()).inSeconds);

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(widget.at)) {
        _t?.cancel();
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final left = math.max(0, widget.at.difference(DateTime.now()).inMilliseconds) / 1000;
    return themedDialog(
      width: 760,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox.square(
          dimension: 230,
          child: CustomPaint(
            painter: _RingPainter(left / _total, p.ring, p.line),
            child: Center(child: Text(Ar.n(left.ceil()), style: Fonts.title(96, p.ink))),
          ),
        ),
        const SizedBox(height: 20),
        Text('الشاشة راح تطفي', style: Fonts.title(44, p.ink)),
        const SizedBox(height: 6),
        Text('حسب جدول الإطفاء التلقائي', style: Fonts.body(21, p.muted)),
        const SizedBox(height: 30),
        ActionRow([
          Act('إلغاء الإطفاء اليوم', () {
            SystemWatch.I.skipToday();
            Navigator.pop(context);
          }, icon: Lu.x, primary: true),
          Act('أطفي هسه', () {
            Navigator.pop(context);
            NativeBridge.sleepNow();
          }, icon: Lu.power),
        ], autofocus: true),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color c, track;
  _RingPainter(this.v, this.c, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 10);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v.clamp(0.0, 1.0), false, p..color = c);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.v != v;
}

// ═══════════════════ ترحيب المناسبة ═══════════════════

class OccasionWelcome extends StatefulWidget {
  final String title, date;
  const OccasionWelcome({super.key, required this.title, required this.date});
  @override
  State<OccasionWelcome> createState() => _OccasionWelcomeState();
}

class _OccasionWelcomeState extends State<OccasionWelcome> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(seconds: 25), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String get _phrase {
    final t = widget.title;
    if (t.contains('ولادة') || t.contains('المولد') || t.contains('عيد') || t.contains('المبعث') || t.contains('رمضان') || t.contains('رأس السنة')) return 'أعاده الله عليكم بالخير والبركات';
    if (t.contains('استشهاد') || t.contains('عاشوراء') || t.contains('وفاة') || t.contains('الأربعين') || t.contains('ضربة')) return 'عظّم الله أجورنا وأجوركم';
    return 'تقبّل الله أعمالكم';
  }

  @override
  Widget build(BuildContext context) {
    final mourning = _phrase.startsWith('عظّم');
    final bg = mourning ? const [Color(0xFF2A0C10), Color(0xFF12060A)] : const [Color(0xFF0B2A20), Color(0xFF06120E)];
    const gold = Color(0xFFE2BE72);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent) Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        },
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 1.1, colors: bg)),
          child: FittedBox(
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Medallion(icon: Lu.calendarHeart, size: 300, color: gold),
                const SizedBox(height: 30),
                Text(widget.date, style: Fonts.body(30, gold, weight: FontWeight.w600)),
                const SizedBox(height: 10),
                SizedBox(width: 1500, child: FitText(widget.title, alignment: Alignment.center, style: Fonts.title(76, const Color(0xFFF4EEDD)))),
                const SizedBox(height: 18),
                Text(_phrase, style: Fonts.body(32, const Color(0xFFD9CFB8))),
                const SizedBox(height: 60),
                Text('أي زر يكمل للواجهة', style: Fonts.body(20, const Color(0xFF9C927C))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ الأمان ورمز الأهل ═══════════════════

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  Future<void> _change(BuildContext context) async {
    if (!await showPinPad(context, title: 'الرمز الحالي')) return;
    if (!context.mounted) return;
    final v = await promptText(context, title: 'الرمز الجديد (٤ أرقام أو أكثر)', obscure: true, number: true);
    if (v == null || v.length < 4 || int.tryParse(v) == null) {
      if (context.mounted && v != null) toast(context, 'الرمز لازم ٤ أرقام أو أكثر');
      return;
    }
    if (!context.mounted) return;
    final again = await promptText(context, title: 'أعد الرمز الجديد للتأكيد', obscure: true, number: true);
    if (again != v) {
      if (context.mounted) toast(context, 'الرمزين مو نفس الشي');
      return;
    }
    PinGuard.change(v);
    if (context.mounted) toast(context, 'تغيّر رمز الأهل');
  }

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final p = s.palette;
      final changed = c.i('pin.changed');
      final until = PinGuard.lockedUntil;
      final weak = c.s('misc.pin') == '0000' || c.s('misc.pin') == '1234';
      return SysScaffold(
        title: 'الأمان ورمز الأهل',
        sub: 'رمز واحد يحمي الإعدادات والملفات والتطبيقات المقفلة',
        icon: Lu.shieldCheck,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Medallion(icon: Lu.key, size: 190, color: weak ? _warn(p) : p.ring),
            const SizedBox(height: 12),
            FitText(weak ? 'الرمز سهل' : 'الرمز مفعّل', alignment: Alignment.center, style: Fonts.title(46, p.ink)),
            FitText(changed == 0 ? 'ما تغيّر من أول تشغيل' : 'آخر تغيير ${Recents.ago(DateTime.fromMillisecondsSinceEpoch(changed))}', alignment: Alignment.center, style: Fonts.body(19, p.muted)),
            const SizedBox(height: 20),
            StatusLine('المحاولات قبل القفل', '${Ar.n(c.i('pin.attempts'))} محاولات', icon: Lu.listChecks),
            StatusLine('مدة القفل المؤقت', '${Ar.n(c.i('pin.lockMins'))} دقائق', icon: Lu.timer),
            StatusLine('الحالة', until != null ? 'مقفل لحد ${Ar.time(until)}' : (weak ? 'غيّر الرمز الافتراضي' : 'محمي'), kind: until != null || weak ? 'warn' : 'ok'),
          ]),
        ),
        right: [
          SysRow(icon: Lu.key, title: 'تغيير رمز الأهل', sub: weak ? 'الرمز الحالي سهل التخمين' : 'يطلب الرمز الحالي أولاً', value: '••••', autofocus: true, onTap: () => _change(context)),
          SysRow(
            icon: Lu.listChecks,
            title: 'عدد المحاولات',
            sub: 'بعدها ينقفل الرمز مؤقتاً',
            value: '${Ar.n(c.i('pin.attempts'))}',
            onTap: () => showChoicePicker<int>(context, title: 'عدد المحاولات', options: [for (final n in [3, 5, 10]) (n, '${Ar.n(n)} محاولات')], value: c.i('pin.attempts'), onChanged: (v) => s.set('pin.attempts', v)),
          ),
          SysRow(
            icon: Lu.timer,
            title: 'مدة القفل المؤقت',
            value: '${Ar.n(c.i('pin.lockMins'))} د',
            onTap: () => showChoicePicker<int>(context, title: 'مدة القفل', options: [for (final n in [1, 5, 15, 30]) (n, '${Ar.n(n)} دقائق')], value: c.i('pin.lockMins'), onChanged: (v) => s.set('pin.lockMins', v)),
          ),
          const SysSection('شنو يحتاج الرمز'),
          SysRow(icon: Lu.settings, title: 'إعدادات رونق', sub: 'حتى بملف العائلة', toggle: c.b('pin.settings'), onTap: () => s.set('pin.settings', !c.b('pin.settings'))),
          SysRow(icon: Lu.users, title: 'الخروج من ملف الأطفال والضيف', toggle: c.b('pin.profiles'), onTap: () => s.set('pin.profiles', !c.b('pin.profiles'))),
          SysRow(icon: Lu.trash, title: 'إزالة التطبيقات', toggle: c.b('pin.uninstall'), onTap: () => s.set('pin.uninstall', !c.b('pin.uninstall'))),
          SysRow(icon: Lu.lock, title: 'التطبيقات المقفلة', sub: 'تنقفل من خيارات أي تطبيق بالواجهة (ضغطة طويلة)', value: Ar.n(s.locked.length), onTap: () {}),
          if (until != null)
            SysRow(icon: Lu.lockOpen, title: 'فك القفل المؤقت', sub: 'يحتاج الرمز الصحيح', onTap: () async {
              s.set('pin.until', 0);
              if (!await showPinPad(context, title: 'فك القفل')) s.set('pin.until', until.millisecondsSinceEpoch);
            }),
        ],
      );
    });
  }
}

// ═══════════════════ معالج إعداد الأطفال ═══════════════════

class KidsSetupWizard extends StatefulWidget {
  const KidsSetupWizard({super.key});
  @override
  State<KidsSetupWizard> createState() => _KidsSetupWizardState();
}

class _KidsSetupWizardState extends State<KidsSetupWizard> {
  int _step = 0;
  static const _titles = ['اسم الأطفال', 'تطبيقاتهم', 'وقت المشاهدة'];

  Widget _dots(Palette p) => Row(children: [
        for (var k = 0; k < 3; k++) ...[
          if (k > 0) Container(width: 50, height: 2, color: k <= _step ? p.ring : p.line),
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: k <= _step ? p.ring : p.surface, border: Border.all(color: k <= _step ? p.ring : p.line)),
            child: k < _step ? AppIcon(Lu.check, color: p.onAccent, size: 22) : Text(Ar.n(k + 1), style: Fonts.body(20, k == _step ? p.onAccent : p.muted, weight: FontWeight.w700)),
          ),
        ],
        const SizedBox(width: 18),
        Text(_titles[_step], style: Fonts.body(22, p.ink, weight: FontWeight.w600)),
      ]);

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final p = s.palette;
      final (bg, ink, accent) = kidsLook(c.s('kids.style'));
      final preview = Container(
        height: 330,
        padding: const EdgeInsets.all(30),
        decoration: ShapeDecoration(gradient: LinearGradient(colors: bg, begin: Alignment.topLeft, end: Alignment.bottomRight), shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(60))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FitText('أهلاً يا ${c.s('kids.name')}', style: Fonts.title(40, ink)),
          const SizedBox(height: 18),
          Expanded(
            child: Row(children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: Container(decoration: BoxDecoration(color: KidsHome._tileColors[i], borderRadius: BorderRadius.circular(30)))),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Text(c.i('kids.limit') > 0 ? 'باقي ${kidsDur(c.i('kids.limit'))}' : 'بلا حد يومي', style: Fonts.body(19, ink, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(7), child: LinearProgressIndicator(value: 1, minHeight: 12, color: accent, backgroundColor: Colors.white70)),
        ]),
      );
      final names = ['الأبطال', 'الصغار', 'الحلوين', 'نجوم البيت', 'الشطار'];
      final List<Widget> rows = switch (_step) {
        0 => [
            for (final (i, n) in names.indexed)
              SysRow(icon: c.s('kids.name') == n ? Lu.circleCheck : Lu.circle, title: n, toggle: c.s('kids.name') == n, autofocus: i == 0, onTap: () => s.set('kids.name', n)),
            SysRow(icon: Lu.userPen, title: 'اسم ثاني', sub: 'اكتب اسم أطفالك', value: names.contains(c.s('kids.name')) ? '' : c.s('kids.name'), onTap: () async {
              final v = await promptText(context, title: 'اسم الأطفال', initial: c.s('kids.name'));
              if (v != null && v.trim().isNotEmpty) s.set('kids.name', v.trim());
            }),
            SysRow(icon: Lu.palette, title: 'لون واجهتهم', value: switch (c.s('kids.style')) { 'sky' => 'سماوي', 'mint' => 'نعناعي', _ => 'دافئ' }, onTap: () => showChoicePicker<String>(context, title: 'لون واجهة الأطفال', options: const [('warm', 'دافئ'), ('sky', 'سماوي'), ('mint', 'نعناعي')], value: c.s('kids.style'), onChanged: (v) => s.set('kids.style', v))),
          ],
        1 => [SizedBox(height: 640, child: const KidsAppsGrid(embedded: true))],
        _ => [
            SysRow(icon: Lu.timer, title: 'الأيام العادية', value: kidsDur(c.i('kids.limit')), autofocus: true, onTap: () => showChoicePicker<int>(context, title: 'وقت الأيام العادية', options: [for (final m in [0, 30, 60, 90, 120, 150, 180]) (m, kidsDur(m))], value: c.i('kids.limit'), onChanged: (v) => s.set('kids.limit', v))),
            SysRow(icon: Lu.calendarRange, title: 'أيام العطلة', sub: 'الجمعة والسبت', value: c.i('kids.weekend') == 0 ? 'نفس العادية' : kidsDur(c.i('kids.weekend')), onTap: () => showChoicePicker<int>(context, title: 'وقت العطلة', options: [(0, 'نفس العادية'), for (final m in [60, 120, 180, 240, 300]) (m, kidsDur(m))], value: c.i('kids.weekend'), onChanged: (v) => s.set('kids.weekend', v))),
            SysRow(icon: Lu.moon, title: 'وقت النوم', value: c.i('kids.bed') < 0 ? 'بلا' : '${Ar.time(DateTime(2000, 1, 1, c.i('kids.bed') ~/ 60, c.i('kids.bed') % 60))} م', onTap: () => showChoicePicker<int>(context, title: 'وقت النوم', options: [(-1, 'بلا وقت نوم'), for (var m = 1140; m <= 1350; m += 30) (m, '${Ar.time(DateTime(2000, 1, 1, m ~/ 60, m % 60))} م')], value: c.i('kids.bed'), onChanged: (v) => s.set('kids.bed', v))),
          ],
      };
      return SysScaffold(
        title: 'إعداد ملف الأطفال',
        sub: 'ثلاث خطوات وتصير عندهم واجهة خاصة بيهم',
        icon: Lu.baby,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _dots(p),
            const SizedBox(height: 24),
            preview,
            const SizedBox(height: 16),
            FitText('المعاينة تتبدل لحظياً مع كل اختيار', style: Fonts.body(18, p.muted)),
          ]),
        ),
        right: [
          ...rows,
          const SizedBox(height: 10),
          ActionRow([
            Act(_step == 2 ? 'تم، شغّل ملف الأطفال' : 'التالي', () {
              if (_step < 2) {
                setState(() => _step++);
              } else {
                s.set('kids.setup', true);
                s.set('profile.active', 'kids');
                ActivityLog.add('baby', 'اكتمل إعداد ملف الأطفال', c.s('kids.name'), kind: 'profile');
                Navigator.pop(context);
              }
            }, icon: _step == 2 ? Lu.check : Lu.chevronLeft, primary: true),
            if (_step > 0) Act('السابق', () => setState(() => _step--), icon: Lu.chevronRight),
          ]),
        ],
      );
    });
  }
}

// ═══════════════════ ربط القابس الذكي (معالج) ═══════════════════

class PlugWizard extends StatefulWidget {
  const PlugWizard({super.key});
  @override
  State<PlugWizard> createState() => _PlugWizardState();
}

class _PlugWizardState extends State<PlugWizard> {
  int _step = 0;
  bool? _offOk, _onOk;
  bool _busy = false;
  String? _found;

  Future<void> _test(bool on) async {
    setState(() => _busy = true);
    final ok = await PlugCfg.get(PlugCfg.url(on));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (on) {
        _onOk = ok;
      } else {
        _offOk = ok;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final p = s.palette;
      final kinds = const [('shelly2', 'Shelly الجيل الثاني', 'Plus وPro'), ('shelly1', 'Shelly الجيل الأول', 'Plug S وغيرها'), ('tasmota', 'Tasmota', 'قوابس بنظام تاسموتا')];
      String kindName(String k) => kinds.firstWhere((e) => e.$1 == k, orElse: () => kinds.first).$2;
      final steps = ['نوع القابس', 'عنوانه بالشبكة', 'الاختبار'];
      final List<Widget> rows = switch (_step) {
        0 => [
            for (final (i, k) in kinds.indexed)
              SysRow(icon: c.s('plug.kind') == k.$1 ? Lu.circleCheck : Lu.circle, title: k.$2, sub: k.$3, toggle: c.s('plug.kind') == k.$1, autofocus: i == 0, onTap: () => s.set('plug.kind', k.$1)),
          ],
        1 => [
            SysRow(icon: Lu.router, title: 'عنوان القابس (IP)', sub: 'تلگاه بتطبيق القابس أو بالراوتر', value: c.s('plug.ip').isEmpty ? 'غير محدد' : c.s('plug.ip'), autofocus: true, onTap: () async {
              final v = await promptText(context, title: 'عنوان القابس', initial: c.s('plug.ip'));
              if (v != null) s.set('plug.ip', v.trim());
            }),
            SysRow(icon: Lu.search, title: _busy ? 'جاري الكشف…' : 'كشف النوع تلقائياً', sub: _found == null ? 'يتأكد إن القابس يرد' : (_found!.isEmpty ? 'ما رد القابس، تأكد من العنوان' : 'لگينا: ${kindName(_found!)}'), onTap: () async {
              if (c.s('plug.ip').isEmpty) return;
              setState(() => _busy = true);
              final k = await PlugCfg.detect(c.s('plug.ip'));
              if (!mounted) return;
              setState(() {
                _busy = false;
                _found = k ?? '';
              });
              if (k != null) s.set('plug.kind', k);
            }),
          ],
        _ => [
            SysRow(icon: Lu.power, title: 'إطفاء تجريبي', sub: 'التلفزيون ينطفي ثواني', value: _offOk == null ? '' : (_offOk! ? 'اشتغل' : 'ما رد'), autofocus: true, onTap: () => _test(false)),
            SysRow(icon: Lu.plugZap, title: 'تشغيل تجريبي', sub: 'ترجع الكهرباء للتلفزيون', value: _onOk == null ? '' : (_onOk! ? 'اشتغل' : 'ما رد'), onTap: () => _test(true)),
            SysRow(icon: Lu.timer, title: 'الانتظار قبل قطع الكهرباء', sub: 'حتى يوصل أمر الإطفاء للتلفزيون أولاً', value: '${Ar.n(c.i('plug.wait'))} ثانية', onTap: () => showChoicePicker<int>(context, title: 'الانتظار', options: [for (final n in [5, 10, 20, 30]) (n, '${Ar.n(n)} ثانية')], value: c.i('plug.wait'), onChanged: (v) => s.set('plug.wait', v))),
          ],
      };
      return SysScaffold(
        title: 'ربط القابس الذكي',
        sub: 'إطفاء حقيقي للتلفزيون مع نوم الستريمر',
        icon: Lu.plugZap,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Medallion(icon: Lu.plugZap, size: 200, color: p.ring),
            const SizedBox(height: 16),
            for (final (k, t) in steps.indexed)
              StatusLine('${Ar.n(k + 1)}. $t', k < _step ? 'تم' : (k == _step ? 'هسه' : 'بعدين'), kind: k < _step ? 'ok' : (k == _step ? 'warn' : 'none'), icon: k < _step ? Lu.circleCheck : null),
            if (_step == 2 && _offOk == true && _onOk == true) ...[const SizedBox(height: 8), const StatusChip('القابس يشتغل تمام', icon: Lu.circleCheck)],
          ]),
        ),
        right: [
          ...rows,
          const SizedBox(height: 10),
          ActionRow([
            Act(_step == 2 ? 'تم، فعّل القابس' : 'التالي', () async {
              if (_step < 2) {
                setState(() => _step++);
              } else {
                if (c.s('power.method') == 'cec') s.set('power.method', 'both');
                await PlugCfg.apply();
                ActivityLog.add('plug-zap', 'انربط القابس الذكي', c.s('plug.ip'), kind: 'power');
                if (context.mounted) Navigator.pop(context);
              }
            }, icon: _step == 2 ? Lu.check : Lu.chevronLeft, primary: true),
            if (_step > 0) Act('السابق', () => setState(() => _step--), icon: Lu.chevronRight),
          ]),
        ],
      );
    });
  }
}

// ═══════════════════ عن رونق والشكر ═══════════════════

class AboutRawnaqScreen extends StatelessWidget {
  const AboutRawnaqScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final p = s.palette;
      final v = s.version.isNotEmpty ? s.version : '3.8.0';
      return SysScaffold(
        title: 'عن رونق',
        sub: 'واجهة عربية لشاشات البيت، بهوية أهل البيت (ع)',
        icon: Lu.info,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RawnaqLockup(markSize: 200, night: p.night, stacked: true, glow: true),
            const SizedBox(height: 18),
            StatusChip('الإصدار ${Ar.n(v)}', icon: Lu.badgeCheck),
            const SizedBox(height: 18),
            FitText('صُنع بحب لعوائلنا، بالعربي من أول حرف لآخر حرف', alignment: Alignment.center, style: Fonts.body(20, p.muted)),
            const SizedBox(height: 18),
            Container(height: 1, color: p.line),
            const SizedBox(height: 18),
            FitText('اللّهمّ صلِّ على محمدٍ وآلِ محمد', alignment: Alignment.center, style: Fonts.title(30, p.ring)),
          ]),
        ),
        right: [
          SysRow(icon: Lu.tv, title: 'الجهاز', value: s.model.isEmpty ? 'أندرويد TV' : s.model, autofocus: true, onTap: () {}),
          SysRow(icon: Lu.scrollText, title: 'سجل الإصدارات', sub: 'كل اللي وصل لرونق', onTap: () => Navigator.push(context, fade(const VersionHistoryScreen()))),
          const SysSection('شكر وتقدير'),
          SysRow(icon: Lu.cloudSun, title: 'Open-Meteo', sub: 'بيانات الطقس وجودة الهواء، مجاناً', onTap: () {}),
          SysRow(icon: Lu.shapes, title: 'Lucide', sub: 'الأيقونات (رخصة ISC)', onTap: () {}),
          SysRow(icon: Lu.type, title: 'Google Fonts', sub: 'ريم كوفي، ريدكس برو، أميري وغيرها', onTap: () {}),
          SysRow(icon: Lu.calendarHeart, title: 'التقويم الهجري', sub: 'حزمة hijri المفتوحة المصدر', onTap: () {}),
          SysRow(icon: Lu.thanks, title: 'وكل من جرّب واقترح', sub: 'أفكاركم صارت جزء من رونق', onTap: () {}),
        ],
      );
    });
  }
}

// ═══════════════════ وضع المناسبات ═══════════════════

class OccasionsScreen extends StatelessWidget {
  const OccasionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final p = s.palette;
      final up = Hijri.upcoming(days: 360, max: 6);
      final today = Hijri.of(DateTime.now());
      return SysScaffold(
        title: 'وضع المناسبات',
        sub: 'الواجهة تتهيأ وحدها للمناسبات الدينية حسب التقويم الهجري',
        icon: Lu.calendarHeart,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              StatusChip(Hijri.label(today), icon: Lu.moonStar),
              const SizedBox(width: 12),
              if (OccasionMode.mourning) const StatusChip('ثيم الدر الحسيني', kind: 'warn', icon: Lu.palette),
            ]),
            const SizedBox(height: 18),
            FitText('المناسبات الجاية', style: Fonts.body(24, p.ink, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final (h, t) in up)
              Container(
                height: 70,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: p.bg.withValues(alpha: p.glass ? 0.3 : 1), borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
                child: Row(children: [
                  SizedBox(width: 130, child: FitText(Hijri.label(h), style: Fonts.body(19, p.ring, weight: FontWeight.w600))),
                  Expanded(child: FitText(t, style: Fonts.body(20, p.ink))),
                  const SizedBox(width: 12),
                  Text(_inDays(h.g), style: Fonts.body(17, p.muted)),
                ]),
              ),
            if (up.isEmpty) FitText('ما بيه مناسبات قريبة', style: Fonts.body(20, p.muted)),
          ]),
        ),
        right: [
          SysRow(icon: Lu.calendarHeart, title: 'وضع المناسبات', sub: 'ترحيب وتنبيه وتهيئة الواجهة', toggle: c.b('occ.mode'), autofocus: true, onTap: () => s.set('occ.mode', !c.b('occ.mode'))),
          SysRow(icon: Lu.palette, title: 'ثيم الدر الحسيني بمحرم والأربعين', sub: 'يرجع ثيمك السابق وحده بعدها', toggle: c.b('occ.theme'), onTap: () => s.set('occ.theme', !c.b('occ.theme'))),
          SysRow(icon: Lu.sparkles, title: 'ترحيب يوم المناسبة', sub: 'شاشة أنيقة أول ما تفتح الواجهة', toggle: c.b('occ.welcome'), onTap: () => s.set('occ.welcome', !c.b('occ.welcome'))),
          SysRow(icon: Lu.moonStar, title: 'تعديل التاريخ الهجري', sub: 'حسب رؤية الهلال عندكم', value: c.i('misc.hijriOffset') == 0 ? 'بلا تعديل' : '${c.i('misc.hijriOffset') > 0 ? '+' : ''}${Ar.n(c.i('misc.hijriOffset'))} يوم', onTap: () => showChoicePicker<int>(context, title: 'تعديل التاريخ الهجري', options: [for (final d in [-2, -1, 0, 1, 2]) (d, d == 0 ? 'بلا تعديل' : '${d > 0 ? '+' : ''}${Ar.n(d)} يوم')], value: c.i('misc.hijriOffset'), onChanged: (v) => s.set('misc.hijriOffset', v))),
          SysRow(icon: Lu.eye, title: 'معاينة الترحيب', onTap: () {
            final o = up.isEmpty ? ('المولد النبوي الشريف', '١٧ ربيع الأول') : (up.first.$2, Hijri.label(up.first.$1));
            Navigator.push(context, fade(OccasionWelcome(title: o.$1, date: o.$2)));
          }),
        ],
      );
    });
  }

  static String _inDays(DateTime g) {
    final n = DateTime.now();
    final d = DateTime(g.year, g.month, g.day).difference(DateTime(n.year, n.month, n.day)).inDays;
    return d == 0 ? 'اليوم' : (d == 1 ? 'باچر' : 'بعد ${Ar.n(d)} يوم');
  }
}

// ═══════════════════ رمضان ═══════════════════

class RamadanScreen extends StatelessWidget {
  const RamadanScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final p = s.palette;
      final nx = Ramadan.next;
      final im = Ramadan.imsak, ift = Ramadan.iftar;
      String hm(DateTime? t) => t == null ? '—' : '${Ar.time(t)} ${t.hour < 12 ? 'ص' : 'م'}';
      return SysScaffold(
        title: 'وضع رمضان',
        sub: 'الإمساك والإفطار بالواجهة، وتنبيه قبل الإفطار',
        icon: Lu.moonStar,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Medallion(icon: Lu.moonStar, size: 200, color: p.ring),
            const SizedBox(height: 10),
            FitText(Ramadan.active ? 'رمضان كريم' : 'رمضان مو هسه', alignment: Alignment.center, style: Fonts.title(48, p.ink)),
            if (Ramadan.active) FitText('اليوم ${Ar.n(Ramadan.day)} من شهر رمضان', alignment: Alignment.center, style: Fonts.body(20, p.muted)),
            const SizedBox(height: 20),
            if (nx != null) FitText('${nx.$1} بعد ${kidsDur(nx.$2.difference(DateTime.now()).inMinutes)}', alignment: Alignment.center, style: Fonts.title(40, p.ring)),
            const SizedBox(height: 18),
            StatusLine('الإمساك', hm(im), icon: Lu.sunrise, kind: 'none'),
            StatusLine('الإفطار (المغرب)', hm(ift), icon: Lu.sunset, kind: 'none'),
          ]),
        ),
        right: [
          SysRow(
            icon: Lu.moonStar,
            title: 'وضع رمضان',
            value: switch (c.s('ramadan.mode')) { 'on' => 'دائماً', 'off' => 'مطفأ', _ => 'تلقائي بالشهر' },
            autofocus: true,
            onTap: () => showChoicePicker<String>(context, title: 'وضع رمضان', options: const [('auto', 'تلقائي بالشهر'), ('on', 'دائماً'), ('off', 'مطفأ')], value: c.s('ramadan.mode'), onChanged: (v) => s.set('ramadan.mode', v)),
          ),
          SysRow(icon: Lu.layoutTop, title: 'الإمساك والإفطار بأعلى الواجهة', toggle: c.b('ramadan.banner'), onTap: () => s.set('ramadan.banner', !c.b('ramadan.banner'))),
          SysRow(icon: Lu.clock, title: 'المواقيت تتبع مدينتك', sub: 'نفس إعدادات أوقات الصلاة', onTap: () {}),
        ],
      );
    });
  }
}

/// كبسولة رمضان بأعلى الواجهة.
class RamadanPill extends StatelessWidget {
  final bool onDark;
  const RamadanPill({super.key, required this.onDark});
  @override
  Widget build(BuildContext context) {
    final nx = Ramadan.next;
    if (!Ramadan.active || !AppState.I.cfg.b('ramadan.banner') || nx == null) return const SizedBox.shrink();
    final p = pal;
    final fg = onDark ? Colors.white : p.ink;
    final mins = nx.$2.difference(DateTime.now()).inMinutes;
    return FocusTap(
      ensureVisible: false,
      onTap: () => Navigator.push(context, fade(const RamadanScreen())),
      builder: (_, f) => AnimatedContainer(
        duration: AppState.I.anim(150),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: p.ring.withValues(alpha: onDark ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: f ? p.ring : p.ring.withValues(alpha: 0.5), width: f ? 3 : 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(Lu.moonStar, color: p.ring, size: 26),
          const SizedBox(width: 10),
          Text('${nx.$1} ${Ar.time(nx.$2)}', style: Fonts.body(21, fg, weight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text('بعد ${kidsDur(mins)}', style: Fonts.body(18, onDark ? Colors.white70 : p.muted)),
        ]),
      ),
    );
  }
}

/// كبسولة الضيف بأعلى الواجهة.
class GuestPill extends StatelessWidget {
  final bool onDark;
  const GuestPill({super.key, required this.onDark});
  @override
  Widget build(BuildContext context) {
    if (!Profiles.guest) return const SizedBox.shrink();
    final p = pal;
    final h = AppState.I.cfg.i('guest.hours');
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: const Color(0xFF3F6AA8).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFF3F6AA8).withValues(alpha: 0.6))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AppIcon(Lu.userRound, color: onDark ? Colors.white : p.ink, size: 24),
        const SizedBox(width: 10),
        Text(h > 0 ? 'وضع الضيف، يرجع وحده بعد ${kidsDur(h * 60)}' : 'وضع الضيف', style: Fonts.body(19, onDark ? Colors.white : p.ink, weight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══════════════════ تقرير الأطفال الأسبوعي ═══════════════════

class KidsReportScreen extends StatelessWidget {
  const KidsReportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final p = s.palette;
      final week = KidsLog.week();
      final total = week.fold<int>(0, (a, b) => a + b.$2);
      final apps = KidsLog.apps.entries.where((e) => s.app(e.key) != null).toList()..sort((a, b) => b.value.compareTo(a.value));
      final limit = s.cfg.i('kids.limit');
      final over = week.where((d) => limit > 0 && d.$2 > KidsLog.limitFor(d.$1)).length;
      return SysScaffold(
        title: 'تقرير الأطفال الأسبوعي',
        sub: 'شكد شاهدوا، وشنو أكثر شي حبّوه',
        icon: Lu.chart,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FitText(kidsDur(total), style: Fonts.title(52, p.ink)),
                  FitText('هذا الأسبوع، بمعدل ${kidsDur((total / 7).round())} باليوم', style: Fonts.body(19, p.muted)),
                ]),
              ),
              StatusChip(over == 0 ? 'ضمن الحد كل الأيام' : 'تجاوزوا الحد ${Ar.n(over)} أيام', kind: over == 0 ? 'ok' : 'warn'),
            ]),
            const SizedBox(height: 26),
            SizedBox(height: 330, child: CustomPaint(painter: _WeekPainter(week, limit, p))),
            const SizedBox(height: 10),
            Row(children: [
              for (final d in week) Expanded(child: FitText(Ar.dayName(d.$1), alignment: Alignment.center, style: Fonts.body(16, p.muted))),
            ]),
          ]),
        ),
        right: [
          const SysSection('أكثر التطبيقات'),
          if (apps.isEmpty) SysRow(icon: Lu.info, title: 'ما بيه بيانات بعد', sub: 'التقرير يتجمع وحده من يشتغل ملف الأطفال', autofocus: true, onTap: () {}),
          for (final (i, e) in apps.take(6).indexed) SysRow(icon: Lu.play, title: s.labelOf(e.key), value: kidsDur(e.value), autofocus: i == 0, onTap: () {}),
          const SysSection('الإعدادات'),
          SysRow(icon: Lu.settings, title: 'إعدادات ملف الأطفال', onTap: () => Navigator.push(context, fade(const KidsScreen()))),
        ],
      );
    });
  }
}

class _WeekPainter extends CustomPainter {
  final List<(DateTime, int)> w;
  final int limit;
  final Palette p;
  _WeekPainter(this.w, this.limit, this.p);
  @override
  void paint(Canvas c, Size s) {
    final mx = math.max(limit.toDouble(), w.fold<int>(0, (a, b) => math.max(a, b.$2)).toDouble()) * 1.15;
    if (mx <= 0) return;
    final cw = s.width / w.length;
    // RTL: أقدم يوم يمين
    for (var i = 0; i < w.length; i++) {
      final d = w[w.length - 1 - i];
      final h = d.$2 / mx * s.height;
      final over = limit > 0 && d.$2 > KidsLog.limitFor(d.$1);
      final x = i * cw + cw * 0.22;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, s.height - math.max(6.0, h), cw * 0.56, math.max(6.0, h)), const Radius.circular(14));
      c.drawRRect(r, Paint()..color = over ? _warn(p) : (i == 0 ? p.ring : p.accent.withValues(alpha: 0.75)));
    }
    if (limit > 0) {
      final y = s.height - limit / mx * s.height;
      for (var x = 0.0; x < s.width; x += 18) {
        c.drawLine(Offset(x, y), Offset(x + 9, y), Paint()..color = p.muted..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeekPainter o) => true;
}

// ═══════════════════ الأجهزة والمزامنة ═══════════════════

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    Sync.rev.addListener(_ch);
    Sync.localIp().then((v) {
      if (v != null && mounted) setState(() => Sync.myIp = v);
    });
  }

  void _ch() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Sync.rev.removeListener(_ch);
    super.dispose();
  }

  void _peer(SyncPeer d) => showActions(context, d.name, [
        ('نسخ إعداداتي إلى «${d.name}»', Lu.upload, () async {
          final ok = await Sync.push(d);
          if (mounted) toast(context, ok ? 'وصلت الإعدادات لـ«${d.name}»' : 'ما ردت الشاشة، تأكد إن الرمز نفسه والمزامنة شغالة بيها');
        }, false),
        ('جيب إعدادات «${d.name}» هنا', Lu.download, () async {
          final ok = await Sync.pull(d);
          if (mounted) toast(context, ok ? 'تطبقت إعدادات «${d.name}»' : 'ما ردت الشاشة');
        }, false),
        ('نسيان هذي الشاشة', Lu.trash, () => Sync.forget(d), true),
      ]);

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final p = s.palette;
      final peers = Sync.peers;
      Widget dev(String name, String sub, bool me) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: p.bg.withValues(alpha: p.glass ? 0.3 : 1),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: me ? p.ring : p.line, width: me ? 2.5 : 1),
            ),
            child: Row(children: [
              Medallion(icon: Lu.tv, size: 76, color: me ? p.ring : p.muted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FitText(name, style: Fonts.body(26, p.ink, weight: FontWeight.w600)),
                  FitText(sub, style: Fonts.body(17, p.muted)),
                ]),
              ),
              StatusChip(me ? 'هذا الجهاز' : 'بالشبكة', icon: me ? Lu.star : Lu.wifi, kind: me ? 'warn' : 'ok'),
            ]),
          );
      return SysScaffold(
        title: 'الأجهزة والمزامنة',
        sub: 'شاشتين بإعدادات وحدة، تنسخ الثيم والترتيب بضغطة',
        icon: Lu.devices,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FitText('شاشاتك', style: Fonts.title(30, p.ink)),
            const SizedBox(height: 16),
            dev(c.s('sync.name'), [if (Sync.myIp.isNotEmpty) Sync.myIp, s.model.isEmpty ? 'Google TV' : s.model].join('، '), true),
            for (final d in peers) dev(d.name, '${d.ip}${d.version.isNotEmpty ? '، الإصدار ${Ar.n(d.version)}' : ''}', false),
            if (peers.isEmpty)
              Row(children: [
                if (Sync.scanning) ...[const RawnaqLoader(size: 56), const SizedBox(width: 16)],
                Expanded(child: FitText(Sync.scanning ? 'جاري البحث بالشبكة…' : 'ما لگينا شاشة ثانية بعد', style: Fonts.body(19, p.muted))),
              ]),
            const SizedBox(height: 8),
            FitText('المزامنة تمر بشبكة البيت بس، وما تطلع برا', style: Fonts.body(16, p.muted)),
          ]),
        ),
        right: [
          if (Sync.weakPin)
            SysRow(icon: Lu.key, title: 'غيّر رمز الأهل أولاً', sub: 'المزامنة ما تشتغل والرمز سهل التخمين', danger: true, onTap: () => Navigator.push(context, fade(const SecurityScreen()))),
          SysRow(icon: Lu.refresh, title: 'مزامنة بالشبكة', sub: 'تخلّي الشاشات الثانية تلگى هذي الشاشة', toggle: c.b('sync.on'), autofocus: true, onTap: () async {
            s.set('sync.on', !c.b('sync.on'));
            await Sync.apply();
          }),
          SysRow(icon: Lu.pencil, title: 'اسم هذي الشاشة', value: c.s('sync.name'), onTap: () async {
            final v = await promptText(context, title: 'اسم الشاشة', initial: c.s('sync.name'));
            if (v != null && v.trim().isNotEmpty) s.set('sync.name', v.trim());
          }),
          SysRow(icon: Lu.search, title: Sync.scanning ? 'جاري البحث…' : 'البحث عن شاشات رونق', sub: 'بنفس شبكة البيت', onTap: () async {
            if (!c.b('sync.on')) {
              s.set('sync.on', true);
              await Sync.apply();
            }
            final l = await Sync.discover();
            if (mounted) toast(context, l.isEmpty ? 'ما لگينا شاشة، شغّل المزامنة بالشاشة الثانية هم' : 'لگينا ${Ar.n(l.length)}');
          }),
          for (final d in peers) SysRow(icon: Lu.devices, title: d.name, sub: 'نسخ أو جلب الإعدادات', value: d.ip, onTap: () => _peer(d)),
          const SysSection('شنو ينتقل'),
          SysRow(icon: Lu.palette, title: 'الثيم والترتيب والخطوط', toggle: c.b('sync.theme'), onTap: () => s.set('sync.theme', !c.b('sync.theme'))),
          SysRow(icon: Lu.grid, title: 'المفضلة وترتيب التطبيقات', toggle: c.b('sync.favorites'), onTap: () => s.set('sync.favorites', !c.b('sync.favorites'))),
          SysRow(icon: Lu.users, title: 'ملفات العائلة والأطفال', toggle: c.b('sync.profiles'), onTap: () => s.set('sync.profiles', !c.b('sync.profiles'))),
          SysRow(icon: Lu.key, title: 'رمز الأهل', sub: 'يبقى منفصل لكل شاشة، ولازم يتطابق حتى تنسخ', onTap: () {}),
        ],
      );
    });
  }
}

// ═══════════════════ سجل النشاط ═══════════════════

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ActivityLog.rev,
      builder: (_, __, ___) => live(() {
        final s = AppState.I;
        final p = s.palette;
        final all = ActivityLog.all;
        final now = DateTime.now();
        String day(DateTime t) {
          final d = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
          return d == 0 ? 'اليوم' : (d == 1 ? 'أمس' : '${Ar.dayName(t)} ${Ar.n(t.day)} ${Ar.months[t.month - 1]}');
        }

        final rows = <Widget>[];
        String? last;
        for (final (i, e) in all.take(60).indexed) {
          final d = day(e.t);
          if (d != last) {
            rows.add(SysSection(d));
            last = d;
          }
          rows.add(SysRow(icon: e.icon, title: e.title, sub: e.sub.isEmpty ? null : e.sub, value: '${Ar.time(e.t)} ${e.t.hour < 12 ? 'ص' : 'م'}', autofocus: i == 0, onTap: () {}));
        }
        if (all.isEmpty) rows.add(SysRow(icon: Lu.info, title: 'السجل فارغ', sub: 'يتسجل هنا كل اللي يصير برونق', autofocus: true, onTap: () {}));
        if (all.isNotEmpty) {
          rows.add(const SizedBox(height: 10));
          rows.add(SysRow(icon: Lu.trash, title: 'مسح السجل', danger: true, onTap: () async {
            if (await showPinPad(context, title: 'مسح سجل النشاط')) ActivityLog.clear();
          }));
        }
        final kinds = [('profile', 'تبديل الملفات', Lu.users), ('guard', 'تدخلات الحارس', Lu.shieldCheck), ('power', 'الإطفاء', Lu.power), ('update', 'التحديثات', Lu.cloudDownload), ('backup', 'النسخ الاحتياطية', Lu.download), ('kids', 'وقت الأطفال', Lu.baby)];
        return SysScaffold(
          title: 'سجل النشاط',
          sub: 'كل اللي صار برونق، بخط زمني',
          icon: Lu.scrollText,
          left: SysCard(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FitText('هذا الأسبوع', style: Fonts.title(30, p.ink)),
              const SizedBox(height: 16),
              for (final k in kinds) StatusLine(k.$2, Ar.n(ActivityLog.countWeek(k.$1)), icon: k.$3, kind: 'none'),
              const SizedBox(height: 6),
              FitText('السجل ينحفظ ٣٠ يوم وينمسح وحده', style: Fonts.body(16, p.muted)),
            ]),
          ),
          right: rows,
        );
      }),
    );
  }
}

// ═══════════════════ سجل الإصدارات ═══════════════════

const kReleases = <(String, String, List<String>)>[
  ('3.8.0', 'تشرين الثاني ٢٠٢٦', [
    'الاسم الجديد: رونق، وتنتقل إعداداتك وترتيبك وحدها',
    'شعار رونق الجديد بشاشة الإقلاع والأيقونة والبانر',
    'الشعار ينكتب بخط اليد وقت التحميل: ر و ن ق ثم النقاط، والحلقة تمشي مع القلم',
    'قسم «حركة الشعار» بالإعدادات: السرعة، رأس القلم، الحلقة، وانتظار الكتابة بالإقلاع',
    'مواقيت الصلاة لكل محافظات العراق توقيت فقط بدون أي تنبيه، ومفتاح توقيع خاص وتحقق من التحديثات',
    'الآيات بخط نظيف بدون أقواس',
    'شاشة الطقس الحية بمشاهد سينمائية وقطرات على الزجاج',
    'مدني، وإضافة مدينة، وتحديد الموقع من شبكة البيت',
    'رمز الأهل بلوحة أرقام وقفل مؤقت',
    'واجهة الأطفال وتقريرهم الأسبوعي ومعالج الإعداد',
    'وضع المناسبات ورمضان، والأجهزة والمزامنة، وسجل النشاط',
  ]),
  ('3.7.0', 'تشرين الثاني ٢٠٢٦', [
    'زر إعدادات الجهاز الذهبي',
    'ثيمات أهل البيت (ع) الخمسة',
    'حارس الواجهة ومركز التنبيهات',
    'التحديث التلقائي من GitHub',
  ]),
  ('3.6.0', 'تشرين الأول ٢٠٢٦', ['الوضع الآمن', 'النسخ الاحتياطي التلقائي', 'تنبيه الأذان']),
  ('3.5.0', 'تشرين الأول ٢٠٢٦', ['الزجاج السائل', 'معرض الترتيبات', 'شاشة السكون بالنجوم']),
];

class VersionHistoryScreen extends StatelessWidget {
  const VersionHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final p = s.palette;
      final c = s.cfg;
      final cur = s.version.isNotEmpty ? s.version : kReleases.first.$1;
      final avail = Updater.available.value;
      return SysScaffold(
        title: 'سجل الإصدارات',
        sub: 'كل تحديث وصل لرونق، وشنو جاب',
        icon: Lu.scrollText,
        left: SysCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Medallion(icon: Lu.badgeCheck, size: 190, color: p.ring),
            const SizedBox(height: 8),
            FitText('الإصدار ${Ar.n(cur)}', alignment: Alignment.center, style: Fonts.title(56, p.ink)),
            const SizedBox(height: 8),
            StatusChip(avail != null ? 'متوفر ${Ar.n(avail.version)}' : 'عندك آخر إصدار', icon: avail != null ? Lu.sparkles : Lu.circleCheck, kind: avail != null ? 'warn' : 'ok'),
            const SizedBox(height: 20),
            StatusLine('المصدر', c.s('update.url').isEmpty ? 'من الحاسبة' : 'تحديث تلقائي، GitHub', kind: 'none', icon: Lu.package),
            StatusLine('آخر فحص', c.i('update.last') == 0 ? 'ما صار' : Recents.ago(DateTime.fromMillisecondsSinceEpoch(c.i('update.last'))), kind: 'none', icon: Lu.clock),
            StatusLine('التحقق من التوقيع', 'نفس مفتاح جهازك', icon: Lu.shieldCheck),
          ]),
        ),
        right: [
          for (final (i, r) in kReleases.indexed)
            FocusTap(
              autofocus: i == 0,
              onTap: () {},
              builder: (_, f) => AnimatedContainer(
                duration: s.anim(150),
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: f ? p.ring : (r.$1 == cur ? p.ring.withValues(alpha: 0.6) : p.line), width: f ? ringW : 1.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text('الإصدار ${Ar.n(r.$1)}', style: Fonts.title(30, p.ink)),
                    const Spacer(),
                    StatusChip(r.$1 == cur ? 'الحالي' : r.$2, kind: r.$1 == cur ? 'ok' : 'none'),
                  ]),
                  const SizedBox(height: 10),
                  for (final n in r.$3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: p.ring, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: FitText(n, style: Fonts.body(19, p.ink))),
                      ]),
                    ),
                ]),
              ),
            ),
        ],
      );
    });
  }
}
