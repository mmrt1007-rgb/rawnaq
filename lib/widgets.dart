import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arabic.dart';
import 'backgrounds.dart';
import 'fonts.dart';
import 'liquid_glass.dart';
import 'palette.dart';
import 'screens/color_editor.dart';
import 'screens/font_picker.dart';
import 'state.dart';
import 'lucide.dart';
import 'royal.dart';
import 'screens/family_screens.dart' show showPinPad;

export 'fonts.dart' show Fonts, FontCatalog;
export 'royal.dart';

Palette get pal => AppState.I.palette;

/// سُمك إطار التركيز (يتضاعف تقريباً مع خيار "إطار تركيز سميك" بإمكانية الوصول).
double get ringW => AppState.I.cfg.b('a11y.thickRing') ? 6.5 : 4;

bool isSelectKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.select ||
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.numpadEnter ||
    k == LogicalKeyboardKey.gameButtonA;

bool isBackKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.browserBack;

/// حارس الضغطات المتبقية: بعد إغلاق شاشة (مثل شاشة السكون) بضغطة، رفع نفس الزر
/// (أو تكراره) ما يوصل للشاشة اللي تحتها. هيچ زر الرجوع ما يفتح شي ثاني،
/// والتطبيق ما ينفتح إلا بضغطة موافق كاملة عليه هو نفسه.
class KeyGuard {
  static DateTime _until = DateTime(0);
  static final Set<PhysicalKeyboardKey> _held = {};

  static bool get active => DateTime.now().isBefore(_until);

  /// يبلع رفع/تكرار كل الأزرار المضغوطة حالياً، ولمدة قصيرة.
  static void swallow([int ms = 800]) {
    _until = DateTime.now().add(Duration(milliseconds: ms));
    _held
      ..clear()
      ..addAll(HardwareKeyboard.instance.physicalKeysPressed);
  }

  /// معالج على مستوى لوحة المفاتيح: يعلّم الرفع المتبقي «مستلم» حتى أندرويد ما ينفذ رجوع ثاني.
  static bool handler(KeyEvent e) {
    if (e is KeyDownEvent) {
      _held.remove(e.physicalKey);
      return false;
    }
    if (_held.contains(e.physicalKey) || (active && e is KeyRepeatEvent)) {
      // نشيله بعد ما توصل الضغطة للعناصر (حتى هي هم تعرف إنها بقايا)
      if (e is KeyUpEvent) {
        final k = e.physicalKey;
        scheduleMicrotask(() => _held.remove(k));
      }
      return true;
    }
    return false;
  }

  /// الزر هذا بقايا ضغطة قديمة؟
  static bool stale(KeyEvent e) => e is! KeyDownEvent && _held.contains(e.physicalKey);
}

DateTime _lastMove = DateTime.fromMillisecondsSinceEpoch(0);

/// الضغط المستمر على سهم: الريموت يرسل تكرار سريع جداً يخلي التركيز يقفز عناصر.
/// هذا يمرر حركة وحدة كل فترة (من إعدادات الريموت) ويبلع الباقي، فالحركة تبقى ثابتة ومقروءة.
/// يرجع true إذا لازم نتجاهل هذا التكرار.
bool repeatTooFast(KeyEvent e, {int? ms}) {
  final now = DateTime.now();
  if (e is! KeyRepeatEvent) {
    _lastMove = now;
    _holdStart = now;
    return false;
  }
  if (now.difference(_lastMove).inMilliseconds < (ms ?? AppState.I.cfg.i('remote.repeat'))) return true;
  _lastMove = now;
  return false;
}

DateTime _holdStart = DateTime.fromMillisecondsSinceEpoch(0);

/// مدة الضغط المستمر الحالي (لتسريع تعديل القيم كل ما طال الضغط).
Duration get holdDuration => DateTime.now().difference(_holdStart);

TraversalDirection? arrowDirection(LogicalKeyboardKey k) => switch (k) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };

/// منطقة تنقل موحّدة (الإعدادات وكل اللوحات والقوائم):
/// ▲▼ فقط تتنقل بين الصفوف داخل المنطقة، وبالحافة يبقى التركيز مكانه.
/// ◀▶ ما تنقل التركيز أبداً: هي لتعديل القيمة بالصف المحدد (شريط سحب، صف اختيار)،
/// والصف نفسه يستقبلها قبل المنطقة. الدخول بموافق، والخروج برجوع فقط.
class NavZone extends StatelessWidget {
  final FocusScopeNode? node;
  final void Function(TraversalDirection dir)? onEdge;
  final Widget child;
  const NavZone({super.key, this.node, this.onEdge, required this.child});

  @override
  Widget build(BuildContext context) => FocusScope(
        node: node,
        onKeyEvent: (scope, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
          final dir = arrowDirection(e.logicalKey);
          if (dir == null) return KeyEventResult.ignored;
          if (repeatTooFast(e)) return KeyEventResult.handled;
          final f = FocusManager.instance.primaryFocus;
          if (f == null) return KeyEventResult.handled;
          final side = dir == TraversalDirection.left || dir == TraversalDirection.right;
          if (side && onEdge != null) {
            onEdge!(dir);
            return KeyEventResult.handled;
          }
          if (f.focusInDirection(dir)) return KeyEventResult.handled;
          if (onEdge != null) {
            onEdge!(dir);
          } else {
            // ما بيه شي بهالاتجاه داخل المنطقة: نطلع منها للي يمها (أزرار التالي والتخطي تحت،
            // اللوحة اللي بجنبها...). قبل جانت المنطقة تحبس التركيز فالريموت يعلگ.
            leaveZone(scope, dir);
          }
          return KeyEventResult.handled;
        },
        child: child,
      );

  /// ينقل التركيز لأقرب عنصر برة [scope] بالاتجاه [dir] (بالمكان على الشاشة).
  static bool leaveZone(FocusNode scope, TraversalDirection dir) {
    final from = FocusManager.instance.primaryFocus?.rect ?? scope.rect;
    final pool = RemoteNav.candidates().where((n) => n != scope && !n.ancestors.contains(scope));
    final best = RemoteNav.nearest(pool, from, dir);
    best?.requestFocus();
    return best != null;
  }
}

// =====================================================================
//  التنقل بالريموت على مستوى التطبيق كله
// =====================================================================

/// يتتبع الشاشة (أو النافذة) اللي فوق، حتى التنقل يدور بس بعناصرها.
class _TopRouteObserver extends NavigatorObserver {
  Route<dynamic>? top;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => top = route;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => top = previousRoute;
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == top) top = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == top) top = newRoute;
  }
}

