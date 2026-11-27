import 'package:flutter/material.dart';

import '../arabic.dart';
import '../state.dart';
import '../widgets.dart';

/// محرر لون بالريموت: ألوان جاهزة + ضبط دقيق للدرجة والتشبع والإضاءة.
Future<Color?> showColorEditor(BuildContext context, {required String title, required Color initial}) =>
    showDialog<Color>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _ColorEditor(title: title, initial: initial),
      ),
    );

class _ColorEditor extends StatefulWidget {
  final String title;
  final Color initial;
  const _ColorEditor({required this.title, required this.initial});

  @override
  State<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends State<_ColorEditor> {
  late HSLColor _hsl;

  static const _swatches = [
    0xFFFFFFFF, 0xFFF4EFE6, 0xFFEADFC9, 0xFFE2D6BF, 0xFFC8902E, 0xFFD9B26A, 0xFFE8D3A4,
    0xFFB5483F, 0xFFA4482B, 0xFFE48A63, 0xFF8E3329, 0xFF5A3C86, 0xFF5B3F8C, 0xFFC8A6F0,
    0xFF0F6E6A, 0xFF1E6B52, 0xFF3E7D5A, 0xFF1F6F5C, 0xFF1D5C96, 0xFF5FB0E6, 0xFF2F4E7E,
    0xFF9AA3B8, 0xFF5E6A68, 0xFF263055, 0xFF141B33, 0xFF0B1020, 0xFF05070D, 0xFF000000,
  ];

  @override
  void initState() {
    super.initState();
    _hsl = HSLColor.fromColor(widget.initial);
  }

  Color get _color => _hsl.toColor();

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return themedDialog(
      width: 1180,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 1180,
        child: Padding(
          padding: const EdgeInsets.all(44),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // المعاينة
            Column(children: [
              AnimatedContainer(
                duration: AppState.I.anim(150),
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: p.line, width: 2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                style: Fonts.body(24, p.muted),
              ),
              const SizedBox(height: 8),
              Container(
                width: 260,
                height: 56,
                decoration: BoxDecoration(color: widget.initial, borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Text('السابق', style: Fonts.body(20, _readable(widget.initial))),
              ),
            ]),
            const SizedBox(width: 44),
            // التحكم
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 820),
                child: AxisClip(axis: Axis.vertical, child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(widget.title, style: Fonts.title(32, p.ink)),
                    const SizedBox(height: 20),
                    Wrap(spacing: 14, runSpacing: 14, children: [
                      for (final (i, v) in _swatches.indexed)
                        FocusTap(
                          autofocus: i == 0,
                          onTap: () => setState(() => _hsl = HSLColor.fromColor(Color(v))),
                          builder: (context, f) => AnimatedContainer(
                            duration: AppState.I.anim(140),
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Color(v),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: f ? p.ring : p.line, width: f ? 5 : 1), boxShadow: royalShadows(p, f),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 24),
                    StepRow(
                      title: 'الدرجة',
                      value: _hsl.hue,
                      min: 0,
                      max: 359,
                      step: 3,
                      format: (v) => '${Ar.n(v.round())}°',
                      onChanged: (v) => setState(() => _hsl = _hsl.withHue(v)),
                    ),
                    StepRow(
                      title: 'التشبع',
                      value: _hsl.saturation,
                      min: 0,
                      max: 1,
                      step: 0.02,
                      format: fmtPct,
                      onChanged: (v) => setState(() => _hsl = _hsl.withSaturation(v)),
                    ),
                    StepRow(
                      title: 'الإضاءة',
                      value: _hsl.lightness,
                      min: 0,
                      max: 1,
                      step: 0.02,
                      format: fmtPct,
                      onChanged: (v) => setState(() => _hsl = _hsl.withLightness(v)),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      PillButton('حفظ اللون', primary: true, onTap: () => Navigator.pop(context, _color)),
                      const SizedBox(width: 16),
                      PillButton('إلغاء', onTap: () => Navigator.pop(context)),
                    ]),
                  ]),
                )),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Color _readable(Color c) => c.computeLuminance() > 0.45 ? Colors.black : Colors.white;
}
