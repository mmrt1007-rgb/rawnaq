import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arabic.dart';
import '../lucide.dart';
import '../palette.dart';
import '../platform.dart';
import '../state.dart';
import '../widgets.dart';
import 'saver_gallery.dart';
import 'screensaver.dart';
import 'settings.dart';
import 'streamer_screens.dart' show QuickDeviceBar, openThemeSettings, openDeviceSettings;

/// اللوحة السريعة — مثل لوحة Google TV (أندرويد ١٤) بأسلوب رونق، مطابقة لصفحة فيكما ٠٦:
/// ورقة جانبية على يسار الشاشة (٦٤٠×١٠٠٠ بهامش ٤٠)، والواجهة خلفها مغبّشة.
///
/// التحكم:
///  • ▲▼ بين الصفوف، ◀▶ بين عمودي البطاقات (وفي صف الصوت: تعديل المستوى).
///  • موافق = تفعيل/إيقاف، ضغطة مطوّلة على موافق = صفحة التفاصيل مباشرة.
///  • رجوع: من التفاصيل للوحة، ومن اللوحة يسكّرها.
Future<void> showQuickPanel(BuildContext context) {
  final night = AppState.I.palette.night;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'اللوحة السريعة',
    barrierColor: Colors.black.withValues(alpha: night ? 0.5 : 0.38),
    transitionDuration: AppState.I.anim(280),
    pageBuilder: (_, __, ___) => const Directionality(textDirection: TextDirection.rtl, child: _QuickPanel()),
    transitionBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return Stack(children: [
        // تغبيش الواجهة خلف اللوحة
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) => BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18 * c.value, sigmaY: 18 * c.value),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        SlideTransition(
          position: Tween(begin: const Offset(-0.25, 0), end: Offset.zero).animate(c),
          child: FadeTransition(opacity: c, child: child),
        ),
      ]);
    },
  );
}

/// المقاسات من فيكما.
const double _panelW = 640, _margin = 40, _pad = 32, _gap = 14, _tileH = 100;

enum _Page { main, net, sleep, mode, mem }

class _QuickPanel extends StatefulWidget {
  const _QuickPanel();

  @override
  State<_QuickPanel> createState() => _QuickPanelState();
}

class _QuickPanelState extends State<_QuickPanel> {
  Map<String, dynamic> _st = const {};
  Timer? _poll;
  final _nodes = FocusNodes();
  _Page _page = _Page.main;
  String _returnTo = 'tile:net';
  bool _cleaning = false;
  bool? _dnsPending;

