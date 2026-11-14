import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tile.dart';
import '../arabic.dart';
import '../brand.dart';
import '../lucide.dart';
import '../palette.dart';
import '../platform.dart';
import '../state.dart';
import '../streamer_services.dart';
import '../family_services.dart';
import '../system_services.dart';
import '../widgets.dart';
import 'quick_panel.dart';
import 'screensaver.dart';
import 'settings.dart';
import 'system_screens.dart';
import 'weather_screens.dart' show WeatherPill;
import 'family_screens.dart' show EmptyState, KidsAppsGrid, KidsReportScreen, KidsSetupWizard, RamadanPill, GuestPill;

// ═══════════════════ أدوات مشتركة (فيكما صفحة 11) ═══════════════════

Color _warn(Palette p) => p.night ? const Color(0xFFE5A13A) : const Color(0xFFB7791F);
Color _bad(Palette p) => p.night ? const Color(0xFFE06A6A) : const Color(0xFFB3261E);
Color _s2(Palette p) => p.night ? Color.lerp(p.bg, p.surface, 0.5)! : Color.lerp(p.bg, Colors.black, 0.02)!;

/// الذهبي المميز لكل ما يخص إعدادات الجهاز (حتى ما يختلط بإعدادات رونق الخضراء).
Color deviceTint(Palette p) => p.ring;

class SysSection extends StatelessWidget {
  final String text;
  const SysSection(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(6, 18, 6, 12), child: FitText(text, style: Fonts.body(24, pal.ink, weight: FontWeight.w600)));
}

/// سطر حالة داخل البطاقة: العنوان يمين والحالة يسار.
class StatusLine extends StatelessWidget {
  final String title, value;
  final String kind;
  final Object? icon;
  const StatusLine(this.title, this.value, {super.key, this.kind = 'ok', this.icon});
  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: ShapeDecoration(
        color: _s2(p),
        shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(44), side: BorderSide(color: p.line)),
      ),
      child: Row(children: [
        Expanded(child: FitText(title, style: Fonts.body(20, p.ink, weight: FontWeight.w600))),
        const SizedBox(width: 12),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: StatusChip(value, kind: kind, icon: icon ?? (kind == 'ok' ? Lu.circleCheck : null))),
      ]),
    );
  }
}

/// كل الشاشات تتحدث لحظياً مع أي تغيير بالإعدادات.
Widget live(Widget Function() build) => ListenableBuilder(listenable: AppState.I, builder: (_, __) => build());

String _hm(int mins) {
  final t = DateTime(2000, 1, 1, mins ~/ 60, mins % 60);
  return '${Ar.time(t)} ${Ar.period(t)}';
}

void _set(String k, Object v) => AppState.I.set(k, v);
void _flip(String k) => AppState.I.set(k, !AppState.I.cfg.b(k));

/// يفتح إعدادات رونق (بملف الأطفال أو الضيف يطلب الرمز).
Future<void> openThemeSettings(BuildContext context) async {
  if (Profiles.restricted && !await askPin(context, title: 'إعدادات رونق تحتاج الرمز')) return;
  if (context.mounted) Navigator.push(context, fade(const SettingsScreen()));
}

/// إعدادات الجهاز (نظام Google TV) — منفصلة تماماً عن إعدادات رونق.
Future<void> openDeviceSettings(BuildContext context) async {
  if (Profiles.restricted && !await askPin(context, title: 'إعدادات الجهاز تحتاج الرمز')) return;
  await NativeBridge.systemSettings();
}

/// إجراء زر النجمة بالريموت ورونق قدامك.
void handleStar(NavigatorState nav) {
  final ctx = nav.context;
  switch (AppState.I.cfg.s('star.action')) {
    case 'saver':
      nav.push(MaterialPageRoute(builder: (_) => const ScreensaverScreen()));
    case 'search':
      nav.push(fade(const SearchScreen()));
    case 'notifs':
      nav.push(fade(const NotificationsScreen()));
    case 'home':
      nav.popUntil((r) => r.isFirst);
    default:
      showQuickPanel(ctx);
  }
}

// ═══════════════════ أزرار الواجهة: بحث، تنبيهات، ملف، إعدادات الجهاز ═══════════════════

class _Round extends StatelessWidget {
  final Object icon;
  final bool onDark, focused;
  final Color? tint;
  final double size;
  const _Round({required this.icon, required this.onDark, required this.focused, this.tint, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final fg = onDark ? (focused ? Colors.black : Colors.white) : (tint ?? p.ink);
    final bg = onDark ? (focused ? Colors.white : Colors.white.withValues(alpha: 0.16)) : (tint != null ? tint!.withValues(alpha: 0.16) : p.surface);
    return AnimatedScale(
      scale: focused ? 1.1 : 1,
      duration: s.anim(150),
      child: AnimatedContainer(
        duration: s.anim(150),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: onDark ? Colors.white.withValues(alpha: 0.35) : (focused ? p.ring : p.line), width: !onDark && focused ? 4 : 1),
        ),
        child: AppIcon(icon, color: fg, size: size * 0.47),
      ),
    );
  }
}

/// زر «إعدادات الجهاز»: كبسولة ذهبية بأيقونة monitor-cog — مميزة عن ترس إعدادات رونق.
class DeviceSettingsPill extends StatelessWidget {
  final bool onDark, compact;
  const DeviceSettingsPill({super.key, required this.onDark, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final gold = onDark ? const Color(0xFFE6C77A) : deviceTint(p);
    return FocusTap(
      ensureVisible: false,
      onTap: () => openDeviceSettings(context),
      builder: (context, f) {
        if (f) announceOption('إعدادات الجهاز', 'نظام Google TV: الشبكة، الحسابات، التطبيقات');
        return AnimatedScale(
          scale: f ? 1.08 : 1,
          duration: s.anim(150),
          child: AnimatedContainer(
            duration: s.anim(150),
            height: 64,
            padding: EdgeInsetsDirectional.fromSTEB(8, 8, compact ? 8 : 24, 8),
            decoration: BoxDecoration(
              color: f ? gold : gold.withValues(alpha: onDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: gold, width: f ? 4 : 1.5),
              boxShadow: f ? [BoxShadow(color: gold.withValues(alpha: 0.45), blurRadius: 28)] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: f ? Colors.white.withValues(alpha: 0.25) : gold.withValues(alpha: 0.9), shape: BoxShape.circle),
                child: AppIcon(Lu.deviceSettings, color: onDark || f ? const Color(0xFF1B1206) : p.onAccent, size: 26),
              ),
              if (!compact) ...[
                const SizedBox(width: 12),
                Text('إعدادات الجهاز', style: Fonts.body(21, f ? const Color(0xFF1B1206) : (onDark ? Colors.white : p.ink), weight: FontWeight.w600)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// مجموعة أزرار الواجهة بجنب زر اللوحة السريعة.
class HomeActions extends StatelessWidget {
  final bool onDark, compact;
  const HomeActions({super.key, required this.onDark, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = AppState.I.cfg;
    final p = AppState.I.palette;
    final items = <Widget>[];
    void add(Widget w) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 14));
      items.add(w);
    }

    if (!compact && c.b('weather.homeChip') && AppState.I.weather != null) add(WeatherPill(onDark: onDark));
    if (!compact && Profiles.guest) add(GuestPill(onDark: onDark));
    if (!compact && Ramadan.active && c.b('ramadan.banner') && Ramadan.next != null) add(RamadanPill(onDark: onDark));
    if (!compact && c.b('home.showSearch')) {
      add(FocusTap(ensureVisible: false, onTap: () => Navigator.push(context, fade(const SearchScreen())), builder: (_, f) {
        if (f) announceOption('البحث', 'التطبيقات والبحث الصوتي');
        return _Round(icon: Lu.search, onDark: onDark, focused: f);
      }));
    }
    if (c.b('home.showBell')) {
      add(FocusTap(
        ensureVisible: false,
        onTap: () => Navigator.push(context, fade(const NotificationsScreen())),
        builder: (_, f) => ValueListenableBuilder<int>(
          valueListenable: Notices.unread,
          builder: (_, n, __) {
            if (f) announceOption('مركز التنبيهات', n > 0 ? '${Ar.n(n)} جديد' : 'لا جديد');
            return Stack(clipBehavior: Clip.none, children: [
              _Round(icon: n > 0 ? Lu.bellDot : Lu.bell, onDark: onDark, focused: f),
              if (n > 0 && c.b('notif.badge'))
                PositionedDirectional(
                  top: -6,
                  start: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 30),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _bad(p), borderRadius: BorderRadius.circular(15)),
                    child: Text(Ar.n(n > 9 ? '9+' : n), style: Fonts.body(15, Colors.white, weight: FontWeight.w700)),
                  ),
                ),
            ]);
          },
        ),
      ));
    }
    if (!compact && c.b('home.showProfile')) {
      add(FocusTap(ensureVisible: false, onTap: () => Navigator.push(context, fade(const ProfilePicker())), builder: (_, f) {
        if (f) announceOption('الملف: ${Profiles.name(Profiles.active)}', 'تبديل الملف');
        return _Round(icon: Profiles.kids ? Lu.baby : (Profiles.guest ? Lu.userRound : Lu.users), onDark: onDark, focused: f, tint: onDark ? null : p.accent);
      }));
    }
    if (c.b('home.showDevice')) add(DeviceSettingsPill(onDark: onDark, compact: compact));
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}

/// شريط «إعدادات الجهاز» الذهبي باللوحة السريعة.
class QuickDeviceBar extends StatelessWidget {
  final bool focused;
  const QuickDeviceBar({super.key, required this.focused});
  @override
  Widget build(BuildContext context) {
    final p = pal;
    final gold = deviceTint(p);
    return AnimatedContainer(
      duration: AppState.I.anim(150),
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: focused ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: gold, width: focused ? ringW : 1.5),
        boxShadow: focused ? [BoxShadow(color: gold.withValues(alpha: 0.4), blurRadius: 28)] : null,
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
          child: AppIcon(Lu.deviceSettings, color: p.night ? const Color(0xFF1B1206) : Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            FitText('إعدادات الجهاز', style: Fonts.body(23, p.ink, weight: FontWeight.w600)),
            FitText('نظام Google TV: الشبكة، الحسابات، التطبيقات', style: Fonts.body(16, p.muted)),
          ]),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('النظام', style: Fonts.body(15, gold, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            AppIcon(Lu.chevronLeft, color: gold, size: 16),
          ]),
        ),
      ]),
    );
  }
}