/// التنقل بالأسهم لكل التطبيق: أي سهم ما استلمه عنصر أو منطقة يوصل هنا.
/// ١) نجرب تنقل فلاتر الاعتيادي (يحترم المجموعات والقوائم).
/// ٢) إذا ما لگى شي: أقرب عنصر بالاتجاه على الشاشة نفسها (هندسياً)، بكل الشاشة الحالية.
/// ٣) إذا التركيز ضايع (بعد إغلاق نافذة أو شاشة): يرجع لأول عنصر بالشاشة.
/// النتيجة: الريموت ما يعلگ بأي مكان، والحركة تروح للي تتوقعه العين.
class RemoteNav extends StatelessWidget {
  final Widget child;
  const RemoteNav({super.key, required this.child});

  static final observer = _TopRouteObserver();

  /// كل العناصر القابلة للتركيز بالشاشة اللي فوق.
  static List<FocusNode> candidates() {
    final top = observer.top;
    bool inTop(BuildContext ctx) {
      final r = ModalRoute.of(ctx);
      if (r == null) return true;
      return top != null && top.isActive ? r == top : r.isCurrent;
    }

    return [
      for (final n in FocusManager.instance.rootScope.traversalDescendants)
        if (n is! FocusScopeNode && n.canRequestFocus && !n.skipTraversal && n.context != null && n.context!.mounted && !n.rect.isEmpty && inTop(n.context!)) n,
    ];
  }

  /// أقرب عنصر بالاتجاه: المسافة على المحور + عقوبة إذا ما بنفس الصف/العمود.
  static FocusNode? nearest(Iterable<FocusNode> pool, Rect from, TraversalDirection dir) {
    FocusNode? best;
    var bestD = double.infinity;
    double gap(double a1, double a2, double b1, double b2) => b2 < a1 ? a1 - b2 : (b1 > a2 ? b1 - a2 : 0);
    for (final n in pool) {
      if (n.hasPrimaryFocus) continue;
      final r = n.rect;
      double along = 0, ortho = 0, centre = 0;
      switch (dir) {
        case TraversalDirection.down:
          if (r.center.dy <= from.center.dy + 2 || r.bottom <= from.bottom - 2) continue;
          along = math.max(0.0, r.top - from.bottom);
          ortho = gap(from.left, from.right, r.left, r.right);
          centre = (r.center.dx - from.center.dx).abs();
        case TraversalDirection.up:
          if (r.center.dy >= from.center.dy - 2 || r.top >= from.top + 2) continue;
          along = math.max(0.0, from.top - r.bottom);
          ortho = gap(from.left, from.right, r.left, r.right);
          centre = (r.center.dx - from.center.dx).abs();
        case TraversalDirection.left:
          if (r.center.dx >= from.center.dx - 2 || r.left >= from.left + 2) continue;
          along = math.max(0.0, from.left - r.right);
          ortho = gap(from.top, from.bottom, r.top, r.bottom);
          centre = (r.center.dy - from.center.dy).abs();
        case TraversalDirection.right:
          if (r.center.dx <= from.center.dx + 2 || r.right <= from.right - 2) continue;
          along = math.max(0.0, r.left - from.right);
          ortho = gap(from.top, from.bottom, r.top, r.bottom);
          centre = (r.center.dy - from.center.dy).abs();
      }
      final d = along + ortho * 2.5 + centre * 0.15;
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    return best;
  }

  /// أول عنصر بالشاشة (أعلى، ثم الأقرب لليمين لأن الواجهة عربية).
  static FocusNode? first(List<FocusNode> pool) {
    if (pool.isEmpty) return null;
    final sorted = [...pool]..sort((a, b) {
        final dy = a.rect.top.compareTo(b.rect.top);
        if ((a.rect.top - b.rect.top).abs() > 12) return dy;
        return b.rect.right.compareTo(a.rect.right);
      });
    return sorted.first;
  }

  static bool move(TraversalDirection dir) {
    final pool = candidates();
    final f = FocusManager.instance.primaryFocus;
    if (f == null || f is FocusScopeNode || !pool.contains(f)) {
      final n = first(pool);
      n?.requestFocus();
      return n != null;
    }
    if (f.focusInDirection(dir) && FocusManager.instance.primaryFocus != f) return true;
    final n = nearest(pool, f.rect, dir);
    n?.requestFocus();
    return n != null;
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
          final dir = arrowDirection(e.logicalKey);
          if (dir == null) return KeyEventResult.ignored;
          // داخل حقل كتابة: الأسهم للمؤشر (الحقل نفسه يطلّع للأعلى والأسفل)
          final ctx = FocusManager.instance.primaryFocus?.context;
          if (ctx != null && ctx.mounted && (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null)) {
            return KeyEventResult.ignored;
          }
          if (repeatTooFast(e)) return KeyEventResult.handled;
          move(dir);
          return KeyEventResult.handled;
        },
        child: child,
      );
}

// =====================================================================
//  عنصر قابل للتركيز بالريموت
// =====================================================================

/// ضغطة = تنفيذ، ضغطة طويلة أو زر القائمة = خيارات.
class FocusTap extends StatefulWidget {
  final Widget Function(BuildContext context, bool focused) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final KeyEventResult Function(KeyEvent e)? onKey;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocus;
  final bool ensureVisible;

  const FocusTap({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.onKey,
    this.autofocus = false,
    this.focusNode,
    this.onFocus,
    this.ensureVisible = true,
  });

  @override
  State<FocusTap> createState() => _FocusTapState();
}

class _FocusTapState extends State<FocusTap> {
  bool _focused = false;
  DateTime? _down;
  bool _longFired = false;

  KeyEventResult _handle(FocusNode node, KeyEvent e) {
    // رفع زر بدأ بشاشة ثانية (مثلاً أغلق شاشة السكون) ما يفتح هذا العنصر
    if (KeyGuard.stale(e)) {
      _down = null;
      return KeyEventResult.handled;
    }
    final extra = widget.onKey?.call(e);
    if (extra == KeyEventResult.handled) return KeyEventResult.handled;

    if (isSelectKey(e.logicalKey)) {
      if (e is KeyDownEvent) {
        _down = DateTime.now();
        _longFired = false;
      } else if (e is KeyRepeatEvent) {
        if (!_longFired &&
            widget.onLongPress != null &&
            _down != null &&
            DateTime.now().difference(_down!) > Duration(milliseconds: AppState.I.cfg.i('remote.longPress'))) {
          _longFired = true;
          widget.onLongPress!();
        }
      } else if (e is KeyUpEvent) {
        if (_down != null && !_longFired) widget.onTap?.call();
        _down = null;
      }
      return KeyEventResult.handled;
    }
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.contextMenu && widget.onLongPress != null) {
      widget.onLongPress!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handle,
      onFocusChange: (f) {
        if (!mounted) return;
        setState(() => _focused = f);
        widget.onFocus?.call(f);
        if (f && widget.ensureVisible) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: AppState.I.anim(240),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.builder(context, _focused),
      ),
    );
  }
}