  AppState get s => AppState.I;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _nodes.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final st = await NativeBridge.systemStatus();
    if (mounted) setState(() => _st = st);
  }

  int _i(String k) => (_st[k] as int?) ?? 0;
  bool _b(String k) => (_st[k] as bool?) ?? false;
  String _str(String k) => (_st[k] as String?) ?? '';

  String _gb(int mb) => mb >= 1024 ? '${Ar.n((mb / 1024).toStringAsFixed(1))} GB' : '${Ar.n(mb)} MB';

  // ───────────── الصفحات ─────────────

  void _open(_Page page, String from) {
    setState(() {
      _returnTo = from;
      _page = page;
    });
  }

  void _backToMain() {
    setState(() => _page = _Page.main);
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes.focus(_returnTo));
  }

  void _close() => Navigator.of(context).maybePop();

  /// يسكّر اللوحة ويكمل بسياق المتصفح (يبقى صالح بعد الإغلاق).
  void _toNav(Future<void> Function(BuildContext) then) {
    final nav = Navigator.of(context);
    nav.pop();
    then(nav.context);
  }

  void _closeAnd(VoidCallback then) {
    Navigator.of(context).pop();
    then();
  }

  // ───────────── الإجراءات ─────────────

  Future<void> _toggleDns() async {
    final want = !(_dnsPending ?? _b('privateDns'));
    setState(() => _dnsPending = want);
    final ok = await NativeBridge.setPrivateDns(want);
    if (!mounted) return;
    if (!ok) {
      setState(() => _dnsPending = null);
      toast(context, 'حجب الإعلانات يحتاج تشغيل install.bat مرة وحدة');
      return;
    }
    await _refresh();
    if (mounted) setState(() => _dnsPending = null);
    if (mounted) toast(context, want ? 'تم تفعيل حجب الإعلانات (AdGuard DNS)' : 'تم إيقاف حجب الإعلانات');
  }

  bool get _dnsOn => _dnsPending ?? _b('privateDns');

  void _toggleDnd() {
    final on = !s.cfg.b('misc.dnd');
    s.set('misc.dnd', on);
    toast(context, on ? 'عدم الإزعاج: شاشة السكون التلقائية متوقفة' : 'تم إيقاف عدم الإزعاج');
  }

  void _cycleMode() {
    const order = ['auto', 'day', 'night'];
    final i = order.indexOf(s.cfg.s('theme.mode'));
    s.set('theme.mode', order[(i + 1) % order.length]);
  }

  Future<void> _clean() async {
    if (_cleaning) return;
    setState(() => _cleaning = true);
    final freed = await NativeBridge.cleanMemory();
    await _refresh();
    if (!mounted) return;
    setState(() => _cleaning = false);
    toast(context, freed > 0 ? 'تم تحرير ${_gb(freed)} من الذاكرة' : 'الذاكرة نظيفة أصلاً');
  }

  Future<void> _screenOff() async {
    Navigator.of(context).pop();
    final ok = await NativeBridge.sleepNow();
    if (!ok) s.sleepFallback.value++;
  }

  void _volumeBy(int d) {
    final max = _i('volumeMax');
    if (max <= 0) return;
    final v = (_i('volume') + d).clamp(0, max);
    setState(() => _st = {..._st, 'volume': v});
    NativeBridge.setVolume(v);
  }

  // ───────────── البطاقات ─────────────

  List<_Tile> _tiles() {
    final net = _str('net');
    final left = s.sleepLeft;
    final mode = s.cfg.s('theme.mode');
    return [
      _Tile(
        id: 'net',
        icon: net == 'ethernet' ? Lu.network : (net == 'none' || net.isEmpty ? Lu.wifiOff : Lu.wifi),
        title: 'الشبكة',
        sub: switch (net) { 'wifi' => 'واي فاي متصل', 'ethernet' => 'كيبل متصل', 'none' => 'غير متصل', '' => '…', _ => 'متصل' },
        active: net != 'none' && net.isNotEmpty,
        onTap: () => _open(_Page.net, 'tile:net'),
        onLong: () => _open(_Page.net, 'tile:net'),
      ),
      _Tile(
        id: 'bt',
        icon: Lu.bluetooth,
        title: 'البلوتوث',
        sub: _b('bt') ? 'مفعّل' : 'مطفأ',
        active: _b('bt'),
        onTap: () => _closeAnd(NativeBridge.bluetoothSettings),
        onLong: () => _closeAnd(NativeBridge.bluetoothSettings),
      ),
      _Tile(
        id: 'ads',
        icon: Lu.eyeOff,
        title: 'حجب الإعلانات',
        sub: _dnsOn ? 'مفعّل · AdGuard' : 'مطفأ',
        active: _dnsOn,
        onTap: _toggleDns,
        onLong: () => _open(_Page.net, 'tile:ads'),
      ),
      _Tile(
        id: 'dnd',
        icon: Lu.bell,
        title: 'عدم الإزعاج',
        sub: s.cfg.b('misc.dnd') ? 'السكون التلقائي متوقف' : 'مطفأ',
        active: s.cfg.b('misc.dnd'),
        onTap: _toggleDnd,
        onLong: _toggleDnd,
      ),
      _Tile(
        id: 'mode',
        icon: mode == 'day' ? Lu.sun : (mode == 'night' ? Lu.moon : Lu.sunMoon),
        title: 'الوضع',
        sub: switch (mode) { 'day' => 'نهاري دائماً', 'night' => 'ليلي دائماً', _ => 'تلقائي' },
        active: mode != 'auto',
        onTap: _cycleMode,
        onLong: () => _open(_Page.mode, 'tile:mode'),
      ),
      _Tile(
        id: 'sleep',
        icon: Lu.timer,
        title: 'مؤقت الإطفاء',
        sub: left == null ? 'متوقف' : 'بعد ${Ar.n((left.inSeconds / 60).ceil())} د',
        active: left != null,
        onTap: () => _open(_Page.sleep, 'tile:sleep'),
        onLong: () => _open(_Page.sleep, 'tile:sleep'),
      ),
      _Tile(
        id: 'saver',
        icon: Lu.monitorPlay,
        title: 'شاشة السكون',
        sub: 'تشغيل الآن',
        onTap: () => _closeAnd(() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScreensaverScreen()))),
        onLong: () => _closeAnd(() => Navigator.of(context).push(fade(const SaverGalleryScreen()))),
      ),
      _Tile(
        id: 'mem',
        icon: Lu.memory,
        title: 'تنظيف الذاكرة',
        sub: _cleaning ? 'جاري التنظيف…' : 'متاح ${_gb(_i('ramFree'))}',
        active: _cleaning,
        onTap: _clean,
        onLong: () => _open(_Page.mem, 'tile:mem'),
      ),
    ];
  }

  /// صفوف التنقل بالصفحة الرئيسية (العمود الأول يمين لأن الاتجاه عربي).
  List<List<String>> get _rows => const [
        ['gear'],
        ['device'],
        ['tile:net', 'tile:bt'],
        ['tile:ads', 'tile:dnd'],
        ['tile:mode', 'tile:sleep'],
        ['tile:saver', 'tile:mem'],
        ['volume'],
        ['off', 'all'],
      ];

  KeyEventResult _nav(KeyEvent e, String id) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final dir = arrowDirection(e.logicalKey);
    if (dir == null) return KeyEventResult.ignored;
    if (repeatTooFast(e)) return KeyEventResult.handled;
    final rows = _rows;
    final r = rows.indexWhere((row) => row.contains(id));
    if (r < 0) return KeyEventResult.ignored;
    final c = rows[r].indexOf(id);
    String? target;
    switch (dir) {
      case TraversalDirection.up:
        if (r > 0) target = rows[r - 1][c.clamp(0, rows[r - 1].length - 1)];
      case TraversalDirection.down:
        if (r < rows.length - 1) target = rows[r + 1][c.clamp(0, rows[r + 1].length - 1)];
      case TraversalDirection.left: // العمود التالي (يسار)
        if (c + 1 < rows[r].length) target = rows[r][c + 1];
      case TraversalDirection.right:
        if (c > 0) target = rows[r][c - 1];
    }
    if (target != null) _nodes.focus(target);
    return KeyEventResult.handled; // ما نطلع من اللوحة بالأسهم أبداً
  }

  KeyEventResult _volumeKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      if (repeatTooFast(e, ms: 90)) return KeyEventResult.handled;
      _volumeBy(k == LogicalKeyboardKey.arrowLeft ? 1 : -1); // يسار = أعلى (اتجاه عربي)
      return KeyEventResult.handled;
    }
    return _nav(e, 'volume');
  }

  // ───────────── البناء ─────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == _Page.main,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToMain();
      },
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = s.palette;
          // اللوحة بلون معاكس هادئ للثيم: سطح الثيم + حد ذهبي خفيف
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(_margin),
              child: Container(
                width: _panelW,
                height: double.infinity,
                padding: const EdgeInsets.all(_pad),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: p.line, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.45 : 0.18), blurRadius: 60, offset: const Offset(0, 24))],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: AnimatedSwitcher(
                    duration: s.anim(200),
                    child: KeyedSubtree(
                      key: ValueKey(_page),
                      child: switch (_page) {
                        _Page.main => _main(p),
                        _Page.net => _netPage(p),
                        _Page.sleep => _sleepPage(p),
                        _Page.mode => _modePage(p),
                        _Page.mem => _memPage(p),
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _main(Palette p) {
    final t = s.now;
    final w = s.weather;
    final tiles = _tiles();
    final net = _str('net');
    final ip = _str('ip');
    final status = [
      switch (net) { 'wifi' => 'واي فاي', 'ethernet' => 'كيبل', 'none' => 'بدون شبكة', '' => '…', _ => 'متصل' },
      if (ip.isNotEmpty) ip,
      if (w != null) '${Ar.n(w.temp)}° ${w.description}',
    ].join('  ·  ');
    final max = _i('volumeMax');
    final vol = _i('volume');
    final ratio = max > 0 ? vol / max : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // الرأس: الساعة يمين، زر كل الإعدادات يسار
      SizedBox(
        height: 104,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              FitText('${Ar.time(t)} ${Ar.period(t)}', style: Fonts.clock(60, p.ink)),
              FitText('${Ar.dayName(t)} ${Ar.gregorian(t)}  ·  ضغطة مطوّلة للتفاصيل', style: Fonts.body(19, p.muted)),
            ]),
          ),
          const SizedBox(width: 16),
          FocusTap(
            focusNode: _nodes.of('gear'),
            onKey: (e) => _nav(e, 'gear'),
            onTap: () => _toNav(openThemeSettings),
            builder: (context, f) => _RoundIcon(icon: Lu.settings, focused: f),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      // شريحة الحالة
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.line)),
        child: Row(children: [
          AppIcon(net == 'ethernet' ? Lu.network : Lu.wifi, color: p.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(child: FitText(status, style: Fonts.body(19, p.ink))),
        ]),
      ),
      const SizedBox(height: 16),
      // إعدادات الجهاز (نظام Google TV): ذهبية ومميزة عن إعدادات رونق
      FocusTap(
        focusNode: _nodes.of('device'),
        onKey: (e) => _nav(e, 'device'),
        onTap: () => _toNav(openDeviceSettings),
        builder: (context, f) => QuickDeviceBar(focused: f),
      ),
      const SizedBox(height: 16),
      // شبكة البطاقات ٢×٤
      LayoutBuilder(builder: (context, box) {
        final tw = (box.maxWidth - _gap) / 2;
        return Wrap(spacing: _gap, runSpacing: _gap, children: [
          for (final (i, tile) in tiles.indexed)
            FocusTap(
              key: ValueKey(tile.id),
              focusNode: _nodes.of('tile:${tile.id}'),
              autofocus: i == 0,
              onKey: (e) => _nav(e, 'tile:${tile.id}'),
              onTap: tile.onTap,
              onLongPress: tile.onLong,
              builder: (context, f) => _TileView(tile: tile, focused: f, width: tw),
            ),
        ]);
      }),
      const SizedBox(height: 22),
      // الصوت: ◀▶ تعديل، موافق كتم
      FocusTap(
        focusNode: _nodes.of('volume'),
        onKey: _volumeKey,
        onTap: () async {
          await NativeBridge.setMute(!_b('muted'));
          _refresh();
        },
        builder: (context, f) => _VolumeRow(ratio: ratio, muted: _b('muted') || vol == 0, focused: f, available: max > 0),
      ),
      const Spacer(),
      // التذييل
      SizedBox(
        height: 64,
        child: Row(children: [
          Expanded(
            child: FocusTap(
              focusNode: _nodes.of('off'),
              onKey: (e) => _nav(e, 'off'),
              onTap: _screenOff,
              builder: (context, f) => _FooterButton(icon: Lu.power, label: 'إطفاء الشاشة', focused: f),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: FocusTap(
              focusNode: _nodes.of('all'),
              onKey: (e) => _nav(e, 'all'),
              onTap: () => _toNav(openThemeSettings),
              builder: (context, f) => _FooterButton(icon: Lu.settings, label: 'إعدادات رونق', focused: f, primary: true),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      FitText('موافق: تفعيل  ·  مطوّلة: التفاصيل  ·  رجوع: إغلاق', alignment: Alignment.center, style: Fonts.body(16, p.muted)),
    ]);
  }

  // ───────────── صفحات التفاصيل ─────────────

  Widget _detail(Palette p, {required String title, required List<Widget> children}) {
    return NavZone(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 72,
          child: Row(children: [
            FocusTap(onTap: _backToMain, builder: (context, f) => _RoundIcon(icon: Lu.chevronRight, focused: f, size: 60)),
            const SizedBox(width: 18),
            Expanded(child: FitText(title, style: Fonts.title(36, p.ink))),
          ]),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.all(5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        const SizedBox(height: 12),
        FitText('رجوع: للوحة السريعة', alignment: Alignment.center, style: Fonts.body(16, p.muted)),
      ]),
    );
  }

  Widget _netPage(Palette p) {
    final net = _str('net');
    final connected = net != 'none' && net.isNotEmpty;
    return _detail(p, title: 'الشبكة', children: [
      Container(
        height: 112,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: connected ? p.accent : p.bg, borderRadius: BorderRadius.circular(28)),
        child: Row(children: [
          AppIcon(net == 'ethernet' ? Lu.network : (connected ? Lu.wifi : Lu.wifiOff), color: connected ? p.onAccent : p.muted, size: 40),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              FitText(s.model.isEmpty ? 'هذه الشاشة' : s.model, style: Fonts.body(26, connected ? p.onAccent : p.ink, weight: FontWeight.w600)),
              FitText(
                switch (net) { 'wifi' => 'متصل · واي فاي', 'ethernet' => 'متصل · كيبل', 'none' => 'غير متصل', _ => 'متصل' },
                style: Fonts.body(19, connected ? p.onAccent.withValues(alpha: 0.8) : p.muted),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      _InfoRow(label: 'عنوان الشاشة', value: _str('ip').isEmpty ? '—' : _str('ip')),
      _InfoRow(label: 'اسم الجهاز', value: s.model.isEmpty ? 'أندرويد' : s.model),
      _InfoRow(label: 'الإنترنت', value: connected ? 'متاح' : 'غير متاح'),
      const SizedBox(height: 6),
      FocusTap(
        autofocus: _returnTo == 'tile:ads',
        onTap: _toggleDns,
        builder: (context, f) => _ActionLine(icon: Lu.eyeOff, title: 'حجب الإعلانات · AdGuard DNS', focused: f, toggle: _dnsOn),
      ),
      FocusTap(
        autofocus: _returnTo != 'tile:ads',
        onTap: () => _closeAnd(NativeBridge.wifiSettings),
        builder: (context, f) => _ActionLine(icon: Lu.settings, title: 'إعدادات الشبكة بالنظام', focused: f),
      ),
    ]);
  }

  Widget _sleepPage(Palette p) {
    const opts = [(0, 'إيقاف'), (15, '١٥ دقيقة'), (30, '٣٠ دقيقة'), (60, 'ساعة'), (90, 'ساعة ونص'), (120, 'ساعتين'), (180, '٣ ساعات')];
    final current = s.sleepLeft == null ? 0 : s.sleepMinutes;
    return _detail(p, title: 'مؤقت الإطفاء', children: [
      for (final (m, label) in opts)
        FocusTap(
          autofocus: m == current,
          onTap: () {
            s.setSleepTimer(m);
            _backToMain();
          },
          builder: (context, f) => _ChoiceLine(label: label, selected: m == current, focused: f),
        ),
      if (!_b('canSleep'))
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: FitText('للإطفاء الحقيقي شغّل install.bat مرة وحدة', style: Fonts.body(17, p.muted)),
        ),
    ]);
  }

  Widget _modePage(Palette p) {
    final mode = s.cfg.s('theme.mode');
    final style = s.cfg.s('ui.style');
    return _detail(p, title: 'الوضع والنمط', children: [
      for (final (id, label) in const [('auto', 'تلقائي حسب الوقت'), ('day', 'نهاري دائماً'), ('night', 'ليلي دائماً')])
        FocusTap(
          autofocus: id == mode,
          onTap: () => s.set('theme.mode', id),
          builder: (context, f) => _ChoiceLine(label: label, selected: id == mode, focused: f),
        ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, bottom: 10),
        child: FitText('نمط الواجهة', style: Fonts.body(19, p.muted)),
      ),
      for (final id in AppState.styles)
        FocusTap(
          onTap: () => s.setStyle(id),
          builder: (context, f) => _ChoiceLine(label: AppState.styleName(id), selected: id == style, focused: f),
        ),
    ]);
  }

  Widget _memPage(Palette p) {
    final ramT = _i('ramTotal'), ramF = _i('ramFree'), stT = _i('storageTotal'), stF = _i('storageFree');
    return _detail(p, title: 'الذاكرة والتخزين', children: [
      _Meter(icon: Lu.memory, label: 'الذاكرة', value: 'متاح ${_gb(ramF)} من ${_gb(ramT)}', ratio: ramT > 0 ? 1 - ramF / ramT : 0),
      _Meter(icon: Lu.drive, label: 'التخزين', value: 'متاح ${_gb(stF)} من ${_gb(stT)}', ratio: stT > 0 ? 1 - stF / stT : 0),
      const SizedBox(height: 6),
      FocusTap(
        autofocus: true,
        onTap: _clean,
        builder: (context, f) => _ActionLine(icon: Lu.memory, title: _cleaning ? 'جاري التنظيف…' : 'تنظيف الذاكرة الآن', focused: f),
      ),
    ]);
  }
}

// ───────────── عناصر العرض ─────────────

class _Tile {
  final String id, title, sub;
  final Object icon;
  final bool active;
  final VoidCallback onTap, onLong;
  const _Tile({
    required this.id,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    required this.onLong,
    this.active = false,
  });
}

BoxDecoration _ring(bool f, double r) => BoxDecoration(
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: f ? pal.ring : Colors.transparent, width: ringW, strokeAlign: BorderSide.strokeAlignOutside),
    );

/// بطاقة: مفعّلة = تعبئة بلون الثيم وأيقونة ونص بلون معاكس، مركّز = إطار ذهبي برا البطاقة.
class _TileView extends StatelessWidget {
  final _Tile tile;
  final bool focused;
  final double width;
  const _TileView({required this.tile, required this.focused, required this.width});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final on = tile.active;
    final fg = on ? p.onAccent : p.ink;
    return AnimatedContainer(
      duration: AppState.I.anim(160),
      width: width,
      height: _tileH,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: on ? p.accent : p.bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: on ? p.accent : p.line, width: 1.5),
      ),
      foregroundDecoration: _ring(focused, 30),
      child: Row(children: [
        AnimatedContainer(
          duration: AppState.I.anim(160),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? p.onAccent.withValues(alpha: 0.18) : p.accent.withValues(alpha: p.night ? 0.2 : 0.11),
            shape: BoxShape.circle,
          ),
          child: AppIcon(tile.icon, color: on ? p.onAccent : p.accent, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            FitText(tile.title, style: Fonts.body(22, fg, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            FitText(tile.sub, style: Fonts.body(17, on ? p.onAccent.withValues(alpha: 0.82) : p.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final Object icon;
  final bool focused;
  final double size;
  const _RoundIcon({required this.icon, required this.focused, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return AnimatedContainer(
      duration: AppState.I.anim(140),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: focused ? p.accent : p.bg, shape: BoxShape.circle, border: Border.all(color: p.line)),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: focused ? p.ring : Colors.transparent, width: ringW, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: AppIcon(icon, color: focused ? p.onAccent : p.ink, size: size * 0.45),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final double ratio;
  final bool muted, focused, available;
  const _VolumeRow({required this.ratio, required this.muted, required this.focused, required this.available});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final r = ratio.clamp(0.0, 1.0);
    return AnimatedContainer(
      duration: AppState.I.anim(140),
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line, width: 1.5)),
      foregroundDecoration: _ring(focused, 30),
      child: Row(children: [
        AppIcon(muted ? Lu.volumeOff : Lu.volume, color: focused ? p.accent : p.ink, size: 30),
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            // المسار يمتلي من اليمين (اتجاه عربي)
            return SizedBox(
              height: 28,
              child: Stack(alignment: AlignmentDirectional.centerStart, children: [
                Container(height: 10, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(6))),
                AnimatedContainer(
                  duration: AppState.I.anim(120),
                  width: box.maxWidth * r,
                  height: 10,
                  decoration: BoxDecoration(color: muted ? p.muted : p.accent, borderRadius: BorderRadius.circular(6)),
                ),
                PositionedDirectional(
                  start: (box.maxWidth - 28) * r,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: focused ? p.ring : p.surface, shape: BoxShape.circle, border: Border.all(color: muted ? p.muted : p.accent, width: 3)),
                  ),
                ),
              ]),
            );
          }),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 86,
          child: FitText(
            !available ? '—' : (muted ? 'مكتوم' : '${Ar.n((r * 100).round())}٪'),
            alignment: AlignmentDirectional.centerEnd,
            style: Fonts.body(22, p.ink, weight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final Object icon;
  final String label;
  final bool focused, primary;
  const _FooterButton({required this.icon, required this.label, required this.focused, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final fill = primary ? p.accent : p.bg;
    final fg = primary ? p.onAccent : p.ink;
    return AnimatedContainer(
      duration: AppState.I.anim(140),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999), border: Border.all(color: primary ? p.accent : p.line, width: 1.5)),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? p.ring : Colors.transparent, width: ringW, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        AppIcon(icon, color: fg, size: 24),
        const SizedBox(width: 10),
        Flexible(child: FitText(label, style: Fonts.body(21, fg, weight: FontWeight.w600))),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
      child: Row(children: [
        Expanded(child: FitText(label, style: Fonts.body(20, p.muted))),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: FitText(value, style: Fonts.body(21, p.ink, weight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _ActionLine extends StatelessWidget {
  final Object icon;
  final String title;
  final bool focused;
  final bool? toggle;
  const _ActionLine({required this.icon, required this.title, required this.focused, this.toggle});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final on = toggle ?? false;
    return AnimatedContainer(
      duration: AppState.I.anim(140),
      height: 72,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line, width: 1.5)),
      foregroundDecoration: _ring(focused, 24),
      child: Row(children: [
        AppIcon(icon, color: on ? p.accent : p.ink, size: 26),
        const SizedBox(width: 14),
        Expanded(child: FitText(title, style: Fonts.body(21, p.ink, weight: FontWeight.w500))),
        const SizedBox(width: 12),
        if (toggle != null)
          AnimatedContainer(
            duration: AppState.I.anim(160),
            width: 64,
            height: 36,
            padding: const EdgeInsets.all(4),
            alignment: on ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            decoration: BoxDecoration(color: on ? p.accent : p.line, borderRadius: BorderRadius.circular(999)),
            child: Container(width: 28, height: 28, decoration: BoxDecoration(color: on ? p.onAccent : p.surface, shape: BoxShape.circle)),
          )
        else
          AppIcon(Lu.chevronLeft, color: focused ? p.accent : p.muted, size: 24),
      ]),
    );
  }
}

class _ChoiceLine extends StatelessWidget {
  final String label;
  final bool selected, focused;
  const _ChoiceLine({required this.label, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return AnimatedContainer(
      duration: AppState.I.anim(140),
      height: 66,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: selected ? p.accent.withValues(alpha: p.night ? 0.2 : 0.11) : p.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? p.accent : p.line, width: 1.5),
      ),
      foregroundDecoration: _ring(focused, 22),
      child: Row(children: [
        Expanded(child: FitText(label, style: Fonts.body(22, p.ink, weight: selected ? FontWeight.w600 : FontWeight.w400))),
        const SizedBox(width: 12),
        if (selected) AppIcon(Lu.circleCheck, color: p.accent, size: 26),
      ]),
    );
  }
}

class _Meter extends StatelessWidget {
  final Object icon;
  final String label, value;
  final double ratio;
  const _Meter({required this.icon, required this.label, required this.value, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final r = ratio.clamp(0.0, 1.0);
    final warn = r > 0.9;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AppIcon(icon, color: p.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(child: FitText(label, style: Fonts.body(21, p.ink, weight: FontWeight.w600))),
          const SizedBox(width: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: FitText(value, style: Fonts.body(18, p.muted))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: r,
            minHeight: 10,
            backgroundColor: p.line,
            valueColor: AlwaysStoppedAnimation(warn ? const Color(0xFFD9534F) : p.accent),
          ),
        ),
      ]),
    );
  }
}
