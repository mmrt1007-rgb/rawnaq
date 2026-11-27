import 'dart:math' as math;

import 'state.dart';
import 'weather.dart' show WeatherHub;

/// مواقيت الأذان للعراق فقط، بالحساب الفلكي المحلي (بدون إنترنت، لأي يوم بالسنة).
/// الافتراضي: طريقة جعفرية (الفجر ١٦°، المغرب ٤° بعد الغروب، منتصف الليل من الغروب للفجر)
/// مع تعديل بالدقائق لكل وقت حتى يطابق التقويم المعتمد (مثل تقويم الأنصاري).
class PrayerCity {
  final String id, name, province;
  final double lat, lon, elevation;
  const PrayerCity(this.id, this.name, this.lat, this.lon, [this.elevation = 30, this.province = '']);

  /// العراق فقط: كل المحافظات الثماني عشرة ومدن رئيسية بكل وحدة، بتوقيت بغداد (+٣ بدون صيفي).
  static const all = [
    PrayerCity('baghdad', 'بغداد', 33.3152, 44.3661, 34, 'بغداد'),
    PrayerCity('basra', 'البصرة', 30.5085, 47.7804, 5, 'البصرة'),
    PrayerCity('zubair', 'الزبير', 30.3892, 47.7019, 15, 'البصرة'),
    PrayerCity('qurnah', 'القرنة', 31.0156, 47.4317, 5, 'البصرة'),
    PrayerCity('faw', 'الفاو', 29.9758, 48.4725, 3, 'البصرة'),
    PrayerCity('amarah', 'العمارة', 31.8356, 47.144, 8, 'ميسان'),
    PrayerCity('aligharbi', 'علي الغربي', 32.4614, 46.6883, 20, 'ميسان'),
    PrayerCity('nasiriyah', 'الناصرية', 31.0439, 46.2576, 5, 'ذي قار'),
    PrayerCity('shatra', 'الشطرة', 31.4097, 46.1716, 10, 'ذي قار'),
    PrayerCity('rifai', 'الرفاعي', 31.7186, 46.1072, 12, 'ذي قار'),
    PrayerCity('najaf', 'النجف', 32.0003, 44.3354, 60, 'النجف'),
    PrayerCity('kufa', 'الكوفة', 32.0347, 44.4011, 30, 'النجف'),
    PrayerCity('karbala', 'كربلاء', 32.616, 44.0249, 30, 'كربلاء'),
    PrayerCity('hindiya', 'الهندية (طويريج)', 32.5442, 44.2208, 30, 'كربلاء'),
    PrayerCity('hillah', 'الحلة', 32.4637, 44.4199, 30, 'بابل'),
    PrayerCity('musayyib', 'المسيب', 32.7786, 44.29, 35, 'بابل'),
    PrayerCity('diwaniyah', 'الديوانية', 31.9929, 44.9258, 20, 'القادسية'),
    PrayerCity('shamiya', 'الشامية', 31.9631, 44.6006, 22, 'القادسية'),
    PrayerCity('samawah', 'السماوة', 31.3099, 45.2803, 10, 'المثنى'),
    PrayerCity('rumaitha', 'الرميثة', 31.5289, 45.2028, 12, 'المثنى'),
    PrayerCity('kut', 'الكوت', 32.5128, 45.8182, 20, 'واسط'),
    PrayerCity('suwaira', 'الصويرة', 32.9256, 44.7756, 30, 'واسط'),
    PrayerCity('numaniyah', 'النعمانية', 32.5603, 45.4258, 20, 'واسط'),
    PrayerCity('hay', 'الحي', 32.1714, 46.0431, 15, 'واسط'),
    PrayerCity('aziziyah', 'العزيزية', 32.9086, 45.0647, 25, 'واسط'),
    PrayerCity('baqubah', 'بعقوبة', 33.7466, 44.6437, 40, 'ديالى'),
    PrayerCity('samarra', 'سامراء', 34.1983, 43.8742, 70, 'صلاح الدين'),
    PrayerCity('tikrit', 'تكريت', 34.607, 43.677, 110, 'صلاح الدين'),
    PrayerCity('ramadi', 'الرمادي', 33.4258, 43.2992, 50, 'الأنبار'),
    PrayerCity('fallujah', 'الفلوجة', 33.35, 43.7833, 45, 'الأنبار'),
    PrayerCity('hit', 'هيت', 33.6417, 42.8261, 60, 'الأنبار'),
    PrayerCity('haditha', 'حديثة', 34.1397, 42.3783, 140, 'الأنبار'),
    PrayerCity('qaim', 'القائم', 34.3833, 41.05, 175, 'الأنبار'),
    PrayerCity('rutba', 'الرطبة', 33.0381, 40.2848, 615, 'الأنبار'),
    PrayerCity('kirkuk', 'كركوك', 35.4681, 44.3922, 350, 'كركوك'),
    PrayerCity('mosul', 'الموصل', 36.335, 43.1189, 223, 'نينوى'),
    PrayerCity('erbil', 'أربيل', 36.1911, 44.0092, 415, 'أربيل'),
    PrayerCity('sulaymaniyah', 'السليمانية', 35.5613, 45.4302, 882, 'السليمانية'),
    PrayerCity('halabja', 'حلبجة', 35.1778, 45.9861, 700, 'حلبجة'),
    PrayerCity('duhok', 'دهوك', 36.8669, 42.9503, 565, 'دهوك'),
    PrayerCity('zakho', 'زاخو', 37.1436, 42.682, 440, 'دهوك'),
  ];