/// المحتوى اليومي بأعلى الواجهة: يطلع أول مرة باليوم ٢٠ ثانية ويختفي، وما يسرق التركيز.
class DailyBanner extends StatefulWidget {
  const DailyBanner({super.key});
  @override
  State<DailyBanner> createState() => _DailyBannerState();
}

class _DailyBannerState extends State<DailyBanner> {
  bool _show = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final c = AppState.I.cfg;
    final n = DateTime.now();
    final key = '${n.year}-${n.month}-${n.day}';
    if (Daily.onHome && c.s('daily.shown') != key) {
      c.set('daily.shown', key);
      _t = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _show = true);
        _t = Timer(const Duration(seconds: 20), () {
          if (mounted) setState(() => _show = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    final d = Daily.today();
    final big = AppState.I.cfg.s('daily.size') == 'large';
    return IgnorePointer(
      child: AnimatedOpacity(
          opacity: _show ? 1 : 0,
          duration: AppState.I.anim(600),
          child: AnimatedSlide(
            offset: _show ? Offset.zero : const Offset(0, -0.4),
            duration: AppState.I.anim(600),
            curve: Curves.easeOutCubic,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1100),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
              decoration: ShapeDecoration(
                color: p.surface.withValues(alpha: 0.94),
                shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(70), side: BorderSide(color: p.ring.withValues(alpha: 0.6), width: 1.5)),
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.45 : 0.14), blurRadius: 40, offset: const Offset(0, 14))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AppIcon(Lu.moonStar, color: p.ring, size: 34),
                const SizedBox(width: 22),
                Flexible(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    FitText(d.$1, alignment: Alignment.center, style: Fonts.title(big ? 40 : 32, p.ink)),
                    const SizedBox(height: 4),
                    FitText(d.$2, alignment: Alignment.center, style: Fonts.body(18, p.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
    );
  }
}

/// المحتوى اليومي بشاشة السكون: هادئ بأسفل الوسط.
class DailySaverLine extends StatelessWidget {
  const DailySaverLine({super.key});
  @override
  Widget build(BuildContext context) {
    final d = Daily.today();
    const sh = [Shadow(color: Color(0xAA000000), blurRadius: 20, offset: Offset(0, 2))];
    final big = AppState.I.cfg.s('daily.size') == 'large';
    return Positioned(
      left: 420,
      right: 420,
      bottom: 64,
      child: IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FitText(d.$1, alignment: Alignment.center, style: Fonts.title(big ? 40 : 32, Colors.white).copyWith(shadows: sh)),
          const SizedBox(height: 6),
          FitText(d.$2, alignment: Alignment.center, style: Fonts.body(18, Colors.white70).copyWith(shadows: sh)),
        ]),
      ),
    );
  }
}

// ═══════════════════ ١. حارس الواجهة ═══════════════════

class GuardScreen extends StatefulWidget {
  const GuardScreen({super.key});
  @override
  State<GuardScreen> createState() => _GuardScreenState();
}

class _GuardScreenState extends State<GuardScreen> {
  Map<String, dynamic> _st = const {};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final st = await Streamer.guardStatus();
    if (mounted) setState(() => _st = st);
  }

  bool get _isHome => '${_st['defaultHome']}' == 'com.rawnaq';
  bool get _service => _st['serviceOn'] == true;

  Future<void> _fix() async {
    _set('guard.on', true);
    final ok = await Streamer.guardSet(true);
    await _load();
    if (!mounted) return;
    toast(context, ok ? 'الحارس شغّال' : 'الصلاحية تحتاج تشغيل install.bat مرة وحدة، أو فعّلها من إمكانية الوصول');
  }

  @override
  Widget build(BuildContext context) {
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      final g = '${_st['google'] ?? ''}';
      final protected = _st.isNotEmpty && (_isHome || _service) && c.b('guard.on');
      final last = (_st['last'] as int?) ?? 0;
      final count = (_st['count'] as int?) ?? 0;
      return SysScaffold(
        title: 'حارس الواجهة',
        sub: 'إذا تحديث النظام رجّع واجهة كوكل، الحارس يرجّع رونق فوراً',
        icon: Lu.shieldCheck,
        left: SysCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 168,
                height: 168,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: (protected ? p.accent : _warn(p)).withValues(alpha: 0.12), shape: BoxShape.circle),
                child: AppIcon(protected ? Lu.shieldCheck : Lu.info, color: protected ? p.accent : _warn(p), size: 90),
              ),
            ),
            const SizedBox(height: 16),
            FitText(_st.isEmpty ? '…' : (protected ? 'محمي' : 'يحتاج انتباه'), alignment: Alignment.center, style: Fonts.title(44, p.ink)),
            FitText('رونق هو الواجهة الوحيدة على الستريمر', alignment: Alignment.center, style: Fonts.body(19, p.muted)),
            const SizedBox(height: 24),
            StatusLine('رونق واجهة افتراضية', _isHome ? 'نعم' : 'لا', kind: _isHome ? 'ok' : 'warn'),
            StatusLine('واجهة كوكل الأصلية', switch (g) { 'disabled' => 'موقوفة', 'enabled' => 'مخفية مع الحارس', 'missing' => 'غير موجودة', _ => '…' },
                kind: g == 'enabled' ? 'none' : 'ok', icon: g == 'enabled' ? Lu.eyeOff : null),
            StatusLine('خدمة الحارس', _service ? 'شغّالة' : 'غير مفعّلة', kind: _service ? 'ok' : 'warn'),
            const SizedBox(height: 8),
            FitText(
              count == 0 ? 'ما احتاج الحارس يتدخل لحد الآن' : 'تدخّل ${Ar.n(count)} مرة، آخرها ${Recents.ago(DateTime.fromMillisecondsSinceEpoch(last))}',
              style: Fonts.body(18, p.muted),
            ),
          ]),
        ),
        right: [
          SysRow(icon: Lu.shieldCheck, title: 'حارس زر الهوم', sub: 'إذا طلعت واجهة كوكل يرجّع رونق خلال ثانية', toggle: c.b('guard.on'), autofocus: true, onTap: () async {
            _flip('guard.on');
            await Streamer.guardSet(c.b('guard.on'));
            _load();
          }),
          SysRow(icon: Lu.wand, title: 'إصلاح الآن', sub: 'يفعّل الحارس ويتأكد من الصلاحية', onTap: _fix),
          SysRow(icon: Lu.key, title: 'صلاحية الحارس', sub: 'إعدادات إمكانية الوصول ← حارس رونق', value: _service ? 'مفعّلة' : 'فعّلها', onTap: Streamer.accessibilitySettings),
          SysRow(
            icon: Lu.tv,
            title: 'فتح واجهة كوكل مؤقتاً',
            sub: 'لإعدادات كوكل الخاصة لمدة ٥ دقائق، وترجع بزر الهوم',
            onTap: () async {
              final ok = await Streamer.guardPause(5);
              if (!ok && context.mounted) toast(context, 'واجهة كوكل موقوفة كلياً — شغّلها من rescue.bat إذا تحتاجها');
            },
          ),
          const SizedBox(height: 10),
          FitText('الحارس يشتغل بصلاحية «إمكانية الوصول» يعطيها المنصّب مرة وحدة.', style: Fonts.body(18, p.muted)),
          FitText('ما يقرأ محتوى الشاشة، بس يعرف إذا واجهة كوكل ظاهرة.', style: Fonts.body(18, p.muted)),
        ],
      );
    });
  }
}