/// نص بسطر واحد يصغر تلقائياً بدل ما ينقص أو يطلع برا مكانه.
class FitText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final AlignmentGeometry alignment;
  const FitText(this.text, {super.key, required this.style, this.alignment = AlignmentDirectional.centerStart});

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      );
}

// =====================================================================
//  أزرار وصفوف الإعدادات
// =====================================================================

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final bool autofocus;
  final Object? icon;

  const PillButton(this.label,
      {super.key, required this.onTap, this.primary = false, this.danger = false, this.autofocus = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return FocusTap(
      autofocus: autofocus,
      onTap: onTap,
      builder: (context, f) {
        // زر الحذف: أحمر هادئ واضح بالنهار والليل (نفس ألوان فيكما)
        final bg = primary ? p.accent : (danger ? (p.night ? const Color(0xFF2A1412) : const Color(0xFFFBF1EF)) : p.surface);
        final fg = primary ? p.onAccent : (danger ? (p.night ? const Color(0xFFF0A49A) : const Color(0xFF8E3329)) : p.ink);
        final edge = danger ? (p.night ? const Color(0xFF6B2E27) : const Color(0xFFE3B9B2)) : p.line;
        return RoyalFrame(
          focused: f,
          marker: false,
          scale: 1.03,
          child: AnimatedContainer(
          duration: AppState.I.anim(180),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: f ? p.ring : edge, width: f ? ringW * 0.62 : 1),
            boxShadow: royalShadows(p, f),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[AppIcon(icon!, color: fg, size: 26), const SizedBox(width: 10)],
            Text(label, maxLines: 1, softWrap: false, style: Fonts.body(22, fg, weight: primary || f ? FontWeight.w600 : null)),
          ])),
        ));
      },
    );
  }
}

/// الخيار المحدد الآن بشاشة الإعدادات (العنوان والوصف) — تقرأه المعاينة الحيّة.
final ValueNotifier<(String, String?)?> focusedOption = ValueNotifier(null);

/// مفتاح الإعداد المحدد الآن (مثل day.accent أو font.clock) — المعاينة تبرز الجزء اللي يتأثر بيه.
final ValueNotifier<String?> focusedKey = ValueNotifier(null);

/// يربط صف إعداد بمفتاحه حتى تعرف المعاينة شنو المحدد بالضبط.
class OptKey extends InheritedWidget {
  final String cfgKey;
  const OptKey({super.key, required this.cfgKey, required super.child});
  static String? of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<OptKey>()?.cfgKey;
  @override
  bool updateShouldNotify(OptKey old) => old.cfgKey != cfgKey;
}

void announceOption(String title, String? sub) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final v = focusedOption.value;
    if (v == null || v.$1 != title || v.$2 != sub) focusedOption.value = (title, sub);
  });
}

/// زخرفة سطح: بالنمط "الناعم العصري" حواف متصلة (squircle) وظل هادئ، وبالباقي حواف دائرية عادية.
/// معامل الاستدارة العام (الإعدادات ← المظهر ← استدارة الزوايا).
double get radiusK => switch (AppState.I.cfg.s('ui.radius')) { 'sharp' => 0.4, 'round' => 1.45, _ => 1.0 };

Decoration surfaceDecoration({required Color color, required double radius, Color? border, double borderWidth = 1, bool shadow = false, List<BoxShadow>? shadows}) {
  final p = pal;
  radius = radius * radiusK;
  if (p.smooth) {
    return ShapeDecoration(
      color: color,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(radius * 2.3),
        side: border == null ? BorderSide.none : BorderSide(color: border, width: borderWidth),
      ),
      shadows: shadows ??
          [
            BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.28 : 0.07), blurRadius: 30, offset: const Offset(0, 12)),
          ],
    );
  }
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: border == null ? null : Border.all(color: border, width: borderWidth),
    boxShadow: shadows ?? (shadow ? [BoxShadow(color: Colors.black.withValues(alpha: p.night ? 0.35 : 0.12), blurRadius: 30, offset: const Offset(0, 12))] : null),
  );
}

/// الهيكل المشترك لصف إعداد.
class RowShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool focused;
  const RowShell({super.key, required this.title, this.subtitle, required this.trailing, required this.focused});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    if (focused) {
      announceOption(title, subtitle);
      final k = OptKey.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) => focusedKey.value = k);
    }
    // فيكما صفحة ١٧: سطح ٢٢، المحدد بحد ذهبي وتوهج وعلامة جانبية، والنصوص سطر واحد يصغر ولا ينزل
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RoyalFrame(
        focused: focused,
        child: AnimatedContainer(
          duration: AppState.I.anim(180),
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: surfaceDecoration(
            color: royalFill(p, p.surface, focused),
            radius: 22,
            border: focused ? p.ring : p.line,
            borderWidth: focused ? ringW * 0.62 : 1,
            shadows: royalShadows(p, focused),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                FitText(title, style: Fonts.body(24, p.ink, weight: focused ? FontWeight.w600 : null)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  FitText(subtitle!, style: Fonts.body(18, p.muted)),
                ],
              ]),
            ),
            const SizedBox(width: 20),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: trailing),
          ]),
        ),
      ),
    );
  }
}

Widget _valueText(String v, bool f) => Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: FitText(v, style: Fonts.body(24, f ? pal.accent : pal.muted, weight: FontWeight.w600))),
      const SizedBox(width: 8),
      AppIcon(Lu.chevronLeft, color: f ? pal.accent : pal.muted, size: 30),
    ]);