  /// «تلقائي»: أقرب مدينة عراقية لموقع الشاشة (من شبكة البيت)، وإذا الموقع برّه العراق أو ما معروف: بغداد.
  static const auto = PrayerCity('auto', 'تلقائي (أقرب مدينة)', 33.3152, 44.3661, 34, 'حسب موقعك');

  /// العراق تقريباً بين خطي عرض ٢٩–٣٧٫٥ وطول ٣٨٫٥–٤٨٫٨
  static bool inIraq(double lat, double lon) => lat > 29 && lat < 37.5 && lon > 38.5 && lon < 48.8;

  static PrayerCity nearest(double lat, double lon) {
    var best = all.first;
    var bd = double.infinity;
    for (final c in all) {
      final d = math.pow(c.lat - lat, 2) + math.pow((c.lon - lon) * math.cos(lat * math.pi / 180), 2);
      if (d < bd) {
        bd = d.toDouble();
        best = c;
      }
    }
    return best;
  }

  static PrayerCity byId(String id) {
    if (id == 'auto') {
      final h = WeatherHub.here;
      if (h != null && inIraq(h.lat, h.lon)) return nearest(h.lat, h.lon);
      return all.first;
    }
    return all.firstWhere((c) => c.id == id, orElse: () => all.first);
  }

  /// اسم للعرض: المدينة والمحافظة (إذا تختلف).
  String get label => province.isEmpty || province == name ? name : '$name · $province';
}

class PrayerTime {
  final String id, name;
  final DateTime time;
  const PrayerTime(this.id, this.name, this.time);
}

class Prayers {
  static const names = {
    'imsak': 'الإمساك',
    'fajr': 'الفجر',
    'sunrise': 'الشروق',
    'dhuhr': 'الظهر',
    'sunset': 'الغروب',
    'maghrib': 'المغرب',
    'midnight': 'منتصف الليل',
  };