// ═══════════════════ ٢. البحث ═══════════════════

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  late final _field = tvFieldNode(_q);

  @override
  void dispose() {
    _q.dispose();
    _field.dispose();
    super.dispose();
  }

  List<String> _results(String q) {
    final s = AppState.I;
    final pool = Profiles.kids ? Profiles.kidsApps : [for (final a in s.installed) a.package];
    if (q.trim().isEmpty) return [for (final r in Recents.entries()) if (pool.contains(r.$1)) r.$1].take(6).toList();
    final n = q.trim().toLowerCase();
    final hits = pool.where((p) => s.labelOf(p).toLowerCase().contains(n) || p.toLowerCase().contains(n)).toList();
    final rec = {for (final (i, r) in Recents.entries().indexed) r.$1: i};
    hits.sort((a, b) => (rec[a] ?? 99).compareTo(rec[b] ?? 99));
    return hits.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: live(() {
        final p = AppState.I.palette;
        final q = _q.text;
        final res = _results(q);
        final m = TileMetrics(300, labels: 'all', style: 'banner');
        return Padding(
          padding: const EdgeInsets.fromLTRB(96, 60, 96, 32),
          child: NavZone(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: AppIcon(Lu.search, color: p.accent, size: 34),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FitText('البحث', style: Fonts.title(44, p.ink)),
                    FitText('التطبيقات المنصّبة، والبحث الصوتي بكوكل', style: Fonts.body(21, p.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 30),
              // حقل البحث + زر المايك
              Container(
                height: 96,
                padding: const EdgeInsets.fromLTRB(36, 12, 12, 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(48),
                  border: Border.all(color: _field.hasFocus ? p.ring : p.line, width: _field.hasFocus ? ringW : 1.5),
                ),
                child: Row(children: [
                  AppIcon(Lu.search, color: p.muted, size: 36),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (n, e) {
                        if (e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.arrowDown)) {
                          FocusScope.of(context).focusInDirection(TraversalDirection.down);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _q,
                        focusNode: _field,
                        autofocus: true,
                        cursorColor: p.accent,
                        style: Fonts.body(34, p.ink, weight: FontWeight.w600),
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (v) {
                          final r = _results(v);
                          if (r.isNotEmpty) NativeBridge.launch(r.first);
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'اكتب اسم تطبيق أو فيلم…',
                          hintStyle: Fonts.body(30, p.muted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FocusTap(
                    onTap: Streamer.voiceSearch,
                    builder: (_, f) => AnimatedContainer(
                      duration: AppState.I.anim(150),
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(36), border: Border.all(color: f ? p.ring : p.accent, width: f ? ringW : 1)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        AppIcon(Lu.mic, color: p.onAccent, size: 30),
                        const SizedBox(width: 12),
                        Text('بحث صوتي', style: Fonts.body(21, p.onAccent, weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              FitText(q.trim().isEmpty ? 'آخر ما فتحته' : (res.isEmpty ? 'ما لكينا تطبيق بهذا الاسم' : 'التطبيقات'), style: Fonts.body(24, p.ink, weight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                height: m.totalHeight + m.bleed * 2,
                child: q.trim().isNotEmpty && res.isEmpty
                    ? const EmptyState(icon: Lu.searchX, title: 'ما لكينا تطبيق بهذا الاسم', sub: 'جرّب اسم ثاني، أو ابحث بكوكل وبالصوت من تحت', row: true)
                    : AxisClip(axis: Axis.horizontal, child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    for (final pkg in res)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 32),
                        child: FocusTap(
                          onTap: () => NativeBridge.launch(pkg),
                          builder: (_, f) => AppTile(package: pkg, m: m, focused: f),
                        ),
                      ),
                  ],
                )),
              ),
              const Spacer(),
              if (q.trim().isNotEmpty)
                SysRow(icon: Lu.globe, title: 'ابحث بكوكل عن «${q.trim()}»', sub: 'أفلام ومسلسلات وفيديوهات من كل التطبيقات', onTap: () async {
                  final ok = await Streamer.webSearch(q.trim());
                  if (!ok && context.mounted) toast(context, 'بحث كوكل غير متاح على هذا الجهاز');
                }),
              SysRow(icon: Lu.mic, title: 'بحث بالصوت', sub: 'أو اضغط زر المايك بالريموت من أي مكان', onTap: Streamer.voiceSearch),
              const SizedBox(height: 4),
              const KeyGuide(),
            ]),
          ),
        );
      }),
    );
  }
}

// ═══════════════════ ٣. مركز التنبيهات ═══════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'all';
  bool _access = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Notices.refresh();
    final a = await Streamer.notifAccess();
    if (mounted) setState(() => _access = a);
    Notices.markSeen();
  }

  @override
  Widget build(BuildContext context) {
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      final all = Notices.all;
      final own = all.where((n) => n.package == null).length;
      final list = all.where((n) => _filter == 'all' || (_filter == 'own') == (n.package == null)).toList();
      final today = DateTime.now();
      bool isToday(DateTime t) => t.year == today.year && t.month == today.month && t.day == today.day;
      Widget item(Notice n, bool first) {
        final col = n.package != null ? p.accent : (n.icon == 'moon' ? p.ring : p.accent);
        return FocusTap(
          autofocus: first,
          onTap: () {
            if (n.package != null) NativeBridge.launch(n.package!);
          },
          builder: (_, f) {
            if (f) announceOption(n.title, n.sub);
            return AnimatedContainer(
              duration: AppState.I.anim(150),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: ShapeDecoration(
                color: p.surface,
                shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(56), side: BorderSide(color: f ? p.ring : p.line, width: f ? ringW : 1)),
              ),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: col.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
                  child: AppIcon(n.package != null ? Lu.bell : n.icon, color: col, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FitText(n.title, style: Fonts.body(21, p.ink, weight: FontWeight.w600)),
                    if (n.sub.isNotEmpty) FitText(n.sub, style: Fonts.body(17, p.muted)),
                  ]),
                ),
                const SizedBox(width: 16),
                Text(isToday(n.time) ? '${Ar.time(n.time)} ${Ar.period(n.time)}' : Recents.ago(n.time), style: Fonts.body(16, p.muted)),
              ]),
            );
          },
        );
      }

      return SysScaffold(
        title: 'مركز التنبيهات',
        sub: 'تنبيهات رونق والتطبيقات بمكان واحد',
        icon: Lu.bellRing,
        left: SysCard(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
          child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
            clipBehavior: Clip.none,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            FitText('تصفية', style: Fonts.body(22, p.ink, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            SysRow(
              icon: Lu.listChecks,
              title: 'عرض',
              sub: 'موافق للتبديل',
              value: switch (_filter) { 'own' => 'رونق (${Ar.n(own)})', 'apps' => 'التطبيقات (${Ar.n(all.length - own)})', _ => 'الكل (${Ar.n(all.length)})' },
              onTap: () => setState(() => _filter = switch (_filter) { 'all' => 'own', 'own' => 'apps', _ => 'all' }),
            ),
            const SizedBox(height: 14),
            if (!_access)
              SysRow(icon: Lu.key, title: 'تفعيل قراءة التنبيهات', sub: 'حتى تطلع تنبيهات التطبيقات هنا', onTap: () async {
                final ok = await Streamer.notifEnable();
                if (!ok) await Streamer.notifSettings();
                _load();
              }),
            SysRow(icon: Lu.bellRing, title: 'تنبيهات التطبيقات', sub: 'العنوان والنص فقط، ما تطلع برّا الجهاز', toggle: c.b('notif.apps'), onTap: () => _flip('notif.apps')),
            SysRow(icon: Lu.bell, title: 'رقم على الواجهة', sub: 'فوق زر الجرس', toggle: c.b('notif.badge'), onTap: () => _flip('notif.badge')),
            SysRow(icon: Lu.bellOff, title: 'كتم بساعات الهدوء', toggle: c.b('notif.quietMute'), onTap: () => _flip('notif.quietMute')),
            SysRow(icon: Lu.info, title: 'التنبيه المنبثق', sub: 'يطلع أعلى الشاشة ويختفي', toggle: c.b('notif.popup'), onTap: () => _flip('notif.popup')),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionRow([Act('مسح الكل', () async {
                await Notices.clear();
                if (mounted) setState(() {});
              }, icon: Lu.trash)]),
            ),
          ]),
          )),
        ),
        right: list.isEmpty
            ? [
                SysCard(
                  child: Column(children: [
                    AppIcon(Lu.bellOff, color: p.muted, size: 64),
                    const SizedBox(height: 16),
                    FitText('ماكو تنبيهات', alignment: Alignment.center, style: Fonts.title(32, p.ink)),
                    FitText('النسخ الاحتياطي والتحديثات والتطبيقات تطلع هنا', alignment: Alignment.center, style: Fonts.body(18, p.muted)),
                  ]),
                ),
              ]
            : [
                if (list.any((n) => isToday(n.time))) const SysSection('اليوم'),
                for (final (i, n) in list.where((n) => isToday(n.time)).indexed) item(n, i == 0),
                if (list.any((n) => !isToday(n.time))) const SysSection('قبل'),
                for (final (i, n) in list.where((n) => !isToday(n.time)).indexed) item(n, i == 0 && !list.any((n) => isToday(n.time))),
              ],
      );
    });
  }
}

// ═══════════════════ ٤. التحديث التلقائي ═══════════════════

class AutoUpdateScreen extends StatefulWidget {
  const AutoUpdateScreen({super.key});
  @override
  State<AutoUpdateScreen> createState() => _AutoUpdateScreenState();
}