/// اختيار من قائمة. موافق يفتح قائمة الخيارات وتبقى مفتوحة؛ تختار براحتك
/// (كل اختيار يتطبق فوراً)، وزر الرجوع فقط يسكّرها.
class ChoiceRow<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool autofocus;

  ChoiceRow({
    Key? key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.autofocus = false,
  }) : super(key: key ?? ValueKey('choice:$title'));

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2;
    return FocusTap(
      autofocus: autofocus,
      onTap: () => showChoicePicker<T>(context, title: title, options: options, value: value, onChanged: onChanged),
      builder: (context, f) => RowShell(title: title, subtitle: subtitle, focused: f, trailing: _valueText(current, f)),
    );
  }
}

Future<void> showChoicePicker<T>(BuildContext context,
    {required String title, required List<(T, String)> options, required T value, required ValueChanged<T> onChanged}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _ChoicePicker<T>(title: title, options: options, value: value, onChanged: onChanged),
    ),
  );
}

class _ChoicePicker<T> extends StatefulWidget {
  final String title;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const _ChoicePicker({super.key, required this.title, required this.options, required this.value, required this.onChanged});

  @override
  State<_ChoicePicker<T>> createState() => _ChoicePickerState<T>();
}

class _ChoicePickerState<T> extends State<_ChoicePicker<T>> {
  late T _value = widget.value;

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return themedDialog(
      width: 720,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 860),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: Fonts.title(30, p.ink)),
          const SizedBox(height: 6),
          Text('أعلى وأسفل للتنقل · موافق للاختيار · رجوع للإغلاق', style: Fonts.body(18, p.muted)),
          const SizedBox(height: 20),
          Flexible(
            child: NavZone(
              child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.all(4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final o in widget.options)
                  FocusTap(
                    key: ValueKey(o.$2),
                    autofocus: o.$1 == _value,
                    onTap: () {
                      setState(() => _value = o.$1);
                      widget.onChanged(o.$1);
                    },
                    builder: (context, f) {
                      final sel = o.$1 == _value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RoyalFrame(
                          focused: f,
                          child: AnimatedContainer(
                            duration: AppState.I.anim(180),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: royalFill(p, sel ? Color.lerp(p.glass ? p.surface : p.bg, p.accent, 0.14)! : (p.glass ? p.surface : p.bg), f),
                              borderRadius: BorderRadius.circular(18 * radiusK),
                              border: Border.all(color: f ? p.ring : (sel ? p.accent : p.line), width: f ? ringW * 0.62 : (sel ? 2 : 1)),
                              boxShadow: royalShadows(p, f),
                            ),
                            child: Row(children: [
                              Expanded(child: FitText(o.$2, style: Fonts.body(24, sel || f ? p.ink : p.muted, weight: sel || f ? FontWeight.w600 : null))),
                              if (sel) AppIcon(Lu.circleCheck, color: p.accent, size: 30),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
              ]),
            )),
            ),
          ),
        ]),
      ),
    );
  }
}

/// قيمة رقمية. موافق يفتح محرر القيمة؛ الأسهم تغيّر وتتطبق فوراً، ورجوع يسكّر.
class StepRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double value, min, max, step;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  StepRow({
    Key? key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onChanged,
    this.subtitle,
  }) : super(key: key ?? ValueKey('step:$title'));

  /// ◀ يزيد (اتجاه امتلاء الشريط بالعربي)، ▶ ينقص. الضغط المستمر يتسارع بعد ثانية.
  KeyEventResult _keys(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k != LogicalKeyboardKey.arrowLeft && k != LogicalKeyboardKey.arrowRight) return KeyEventResult.ignored;
    if (repeatTooFast(e, ms: 70)) return KeyEventResult.handled;
    final dir = k == LogicalKeyboardKey.arrowLeft ? 1 : -1;
    final fast = e is KeyRepeatEvent && holdDuration > const Duration(milliseconds: 1000);
    final steps = fast ? math.max(1, ((max - min) / step / 40).round()) : 1;
    var v = ((value + dir * steps * step) / step).round() * step; // بدون أخطاء تقريب
    v = double.parse(v.clamp(min, max).toStringAsFixed(4));
    if (v != value) onChanged(v);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final ratio = ((value - min) / (max - min)).clamp(0.0, 1.0);
    // شريط سحب: يتعدل باليمين واليسار مباشرة وهو محدد، وموافق ما يفتح شي.
    return FocusTap(
      onTap: () {},
      onKey: _keys,
      builder: (context, f) => RowShell(
        title: title,
        subtitle: subtitle,
        focused: f,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 200,
            height: 24,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Container(height: 8, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(8))),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedContainer(
                    duration: AppState.I.anim(90),
                    width: w * ratio,
                    height: 8,
                    decoration: BoxDecoration(color: f ? p.ring : p.accent, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (f)
                  PositionedDirectional(
                    start: (w * ratio - 12).clamp(0.0, w - 24),
                    child: Container(width: 24, height: 24, decoration: BoxDecoration(color: p.ring, shape: BoxShape.circle)),
                  ),
              ]);
            }),
          ),
          const SizedBox(width: 18),
          AnimatedOpacity(opacity: f ? 1 : 0, duration: AppState.I.anim(120), child: AppIcon(Lu.chevronRight, color: p.ring, size: 26)),
          const SizedBox(width: 6),
          Flexible(child: FitText(format(value), style: Fonts.body(24, f ? p.accent : p.muted, weight: FontWeight.w600))),
          const SizedBox(width: 6),
          AnimatedOpacity(opacity: f ? 1 : 0, duration: AppState.I.anim(120), child: AppIcon(Lu.chevronLeft, color: p.ring, size: 26)),
        ]),
      ),
    );
  }
}

/// صف اختيار أفقي (بطاقات الثيمات، الأنماط، الإعدادات الجاهزة، أزرار الإجراءات):
/// الصف كله عنصر واحد بالتنقل العمودي. ◀▶ تحدد البطاقة داخل الصف، وموافق يطبّقها.
/// إذا طلعت من الصف بدون موافق، يرجع التحديد للعنصر المطبّق.
class SelectorRow<T> extends StatefulWidget {
  final String? title;
  final List<T> values;
  final T? selected;
  final ValueChanged<T> onSelect;
  final Widget Function(BuildContext context, T value, bool highlighted, bool selected) itemBuilder;
  final bool autofocus;
  final double spacing;
  final bool framed;
  final FocusNode? focusNode;

  /// يُستدعى عند تحريك التحديد داخل الصف (قبل التطبيق)، وبـ null عند الخروج — للمعاينة الحيّة.
  final ValueChanged<T?>? onHighlight;

