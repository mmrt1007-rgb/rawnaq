import 'package:flutter/material.dart';

import '../arabic.dart';
import '../lucide.dart';
import '../brand.dart';
import '../platform.dart';
import '../state.dart';
import '../widgets.dart';
import 'settings_preview.dart' show kAppVersion;

/// حول رونق — مطابقة لفيكما (صفحة ٠٦): العلامة يسار، والتفاصيل يمين (الجهاز ثم الحقوق والمصادر).
/// شاشة عرض فقط: رجوع يطلع منها.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Map<String, dynamic> _st = const {};

  @override
  void initState() {
    super.initState();
    NativeBridge.systemStatus().then((v) {
      if (mounted) setState(() => _st = v);
    });
  }

  int _i(String k) => (_st[k] as int?) ?? 0;
  String _gb(int mb) => mb >= 1024 ? '${Ar.n((mb / 1024).toStringAsFixed(1))} GB' : '${Ar.n(mb)} MB';

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final p = s.palette;
    final ramT = _i('ramTotal'), ramF = _i('ramFree'), stT = _i('storageTotal'), stF = _i('storageFree');
    final ip = (_st['ip'] as String?) ?? '';
    final device = <(Object, String, String)>[
      (Lu.tv, 'الجهاز', s.model.isEmpty ? 'أندرويد TV' : s.model),
      (Lu.monitor, 'الشاشة', '${s.screenInches != null ? '${Ar.n(s.screenInches!.round())} بوصة · ' : ''}${Ar.n(s.screenW)} × ${Ar.n(s.screenH)}'),
      (Lu.cpu, 'النظام', 'Android · SDK ${Ar.n(s.sdk)}'),
      (Lu.memory, 'الذاكرة', ramT > 0 ? '${_gb(ramT)} · متاح ${Ar.n((ramF / ramT * 100).round())}٪' : '${Ar.n((s.ramMb / 1024).toStringAsFixed(1))} GB'),
      (Lu.drive, 'التخزين', stT > 0 ? '${_gb(stT)} · متاح ${_gb(stF)}' : '—'),
      (Lu.network, 'عنوان الشبكة', ip.isEmpty ? '—' : ip),
    ];
    const rights = <(Object, String, String)>[
      (Lu.shapes, 'الأيقونات', 'Lucide · ISC'),
      (Lu.type, 'الخطوط', 'Google Fonts · OFL'),
      (Lu.images, 'الخلفيات', 'ويكيميديا كومنز · رخص حرة'),
      (Lu.landmark, 'مواقيت الصلاة', 'حساب فلكي محلي'),
    ];

    Widget row((Object, String, String) r) => Container(
          height: 58,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
          child: Row(children: [
            AppIcon(r.$1, color: p.accent, size: 26),
            const SizedBox(width: 14),
            SizedBox(width: 190, child: FitText(r.$2, style: Fonts.body(21, p.muted))),
            const SizedBox(width: 12),
            Expanded(child: FitText(r.$3, alignment: AlignmentDirectional.centerEnd, style: Fonts.body(22, p.ink, weight: FontWeight.w600))),
          ]),
        );

    return ThemedScaffold(
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(112, 60, 112, 60),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // التفاصيل (يمين)
            SizedBox(
              width: 840,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('حول رونق', style: Fonts.title(48, p.ink)),
                const SizedBox(height: 22),
                Text('الجهاز', style: Fonts.body(20, p.muted)),
                const SizedBox(height: 10),
                for (final r in device) row(r),
                const SizedBox(height: 16),
                Text('الحقوق والمصادر', style: Fonts.body(20, p.muted)),
                const SizedBox(height: 10),
                for (final r in rights) row(r),
              ]),
            ),
            const Spacer(),
            // العلامة (يسار)
            SizedBox(
              width: 760,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                RawnaqLockup(markSize: 230, night: p.night, stacked: true, glow: true),
                const SizedBox(height: 8),
                SizedBox(
                  width: 760,
                  child: FitText('واجهة رئيسية عربية أنيقة لشاشات أندرويد TV', alignment: Alignment.center, style: Fonts.body(28, p.muted)),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: p.ring, width: 1.5)),
                  child: Text('الإصدار ${Ar.n(kAppVersion)} · رجوع للخروج', style: Fonts.body(21, p.accent, weight: FontWeight.w600)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