class _AutoUpdateScreenState extends State<AutoUpdateScreen> {
  String _source = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    Streamer.installSource().then((v) {
      if (mounted) setState(() => _source = v);
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final u = await Updater.check();
    if (!mounted) return;
    setState(() => _checking = false);
    toast(context, u != null ? 'متوفر الإصدار ${Ar.n(u.version)}' : (Updater.lastError.isNotEmpty ? Updater.lastError : 'عندك آخر إصدار'));
  }

  @override
  Widget build(BuildContext context) {
    final fromPlay = _source == 'com.android.vending';
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      final s = AppState.I;
      final current = s.version.isNotEmpty ? s.version : kAppVersionFallback;
      return ValueListenableBuilder<UpdateInfo?>(
        valueListenable: Updater.available,
        builder: (_, u, __) => ValueListenableBuilder<double?>(
          valueListenable: Updater.progress,
          builder: (_, prog, __) => SysScaffold(
            title: 'التحديث التلقائي',
            sub: 'رونق يحدّث نفسه بدون حاسبة، ونسختك الاحتياطية تنحفظ قبل كل تحديث',
            icon: Lu.cloudDownload,
            left: SysCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(u != null ? 'متوفر تحديث' : 'عندك آخر إصدار', icon: u != null ? Lu.sparkles : Lu.circleCheck)),
                const SizedBox(height: 14),
                FitText('الإصدار ${Ar.n(u?.version ?? current)}', style: Fonts.title(52, p.ink)),
                FitText(u != null ? 'الحالي ${Ar.n(current)}' : 'آخر فحص: ${c.i('update.last') == 0 ? 'ما صار' : Recents.ago(DateTime.fromMillisecondsSinceEpoch(c.i('update.last')))}',
                    style: Fonts.body(19, p.muted)),
                const SizedBox(height: 20),
                if (u != null && u.notes.isNotEmpty) ...[
                  FitText('الجديد', style: Fonts.body(22, p.ink, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final n in u.notes.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: FitText(n, style: Fonts.body(19, p.ink))),
                      ]),
                    ),
                ],
                if (prog != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    RawnaqLoader(size: 84, progress: prog),
                    const SizedBox(width: 20),
                    Expanded(child: FitText('جاري التنزيل ${Ar.n((prog * 100).round())}٪', style: Fonts.body(20, p.ink, weight: FontWeight.w600))),
                  ]),
                ],
                if (u != null && prog == null) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ActionRow([
                      Act('تثبيت الآن', () async {
                        final ok = await Updater.downloadAndInstall(u);
                        if (context.mounted) toast(context, ok ? 'وافق على التثبيت بالشاشة اللي تطلع' : Updater.lastError);
                      }, icon: Lu.download, primary: true),
                    ]),
                  ),
                ],
                if (fromPlay) ...[
                  const SizedBox(height: 16),
                  FitText('رونق منصّب من Google Play، فالتحديث يوصل وحده من المتجر.', style: Fonts.body(18, p.muted)),
                ],
              ]),
            ),
            right: [
              SysRow(icon: Lu.package, title: 'مصدر التحديث', sub: fromPlay ? 'Google Play كتطبيق خاص بحسابك' : 'ملف تحديث على رابط (GitHub أو أي استضافة)', value: fromPlay ? 'Google Play' : 'رابط', autofocus: true, onTap: () {}),
              if (!fromPlay)
                SysRow(
                  icon: Lu.globe,
                  title: 'رابط ملف التحديث',
                  sub: 'ملف JSON بيه الإصدار ورابط الـ APK',
                  value: c.s('update.url').isEmpty ? 'غير محدد' : 'محدد',
                  onTap: () async {
                    final v = await promptText(context, title: 'رابط ملف التحديث', initial: c.s('update.url'));
                    if (v != null) _set('update.url', v.trim());
                  },
                ),
              SysRow(icon: Lu.refresh, title: 'فحص تلقائي', sub: 'مرة باليوم', toggle: c.b('update.auto'), onTap: () => _flip('update.auto')),
              SysRow(icon: Lu.moonStar, title: 'التنبيه بساعات الهدوء فقط', sub: 'ما يقاطع فيلم أو مباراة', toggle: c.b('update.quiet'), onTap: () => _flip('update.quiet')),
              SysRow(icon: Lu.download, title: 'نسخة احتياطية قبل التحديث', sub: 'ترجع لإعداداتك إذا صار أي شي', toggle: c.b('update.backup'), onTap: () => _flip('update.backup')),
              SysRow(icon: Lu.cloudDownload, title: _checking ? 'جاري الفحص…' : 'فحص الآن', onTap: _check),
              SysRow(icon: Lu.rotateCcw, title: 'النسخ الاحتياطية', sub: 'للرجوع لإعداداتك السابقة', onTap: () => Navigator.push(context, fade(const BackupScreen()))),
            ],
          ),
        ),
      );
    });
  }
}

const kAppVersionFallback = '3.8.0';

// ═══════════════════ ٥. ملفات العائلة ═══════════════════

class ProfilePicker extends StatelessWidget {
  const ProfilePicker({super.key});

  Future<void> _pick(BuildContext context, String id) async {
    if (id == Profiles.active) {
      Navigator.pop(context);
      return;
    }
    // الخروج من ملف الأطفال أو الضيف يحتاج الرمز
    if (Profiles.restricted && !await askPin(context, title: 'تبديل الملف يحتاج الرمز')) return;
    AppState.I.set('profile.active', id);
    if (id == 'guest') AppState.I.set('guest.since', DateTime.now().millisecondsSinceEpoch);
    ActivityLog.add(id == 'kids' ? 'baby' : (id == 'guest' ? 'user-round' : 'users'), 'تحوّل لملف ${Profiles.name(id)}', '', kind: 'profile');
    Profiles.lock.value = null;
    if (context.mounted) {
      Navigator.pop(context);
      toast(context, 'ملف ${Profiles.name(id)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      child: live(() {
        final p = AppState.I.palette;
        final c = AppState.I.cfg;
        final items = [
          ('family', 'العائلة', Lu.users, 'كل التطبيقات', [const Color(0xFF1F8A64), const Color(0xFF0A3A2A)]),
          ('kids', 'الأطفال', Lu.baby, c.i('kids.limit') > 0 ? '${_dur(c.i('kids.limit'))} باليوم، برمز' : 'بلا حد يومي', [const Color(0xFFE0973A), const Color(0xFF7A3A08)]),
          ('guest', 'الضيف', Lu.userRound, 'بدون إعدادات', [const Color(0xFF3F6AA8), const Color(0xFF14243F)]),
        ];
        return NavZone(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FitText('منو يشاهد؟', alignment: Alignment.center, style: Fonts.title(64, p.ink)),
            FitText('اختار ملفك، وكل ملف بتطبيقاته وحدوده', alignment: Alignment.center, style: Fonts.body(22, p.muted)),
            const SizedBox(height: 70),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final (i, it) in items.indexed) ...[
                if (i > 0) const SizedBox(width: 96),
                FocusTap(
                  autofocus: it.$1 == Profiles.active,
                  onTap: () => _pick(context, it.$1),
                  builder: (_, f) => Column(children: [
                    AnimatedScale(
                      scale: f ? 1.08 : 1,
                      duration: AppState.I.anim(180),
                      child: Container(
                        width: 240,
                        height: 240,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: it.$5, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          border: Border.all(color: f ? p.ring : Colors.transparent, width: 6),
                          boxShadow: f ? [BoxShadow(color: p.ring.withValues(alpha: 0.5), blurRadius: 44, spreadRadius: 4)] : null,
                        ),
                        child: AppIcon(it.$3, color: Colors.white, size: 104),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(it.$2, style: Fonts.title(32, f ? p.ink : p.muted)),
                    Text(it.$4, style: Fonts.body(19, p.muted)),
                    if (it.$1 == Profiles.active) ...[const SizedBox(height: 8), const StatusChip('الحالي', icon: Lu.circleCheck)],
                  ]),
                ),
              ],
            ]),
            const SizedBox(height: 60),
            ActionRow([
              Act('إعدادات ملف الأطفال', () async {
                if (Profiles.restricted && !await askPin(context)) return;
                if (context.mounted) Navigator.push(context, fade(const KidsScreen()));
              }, icon: Lu.settings),
            ]),
          ]),
        );
      }),
    );
  }
}

String _dur(int mins) {
  if (mins <= 0) return 'بلا حد';
  final h = mins ~/ 60, m = mins % 60;
  final hs = switch (h) { 0 => '', 1 => 'ساعة', 2 => 'ساعتان', _ => '${Ar.n(h)} ساعات' };
  if (m == 0) return hs;
  final ms = m == 30 ? 'نص' : '${Ar.n(m)} دقيقة';
  return hs.isEmpty ? ms : '$hs و$ms';
}

