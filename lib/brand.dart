import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

import 'package:flutter/material.dart';

import 'brand_paths.dart';
import 'fonts.dart';
import 'state.dart';

// ═══════════════════════════════════════════════════════════════════════
//  هوية رونق (فيكما صفحة ١٥): الاسم نفسه هو الشعار. «رونق» بخط النستعليق
//  الذهبي داخل حلقة مزدوجة، وقطرتا نور فوقها وجوّها.
//  نفس المسارات المستعملة بأيقونة التطبيق والبانر وشاشة الإقلاع.
// ═══════════════════════════════════════════════════════════════════════

/// صندوق بحجم ثابت ما يتمدد ويه قيود الأب (الشعار ما يكبر ويغطي اللي يمه).
Widget _fixed(double w, double h, Widget child) => Center(widthFactor: 1, heightFactor: 1, child: SizedBox(width: w, height: h, child: child));

class BrandColors {
  static const night = Color(0xFF04140F);
  static const emeraldDeep = Color(0xFF05261D);
  static const emerald = Color(0xFF17644D);
  static const emeraldInk = Color(0xFF0E4A39);
  static const goldLight = Color(0xFFF7E7B4);
  static const gold = Color(0xFFDDB767);
  static const goldOld = Color(0xFFA5762A);
  static const goldFlat = Color(0xFFC9A24E);
  static const ivory = Color(0xFFF6F1E6);

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldOld],
    stops: [0, 0.45, 1],
  );
}

/// قارئ بسيط لمسارات SVG المطلقة (M L C Z): كل مسارات الشعار بهذي الصيغة.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLCZmlcz]|-?\d*\.?\d+(?:e-?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  String cmd = 'M';
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'^[MLCZmlcz]$').hasMatch(t)) {
      cmd = t.toUpperCase();
      i++;
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        path.moveTo(n(), n());
        cmd = 'L'; // أرقام بعد M تعتبر خطوط
      case 'L':
        path.lineTo(n(), n());
      case 'C':
        path.cubicTo(n(), n(), n(), n(), n(), n());
      default:
        i++;
    }
  }
  return path;
}

class _P {
  static final dropTop = parseSvgPath(kDropTop);
  static final dropBottom = parseSvgPath(kDropBottom);
  static final word = parseSvgPath(kNastaliqPath);
  static final la = parseSvgPath(kWordLaPath);
}

const _vGold = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF8E9BC), Color(0xFFD9B266), Color(0xFF9E7230)],
  stops: [0, 0.5, 1],
);

/// royal: ذهبي متدرج (فوق الزمردي والليلي) · day: زمردي (فوق العاجي)
/// gold / white: أحادي · bold: حلقة عريضة للأحجام الصغيرة.
enum MarkStyle {
  royal,
  day,
  gold,
  white,
  bold;

  static MarkStyle of(bool night) => night ? royal : day;
}

/// الشعار: «رونق» بالنستعليق داخل الحلقة. [size] قطر المربع كامل.
class RawnaqMark extends StatelessWidget {
  final double size;
  final MarkStyle style;
  final bool glow;
  const RawnaqMark({super.key, this.size = 120, this.style = MarkStyle.royal, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final mark = _fixed(size, size, CustomPaint(painter: _MarkPainter(style)));
    if (!glow) return mark;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      Container(
        width: size * 0.7,
        height: size * 0.7,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: BrandColors.gold.withValues(alpha: style == MarkStyle.day ? 0.14 : 0.22), blurRadius: size * 0.6, spreadRadius: size * 0.02),
        ]),
      ),
      mark,
    ]);
  }
}

/// يرسم الاسم بالنستعليق بعرض [w] ومركزه [c].
void _drawWord(Canvas canvas, double w, Offset c, Paint paint) {
  final k = w / kNastaliqW;
  canvas.save();
  canvas.translate(c.dx - w / 2, c.dy - kNastaliqH * k / 2);
  canvas.scale(k);
  canvas.drawPath(_P.word, paint);
  canvas.restore();
}