  const SelectorRow({
    super.key,
    this.title,
    required this.values,
    required this.selected,
    required this.onSelect,
    required this.itemBuilder,
    this.autofocus = false,
    this.spacing = 16,
    this.framed = true,
    this.focusNode,
    this.onHighlight,
  });

  @override
  State<SelectorRow<T>> createState() => _SelectorRowState<T>();
}

class _SelectorRowState<T> extends State<SelectorRow<T>> {
  late int _hi = _selectedIndex;
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};

  int get _selectedIndex {
    final i = widget.values.indexWhere((v) => v == widget.selected);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _show(int i) {
    final ctx = _keys[i]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: AppState.I.anim(200), curve: Curves.easeOutCubic);
  }

  KeyEventResult _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k != LogicalKeyboardKey.arrowLeft && k != LogicalKeyboardKey.arrowRight) return KeyEventResult.ignored;
    if (repeatTooFast(e)) return KeyEventResult.handled;
    final to = _hi + (k == LogicalKeyboardKey.arrowLeft ? 1 : -1); // بالعربي: اليسار = التالي
    if (to >= 0 && to < widget.values.length) {
      setState(() => _hi = to);
      _show(to);
      widget.onHighlight?.call(widget.values[to]);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return FocusTap(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKey: _onKey,
      onFocus: (f) {
        if (!f) setState(() => _hi = _selectedIndex);
        widget.onHighlight?.call(f && _hi < widget.values.length ? widget.values[_hi] : null);
        if (f && widget.title != null) announceOption(widget.title!, 'اليمين واليسار للمعاينة · موافق يطبّق');
        if (f) focusedKey.value = null;
      },
      onTap: () {
        if (_hi < widget.values.length) widget.onSelect(widget.values[_hi]);
      },
      builder: (context, f) {
        final items = AxisClip(axis: Axis.horizontal, child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.all(6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, v) in widget.values.indexed) ...[
              if (i > 0) SizedBox(width: widget.spacing),
              KeyedSubtree(
                key: _keys.putIfAbsent(i, () => GlobalKey()),
                child: widget.itemBuilder(context, v, f && i == _hi, i == _selectedIndex),
              ),
            ],
          ]),
        ));
        if (!widget.framed) return items;
        return AnimatedContainer(
          duration: AppState.I.anim(160),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: surfaceDecoration(color: p.surface, radius: 22, border: f ? p.ring : p.line, borderWidth: f ? ringW : 1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Expanded(child: FitText(widget.title!, style: Fonts.body(24, p.ink))),
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(f ? 'اليمين واليسار للاختيار · موافق يطبّق' : '', style: Fonts.body(17, p.muted, weight: FontWeight.w300)))),
                ]),
              ),
            items,
          ]),
        );
      },
    );
  }
}

/// شريط دليل الأزرار (نفس تصميم فيكما): تنقل · دخول · تعديل · خروج.
class KeyGuide extends StatelessWidget {
  const KeyGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    Widget key(List<Widget> k, String d) => FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.ring, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: k),
          ),
          const SizedBox(width: 10),
          Text(d, style: Fonts.body(19, p.muted)),
        ]));
    Widget icon(Lu i) => AppIcon(i, color: p.ink, size: 20);
    Widget label(String t) => Text(t, style: Fonts.body(17, p.ink, weight: FontWeight.w600));
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            key([icon(Lu.chevronUp), icon(Lu.chevronDown)], 'تنقل'),
            const SizedBox(width: 30),
            key([label('موافق')], 'دخول وتطبيق'),
            const SizedBox(width: 30),
            key([icon(Lu.chevronRight), icon(Lu.chevronLeft)], 'تعديل القيمة'),
            const SizedBox(width: 30),
            key([label('رجوع')], 'خروج خطوة'),
          ]),
        ),
      ),
    );
  }
}

/// زر بصف إجراءات.
class Act {
  final String label;
  final Object? icon;
  final VoidCallback onTap;
  final bool primary, danger;
  const Act(this.label, this.onTap, {this.icon, this.primary = false, this.danger = false});
}

/// صف أزرار إجراءات بنفس منطق صف الاختيار: ◀▶ تحدد الزر، موافق ينفّذه.
class ActionRow extends StatelessWidget {
  final List<Act> actions;
  final bool autofocus;
  const ActionRow(this.actions, {super.key, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return SelectorRow<int>(
      framed: false,
      autofocus: autofocus,
      spacing: 14,
      values: [for (var i = 0; i < actions.length; i++) i],
      selected: 0,
      onSelect: (i) => actions[i].onTap(),
      itemBuilder: (context, i, hi, _) {
        final a = actions[i];
        final bg = a.primary ? p.accent : (a.danger ? (p.night ? const Color(0xFF2A1412) : const Color(0xFFFBF1EF)) : p.surface);
        final fg = a.primary ? p.onAccent : (a.danger ? (p.night ? const Color(0xFFF0A49A) : const Color(0xFF8E3329)) : p.ink);
        return AnimatedContainer(
          duration: AppState.I.anim(140),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hi ? p.ring : p.line, width: hi ? ringW : 1),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (a.icon != null) ...[AppIcon(a.icon!, color: fg, size: 26), const SizedBox(width: 10)],
            Text(a.label, style: Fonts.body(22, fg, weight: a.primary ? FontWeight.w600 : null)),
          ])),
        );
      },
    );
  }
}

/// يفتح محرر قيمة رقمية (نفس محرر صفوف الإعدادات).
Future<void> showStepEditor(BuildContext context,
    {required String title,
    required double value,
    required double min,
    required double max,
    required double step,
    required String Function(double) format,
    required ValueChanged<double> onChanged}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _StepEditor(title: title, value: value, min: min, max: max, step: step, format: format, onChanged: onChanged),
    ),
  );
}

class _StepEditor extends StatefulWidget {
  final String title;
  final double value, min, max, step;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  const _StepEditor({required this.title, required this.value, required this.min, required this.max, required this.step, required this.format, required this.onChanged});

  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  late double _v = widget.value;

