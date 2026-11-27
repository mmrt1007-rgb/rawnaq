import 'package:flutter/material.dart';

import 'fonts_available.dart';
import 'state.dart';

/// الخطوط المضمّنة داخل التطبيق (تعمل بدون إنترنت).
class FontCatalog {
  static List<String> get all => availableFonts;

  static bool has(String family) => availableFonts.contains(family);

  static const _arabicNames = {
    'Amiri': 'الأميري',
    'Amiri Quran': 'الأميري قرآن',
    'Aref Ruqaa': 'عارف رقعة',
    'Aref Ruqaa Ink': 'رقعة الحبر',
    'Reem Kufi': 'ريم كوفي',
    'Reem Kufi Fun': 'ريم كوفي مرح',
    'IBM Plex Sans Arabic': 'بلكس عربي',
    'Cairo': 'القاهرة',
    'Tajawal': 'تجوال',
    'Almarai': 'المراعي',
    'Noto Naskh Arabic': 'نوتو نسخ',
    'Noto Kufi Arabic': 'نوتو كوفي',
    'Noto Sans Arabic': 'نوتو سانس',
    'Noto Nastaliq Urdu': 'نستعليق',
    'Lateef': 'لطيف',
    'Scheherazade New': 'شهرزاد',
    'Harmattan': 'هرمتان',
    'Markazi Text': 'مركزي',
    'El Messiri': 'المسيري',
    'Changa': 'چنگا',
    'Lalezar': 'لاله‌زار',
    'Rakkas': 'رقّاص',
    'Mada': 'مدى',
    'Readex Pro': 'ريدكس',
    'Kufam': 'كوفام',
    'Baloo Bhaijaan 2': 'بالو بهيجان',
    'Marhey': 'مرحي',
    'Vibes': 'فايبز',
    'Lemonada': 'ليموناضة',
    'Katibeh': 'كاتبة',
    'Mirza': 'ميرزا',
    'Jomhuria': 'جمهورية',
    'Blaka': 'بلاكا',
    'Gulzar': 'گلزار',
    'Alkalami': 'القلمي',
    'Rubik': 'روبيك',
    'Zain': 'زين',
    'Qahiri': 'قاهري',
    'Badeen Display': 'بديع',
    'Playpen Sans Arabic': 'بلايبن',
    'Handjet': 'هاندجت',
  };

  static String label(String family) => _arabicNames[family] ?? family;
}

/// أنماط النصوص. كل نص بالواجهة يمر من هنا، فتغيير الخط أو الحجم ينعكس على الكل.
class Fonts {
  static double get scale => AppState.I.cfg.d('font.scale') * AppState.I.cfg.d('a11y.textScale');

  static FontWeight _w(FontWeight? w) {
    if (w != null) return w;
    final base = AppState.I.cfg.i('font.weight');
    return FontWeight.values.firstWhere((x) => x.value == base, orElse: () => FontWeight.w400);
  }

  static TextStyle family(String fam, double size, Color color, {FontWeight? weight, double height = 1.3}) =>
      TextStyle(
        fontFamily: FontCatalog.has(fam) ? fam : null,
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w400,
        height: height,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// نصوص الواجهة العامة (تتأثر بمقياس الخط العام).
  static TextStyle body(double size, Color color, {FontWeight? weight}) =>
      family(AppState.I.cfg.s('font.ui'), size * scale, color, weight: _w(weight));

  /// العناوين.
  static TextStyle title(double size, Color color, {FontWeight weight = FontWeight.w700}) =>
      family(AppState.I.cfg.s('font.title'), size * scale, color, weight: weight, height: 1.25);

  /// الساعة (حجمها مستقل بإعداد خاص).
  static TextStyle clock(double size, Color color, {FontWeight weight = FontWeight.w700, String? fam}) =>
      family(fam ?? AppState.I.cfg.s('font.clock'), size, color, weight: weight, height: 1.0);
}