  /// أوقات يوم معيّن حسب الإعدادات.
  static List<PrayerTime> forDay(DateTime day) {
    final c = AppState.I.cfg;
    final city = PrayerCity.byId(c.s('prayer.city'));
    final raw = _compute(day, city, c.d('prayer.fajrAngle'), c.d('prayer.maghribAngle'));
    final next = _compute(day.add(const Duration(days: 1)), city, c.d('prayer.fajrAngle'), c.d('prayer.maghribAngle'));

    DateTime at(double hours, String id) {
      final base = DateTime(day.year, day.month, day.day);
      final adj = c.i('prayer.adj.$id');
      return base.add(Duration(seconds: (hours * 3600).round())).add(Duration(minutes: adj));
    }

    final fajr = at(raw['fajr']!, 'fajr');
    final sunset = at(raw['sunset']!, 'sunset');
    final nextFajr = at(next['fajr']! + 24, 'fajr');
    final midnight = sunset.add(Duration(seconds: nextFajr.difference(sunset).inSeconds ~/ 2))
        .add(Duration(minutes: c.i('prayer.adj.midnight')));
    final imsak = fajr.subtract(Duration(minutes: c.i('prayer.imsakMinutes')));

    final all = [
      PrayerTime('imsak', names['imsak']!, imsak),
      PrayerTime('fajr', names['fajr']!, fajr),
      PrayerTime('sunrise', names['sunrise']!, at(raw['sunrise']!, 'sunrise')),
      PrayerTime('dhuhr', names['dhuhr']!, at(raw['dhuhr']!, 'dhuhr')),
      PrayerTime('sunset', names['sunset']!, sunset),
      PrayerTime('maghrib', names['maghrib']!, at(raw['maghrib']!, 'maghrib')),
      PrayerTime('midnight', names['midnight']!, midnight),
    ];
    final shown = c.s('prayer.shown').split(',');
    return all.where((p) => shown.contains(p.id)).toList();
  }

  /// الوقت القادم (يلف لليوم التالي بعد آخر وقت).
  static PrayerTime? next(DateTime now) {
    final today = forDay(now);
    for (final p in today) {
      if (p.time.isAfter(now)) return p;
    }
    final tomorrow = forDay(now.add(const Duration(days: 1)));
    return tomorrow.isEmpty ? null : tomorrow.first;
  }

  // ---------- الحساب الفلكي ----------
  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
  static double _fix(double a, double b) {
    final r = a - b * (a / b).floorToDouble();
    return r < 0 ? r + b : r;
  }

  static double _julian(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() + (30.6001 * (m + 1)).floorToDouble() + d + b - 1524.5;
  }

  /// (الميل، معادلة الزمن) لليوم الجولياني.
  static (double, double) _sun(double jd) {
    final d = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _fix(_deg(math.atan2(math.cos(_rad(e)) * math.sin(_rad(l)), math.cos(_rad(l)))) / 15, 24);
    final decl = _deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l))));
    final eqt = q / 15 - ra;
    return (decl, eqt);
  }

  /// الأوقات بالساعات المحلية (بدون التعديلات).
  static Map<String, double> _compute(DateTime day, PrayerCity city, double fajrAngle, double maghribAngle) {
    const tz = 3.0; // توقيت العراق (بدون توقيت صيفي)
    final jd = _julian(day.year, day.month, day.day) - city.lon / (15 * 24);
    final lat = city.lat;

    double midDay(double t) {
      final eqt = _sun(jd + t).$2;
      return _fix(12 - eqt, 24);
    }

    double angleTime(double angle, double t, bool before) {
      final decl = _sun(jd + t).$1;
      final noon = midDay(t);
      final cosT = (-math.sin(_rad(angle)) - math.sin(_rad(decl)) * math.sin(_rad(lat))) /
          (math.cos(_rad(decl)) * math.cos(_rad(lat)));
      final tt = _deg(math.acos(cosT.clamp(-1.0, 1.0))) / 15;
      return noon + (before ? -tt : tt);
    }

    final riseSet = 0.833 + 0.0347 * math.sqrt(city.elevation);
    var t = {'fajr': 5.0, 'sunrise': 6.0, 'dhuhr': 12.0, 'sunset': 18.0, 'maghrib': 18.0};
    for (var i = 0; i < 2; i++) {
      t = {
        'fajr': angleTime(fajrAngle, t['fajr']! / 24, true),
        'sunrise': angleTime(riseSet, t['sunrise']! / 24, true),
        'dhuhr': midDay(t['dhuhr']! / 24),
        'sunset': angleTime(riseSet, t['sunset']! / 24, false),
        'maghrib': angleTime(maghribAngle, t['maghrib']! / 24, false),
      };
    }
    return t.map((k, v) => MapEntry(k, v + tz - city.lon / 15));
  }
}