  void _by(int steps) {
    final st = widget.step;
    var v = ((_v + steps * st) / st).round() * st; // بدون أخطاء تقريب
    v = double.parse(v.clamp(widget.min, widget.max).toStringAsFixed(4));
    if (v == _v) return;
    setState(() => _v = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final ratio = ((_v - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, e) {
            if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
            final k = e.logicalKey;
            // من اليمين لليسار: يسار = زيادة. أعلى/أسفل = خطوات كبيرة
            if (k == LogicalKeyboardKey.arrowLeft) _by(1);
            if (k == LogicalKeyboardKey.arrowRight) _by(-1);
            if (k == LogicalKeyboardKey.arrowUp) _by(5);
            if (k == LogicalKeyboardKey.arrowDown) _by(-5);
            if (isBackKey(k)) return KeyEventResult.ignored; // يسكّرها النظام
            return KeyEventResult.handled;
          },
          child: themedDialog(
            width: 1100,
            inset: EdgeInsets.zero,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(widget.title, style: Fonts.title(30, p.ink))),
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(widget.format(_v), style: Fonts.title(40, p.accent)))),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                height: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(children: [
                    Container(color: p.line),
                    AnimatedFractionallySizedBox(
                      duration: AppState.I.anim(90),
                      widthFactor: ratio,
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(color: p.accent),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              Text('يمين ويسار للتغيير · رجوع للإغلاق', style: Fonts.body(20, p.muted), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }
}

/// تفعيل/إيقاف: موافق يبدّل مباشرة.
class ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  ToggleRow({Key? key, required this.title, required this.value, required this.onChanged, this.subtitle})
      : super(key: key ?? ValueKey('toggle:$title'));

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return FocusTap(
      onTap: () => onChanged(!value),
      builder: (context, f) => RowShell(
        title: title,
        subtitle: subtitle,
        focused: f,
        trailing: AnimatedContainer(
          duration: AppState.I.anim(180),
          width: 72,
          height: 40,
          padding: const EdgeInsets.all(4),
          alignment: value ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
          decoration: BoxDecoration(
            color: value ? p.accent : p.line,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedContainer(
            duration: AppState.I.anim(180),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: value ? p.onAccent : p.surface,
              shape: BoxShape.circle,
              border: f ? Border.all(color: p.ring, width: 2.5) : null,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }
}

class ColorRow extends StatelessWidget {
  final String title;
  final Color value;
  final ValueChanged<Color> onChanged;
  ColorRow({Key? key, required this.title, required this.value, required this.onChanged})
      : super(key: key ?? ValueKey('color:$title'));

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return FocusTap(
      onTap: () async {
        final c = await showColorEditor(context, title: title, initial: value);
        if (c != null) onChanged(c);
      },
      builder: (context, f) => RowShell(
        title: title,
        focused: f,
        trailing: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_hex(value), style: Fonts.body(20, p.muted)),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 44,
            decoration: BoxDecoration(
              color: value,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.line, width: 2),
            ),
          ),
        ])),
      ),
    );
  }

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class FontRow extends StatelessWidget {
  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  FontRow({Key? key, required this.title, required this.value, required this.onChanged})
      : super(key: key ?? ValueKey('font:$title'));

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return FocusTap(
      onTap: () async {
        final f = await showFontPicker(context, title: title, current: value);
        if (f != null) onChanged(f);
      },
      builder: (context, f) => RowShell(
        title: title,
        focused: f,
        trailing: FitText(
          FontCatalog.label(value),
          style: Fonts.family(value, 28, f ? p.accent : p.ink, weight: FontWeight.w600),
          alignment: AlignmentDirectional.centerEnd,
        ),
      ),
    );
  }
}

class NavRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;
  final bool autofocus;
  NavRow({Key? key, required this.title, required this.onTap, this.value = '', this.subtitle, this.autofocus = false})
      : super(key: key ?? ValueKey('nav:$title'));

  @override
  Widget build(BuildContext context) => FocusTap(
        autofocus: autofocus,
        onTap: onTap,
        builder: (context, f) => RowShell(
          title: title,
          subtitle: subtitle,
          focused: f,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: FitText(value, style: Fonts.body(22, f ? pal.accent : pal.muted, weight: FontWeight.w600))),
            const SizedBox(width: 8),
            AppIcon(Lu.chevronLeft, color: pal.muted, size: 30),
          ]),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  SectionTitle(this.text, {Key? key}) : super(key: key ?? ValueKey('sec:$text'));

  /// فيكما صفحة ١٧: معيّن ذهبي + العنوان + خط شعري يكمل للحافة.
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 30, bottom: 14, right: 6),
        child: Row(children: [
          const RoyalDiamond(size: 9),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: FitText(text, style: Fonts.body(22, pal.ink.withValues(alpha: 0.9), weight: FontWeight.w600)),
          ),
          const SizedBox(width: 18),
          Expanded(child: Container(height: 1, color: pal.line)),
        ]),
      );
}

// ---------- قص قوائم التمرير ----------
//  القوائم كانت بلا قص حتى ما ينقص توهج التركيز، فالعناصر اللي برة القائمة جانت تنرسم فوق
//  باقي الواجهة (بطاقات فوق القائمة الجانبية، صفوف فوق العناوين). هسه القص على اتجاه التمرير
//  بس، والاتجاه الثاني يبقى مفتوح حتى التوهج والتكبير يبينون كاملين.

class AxisClip extends StatelessWidget {
  final Axis axis;
  final double bleed;
  final Widget child;
  const AxisClip({super.key, required this.axis, required this.child, this.bleed = 80});

  @override
  Widget build(BuildContext context) => ClipRect(clipper: _AxisClipper(axis, bleed), child: child);
}

class _AxisClipper extends CustomClipper<Rect> {
  final Axis axis;
  final double bleed;
  _AxisClipper(this.axis, this.bleed);

  @override
  Rect getClip(Size s) => axis == Axis.horizontal ? Rect.fromLTRB(0, -bleed, s.width, s.height + bleed) : Rect.fromLTRB(-bleed, 0, s.width + bleed, s.height);

  @override
  bool shouldReclip(_AxisClipper o) => o.axis != axis || o.bleed != bleed;
}

// ---------- حقول النص بالريموت ----------
//  حقل النص يبلع الأسهم (يحرك المؤشر)، فبالريموت تعلگ داخله. هذي العقدة تشوف المفاتيح
//  قبل الحقل: أعلى/أسفل تطلع منه دائماً، ويسار/يمين تطلع إذا المؤشر بطرف النص.

FocusNode tvFieldNode(TextEditingController c) => FocusNode(onKeyEvent: (node, e) => tvFieldKeys(node, e, c));

