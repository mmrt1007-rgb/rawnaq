import 'package:hijri/hijri_calendar.dart';

/// أدوات التاريخ والأرقام العربية بالتسميات العراقية.
class Ar {
  static const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static const months = [
    'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
    'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
  ];

  static const hijriMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  // DateTime.weekday: 1 = الاثنين ... 7 = الأحد
  static const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  static String n(Object value) =>
      value.toString().split('').map((c) {
        final d = int.tryParse(c);
        return d == null ? c : _digits[d];
      }).join();

  static String time(DateTime t, {bool h24 = false}) {
    final h = h24 ? t.hour : (t.hour % 12 == 0 ? 12 : t.hour % 12);
    final hs = h24 ? h.toString().padLeft(2, '0') : h.toString();
    return '${n(hs)}:${n(t.minute.toString().padLeft(2, '0'))}';
  }

  static String period(DateTime t) => t.hour < 12 ? 'صباحاً' : 'مساءً';

  static String greeting(DateTime t) {
    if (t.hour >= 4 && t.hour < 12) return 'صباح النور';
    if (t.hour >= 12 && t.hour < 17) return 'طاب يومك';
    return 'مساء النور';
  }

  static String dayName(DateTime t) => days[t.weekday - 1];

  static String gregorian(DateTime t) => '${n(t.day)} ${months[t.month - 1]} ${n(t.year)}';

  /// [offset] تصحيح يدوي بالأيام حتى يطابق رؤية الهلال المحلية.
  static String hijri(DateTime t, int offset) {
    final h = HijriCalendar.fromDate(t.add(Duration(days: offset)));
    return '${n(h.hDay)} ${hijriMonths[h.hMonth - 1]} ${n(h.hYear)} هـ';
  }
}