class KidsScreen extends StatelessWidget {
  const KidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final c = s.cfg;
      final p = s.palette;
      final apps = Profiles.kidsApps;
      final used = Profiles.usedToday;
      final allowed = Profiles.allowedToday;
      final left = allowed > 0 ? (allowed - used).clamp(0, 9999) : 0;
      const ink = Color(0xFF5A3410);
      final preview = Container(
        height: 360,
        padding: const EdgeInsets.all(32),
        decoration: ShapeDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFCE9C8), Color(0xFFF6D7B0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(60)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: FitText('أهلاً يا أبطال', style: Fonts.title(32, ink))),
            Text('${Ar.time(s.now)}', style: Fonts.body(24, ink, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: Row(children: [
              for (final (i, pkg) in (apps.isEmpty ? <String>[] : apps).take(4).indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: Column(children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: [const Color(0xFFE4572E), const Color(0xFF2E8A6A), const Color(0xFF7A5AC8), const Color(0xFF2F7EC8)][i % 4],
                          borderRadius: BorderRadius.circular(36),
                        ),
                        alignment: Alignment.center,
                        child: FitText(s.labelOf(pkg).characters.first, alignment: Alignment.center, style: Fonts.title(44, Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FitText(s.labelOf(pkg), alignment: Alignment.center, style: Fonts.body(16, ink, weight: FontWeight.w600)),
                  ]),
                ),
              ],
              if (apps.isEmpty) Expanded(child: Center(child: FitText('اختار تطبيقات الأطفال من اليمين', alignment: Alignment.center, style: Fonts.body(20, ink)))),
            ]),
          ),
          const SizedBox(height: 16),
          FitText(allowed > 0 ? 'باقي ${_dur(left)}' : 'بلا حد يومي', style: Fonts.body(18, ink, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              value: allowed > 0 ? (left / allowed).clamp(0.0, 1.0) : 1,
              minHeight: 14,
              color: const Color(0xFFE0973A),
              backgroundColor: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ]),
      );
      final limits = [for (final m in [0, 30, 60, 90, 120, 150, 180, 240]) (m, _dur(m))];
      final beds = [(-1, 'بلا وقت نوم'), for (var m = 1140; m <= 1350; m += 30) (m, _hm(m))];
      return SysScaffold(
        title: 'ملف الأطفال',
        sub: 'تطبيقات مختارة، ووقت محدد، ورمز للخروج',
        icon: Lu.baby,
        left: SysCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: StatusChip('معاينة حية', icon: Lu.eye)),
            const SizedBox(height: 18),
            preview,
            const SizedBox(height: 18),
            FitText('الواجهة الصغيرة تتبدّل لحظياً مع كل تغيير', style: Fonts.body(18, p.muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              const StatusChip('الخروج برمز', icon: Lu.lock),
              const StatusChip('بلا إعدادات', icon: Lu.eyeOff),
              if (c.i('kids.bed') >= 0) StatusChip('ينتهي ${_hm(c.i('kids.bed'))}', icon: Lu.moonStar),
            ]),
          ]),
        ),
        right: [
          SysRow(
            icon: Lu.timer,
            title: 'وقت المشاهدة اليومي',
            sub: used == 0 ? 'اليوم ما شاهدوا بعد' : 'اليوم شاهدوا ${_dur(used)}',
            value: _dur(c.i('kids.limit')),
            autofocus: true,
            onTap: () => showChoicePicker<int>(context, title: 'وقت المشاهدة اليومي', options: limits, value: c.i('kids.limit'), onChanged: (v) => _set('kids.limit', v)),
          ),
          SysRow(
            icon: Lu.grid,
            title: 'التطبيقات المسموحة',
            sub: apps.isEmpty ? 'ما مختار شي بعد' : '${Ar.n(apps.length)} تطبيقات مختارة',
            value: 'تعديل',
            onTap: () => Navigator.push(context, fade(const KidsAppsGrid())),
          ),
          SysRow(
            icon: Lu.moon,
            title: 'وقت النوم',
            sub: 'بعده تطلع شاشة «تصبحون على خير» لحد الصبح',
            value: c.i('kids.bed') < 0 ? 'بلا' : _hm(c.i('kids.bed')),
            onTap: () => showChoicePicker<int>(context, title: 'وقت النوم', options: beds, value: c.i('kids.bed'), onChanged: (v) => _set('kids.bed', v)),
          ),
          SysRow(
            icon: Lu.key,
            title: 'رمز الخروج',
            sub: 'نفس رمز رونق، يطلبه تبديل الملف والإعدادات',
            value: '••••',
            onTap: () async {
              if (!await askPin(context, title: 'الرمز الحالي')) return;
              if (!context.mounted) return;
              final v = await promptText(context, title: 'الرمز الجديد (٤ أرقام)', obscure: true, number: true);
              if (v != null && v.length >= 4 && int.tryParse(v) != null) PinGuard.change(v);
            },
          ),
          SysRow(icon: Lu.userPen, title: 'اسم الأطفال', sub: 'يظهر بالترحيب وشاشة النوم', value: c.s('kids.name'), onTap: () async {
            final v = await promptText(context, title: 'اسم الأطفال', initial: c.s('kids.name'));
            if (v != null && v.trim().isNotEmpty) _set('kids.name', v.trim());
          }),
          SysRow(
            icon: Lu.calendarRange,
            title: 'وقت أيام العطلة',
            sub: 'الجمعة والسبت',
            value: c.i('kids.weekend') == 0 ? 'نفس العادية' : _dur(c.i('kids.weekend')),
            onTap: () => showChoicePicker<int>(context, title: 'وقت العطلة', options: [(0, 'نفس العادية'), for (final m in [60, 120, 180, 240, 300]) (m, _dur(m))], value: c.i('kids.weekend'), onChanged: (v) => _set('kids.weekend', v)),
          ),
          SysRow(
            icon: Lu.timer,
            title: 'التمديد برمز الأهل',
            value: _dur(c.i('kids.step')),
            onTap: () => showChoicePicker<int>(context, title: 'مقدار التمديد', options: [for (final m in [15, 30, 60]) (m, _dur(m))], value: c.i('kids.step'), onChanged: (v) => _set('kids.step', v)),
          ),
          SysRow(
            icon: Lu.palette,
            title: 'لون واجهتهم',
            value: switch (c.s('kids.style')) { 'sky' => 'سماوي', 'mint' => 'نعناعي', _ => 'دافئ' },
            onTap: () => showChoicePicker<String>(context, title: 'لون واجهة الأطفال', options: const [('warm', 'دافئ'), ('sky', 'سماوي'), ('mint', 'نعناعي')], value: c.s('kids.style'), onChanged: (v) => _set('kids.style', v)),
          ),
          SysRow(icon: Lu.chart, title: 'التقرير الأسبوعي', sub: 'شكد شاهدوا وأكثر التطبيقات', onTap: () => Navigator.push(context, fade(const KidsReportScreen()))),
          SysRow(icon: Lu.sparkles, title: 'معالج الإعداد', sub: 'الاسم والتطبيقات والوقت بثلاث خطوات', onTap: () => Navigator.push(context, fade(const KidsSetupWizard()))),
          SysRow(
            icon: Lu.baby,
            title: Profiles.kids ? 'ملف الأطفال شغّال الآن' : 'تشغيل ملف الأطفال الآن',
            toggle: Profiles.kids,
            onTap: () async {
              if (Profiles.kids) {
                if (!await askPin(context, title: 'الخروج من ملف الأطفال')) return;
                _set('profile.active', 'family');
              } else {
                _set('profile.active', 'kids');
              }
            },
          ),
        ],
      );
    });
  }
}

// ═══════════════════ ٦. التلفزيون والطاقة ═══════════════════

class PowerScreen extends StatefulWidget {
  const PowerScreen({super.key});
  @override
  State<PowerScreen> createState() => _PowerScreenState();
}

