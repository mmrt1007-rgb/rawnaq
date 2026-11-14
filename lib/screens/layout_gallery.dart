import 'package:flutter/material.dart';

import '../lucide.dart';
import '../state.dart';
import '../widgets.dart';

/// ترتيبات الشاشة الرئيسية: المعرّف، الاسم، الوصف، الأيقونة.
const homeLayouts = <(String, String, String, Lu)>[
  ('modern', 'الحديثة', 'بطاقة بارزة للتطبيق المحدد، ساعة أنيقة، وشريط مربعات ناعمة — الأخف والأسرع', Lu.dashboard),
  ('row', 'صف واحد', 'الساعة بالأعلى وصف تطبيقات هادئ تحتها', Lu.gallery),
  ('grid', 'شبكة', 'كل التطبيقات قدامك بشبكة مرتبة', Lu.grid),
  ('pages', 'صفحات', 'شبكة تتقلب صفحة بعد صفحة', Lu.squareStack),
  ('column', 'عمود جانبي', 'قائمة عمودية بجانب الساعة', Lu.panelLeft),
  ('cinema', 'سينمائي', 'خلفية كاملة وصف تطبيقات عائم بالأسفل', Lu.tv),
  ('tvgrid', 'شبكة التلفاز', 'مساحة علوية للتطبيق المحدد وشبكة تحتها', Lu.dashboard),
  ('ribbons', 'شرائط', 'شريط تنقل وبطاقة بارزة وشرائط تطبيقات', Lu.rows),
  ('liquid', 'الزجاج السائل', 'شريط تنقل زجاجي ورف تطبيقات زجاجي عائم', Lu.droplet),
  ('dock', 'المرسى', 'ساعة كبيرة بالوسط وشريط تطبيقات سفلي يكبر عليه المحدد', Lu.appWindow),
  ('hero', 'البطاقة البارزة', 'التطبيق المحدد بطاقة كبيرة مع الوقت والمواقيت', Lu.layoutTop),
  ('split', 'اللوحتين', 'لوحة معلومات يمين وشبكة تطبيقات يسار', Lu.columns3),
];

/// معرض ترتيبات الواجهة — تصميم فيكما "معرض ترتيبات الواجهة":
/// معاينة يسار تتبع الترتيب المحدد، وقائمة الترتيبات يمين. ▲▼ للتنقل، موافق للتطبيق، رجوع للخروج.
class LayoutGalleryScreen extends StatefulWidget {
  const LayoutGalleryScreen({super.key});

  @override
  State<LayoutGalleryScreen> createState() => _LayoutGalleryScreenState();
}