class _MarkPainter extends CustomPainter {
  final MarkStyle style;
  _MarkPainter(this.style);

  static const _box = Rect.fromLTWH(0, 0, 240, 240);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.scale(s.width / 240);
    final gradient = style == MarkStyle.royal || style == MarkStyle.bold;
    final flat = switch (style) {
      MarkStyle.day => BrandColors.emeraldInk,
      MarkStyle.gold => BrandColors.goldFlat,
      MarkStyle.white => Colors.white,
      _ => BrandColors.gold,
    };
    Paint paint({double? stroke, double alpha = 1}) {
      final p = Paint();
      if (stroke != null) {
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke;
      }
      if (gradient) {
        p.shader = _vGold.createShader(_box);
      } else {
        p.color = flat.withValues(alpha: alpha);
      }
      return p;
    }

    const c = Offset(120, 120);
    if (style == MarkStyle.bold) {
      canvas.drawCircle(c, 102, paint(stroke: 7));
      _drawWord(canvas, 168, const Offset(118, 126), paint());
      canvas.restore();
      return;
    }
    canvas.drawCircle(c, 104, paint(stroke: 3));
    if (gradient) {
      canvas.saveLayer(_box, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.75));
      canvas.drawCircle(c, 96, paint(stroke: 1));
      canvas.restore();
    } else {
      canvas.drawCircle(c, 96, paint(stroke: 1, alpha: 0.75));
    }
    canvas.drawPath(_P.dropTop, paint());
    canvas.drawPath(_P.dropBottom, paint());
    // الاسم: تدرج عمودي على ارتفاعه هو
    final wp = gradient ? (Paint()..shader = _vGold.createShader(const Rect.fromLTWH(0, 66, 240, 122))) : paint();
    _drawWord(canvas, 150, const Offset(118, 126), wp);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter o) => o.style != style;
}

/// الاسم وحده بالنستعليق (للعناوين). [height] ارتفاعه.
class RawnaqLogotype extends StatelessWidget {
  final double height;
  final bool night;
  final Color? color;
  const RawnaqLogotype({super.key, this.height = 64, this.night = true, this.color});

  @override
  Widget build(BuildContext context) {
    final w = kNastaliqW * height / kNastaliqH;
    return _fixed(w, height, CustomPaint(painter: _LogoPainter(night, color)));
  }
}

class _LogoPainter extends CustomPainter {
  final bool night;
  final Color? color;
  _LogoPainter(this.night, this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();
    if (color != null) {
      p.color = color!;
    } else if (night) {
      p.shader = _vGold.createShader(Offset.zero & s);
    } else {
      p.color = BrandColors.emeraldInk;
    }
    _drawWord(canvas, s.width, s.center(Offset.zero), p);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter o) => o.night != night || o.color != color;
}

/// RAWNAQ بخط Cinzel المحوّل لمسارات. [width] عرضه.
class RawnaqLatin extends StatelessWidget {
  final double width;
  final Color color;
  const RawnaqLatin({super.key, required this.width, this.color = BrandColors.goldFlat});

  @override
  Widget build(BuildContext context) => _fixed(width, kWordLaH * width / kWordLaW, CustomPaint(painter: _LatinPainter(color)));
}

class _LatinPainter extends CustomPainter {
  final Color color;
  _LatinPainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.scale(s.width / kWordLaW);
    canvas.drawPath(_P.la, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LatinPainter o) => o.color != color;
}

/// الشعار الكامل: مكدّس (الحلقة وتحتها RAWNAQ) أو أفقي (الحلقة يمين وRAWNAQ يسارها).
/// [markSize] قطر الحلقة، وباقي القياسات بنفس نسب فيكما.
class RawnaqLockup extends StatelessWidget {
  final double markSize;
  final bool night;
  final bool stacked;
  final bool latin;
  final bool glow;
  const RawnaqLockup({super.key, this.markSize = 120, this.night = true, this.stacked = false, this.latin = true, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final k = markSize / 240;
    final mark = RawnaqMark(size: markSize, style: MarkStyle.of(night), glow: glow);
    if (!latin) return mark;
    if (stacked) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        mark,
        SizedBox(height: 26 * k),
        RawnaqLatin(width: 220 * k),
      ]);
    }
    return Row(textDirection: TextDirection.rtl, mainAxisSize: MainAxisSize.min, children: [
      mark,
      SizedBox(width: 40 * k),
      RawnaqLatin(width: 300 * k),
    ]);
  }
}