KeyEventResult tvFieldKeys(FocusNode node, KeyEvent e, TextEditingController c) {
  if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
  final k = e.logicalKey;
  TraversalDirection? dir;
  if (k == LogicalKeyboardKey.arrowDown) {
    dir = TraversalDirection.down;
  } else if (k == LogicalKeyboardKey.arrowUp) {
    dir = TraversalDirection.up;
  } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
    final sel = c.selection;
    final len = c.text.length;
    final atEnd = !sel.isValid || (sel.isCollapsed && sel.baseOffset >= len);
    final atStart = !sel.isValid || (sel.isCollapsed && sel.baseOffset <= 0);
    // النص عربي (من اليمين): اليسار = نهاية النص، واليمين = بدايته
    if (k == LogicalKeyboardKey.arrowLeft && atEnd) dir = TraversalDirection.left;
    if (k == LogicalKeyboardKey.arrowRight && atStart) dir = TraversalDirection.right;
  }
  if (dir == null) return KeyEventResult.ignored;
  node.focusInDirection(dir);
  return KeyEventResult.handled;
}

// ---------- صفوف مربوطة مباشرة بمفاتيح الإعدادات ----------

AppState get _s => AppState.I;

Widget cChoice<T extends Object>(String title, String key, List<(T, String)> options, {String? sub}) =>
    OptKey(key: ValueKey('o:$key'), cfgKey: key, child: ChoiceRow<T>(key: ValueKey('c:$key'), title: title, subtitle: sub, value: _s.cfg.get<T>(key), options: options, onChanged: (v) => _s.set(key, v)));

Widget cStep(String title, String key, double min, double max, double step, String Function(double) fmt, {String? sub}) => OptKey(
    key: ValueKey('o:$key'),
    cfgKey: key,
    child: StepRow(
      key: ValueKey('c:$key'),
      title: title,
      subtitle: sub,
      value: _s.cfg.d(key),
      min: min,
      max: max,
      step: step,
      format: fmt,
      onChanged: (v) => _s.set(key, v),
    ));

Widget cStepInt(String title, String key, int min, int max, String Function(int) fmt, {int step = 1, String? sub}) => OptKey(
    key: ValueKey('o:$key'),
    cfgKey: key,
    child: StepRow(
      key: ValueKey('c:$key'),
      title: title,
      subtitle: sub,
      value: _s.cfg.i(key).toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      step: step.toDouble(),
      format: (v) => fmt(v.round()),
      onChanged: (v) => _s.set(key, v.round()),
    ));

Widget cToggle(String title, String key, {String? sub}) =>
    OptKey(key: ValueKey('o:$key'), cfgKey: key, child: ToggleRow(key: ValueKey('c:$key'), title: title, subtitle: sub, value: _s.cfg.b(key), onChanged: (v) => _s.set(key, v)));

Widget cColor(String title, String key) =>
    OptKey(key: ValueKey('o:$key'), cfgKey: key, child: ColorRow(key: ValueKey('c:$key'), title: title, value: _s.cfg.c(key), onChanged: (c) => _s.set(key, c.toARGB32())));

Widget cFont(String title, String key) =>
    OptKey(key: ValueKey('o:$key'), cfgKey: key, child: FontRow(key: ValueKey('c:$key'), title: title, value: _s.cfg.s(key), onChanged: (f) => _s.set(key, f)));

String fmtPx(double v) => Ar.n(v.round());
String fmtPct(double v) => '${Ar.n((v * 100).round())}٪';
String fmtX(double v) => '×${Ar.n(v.toStringAsFixed(2))}';

// =====================================================================
//  نوافذ منبثقة وانتقالات
// =====================================================================

/// رمز الأهل: لوحة أرقام بالمحاولات والقفل المؤقت (فيكما صفحة ١٢).
Future<bool> askPin(BuildContext context, {String title = 'رمز الأهل'}) => showPinPad(context, title: title);

Future<String?> promptText(BuildContext context,
    {required String title, String initial = '', bool obscure = false, bool number = false}) {
  final p = pal;
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: themedDialog(
        width: 720,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Fonts.title(30, p.ink)),
          const SizedBox(height: 24),
          TextField(
            controller: ctrl,
            focusNode: tvFieldNode(ctrl),
            autofocus: true,
            obscureText: obscure,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            style: Fonts.body(26, p.ink),
            cursorColor: p.accent,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.glass ? Colors.black.withValues(alpha: 0.15) : p.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            PillButton('إلغاء', onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 14),
            PillButton('موافق', primary: true, onTap: () => Navigator.pop(ctx, ctrl.text)),
          ]),
        ]),
      ),
    ),
  );
}

/// نافذة تأكيد بسيطة: ترجع true إذا اختار «نعم».
Future<bool?> confirmDialog(BuildContext context, {required String title, String body = '', String yes = 'نعم', String no = 'إلغاء'}) {
  final p = pal;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: themedDialog(
        width: 760,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FitText(title, style: Fonts.title(32, p.ink)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(body, style: Fonts.body(21, p.muted), maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            PillButton(no, autofocus: true, onTap: () => Navigator.pop(ctx, false)),
            const SizedBox(width: 14),
            PillButton(yes, primary: true, onTap: () => Navigator.pop(ctx, true)),
          ]),
        ]),
      ),
    ),
  );
}

/// قائمة خيارات منبثقة.
Future<void> showActions(BuildContext context, String title, List<(String, Object, VoidCallback, bool)> actions,
    {AlignmentGeometry? align, double width = 640, EdgeInsets inset = const EdgeInsets.all(60)}) {
  final p = pal;
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: themedDialog(
        width: width,
        alignment: align,
        inset: inset,
        padding: const EdgeInsets.all(34),
        child: NavZone(child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
          clipBehavior: Clip.none,
          child: SizedBox(
            width: width - 68,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FitText(title, style: Fonts.title(34, p.ink)),
              const SizedBox(height: 24),
              for (final (i, a) in actions.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PillButton(
                    a.$1,
                    icon: a.$2,
                    danger: a.$4,
                    autofocus: i == 0,
                    onTap: () {
                      Navigator.pop(ctx);
                      a.$3();
                    },
                  ),
                ),
            ]),
          ),
        ))),
      ),
    ),
  );
}

void toast(BuildContext context, String msg) {
  final p = pal;
  // تنبيه ملكي: سطح الثيم بحد ذهبي ومعيّن، سطر واحد يصغر ولا ينزل
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Row(children: [
      const RoyalDiamond(size: 9),
      const SizedBox(width: 14),
      Expanded(child: FitText(msg, style: Fonts.body(22, p.ink))),
    ]),
    backgroundColor: p.glass ? Color.lerp(p.bg, p.surface.withValues(alpha: 1), 0.5) : p.surface,
    elevation: 12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22 * radiusK), side: BorderSide(color: p.ring.withValues(alpha: 0.55))),
    behavior: SnackBarBehavior.floating,
    width: 900,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
    duration: const Duration(seconds: 3),
  ));
}

