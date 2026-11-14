import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lucide.dart';
import '../state.dart';
import '../widgets.dart';

/// الريموت والتنقل — تصميم فيكما: رسم الريموت مع شرح كل زر يسار، وخيارات التنقل يمين.
class RemoteSettingsScreen extends StatelessWidget {
  const RemoteSettingsScreen({super.key});

  static const _legend = [
    ('موافق', 'يفتح أو يثبّت — ضغطة طويلة للخيارات'),
    ('الأسهم', 'تنقل بترتيب القراءة ويلتف بنهاية الصف'),
    ('رجوع', 'خطوة وحدة للخلف — ما يطلعك من القائمة كلها'),
    ('هوم', 'يسكّر كل شي ويرجع لأول تطبيق'),
    ('قائمة', 'خيارات العنصر المحدد'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return ThemedScaffold(
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = s.palette;
          return Padding(
            padding: const EdgeInsets.fromLTRB(112, 64, 112, 56),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الريموت والتنقل', style: Fonts.title(52, p.ink)),
              const SizedBox(height: 6),
              FitText('كل زر يسوي شي واحد واضح — بدون خروج مفاجئ ولا قفز غلط', style: Fonts.body(24, p.muted, weight: FontWeight.w300)),
              const SizedBox(height: 32),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 600,
                    child: GlassPanel(
                      radius: BorderRadius.circular(32),
                      padding: const EdgeInsets.all(28),
                      child: NavZone(
                        child: SingleChildScrollView(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.all(5),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text('التنقل', style: Fonts.title(32, p.ink)),
                            const SizedBox(height: 16),
                            ChoiceRow<int>(
                              key: const ValueKey('repeat'),
                              autofocus: true,
                              title: 'سرعة التنقل عند الضغط المستمر',
                              value: s.cfg.i('remote.repeat'),
                              options: const [(80, 'سريعة'), (140, 'هادئة'), (220, 'بطيئة جداً')],
                              onChanged: (v) => s.set('remote.repeat', v),
                            ),
                            cChoice<int>('مدة الضغطة الطويلة', 'remote.longPress', const [(400, 'قصيرة (٠٫٤ ثانية)'), (550, 'عادية (٠٫٥ ثانية)'), (750, 'طويلة (٠٫٧٥ ثانية)')]),
                            cToggle('الالتفاف بنهاية الصف', 'remote.wrap', sub: 'يسار بآخر الصف ينزل للصف اللي تحته، وبآخر تطبيق يرجع للأول'),
                            cToggle('تأكيد قبل الخروج من الإعدادات', 'remote.confirmExit', sub: 'رجوع بأول قسم يسأل قبل ما يطلع'),
                            cChoice<String>('حركة التركيز', 'remote.motion', const [('none', 'بدون'), ('soft', 'ناعمة'), ('full', 'تكبير ولمعة')]),
                            cChoice<String>('إطار التركيز', 'remote.ring', const [('thin', 'خط رفيع'), ('gold', 'ذهبي'), ('glow', 'توهج')]),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 96),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          SizedBox(
                            width: 500,
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              for (final (k, d) in _legend)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(k, style: Fonts.body(20, p.ink, weight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    FitText(d, style: Fonts.body(18, p.muted, weight: FontWeight.w300)),
                                  ]),
                                ),
                            ]),
                          ),
                          const SizedBox(width: 60),
                          const _Remote(),
                        ]),
                      ),
                    ),
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

/// رسم ريموت بسيط وأنيق بنفس ألوان الثيم.
class _Remote extends StatelessWidget {
  const _Remote();

  @override
  Widget build(BuildContext context) {
    final p = pal;
    Widget round(String label) => Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)),
          child: Text(label, style: Fonts.body(15, p.ink, weight: FontWeight.w500)),
        );
    Widget arrow(double turns) => Transform.rotate(angle: turns * 2 * math.pi, child: AppIcon(Lu.chevronLeft, color: p.muted, size: 22));
    return Container(
      width: 300,
      height: 700,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(150),
        border: Border.all(color: p.line, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 50, offset: const Offset(0, 20))],
      ),
      child: Column(children: [
        const SizedBox(height: 70),
        Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)),
          child: Stack(alignment: Alignment.center, children: [
            Positioned(top: 12, child: arrow(0.25)),
            Positioned(bottom: 12, child: arrow(-0.25)),
            Positioned(left: 12, child: arrow(0)),
            Positioned(right: 12, child: arrow(0.5)),
            Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.5), blurRadius: 24)],
              ),
              child: Text('موافق', style: Fonts.body(18, p.onAccent, weight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 60),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [round('هوم'), const SizedBox(width: 38), round('رجوع')]),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [round('الصوت'), const SizedBox(width: 38), round('قائمة')]),
      ]),
    );
  }
}