/// شريط تحميل ذهبي رفيع (شاشة الإقلاع).
class BrandProgress extends StatelessWidget {
  final double value;
  final double width;
  final bool night;
  const BrandProgress({super.key, required this.value, this.width = 420, this.night = true});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Container(
      width: width,
      height: 4,
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: (night ? Colors.white : BrandColors.emeraldInk).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        width: math.max(4.0, width * v),
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(colors: [BrandColors.goldOld, BrandColors.goldLight], begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd),
        ),
      ),
    );
  }
}

/// اسم الواجهة بأعلى الشاشة: «رونق» يطلع بالنستعليق، وأي اسم ثاني يطلع جنب الشعار.
class BrandTitle extends StatelessWidget {
  final String text;
  final double height;
  final Color color;
  final bool night;
  const BrandTitle({super.key, required this.text, required this.height, required this.color, required this.night});

  @override
  Widget build(BuildContext context) {
    if (text.trim() == 'رونق') return RawnaqLogotype(height: height, night: night);
    return Row(textDirection: TextDirection.rtl, mainAxisSize: MainAxisSize.min, children: [
      RawnaqMark(size: height, style: MarkStyle.of(night)),
      SizedBox(width: height * 0.2),
      Text(text, style: Fonts.title(height * 0.48, color)),
    ]);
  }
}

// ═══════════════════ حركة الشعار: الكتابة بخط اليد ═══════════════════
//  فيكما صفحة ١٥ «حركة الشعار · الكتابة بخط اليد» وصفحة ١٦ رقم ١٣ (الإعدادات).
//  القلم يكتب الراء، ثم الواو، ثم النون موصولة بالقاف، وبعدها ينقّط: نقطة النون
//  ثم نقطة القاف اليمنى ثم اليسرى. كل حرف ينكشف على طول مسار القلم (خط الوسط)
//  بريشة مدورة، والحبر يلمع طري خلف القلم لحظة ويجف.
//  الحلقة تمشي مع القلم، والقلم ما يسبق التحميل الحقيقي أبداً: إذا التحميل تأخر
//  يوقف بمكانه ويتنفس بهدوء، وإذا خلص بسرعة تكمل الكتابة بإيقاعها الطبيعي.
//  progress = null يعني مدة غير معروفة: تتقدم بهدوء لحد ٩٠٪ وتكمل لما يصير done.

/// مقطع من خطة الكتابة: 0 حرف · 1 نقطة · 2 رفع القلم بين حرفين.
class _Seg {
  final int kind, idx;
  final double dur;
  final double start;
  const _Seg(this.kind, this.idx, this.dur, this.start);
}

class _Hand {
  static List<String> _subs(String d) => d.split(RegExp(r'(?=M )')).where((s) => s.trim().isNotEmpty).toList();

  // الحروف: الجسم، مسار القلم، عرض الريشة
  static final glyphs = [kLetterRa, kLetterWaw, _subs(kLetterNun)[0], _subs(kLetterQaf)[0]].map(parseSvgPath).toList();
  static final pens = [kPenRa, kPenWaw, kPenNun, kPenQaf].map((d) => parseSvgPath(d).computeMetrics().first).toList();
  static const widths = [kPenRaW, kPenWawW, kPenNunW, kPenQafW];
  static final lens = pens.map((m) => m.length).toList();
  static final bounds = glyphs.map((g) => g.getBounds().inflate(4)).toList();

