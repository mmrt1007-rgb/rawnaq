import 'package:flutter/material.dart';

import '../fonts.dart';
import '../state.dart';
import '../widgets.dart';
import '../lucide.dart';

/// اختيار خط: كل خط يُعرض بنفسه مع جملة تجربة.
Future<String?> showFontPicker(BuildContext context, {required String title, required String current}) =>
    showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        final p = pal;
        final fonts = FontCatalog.all;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: themedDialog(
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 1240,
              height: 900,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(44, 40, 44, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(title, style: Fonts.title(32, p.ink))),
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text('${fonts.length} خط', style: Fonts.body(22, p.muted)))),
                  ]),
                  const SizedBox(height: 20),
                  if (fonts.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'الخطوط تنضاف للتطبيق وقت البناء من الحاسبة.\nشغّل install.bat والحاسبة متصلة بالإنترنت.',
                          textAlign: TextAlign.center,
                          style: Fonts.body(26, p.muted),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: AxisClip(axis: Axis.vertical, child: ListView.builder(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        itemCount: fonts.length,
                        itemBuilder: (_, i) {
                          final f = fonts[i];
                          final selected = f == current;
                          return FocusTap(
                            autofocus: selected || (i == 0 && !fonts.contains(current)),
                            onTap: () => Navigator.pop(ctx, f),
                            builder: (context, focused) => AnimatedContainer(
                              duration: AppState.I.anim(150),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                              decoration: BoxDecoration(
                                color: selected ? p.accent.withValues(alpha: 0.14) : (p.glass ? p.surface : p.bg),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: focused ? p.ring : p.line, width: focused ? ringW : 1),
                              ),
                              child: Row(children: [
                                SizedBox(
                                  width: 300,
                                  child: FitText(
                                    FontCatalog.label(f),
                                    style: Fonts.family(f, 34, p.ink, weight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: FitText(
                                    'رونق ١٢:٣٠ · بسم الله الرحمن الرحيم',
                                    style: Fonts.family(f, 34, p.muted),
                                  ),
                                ),
                                if (selected) AppIcon(Lu.circleCheck, color: p.accent, size: 34),
                              ]),
                            ),
                          );
                        },
                      )),
                    ),
                ]),
              ),
            ),
          ),
        );
      },
    );