Route<T> fade<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: AppState.I.anim(280),
      reverseTransitionDuration: AppState.I.anim(200),
      pageBuilder: (_, __, ___) => page,
      // انتقال الشاشات من إعداد "الحركة والسرعة": تلاشي، انزلاق جانبي، أو تكبير هادئ
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: AppState.I.curve == Curves.easeOutBack ? Curves.easeOutCubic : AppState.I.curve);
        return switch (AppState.I.cfg.s('motion.page')) {
          // الملكي: تلاشي مع صعود هادئ وتكبير خفيف
          'royal' => FadeTransition(
              opacity: c,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.018), end: Offset.zero).animate(c),
                child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(c), child: child),
              ),
            ),
          'slide' => SlideTransition(
              position: Tween(begin: const Offset(-0.08, 0), end: Offset.zero).animate(c),
              child: FadeTransition(opacity: c, child: child),
            ),
          'zoom' => ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(c),
              child: FadeTransition(opacity: c, child: child),
            ),
          _ => FadeTransition(
              opacity: c,
              child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(c), child: child),
            ),
        };
      },
    );

Object weatherIcon(String kind) => switch (kind) {
      'sun' => Lu.sun,
      'moon' => Lu.moon,
      'cloud' => Lu.cloud,
      'fog' => Lu.cloudFog,
      'dust' => Lu.haze,
      'storm' => Lu.cloudLightning,
      _ => Lu.cloudRain,
    };

/// شاشة بخلفية الثيم، تتحدث فوراً مع أي تغيير.
class ThemedScaffold extends StatelessWidget {
  final Widget child;
  const ThemedScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final p = AppState.I.palette;
        final body = Scaffold(backgroundColor: Colors.transparent, resizeToAvoidBottomInset: false, body: child);
        if (p.glass) {
          // الزجاج: خلفية الواجهة تبان من ورا الألواح المغبشة
          return ColoredBox(
            color: p.bg,
            child: Stack(fit: StackFit.expand, children: [homeBackdrop(), body]),
          );
        }
        return AnimatedContainer(duration: AppState.I.anim(700), color: p.bg, child: body);
      },
    );
  }
}

/// لوح بنمط الثيم: كلاسيكي = سطح صلب، زجاجي = تغبيش حقيقي لما وراه + سطح شفاف.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final double? width, height;
  final bool border;
  final Color? color;
  final Color? borderColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(32)),
    this.padding,
    this.width,
    this.height,
    this.border = true,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final lite = AppState.I.lite;
    final fill = color ?? (p.glass && lite ? Color.lerp(p.bg, p.surface.withValues(alpha: 1), 0.25)!.withValues(alpha: 0.86) : p.surface);
    if (p.liquid) {
      // الزجاج السائل: نفس اللوح بمحرك Liquid Glass (تغبيش + تشبّع + حافة لامعة)
      return LiquidGlass(
        width: width,
        height: height,
        padding: padding,
        radius: radius.topLeft.x,
        shadow: border,
        child: child,
      );
    }
    final inner = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    final box = Container(
      width: width,
      height: height,
      decoration: p.smooth && !p.glass
          ? surfaceDecoration(color: fill, radius: radius.topLeft.x, border: border ? (borderColor ?? p.line) : null)
          : BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: border ? Border.all(color: borderColor ?? p.line) : null,
            ),
      // لمعة الزجاج طبقة فوق اللون (لو بنفس الصندوق، التدرج يلغي اللون)
      child: p.glass
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.white.withValues(alpha: p.night ? 0.07 : 0.22), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
              child: inner,
            )
          : inner,
    );
    if (!p.glass || p.blur <= 0 || lite) return box;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: p.blur, sigmaY: p.blur), child: box),
    );
  }
}

/// نافذة منبثقة بنمط الثيم (زجاجية أو كلاسيكية).
Widget themedDialog({required Widget child, double? width, double? height, EdgeInsets inset = const EdgeInsets.all(60), EdgeInsetsGeometry padding = const EdgeInsets.all(40), AlignmentGeometry? alignment}) =>
    Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: inset,
      alignment: alignment,
      child: GlassPanel(
        width: width,
        height: height,
        radius: BorderRadius.circular(36),
        padding: padding,
        color: pal.glass ? null : pal.surface,
        borderColor: pal.ring.withValues(alpha: 0.38),
        child: child,
      ),
    );

/// تنقل شبكة بترتيب القراءة: يسار = التالي ويلتف للصف اللي تحته، يمين = السابق،
/// وبآخر عنصر يرجع للأول. أعلى/أسفل = صف كامل (من الصف الأول يطلع للعناوين).
KeyEventResult gridNav(KeyEvent e,
    {required int index, required int count, required int cols, required void Function(int) focus}) {
  if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
  if (count == 0) return KeyEventResult.ignored;
  final k = e.logicalKey;
  if (arrowDirection(k) != null && repeatTooFast(e)) return KeyEventResult.handled;
  final wrap = AppState.I.cfg.b('remote.wrap');
  int? to;
  if (k == LogicalKeyboardKey.arrowLeft) to = wrap ? (index + 1) % count : (index + 1 < count ? index + 1 : index);
  if (k == LogicalKeyboardKey.arrowRight) to = wrap ? (index - 1 + count) % count : (index > 0 ? index - 1 : index);
  if (k == LogicalKeyboardKey.arrowDown) {
    if (index + cols < count) {
      to = index + cols;
    } else if (index ~/ cols < (count - 1) ~/ cols) {
      to = count - 1;
    } else {
      return KeyEventResult.handled; // آخر صف: يبقى مكانه
    }
  }
  if (k == LogicalKeyboardKey.arrowUp && index - cols >= 0) to = index - cols;
  if (to == null) return KeyEventResult.ignored;
  if (to != index) focus(to);
  return KeyEventResult.handled;
}

/// خريطة عقد تركيز ثابتة لعناصر قائمة (تبقى مع إعادة البناء).
class FocusNodes {
  final Map<String, FocusNode> _m = {};
  FocusNode of(String id) => _m.putIfAbsent(id, () => FocusNode(debugLabel: id));
  void focus(String id) => _m[id]?.requestFocus();
  void dispose() {
    for (final n in _m.values) {
      n.dispose();
    }
    _m.clear();
  }
}