  // النقاط: نقطة النون، ونقطتا القاف (شكل واحد نقسمه عند x = 89)
  static final nunDot = parseSvgPath(_subs(kLetterNun)[1]);
  static final qafDots = parseSvgPath(_subs(kLetterQaf)[1]);
  static const dotC = [Offset(186, 14), Offset(112, 56), Offset(78, 60)]; // مكان نزول القلم
  static const dotR = [30.0, 28.0, 28.0];
  static const dotClip = [null, Rect.fromLTRB(89, 0, 170, 120), Rect.fromLTRB(-10, 0, 89, 120)];
  static Path dotGlyph(int i) => i == 0 ? nunDot : qafDots;

  static final union = () {
    final u = Path();
    for (final g in [...glyphs, nunDot, qafDots]) {
      u.addPath(g, Offset.zero);
    }
    return u;
  }();

  // التوقيت بالثواني عند السرعة «متوازنة» (نفس شريط التوقيت بفيكما)
  static final plan = () {
    const raw = [(0, 0, 0.52), (2, 0, 0.16), (0, 1, 0.70), (2, 0, 0.16), (0, 2, 0.48), (0, 3, 1.02), (2, 0, 0.26), (1, 0, 0.32), (2, 0, 0.16), (1, 1, 0.26), (2, 0, 0.10), (1, 2, 0.26)];
    var s = 0.0;
    final out = <_Seg>[];
    for (final (k, i, d) in raw) {
      out.add(_Seg(k, i, d, s));
      s += d;
    }
    return out;
  }();
  static final double total = plan.last.start + plan.last.dur; // ٤٫٤ ث

  static Offset startOf(_Seg s) => s.kind == 1 ? dotC[s.idx] : pens[s.idx].getTangentForOffset(0)!.position;
  static Offset endOf(_Seg s) => s.kind == 1 ? dotC[s.idx] + const Offset(-8, 10) : pens[s.idx].getTangentForOffset(lens[s.idx])!.position;

  /// منحنى القلم: يبدأ هادئ، يسرع بالنص، ويهدّي بالنهاية (بدون توقف تام).
  static double penEase(double t) => t - 0.78 * math.sin(2 * math.pi * t) / (2 * math.pi);
  static double inOut(double t) => t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2).toDouble() / 2;
  static double outCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
}

/// سرعات الكتابة من الإعدادات: هادئة ×١٫٣ · متوازنة ×١ · رشيقة ×٠٫٧٥
double loaderSpeedFactor([String? id]) => switch (id ?? AppState.I.cfg.s('loader.speed')) { 'calm' => 1.3, 'brisk' => 0.75, _ => 1.0 };

/// مدة الكتابة الكاملة بالثواني حسب السرعة (بدون اللمعة).
double loaderWriteSeconds([String? id]) => _Hand.total * loaderSpeedFactor(id);

/// شاشة الإقلاع تنتظر هذا قبل ما تفتح الواجهة (إذا «انتظر الكتابة» مفعّل).
class BootWriting {
  static Completer<void> _c = Completer<void>();
  static Future<void> get done => _c.future;
  static void finish() {
    if (!_c.isCompleted) _c.complete();
  }

  static void reset() {
    if (_c.isCompleted) _c = Completer<void>();
  }
}

class RawnaqLoader extends StatefulWidget {
  final double? progress;
  final bool done;
  final double size;
  final bool? night;
  final VoidCallback? onFinished;
  const RawnaqLoader({super.key, this.progress, this.done = false, this.size = 120, this.night, this.onFinished});

  @override
  State<RawnaqLoader> createState() => _RawnaqLoaderState();
}

class _LoaderState {
  double ring = 0; // كسر الحلقة
  double tb = 0; // الزمن المكتوب (بثواني الخطة)
  double breathe = 0; // القلم ينتظر التحميل
  double shine = -1; // ٠..١ أثناء اللمعة
  bool write = true, pen = true, wet = true, ringOn = true;
}