class _PowerScreenState extends State<PowerScreen> {
  Map<String, dynamic> _st = const {};
  String? _plugOk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await Streamer.powerStatus();
    String? ok;
    final ip = AppState.I.cfg.s('plug.ip');
    if (ip.isNotEmpty) ok = await PlugCfg.detect(ip) != null ? 'yes' : 'no';
    if (mounted) setState(() {
      _st = st;
      _plugOk = ok;
    });
  }

  void _apply(String k, Object v) {
    _set(k, v);
    PlugCfg.apply();
  }

  Future<void> _test(bool on) async {
    final ok = await PlugCfg.get(PlugCfg.url(on));
    if (mounted) toast(context, ok ? (on ? 'رجعت الكهرباء للتلفزيون' : 'انقطعت الكهرباء عن التلفزيون') : 'القابس ما رد، تأكد من العنوان');
  }

  @override
  Widget build(BuildContext context) {
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      final method = c.s('power.method');
      final plug = method != 'cec';
      Widget node(String t, String sub, Object ic, Color col) => Expanded(
            child: Container(
              height: 150,
              padding: const EdgeInsets.all(14),
              decoration: ShapeDecoration(color: _s2(p), shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(50), side: BorderSide(color: p.line))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AppIcon(ic, color: col, size: 46),
                const SizedBox(height: 10),
                FitText(t, alignment: Alignment.center, style: Fonts.body(19, p.ink, weight: FontWeight.w600)),
                FitText(sub, alignment: Alignment.center, style: Fonts.body(15, p.muted)),
              ]),
            ),
          );
      final lastOff = (_st['lastOff'] as int?) ?? 0;
      return SysScaffold(
        title: 'التلفزيون والطاقة',
        sub: 'تشغيل وإطفاء الشاشة كلها من الستريمر، وإذا ما استجاب التلفزيون نقطع الكهرباء بالقابس الذكي',
        icon: Lu.power,
        left: SysCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FitText('سلسلة التحكم', style: Fonts.body(22, p.ink, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(children: [
              node('الستريمر', 'Google TV', Lu.tvPlay, p.accent),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: AppIcon(Lu.chevronLeft, color: p.accent, size: 30)),
              if (plug) ...[
                node('القابس الذكي', c.s('plug.ip').isEmpty ? 'غير محدد' : c.s('plug.ip'), Lu.plugZap, p.ring),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: AppIcon(Lu.chevronLeft, color: p.accent, size: 30)),
              ],
              node('التلفزيون', plug ? 'كهرباء + HDMI' : 'HDMI-CEC', Lu.tv, p.muted),
            ]),
            const SizedBox(height: 20),
            const StatusLine('أوامر HDMI-CEC', 'تتضبط بـ cec-fix.bat', kind: 'none', icon: Lu.hdmi),
            if (plug)
              StatusLine('القابس الذكي', c.s('plug.ip').isEmpty ? 'غير محدد' : (_plugOk == null ? '…' : (_plugOk == 'yes' ? 'متصل' : 'ما يرد')),
                  kind: _plugOk == 'yes' ? 'ok' : (c.s('plug.ip').isEmpty ? 'warn' : (_plugOk == 'no' ? 'bad' : 'none'))),
            if (plug && lastOff > 0)
              StatusLine('آخر قطع للكهرباء', '${Recents.ago(DateTime.fromMillisecondsSinceEpoch(lastOff))}${_st['lastOffOk'] == true ? '' : '، فشل'}',
                  kind: _st['lastOffOk'] == true ? 'ok' : 'bad'),
            const SizedBox(height: 8),
            FitText(
              plug ? 'بالتشغيل ترجع الكهرباء وتشتغل الشاشة وحدها، بشرط «Power on mode = On» بإعداداتها.' : 'إذا الشاشة تبقى زرقاء بعد النوم، فعّل القابس الذكي.',
              style: Fonts.body(17, p.muted),
            ),
          ]),
        ),
        right: [
          SysRow(
            icon: Lu.power,
            title: 'طريقة الإطفاء',
            sub: 'الأقوى: CEC وبعده قطع الكهرباء',
            value: switch (method) { 'plug' => 'القابس فقط', 'both' => 'الاثنين معاً', _ => 'CEC فقط' },
            autofocus: true,
            onTap: () => showChoicePicker<String>(context,
                title: 'طريقة الإطفاء', options: const [('cec', 'CEC فقط (كيبل HDMI)'), ('both', 'الاثنين معاً (CEC والقابس)'), ('plug', 'القابس الذكي فقط')], value: method, onChanged: (v) => _apply('power.method', v)),
          ),
          SysRow(
            icon: Lu.plug,
            title: 'عنوان القابس الذكي',
            sub: 'Shelly أو Tasmota على نفس الشبكة',
            value: c.s('plug.ip').isEmpty ? 'غير محدد' : c.s('plug.ip'),
            onTap: () async {
              final v = await promptText(context, title: 'عنوان القابس (IP)', initial: c.s('plug.ip'));
              if (v == null) return;
              _apply('plug.ip', v.trim());
              final k = v.trim().isEmpty ? null : await PlugCfg.detect(v.trim());
              if (k != null) _apply('plug.kind', k);
              if (context.mounted && v.trim().isNotEmpty) toast(context, k != null ? 'لكينا القابس: ${k == 'tasmota' ? 'Tasmota' : 'Shelly'}' : 'ما رد قابس على هذا العنوان');
              _load();
            },
          ),
          SysRow(
            icon: Lu.cable,
            title: 'نوع القابس',
            value: switch (c.s('plug.kind')) { 'shelly1' => 'Shelly الأول', 'tasmota' => 'Tasmota', _ => 'Shelly Plus' },
            onTap: () => showChoicePicker<String>(context,
                title: 'نوع القابس', options: const [('shelly2', 'Shelly Plus / Gen2'), ('shelly1', 'Shelly Gen1'), ('tasmota', 'Tasmota')], value: c.s('plug.kind'), onChanged: (v) => _apply('plug.kind', v)),
          ),
          SysRow(
            icon: Lu.timer,
            title: 'انتظار قبل قطع الكهرباء',
            sub: 'حتى الشاشة تطفي بهدوء أول',
            value: '${Ar.n(c.i('plug.wait'))} ثانية',
            onTap: () => showChoicePicker<int>(context,
                title: 'انتظار قبل القطع', options: [for (final s in [5, 10, 15, 20, 30]) (s, '${Ar.n(s)} ثانية')], value: c.i('plug.wait'), onChanged: (v) => _apply('plug.wait', v)),
          ),
          SysRow(icon: Lu.zap, title: 'اختبار: قطع الكهرباء', sub: 'الشاشة تنطفي فوراً', onTap: () => _test(false)),
          SysRow(icon: Lu.power, title: 'اختبار: رجوع الكهرباء', onTap: () => _test(true)),
          SysRow(icon: Lu.moon, title: 'نوم الستريمر الآن', sub: 'ينفّذ التسلسل كامل', onTap: () async {
            final ok = await NativeBridge.sleepNow();
            if (!ok) AppState.I.sleepFallback.value++;
          }),
          SysRow(icon: Lu.hdmi, title: 'إعدادات HDMI-CEC بالنظام', onTap: NativeBridge.displaySettings),
        ],
      );
    });
  }
}

// ═══════════════════ ٧. العرض والصوت ═══════════════════

class DisplaySoundScreen extends StatefulWidget {
  const DisplaySoundScreen({super.key});
  @override
  State<DisplaySoundScreen> createState() => _DisplaySoundScreenState();
}

class _DisplaySoundScreenState extends State<DisplaySoundScreen> {
  Map<String, dynamic> _d = const {};
  String _match = '';
  String _cecVol = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Streamer.displayInfo();
    final m = await Streamer.getSetting('secure', 'match_content_frame_rate') ?? '';
    final v = await Streamer.getSetting('global', 'hdmi_control_volume_control_enabled') ?? '';
    if (mounted) setState(() {
      _d = d;
      _match = m;
      _cecVol = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppState.I.palette;
    final w = (_d['w'] as int?) ?? 0, h = (_d['h'] as int?) ?? 0;
    final hz = ((_d['hz'] as num?) ?? 0).round();
    final maxW = (_d['maxW'] as int?) ?? w;
    final res = w >= 3800 ? '4K' : (w >= 1900 ? 'Full HD' : (w > 0 ? '${Ar.n(w)}×${Ar.n(h)}' : '…'));
    final hdr = ((_d['hdr'] as List?) ?? const []).cast<String>();
    final audio = ((_d['audio'] as List?) ?? const []).cast<String>();
    final out = audio.contains('bluetooth') ? 'سماعة بلوتوث' : (audio.contains('arc') ? 'سماعة عبر ARC' : (audio.contains('usb') ? 'سماعة USB' : 'سماعات التلفزيون'));
    final matchLabel = switch (_match) { '0' => 'أبداً', '1' => 'بدون تقطيع فقط', '2' => 'دائماً', _ => 'حسب النظام' };
    final low = maxW > w && w > 0;
    return SysScaffold(
      title: 'العرض والصوت',
      sub: 'أفضل صورة وصوت على شاشتك',
      icon: Lu.monitor,
      left: SysCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FitText('الحالة الآن', style: Fonts.body(22, p.ink, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          StatusLine('الدقة', w == 0 ? '…' : '$res بـ ${Ar.n(hz)} هيرتز', kind: low ? 'warn' : 'ok'),
          StatusLine('HDR', hdr.isEmpty ? 'الشاشة ما تدعمه' : hdr.where((e) => e != 'Dolby Vision').join('، '), kind: hdr.isEmpty ? 'none' : 'ok', icon: hdr.isEmpty ? Lu.info : null),
          StatusLine('Dolby Vision', hdr.contains('Dolby Vision') ? 'مدعوم' : 'غير مدعوم', kind: hdr.contains('Dolby Vision') ? 'ok' : 'none', icon: hdr.contains('Dolby Vision') ? null : Lu.info),
          StatusLine('مطابقة الإطارات', matchLabel, kind: _match == '0' ? 'none' : 'ok'),
          StatusLine('مخرج الصوت', out),
          const SizedBox(height: 8),
          FitText(low ? 'الشاشة تدعم دقة أعلى من الحالية — جرّب كيبل HDMI أفضل أو المنفذ الأول.' : 'إذا نزلت الدقة بسبب كيبل ضعيف يبين هنا.', style: Fonts.body(17, p.muted)),
        ]),
      ),
      right: [
        SysRow(
          icon: Lu.film,
          title: 'مطابقة معدل الإطارات',
          sub: 'الأفلام تشتغل بإطاراتها الأصلية بلا تقطيع',
          value: matchLabel,
          autofocus: true,
          onTap: () => showChoicePicker<String>(context,
              title: 'مطابقة معدل الإطارات', options: const [('1', 'بدون تقطيع فقط (مستحسن)'), ('2', 'دائماً'), ('0', 'أبداً')], value: _match.isEmpty ? '1' : _match, onChanged: (v) async {
            final ok = await Streamer.putSetting('secure', 'match_content_frame_rate', v);
            if (!ok && context.mounted) toast(context, 'تحتاج صلاحية install.bat، أو غيّرها من إعدادات العرض');
            _load();
          }),
        ),
        SysRow(icon: Lu.sun, title: 'وضع HDR والصورة', sub: 'من إعدادات العرض بالنظام', onTap: NativeBridge.displaySettings),
        SysRow(icon: Lu.monitor, title: 'الدقة', sub: 'أعلى دقة تدعمها الشاشة', value: w == 0 ? '…' : '$res ${Ar.n(hz)}Hz', onTap: NativeBridge.displaySettings),
        SysRow(icon: Lu.speaker, title: 'مخرج الصوت', sub: 'التلفزيون أو سماعة خارجية', value: out, onTap: NativeBridge.soundSettings),
        SysRow(
          icon: Lu.volume,
          title: 'صوت التلفزيون من الريموت',
          sub: 'أزرار الصوت تتحكم بالتلفزيون عبر CEC',
          toggle: _cecVol != '0',
          onTap: () async {
            final ok = await Streamer.putSetting('global', 'hdmi_control_volume_control_enabled', _cecVol == '0' ? '1' : '0');
            if (!ok && context.mounted) toast(context, 'غيّرها من إعدادات العرض والصوت ← HDMI-CEC');
            _load();
          },
        ),
        SysRow(icon: Lu.deviceSettings, title: 'إعدادات العرض بالنظام', sub: 'الصفحة الأصلية للعرض والصوت', onTap: NativeBridge.displaySettings),
      ],
    );
  }
}

// ═══════════════════ ٨. زر النجمة والريموت ═══════════════════