class _LayoutGalleryScreenState extends State<LayoutGalleryScreen> {
  String? _focused;

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = s.palette;
          final current = s.cfg.s('home.layout');
          final shown = homeLayouts.firstWhere((x) => x.$1 == (_focused ?? current), orElse: () => homeLayouts.first);
          return Padding(
            padding: const EdgeInsets.fromLTRB(112, 64, 112, 56),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ترتيب الواجهة', style: Fonts.title(52, p.ink)),
              const SizedBox(height: 6),
              FitText('${homeLayouts.length} ترتيب للشاشة الرئيسية — الأعلى والأسفل للتنقل · موافق للتطبيق · رجوع للخروج',
                  style: Fonts.body(24, p.muted, weight: FontWeight.w300)),
              const SizedBox(height: 32),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 620,
                    child: GlassPanel(
                      radius: BorderRadius.circular(32),
                      padding: const EdgeInsets.all(22),
                      child: NavZone(
                        child: SingleChildScrollView(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.all(5),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (final l in homeLayouts)
                              FocusTap(
                                key: ValueKey('layout-${l.$1}'),
                                autofocus: l.$1 == current,
                                onFocus: (f) {
                                  if (f) setState(() => _focused = l.$1);
                                },
                                onTap: () => s.set('home.layout', l.$1),
                                builder: (context, f) => _LayoutRow(layout: l, focused: f, selected: l.$1 == current),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final h = (box.maxHeight - 130).clamp(200.0, box.maxWidth * 9 / 16);
                      final w = h * 16 / 9;
                      return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: p.line, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 50, offset: const Offset(0, 20))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(27),
                            child: AnimatedSwitcher(
                              duration: s.anim(220),
                              child: CustomPaint(key: ValueKey(shown.$1), painter: LayoutSketch(shown.$1, p.night), child: const SizedBox.expand()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: w,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(shown.$2, style: Fonts.title(36, p.ink)),
                              if (shown.$1 == current) ...[
                                const SizedBox(width: 14),
                                AppIcon(Lu.circleCheck, color: p.accent, size: 30),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            FitText(shown.$3, style: Fonts.body(22, p.muted, weight: FontWeight.w300)),
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
}

class _LayoutRow extends StatelessWidget {
  final (String, String, String, Lu) layout;
  final bool focused, selected;
  const _LayoutRow({required this.layout, required this.focused, required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return AnimatedContainer(
      duration: AppState.I.anim(140),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? p.accent.withValues(alpha: 0.16) : (p.glass ? Colors.black.withValues(alpha: p.night ? 0.15 : 0.04) : p.bg),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: focused ? p.ring : (selected ? p.accent : p.line), width: focused ? ringW : 1),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(12)),
          child: AppIcon(layout.$4, color: p.onAccent, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(child: FitText(layout.$2, style: Fonts.body(22, p.ink, weight: selected ? FontWeight.w600 : null))),
        if (selected) Text('الحالي', style: Fonts.body(18, p.accent, weight: FontWeight.w500)),
      ]),
    );
  }
}

/// رسم مبسّط لكل ترتيب (صناديق بنفس تكوين الواجهة) — خفيف وواضح.
class LayoutSketch extends CustomPainter {
  final String layout;
  final bool night;
  const LayoutSketch(this.layout, this.night);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: night ? const [Color(0xFF123A2C), Color(0xFF06120E), Color(0xFF0E1F2E)] : const [Color(0xFFCFE3D6), Color(0xFFF3EEE4), Color(0xFFE7D3A8)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final ink = night ? Colors.white : const Color(0xFF13201A);
    final tileCols = [const Color(0xFFC0392B), const Color(0xFF2F4E7E), const Color(0xFF2E7D5B), const Color(0xFF5A3C86), const Color(0xFF1F6F5C), const Color(0xFFA86E2A), const Color(0xFF8C4A5E), const Color(0xFF3F6E8C)];
    void box(double x, double y, double bw, double bh, Color c, {double r = 10, bool ring = false}) {
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x * w, y * h, bw * w, bh * h), Radius.circular(r));
      canvas.drawRRect(rr, Paint()..color = c);
      if (ring) {
        canvas.drawRRect(rr.inflate(3), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFD8B467));
      }
    }

    void text(double x, double y, double bw, double bh, {double a = 0.85}) => box(x, y, bw, bh, ink.withValues(alpha: a), r: 4);
    void glass(double x, double y, double bw, double bh, {double r = 18}) {
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x * w, y * h, bw * w, bh * h), Radius.circular(r));
      canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: night ? 0.10 : 0.45));
      canvas.drawRRect(rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.5));
    }

    // صف تطبيقات: من اليمين لليسار (الأول محدد)
    void row(double y, double tw, double th, int n, {double right = 0.94, double gap = 0.018}) {
      for (var i = 0; i < n; i++) {
        box(right - tw - i * (tw + gap), y, tw, th, tileCols[i % tileCols.length], ring: i == 0);
      }
    }

    switch (layout) {
      case 'grid':
      case 'pages':
        text(0.70, 0.08, 0.24, 0.07);
        for (var r = 0; r < (layout == 'pages' ? 2 : 3); r++) {
          row(0.26 + r * 0.22, 0.14, 0.16, 6, right: 0.94, gap: 0.016);
        }
        if (layout == 'pages') {
          for (var i = 0; i < 3; i++) {
            canvas.drawCircle(Offset(w * (0.47 + i * 0.03), h * 0.86), 4, Paint()..color = ink.withValues(alpha: i == 0 ? 0.9 : 0.3));
          }
        }
      case 'column':
        text(0.10, 0.12, 0.30, 0.14);
        for (var i = 0; i < 6; i++) {
          box(0.62, 0.10 + i * 0.13, 0.32, 0.10, tileCols[i], ring: i == 0);
        }
      case 'cinema':
        text(0.72, 0.08, 0.22, 0.05);
        text(0.60, 0.56, 0.34, 0.07);
        row(0.70, 0.14, 0.16, 6);
      case 'tvgrid':
        text(0.60, 0.30, 0.34, 0.09);
        text(0.70, 0.42, 0.24, 0.04, a: 0.6);
        row(0.56, 0.155, 0.17, 5, gap: 0.02);
        row(0.78, 0.155, 0.17, 5, gap: 0.02);
      case 'ribbons':
        glass(0.32, 0.06, 0.36, 0.07, r: 30);
        box(0.36, 0.18, 0.58, 0.30, const Color(0xFF2F4E7E), r: 14, ring: true);
        row(0.56, 0.12, 0.13, 7, gap: 0.015);
        row(0.76, 0.12, 0.13, 7, gap: 0.015);
      case 'modern':
        glass(0.34, 0.05, 0.32, 0.06, r: 30);
        box(0.05, 0.16, 0.45, 0.45, const Color(0xFFC0392B), r: 22, ring: false);
        text(0.62, 0.20, 0.32, 0.14);
        text(0.66, 0.40, 0.28, 0.04, a: 0.7);
        text(0.70, 0.47, 0.24, 0.03, a: 0.5);
        row(0.72, 0.11, 0.10, 8, gap: 0.012);
      case 'liquid':
        text(0.74, 0.08, 0.20, 0.10);
        glass(0.34, 0.08, 0.30, 0.07, r: 30);
        glass(0.06, 0.08, 0.18, 0.05, r: 30);
        text(0.74, 0.52, 0.20, 0.05);
        glass(0.06, 0.64, 0.88, 0.28, r: 26);
        row(0.70, 0.12, 0.13, 6, right: 0.91, gap: 0.02);
      case 'dock':
        text(0.38, 0.22, 0.24, 0.16);
        text(0.33, 0.43, 0.34, 0.04, a: 0.6);
        glass(0.17, 0.74, 0.66, 0.18, r: 24);
        for (var i = 0; i < 8; i++) {
          final s = i == 0 ? 0.084 : 0.07;
          box(0.80 - s - i * 0.079, i == 0 ? 0.745 : 0.77, s, s * w / h, tileCols[i], r: 10, ring: i == 0); // مربعات
        }
      case 'hero':
        box(0.40, 0.08, 0.54, 0.52, const Color(0xFFC0392B), r: 16, ring: true);
        text(0.06, 0.10, 0.24, 0.12);
        for (var i = 0; i < 3; i++) {
          glass(0.06, 0.30 + i * 0.09, 0.26, 0.07, r: 10);
        }
        row(0.72, 0.115, 0.13, 7, gap: 0.015);
      case 'split':
        glass(0.66, 0.05, 0.30, 0.90, r: 20);
        text(0.72, 0.10, 0.20, 0.12);
        for (var i = 0; i < 6; i++) {
          text(0.70, 0.32 + i * 0.07, 0.22, 0.035, a: i == 4 ? 0.9 : 0.45);
        }
        for (var r = 0; r < 3; r++) {
          row(0.14 + r * 0.27, 0.17, 0.19, 3, right: 0.60, gap: 0.025);
        }
      default: // row
        text(0.66, 0.14, 0.28, 0.14);
        text(0.70, 0.32, 0.24, 0.04, a: 0.6);
        row(0.62, 0.14, 0.16, 6);
    }
  }

  @override
  bool shouldRepaint(LayoutSketch old) => old.layout != layout || old.night != night;
}