class _RawnaqLoaderState extends State<RawnaqLoader> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _st = _LoaderState();
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero, _now = Duration.zero;
  double _target = 0, _shown = 0;
  Duration? _unknownFrom, _finishAt;
  bool _reported = false;

  bool get _done => widget.done || (widget.progress ?? 0) >= 1;
  bool get _reduce => AppState.I.anim(100) == Duration.zero;

  @override
  void initState() {
    super.initState();
    _target = (widget.progress ?? 0).clamp(0.0, 1.0);
    if (widget.progress == null) _unknownFrom = Duration.zero;
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant RawnaqLoader old) {
    super.didUpdateWidget(old);
    // ما نرجع لورا أبداً
    if (widget.progress != null) _target = math.max(_target, widget.progress!.clamp(0.0, 1.0));
    if (widget.progress == null && _unknownFrom == null) _unknownFrom = _now;
    if (!_ticker.isActive && !_reported) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration t) {
    _now = t;
    final dt = _last == Duration.zero ? 0.016 : math.min(0.05, (t - _last).inMicroseconds / 1e6);
    _last = t;
    final c = AppState.I.cfg;
    final st = _st
      ..write = c.b('loader.write')
      ..pen = c.b('loader.pen')
      ..wet = c.b('loader.wet')
      ..ringOn = c.b('loader.ring');
    final speed = loaderSpeedFactor();
    final reduce = _reduce;

    // التحميل الحقيقي (ناعم وما يرجع لورا)
    var tgt = _target;
    if (_unknownFrom != null && !_done) {
      final s = (t - _unknownFrom!).inMicroseconds / 1e6;
      tgt = math.max(tgt, 0.9 * (1 - math.exp(-s / 2.2)));
    }
    if (_done) tgt = 1;
    if (reduce) {
      _shown = tgt;
    } else {
      _shown += (tgt - _shown) * (1 - math.exp(-dt * (_done ? 12 : 7)));
      _shown += math.max(0.0, math.min(tgt - _shown, dt * 0.04));
      if (tgt - _shown < 0.0008) _shown = tgt;
    }

    // القلم: يمشي بإيقاعه، وما يسبق التحميل
    final total = _Hand.total;
    final cap = total * _shown;
    if (!st.write || reduce) {
      st.tb = st.write ? cap : total;
      st.breathe = 0;
    } else {
      final want = st.tb + dt / speed;
      final waiting = want > cap && st.tb < total;
      st.tb = math.min(total, math.max(st.tb, math.min(want, cap)));
      st.breathe = waiting ? st.breathe + dt : 0;
    }
    st.ring = st.write ? st.tb / total : _shown;
    _frame.value++;

    final complete = st.write ? st.tb >= total : _shown >= 1;
    if (complete) {
      _finishAt ??= t;
      final shineMs = (!c.b('loader.shine') || reduce) ? 0 : (950 * speed).round();
      final el = (t - _finishAt!).inMilliseconds;
      st.shine = shineMs == 0 ? -1 : (el / shineMs).clamp(0.0, 1.0);
      if (el >= shineMs) {
        st.shine = -1;
        _frame.value++;
        if (!_reported) {
          _reported = true;
          widget.onFinished?.call();
        }
        _ticker.stop(); // ما يصرف شي بعد ما يكتمل
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night ?? AppState.I.palette.night;
    return _fixed(widget.size, widget.size, RepaintBoundary(child: CustomPaint(painter: _LoaderPainter(_st, night, widget.size < 110, _frame))));
  }
}

class _LoaderPainter extends CustomPainter {
  final _LoaderState st;
  final bool night, bold;
  _LoaderPainter(this.st, this.night, this.bold, Listenable frame) : super(repaint: frame);

  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size s) {
    final tb = st.tb;
    canvas.save();
    canvas.scale(s.width / 240);
    const c = Offset(120, 120);
    final r = bold ? 102.0 : 104.0;
    final w = bold ? 7.0 : 3.0;
    final line = night ? BrandColors.gold : BrandColors.emeraldInk;
    final ringGold = (night ? _vGold : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC9A24E), Color(0xFF9E7230), Color(0xFF6E4E1C)]))
        .createShader(const Rect.fromLTWH(0, 0, 240, 240));

    // المسار والحلقة الداخلية
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = w..color = line.withValues(alpha: night ? 0.14 : 0.12));
    if (!bold) canvas.drawCircle(c, 96, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = line.withValues(alpha: night ? 0.22 : 0.18));
    final p = st.ringOn ? st.ring : 0.0;
    // قوس التقدم من الأعلى باتجاه عقارب الساعة
    if (p > 0.002) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * p, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..shader = ringGold);
      if (p < 0.998) {
        final a = -math.pi / 2 + 2 * math.pi * p;
        final h = c + Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawCircle(h, bold ? 11 : 10, Paint()..color = (night ? const Color(0xFFF8E9BC) : BrandColors.gold).withValues(alpha: night ? 0.3 : 0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawCircle(h, bold ? 4.5 : 3.4, Paint()..color = night ? const Color(0xFFFFF6DC) : const Color(0xFFB8893A));
      }
    }
    // القطرتين: العليا تضوي مع أول حرف، والسفلى لما توصل الحلقة للنص
    if (!bold) {
      final lit = night ? const Color(0xFFF1D58E) : const Color(0xFFB8893A);
      final dim = line.withValues(alpha: night ? 0.22 : 0.18);
      canvas.drawPath(_P.dropTop, Paint()..color = p > 0.004 || !st.ringOn ? lit : dim);
      canvas.drawPath(_P.dropBottom, Paint()..color = p >= 0.5 || !st.ringOn ? lit : dim);
    }

    // الاسم
    final ww = bold ? 168.0 : 150.0, k = ww / kNastaliqW;
    canvas.save();
    canvas.translate(118 - ww / 2, 126 - kNastaliqH * k / 2);
    canvas.scale(k);
    final ghost = Paint()..color = line.withValues(alpha: night ? 0.10 : 0.08);
    final ink = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: night ? const [Color(0xFFFBEFC8), Color(0xFFD9B266), Color(0xFF9E7230)] : const [Color(0xFF1E7A5E), Color(0xFF0E4A39), Color(0xFF062A20)],
        stops: const [0, 0.55, 1],
      ).createShader(const Rect.fromLTWH(0, 0, kNastaliqW, kNastaliqH));
    final sheen = night ? const Color(0xFFFFF8E2) : const Color(0xFF5FB896);
    // الدليل الخافت تحت الحبر
    canvas.drawPath(_Hand.union, ghost);

    Offset? penAt;
    var penA = 0.0, penR = 1.0;
    final plan = _Hand.plan;
    for (var n = 0; n < plan.length; n++) {
      final g = plan[n];
      final u = ((tb - g.start) / g.dur).clamp(0.0, 1.0);
      if (g.kind == 0) {
        final i = g.idx;
        if (u <= 0) continue;
        final glyph = _Hand.glyphs[i];
        if (u >= 1) {
          canvas.drawPath(glyph, ink);
        } else {
          final d = _Hand.penEase(u) * _Hand.lens[i];
          _reveal(canvas, glyph, _Hand.pens[i].extractPath(0, d), _Hand.widths[i], ink, _Hand.bounds[i]);
          penAt = _Hand.pens[i].getTangentForOffset(d)?.position;
          penA = 1;
        }
        // لمعة الحبر الطري: آخر ٤٨ وحدة خلف القلم، وتجف بعد ما يخلص الحرف
        if (st.wet) {
          final after = tb - g.start - g.dur;
          final a = u < 1 ? 0.55 : 0.55 - after * 1.6;
          if (a > 0.01) {
            final d = _Hand.penEase(u) * _Hand.lens[i];
            _reveal(canvas, glyph, _Hand.pens[i].extractPath(math.max(0.0, d - 48), d), _Hand.widths[i], Paint()..color = sheen.withValues(alpha: a), _Hand.bounds[i]);
          }
        }
      } else if (g.kind == 1) {
        final i = g.idx;
        if (u <= 0) continue;
        final glyph = _Hand.dotGlyph(i);
        final rr = _Hand.dotR[i] * _Hand.outCubic(u);
        canvas.saveLayer(glyph.getBounds().inflate(6), Paint());
        final clip = _Hand.dotClip[i];
        if (clip != null) canvas.clipRect(clip);
        canvas.drawCircle(_Hand.dotC[i], rr, Paint()..color = _white);
        canvas.drawPath(glyph, Paint()..shader = ink.shader..blendMode = BlendMode.srcIn);
        canvas.restore();
        if (u < 1) {
          // نقرة القلم: ينزل، يضغط، ويسحب للأسفل يسار
          penAt = _Hand.dotC[i] + Offset(-8 * u, 10 * u);
          penA = u < 0.25 ? u / 0.25 : 1 - 0.6 * math.max(0.0, (u - 0.6) / 0.4);
          penR = 1 + 0.35 * math.sin(math.pi * math.min(1.0, u * 1.6));
        }
      } else if (u > 0 && u < 1) {
        // رفع القلم بقوس خفيف للحرف الجاي
        final a = _Hand.endOf(plan[n - 1]), b = _Hand.startOf(plan[n + 1]);
        final e = _Hand.inOut(u);
        penAt = Offset.lerp(a, b, e)! - Offset(0, math.sin(math.pi * u) * 18);
        penA = 0.28;
        penR = 0.7;
      }
    }
    if (tb >= _Hand.total) penAt = null;

    // رأس القلم المضيء
    if (st.pen && penAt != null) {
      if (st.breathe > 0) penA *= 0.7 + 0.3 * math.sin(st.breathe * 3.2);
      final gr = (bold ? 30.0 : 24.0) * penR;
      final glow = night ? const Color(0xFFFFF1C9) : const Color(0xFFE3BC6A);
      canvas.drawCircle(
        penAt,
        gr,
        Paint()
          ..shader = RadialGradient(colors: [glow.withValues(alpha: 0.9 * penA), glow.withValues(alpha: 0.45 * penA), glow.withValues(alpha: 0)], stops: const [0, 0.35, 1])
              .createShader(Rect.fromCircle(center: penAt, radius: gr)),
      );
      canvas.drawCircle(penAt, bold ? 6.5 : 5, Paint()..color = (night ? const Color(0xFFFFFBEF) : const Color(0xFFC99A48)).withValues(alpha: penA));
    }

    // لمعة الختام: تمر من اليمين لليسار على الاسم
    final sh = st.shine;
    if (sh >= 0 && sh < 1) {
      final x = kNastaliqW + 140 - _Hand.inOut(sh) * (kNastaliqW + 300);
      canvas.save();
      canvas.clipPath(_Hand.union);
      canvas.transform(Matrix4.skewX(-0.32).storage);
      canvas.drawRect(
        Rect.fromLTWH(x, -40, 140, kNastaliqH + 80),
        Paint()
          ..shader = LinearGradient(colors: [_white.withValues(alpha: 0), _white.withValues(alpha: 0.85 * math.sin(math.pi * sh)), _white.withValues(alpha: 0)])
              .createShader(Rect.fromLTWH(x, 0, 140, 10)),
      );
      canvas.restore();
    }
    canvas.restore();
    canvas.restore();
  }

  /// يكشف [glyph] تحت ريشة مدورة تمشي على [stroke].
  static void _reveal(Canvas canvas, Path glyph, Path stroke, double width, Paint paint, Rect bounds) {
    canvas.saveLayer(bounds, Paint());
    canvas.drawPath(
      stroke,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _white,
    );
    canvas.drawPath(glyph, Paint()..shader = paint.shader..color = paint.color..blendMode = BlendMode.srcIn);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter o) => o.night != night || o.bold != bold || o.st != st;
}

/// صورة تتحمل: شعار التحميل بالنص لحد ما تنرسم أول صورة، وبعدها تظهر بنعومة.
ImageFrameBuilder brandImageFrame({Color? background, double size = 56}) => (context, child, frame, sync) {
      if (sync) return child;
      return AnimatedSwitcher(
        duration: AppState.I.anim(260),
        child: frame != null
            ? KeyedSubtree(key: const ValueKey('img'), child: child)
            : ColoredBox(key: const ValueKey('wait'), color: background ?? Colors.transparent, child: Center(child: RawnaqLoader(size: size))),
      );
    };