class StarScreen extends StatelessWidget {
  const StarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      const body = Color(0xFF1B2421), kc = Color(0xFF2E3835), ink = Color(0xFFD7DDDA);
      Widget b(Object ic, {bool star = false}) => Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: star ? const Color(0xFFD8B467) : kc,
              shape: BoxShape.circle,
              boxShadow: star ? [const BoxShadow(color: Color(0x99D8B467), blurRadius: 30, spreadRadius: 3)] : null,
            ),
            child: AppIcon(ic, color: star ? const Color(0xFF1B1206) : ink, size: 24),
          );
      final remote = Container(
        width: 180,
        height: 500,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(color: body, borderRadius: BorderRadius.circular(90), border: Border.all(color: p.line)),
        child: Column(children: [
          Container(width: 130, height: 130, decoration: const BoxDecoration(color: kc, shape: BoxShape.circle), alignment: Alignment.center, child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFF3C4844), shape: BoxShape.circle))),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [b(Lu.chevronRight), const SizedBox(width: 16), b(Lu.house)]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [b(Lu.mic), const SizedBox(width: 16), b(Lu.star, star: true)]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [b(Lu.play), const SizedBox(width: 16), b(Lu.volumeOff)]),
          const Spacer(),
          Container(width: 52, height: 110, decoration: BoxDecoration(color: kc, borderRadius: BorderRadius.circular(26)), child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: const [AppIcon(Lu.plus, color: ink, size: 22), SizedBox(width: 22, height: 3, child: ColoredBox(color: ink))])),
        ]),
      );
      return SysScaffold(
        title: 'زر النجمة والريموت',
        sub: 'اربط أزرار ريموت الستريمر برونق',
        icon: Lu.star,
        left: SysCard(
          child: Column(children: [
            FitText('ريموت الستريمر', style: Fonts.body(22, p.ink, weight: FontWeight.w600)),
            const SizedBox(height: 18),
            remote,
            const SizedBox(height: 18),
            FitText('زر النجمة يقبل تطبيق واحد تختاره، ورونق يحدد شنو يصير بعدها', alignment: Alignment.center, style: Fonts.body(17, p.muted)),
          ]),
        ),
        right: [
          const SysSection('الربط مرة وحدة'),
          SysRow(icon: Lu.settings, title: '١. إعدادات النظام', sub: 'الريموت والملحقات ← تخصيص زر النجمة', autofocus: true, onTap: NativeBridge.systemSettings),
          SysRow(icon: Lu.star, title: '٢. اختار «رونق»', sub: 'من قائمة التطبيقات', onTap: () {}),
          const SysSection('شنو يسوي الزر'),
          SysRow(
            icon: Lu.star,
            title: 'داخل رونق',
            sub: 'ضغطة على النجمة ورونق قدامك',
            value: switch (c.s('star.action')) { 'saver' => 'شاشة السكون', 'search' => 'البحث', 'notifs' => 'التنبيهات', 'home' => 'أول تطبيق', _ => 'اللوحة السريعة' },
            onTap: () => showChoicePicker<String>(context,
                title: 'زر النجمة داخل رونق',
                options: const [('quick', 'اللوحة السريعة'), ('search', 'البحث'), ('notifs', 'مركز التنبيهات'), ('saver', 'شاشة السكون'), ('home', 'الرجوع لأول تطبيق')],
                value: c.s('star.action'),
                onChanged: (v) => _set('star.action', v)),
          ),
          SysRow(icon: Lu.house, title: 'من تطبيق ثاني', sub: 'يرجّعك لرونق مباشرة', value: 'الواجهة', onTap: () {}),
          SysRow(icon: Lu.power, title: 'زر الطاقة', sub: 'ينوّم الستريمر، والتلفزيون يطفي حسب «التلفزيون والطاقة»', value: 'إطفاء كامل', onTap: () => Navigator.push(context, fade(const PowerScreen()))),
        ],
      );
    });
  }
}

// ═══════════════════ ٩. المنزل الذكي ═══════════════════

class SmartHomeScreen extends StatelessWidget {
  const SmartHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      final mode = c.s('smart.mode');
      Widget opt(String id, String t, String s, Object ic, String kind) {
        final sel = mode == id;
        final col = kind == 'ok' ? p.accent : _warn(p);
        return Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: ShapeDecoration(color: _s2(p), shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(52), side: BorderSide(color: sel ? p.ring : p.line, width: sel ? ringW : 1))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 56, height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: col.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)), child: AppIcon(ic, color: col, size: 30)),
                const Spacer(),
                if (sel) const StatusChip('المختار', icon: Lu.check),
              ]),
              const SizedBox(height: 18),
              FitText(t, style: Fonts.body(22, p.ink, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(s, style: Fonts.body(17, p.muted)),
            ]),
          ),
        );
      }

      return SysScaffold(
        title: 'المنزل الذكي',
        sub: 'ستريمرك مركز للمنزل الذكي، وهنا نحافظ على هذي الميزة',
        icon: Lu.smartHome,
        left: SysCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: StatusChip('انتبه', kind: 'warn', icon: Lu.info)),
            const SizedBox(height: 14),
            FitText('لوحة Google Home جزء من واجهة كوكل', style: Fonts.body(25, p.ink, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('إذا أوقفنا واجهة كوكل كلياً تختفي لوحة الأجهزة الذكية من الستريمر. الأسلم نخفيها بدل إيقافها، والحارس يرجّع رونق كل ما تطلع.', style: Fonts.body(19, p.muted)),
            const SizedBox(height: 22),
            Row(children: [
              opt('hide', 'إخفاء مع الحارس', 'لوحة المنزل الذكي تبقى، ورونق هو الواجهة', Lu.shieldCheck, 'ok'),
              const SizedBox(width: 20),
              opt('disable', 'إيقاف كامل', 'أخف وأسرع، بس تروح لوحة الأجهزة الذكية', Lu.circleX, 'warn'),
            ]),
            const SizedBox(height: 16),
            Text('الستريمر يبقى مركز Matter وThread بالحالتين، والأجهزة تشتغل من تطبيق Google Home بالموبايل.', style: Fonts.body(17, p.muted)),
          ]),
        ),
        right: [
          SysRow(
            icon: Lu.tv,
            title: 'التعامل مع واجهة كوكل',
            sub: 'يتطبّق بالمنصّب: جواب N يخفيها، وY يوقفها',
            value: mode == 'disable' ? 'إيقاف كامل' : 'إخفاء مع الحارس',
            autofocus: true,
            onTap: () => showChoicePicker<String>(context,
                title: 'واجهة كوكل', options: const [('hide', 'إخفاء مع الحارس (المقترح)'), ('disable', 'إيقاف كامل')], value: mode, onChanged: (v) => _set('smart.mode', v)),
          ),
          SysRow(
            icon: Lu.smartHome,
            title: 'فتح لوحة Google Home',
            sub: 'تفتح واجهة كوكل ١٠ دقائق للأجهزة الذكية',
            onTap: () async {
              final ok = await Streamer.guardPause(10);
              if (!ok && context.mounted) toast(context, 'واجهة كوكل موقوفة كلياً، اختار «إخفاء مع الحارس» وأعد تشغيل install.bat');
            },
          ),
          SysRow(icon: Lu.shieldCheck, title: 'حارس الواجهة', sub: 'يرجّع رونق بعد ما تخلص', onTap: () => Navigator.push(context, fade(const GuardScreen()))),
          SysRow(icon: Lu.plug, title: 'القابس الذكي للتلفزيون', value: c.s('plug.ip').isEmpty ? 'غير محدد' : 'مضبوط', onTap: () => Navigator.push(context, fade(const PowerScreen()))),
        ],
      );
    });
  }
}

// ═══════════════════ ١٠. التقويم الهجري ═══════════════════

class HijriScreen extends StatelessWidget {
  const HijriScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      final now = DateTime.now();
      final month = Hijri.month(now);
      final today = Hijri.of(now);
      final first = month.first.g;
      final lead = (first.weekday + 1) % 7; // السبت أول الأسبوع
      final cells = <Widget>[];
      for (var i = 0; i < lead; i++) {
        cells.add(const SizedBox.shrink());
      }
      for (final d in month) {
        final isToday = d.d == today.d;
        final occ = Hijri.occasionOf(d) != null;
        cells.add(Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isToday ? p.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: !isToday && occ ? p.ring : Colors.transparent, width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(Ar.n(d.d), style: Fonts.body(24, isToday ? p.onAccent : p.ink, weight: FontWeight.w600)),
            Text(Ar.n(d.g.day), style: Fonts.body(13, isToday ? p.onAccent : p.muted)),
            if (occ && !isToday) Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 3), decoration: BoxDecoration(color: p.ring, shape: BoxShape.circle)),
          ]),
        ));
      }
      final up = Hijri.upcoming();
      final days = [for (final d in const ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة']) Center(child: Text(d, style: Fonts.body(15, p.muted, weight: FontWeight.w600)))];
      return SysScaffold(
        title: 'التقويم الهجري',
        sub: 'التاريخ الهجري والمناسبات، مع تصحيح يوم حسب الرؤية',
        icon: Lu.calendarHeart,
        left: SysCard(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FitText('${Ar.hijriMonths[today.m - 1]} ${Ar.n(today.y)}', style: Fonts.title(34, p.ink)),
            FitText('${Ar.months[first.month - 1]}${month.last.g.month != first.month ? ' و${Ar.months[month.last.g.month - 1]}' : ''} ${Ar.n(first.year)}', style: Fonts.body(17, p.muted)),
            const SizedBox(height: 12),
            SizedBox(height: 30, child: Row(children: [for (final d in days) Expanded(child: d)])),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final rows = (cells.length / 7).ceil();
                final cw = box.maxWidth / 7;
                final ch = (box.maxHeight / rows).clamp(40.0, cw * 1.05);
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: ch * rows,
                    child: GridView.count(crossAxisCount: 7, physics: const NeverScrollableScrollPhysics(), childAspectRatio: cw / ch, padding: EdgeInsets.zero, children: cells),
                  ),
                );
              }),
            ),
          ]),
        ),
        right: [
          const SysSection('المناسبات القادمة'),
          for (final (i, (d, o)) in up.indexed)
            SysRow(
              icon: Lu.calendarHeart,
              title: o,
              sub: Hijri.label(d),
              value: d.g.difference(DateTime(now.year, now.month, now.day)).inDays == 0 ? 'اليوم' : 'بعد ${Ar.n(d.g.difference(DateTime(now.year, now.month, now.day)).inDays)} يوم',
              autofocus: i == 0,
              onTap: () {},
            ),
          const SysSection('الإعدادات'),
          SysRow(
            icon: Lu.calendar,
            title: 'تصحيح التاريخ',
            sub: 'يوم زايد أو ناقص حسب الرؤية',
            value: c.i('misc.hijriOffset') == 0 ? '٠' : '${c.i('misc.hijriOffset') > 0 ? '+' : '−'}${Ar.n(c.i('misc.hijriOffset').abs())}',
            onTap: () => showChoicePicker<int>(context,
                title: 'تصحيح التاريخ الهجري', options: [for (final v in [-2, -1, 0, 1, 2]) (v, v == 0 ? 'بدون تصحيح' : '${v > 0 ? '+' : '−'}${Ar.n(v.abs())} يوم')], value: c.i('misc.hijriOffset'), onChanged: (v) => _set('misc.hijriOffset', v)),
          ),
        ],
      );
    });
  }
}

// ═══════════════════ ١١. المحتوى اليومي ═══════════════════

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final p = AppState.I.palette;
      final c = AppState.I.cfg;
      final d = Daily.today();
      final big = c.s('daily.size') == 'large';
      const kinds = [('ayah', 'آية'), ('hadith', 'حديث'), ('dua', 'دعاء')];
      return SysScaffold(
        title: 'المحتوى اليومي',
        sub: 'آية أو حديث أو دعاء كل يوم، بالواجهة وشاشة السكون',
        icon: Lu.quote,
        left: SysCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: StatusChip('معاينة حية', icon: Lu.eye)),
            const SizedBox(height: 18),
            Container(
              height: 360,
              padding: const EdgeInsets.all(28),
              decoration: ShapeDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F3A2C), Color(0xFF04100C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(60)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(Ar.time(AppState.I.now), style: Fonts.clock(76, const Color(0xFFF3EBD6))),
                const SizedBox(height: 14),
                const AppIcon(Lu.moonStar, color: Color(0xFFD8B467), size: 28),
                const SizedBox(height: 10),
                FitText(c.b('daily.on') ? d.$1 : 'المحتوى اليومي متوقف', alignment: Alignment.center, style: Fonts.title(big ? 36 : 28, const Color(0xFFF3EBD6))),
                const SizedBox(height: 6),
                FitText(c.b('daily.on') ? d.$2 : '', alignment: Alignment.center, style: Fonts.body(17, const Color(0xFFC9D6CF))),
              ]),
            ),
            const SizedBox(height: 18),
            Wrap(spacing: 10, children: [for (final k in kinds) StatusChip(k.$2, kind: c.s('daily.kind') == k.$1 ? 'ok' : 'none', icon: c.s('daily.kind') == k.$1 ? Lu.check : null)]),
            const SizedBox(height: 14),
            Text('يتبدل كل يوم من مجموعة مختارة. بالواجهة يطلع أول مرة باليوم ٢٠ ثانية ويختفي.', style: Fonts.body(17, p.muted)),
          ]),
        ),
        right: [
          SysRow(icon: Lu.quote, title: 'المحتوى اليومي', toggle: c.b('daily.on'), autofocus: true, onTap: () => _flip('daily.on')),
          SysRow(
            icon: Lu.book,
            title: 'نوع المحتوى',
            sub: 'آية، حديث، دعاء',
            value: kinds.firstWhere((k) => k.$1 == c.s('daily.kind'), orElse: () => kinds.first).$2,
            onTap: () => showChoicePicker<String>(context, title: 'نوع المحتوى', options: kinds, value: c.s('daily.kind'), onChanged: (v) => _set('daily.kind', v)),
          ),
          SysRow(
            icon: Lu.layoutTop,
            title: 'مكان الظهور',
            value: switch (c.s('daily.where')) { 'home' => 'الواجهة', 'saver' => 'شاشة السكون', _ => 'الاثنين' },
            onTap: () => showChoicePicker<String>(context,
                title: 'مكان الظهور', options: const [('both', 'الواجهة وشاشة السكون'), ('home', 'الواجهة فقط'), ('saver', 'شاشة السكون فقط')], value: c.s('daily.where'), onChanged: (v) => _set('daily.where', v)),
          ),
          SysRow(
            icon: Lu.textSize,
            title: 'حجم الخط',
            value: big ? 'كبير' : 'متوسط',
            onTap: () => _set('daily.size', big ? 'medium' : 'large'),
          ),
          SysRow(icon: Lu.baby, title: 'إظهار بملف الأطفال', toggle: c.b('daily.kids'), onTap: () => _flip('daily.kids')),
        ],
      );
    });
  }
}

// ═══════════════════ ١٢. الأداء والحجم ═══════════════════

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return live(() {
      final s = AppState.I;
      final p = s.palette;
      final c = s.cfg;
      final scale = c.s('ui.scale');
      final n = switch (scale) { 'small' => 5, 'large' => 3, _ => 4 };
      final sz = switch (scale) { 'small' => 22.0, 'large' => 36.0, _ => 28.0 };
      const cols = [Color(0xFFC4302B), Color(0xFFB20710), Color(0xFF2E7D5B), Color(0xFFA87A2E), Color(0xFF5E4A8E)];
      const icons = [Lu.play, Lu.film, Lu.tv, Lu.book, Lu.trophy];
      final preview = Container(
        height: 340,
        padding: const EdgeInsets.all(26),
        decoration: ShapeDecoration(color: p.bg, shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(56), side: BorderSide(color: p.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(Ar.time(s.now), style: Fonts.clock(sz + 14, p.ink)),
          Text('المفضلة', style: Fonts.body(sz - 6, p.muted, weight: FontWeight.w600)),
          SizedBox(height: sz * 0.5),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedContainer(
                    duration: s.anim(260),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cols[i], const Color(0xFF111111)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      border: i == 0 ? Border.all(color: p.ring, width: 3) : null,
                    ),
                    child: AppIcon(icons[i], color: Colors.white, size: sz),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      );
      final perf = c.s('ui.performance');
      final dev = '${s.model.isEmpty ? 'الجهاز' : s.model}${s.ramMb > 0 ? '، ذاكرة ${Ar.n((s.ramMb / 1024).toStringAsFixed(1))} GB' : ''}';
      return SysScaffold(
        title: 'الأداء والحجم',
        sub: s.lite ? '$dev، فاشتغل الوضع الخفيف' : '$dev، وكل المؤثرات مفعّلة',
        icon: Lu.gauge,
        left: SysCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: StatusChip('معاينة حية', icon: Lu.eye)),
            const SizedBox(height: 18),
            preview,
            const SizedBox(height: 18),
            Wrap(spacing: 10, children: [
              for (final k in const [('small', 'صغير'), ('medium', 'متوسط'), ('large', 'كبير')]) StatusChip(k.$2, kind: scale == k.$1 ? 'ok' : 'none', icon: scale == k.$1 ? Lu.check : null),
            ]),
            const SizedBox(height: 12),
            Text('مسافة الجلوس المناسبة: ${switch (scale) { 'small' => 'متر ونص', 'large' => '٤ أمتار وأكثر', _ => '٣ أمتار' }}', style: Fonts.body(18, p.muted)),
          ]),
        ),
        right: [
          SysRow(
            icon: Lu.scaling,
            title: 'حجم الواجهة',
            sub: 'يتغير الحجم لكل الشاشات فوراً',
            value: switch (scale) { 'small' => 'صغير', 'large' => 'كبير', _ => 'متوسط' },
            autofocus: true,
            onTap: () => showChoicePicker<String>(context,
                title: 'حجم الواجهة', options: const [('small', 'صغير (شاشة قريبة)'), ('medium', 'متوسط'), ('large', 'كبير (جلسة بعيدة)')], value: scale, onChanged: (v) => _set('ui.scale', v)),
          ),
          SysRow(
            icon: Lu.gauge,
            title: 'وضع الأداء',
            sub: 'كشف تلقائي للجهاز',
            value: switch (perf) { 'quality' => 'أعلى جودة', 'fast' => 'خفيف', _ => s.lite ? 'تلقائي (خفيف)' : 'تلقائي (كامل)' },
            onTap: () => showChoicePicker<String>(context,
                title: 'وضع الأداء', options: const [('auto', 'تلقائي'), ('quality', 'أعلى جودة'), ('fast', 'خفيف وسريع')], value: perf, onChanged: (v) => _set('ui.performance', v)),
          ),
          SysRow(icon: Lu.gauge, title: 'سلاسة الواجهة الآن', value: '${Ar.n(SystemWatch.I.fps.round())} إطار/ث', onTap: () => Navigator.push(context, fade(const HealthScreen()))),
          SysRow(icon: Lu.memory, title: 'صحة النظام', sub: 'الذاكرة، التخزين، الشبكة', onTap: () => Navigator.push(context, fade(const HealthScreen()))),
        ],
      );
    });
  }
}
