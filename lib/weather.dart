import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'arabic.dart';
import 'state.dart';

// ═══════════════════ الطقس المختصر (شريط الواجهة وشاشة السكون) ═══════════════════

/// حالة الطقس الحالية (للواجهة وشاشة السكون). تنبني من نفس توقعات شاشة الطقس،
/// فالواجهة وشاشة الطقس يحچون نفس الحالة دائماً.
class Weather {
  final String place;
  final int temp, max, min, code;
  final bool isDay;
  final String? _sky, _desc;

  const Weather({
    required this.place,
    required this.temp,
    required this.max,
    required this.min,
    required this.code,
    required this.isDay,
    String? sky,
    String? desc,
  })  : _sky = sky,
        _desc = desc;

  factory Weather.fromForecast(Forecast f) => Weather(
        place: f.city.name,
        temp: f.temp,
        code: f.code,
        isDay: f.isDay,
        max: f.days.isEmpty ? f.temp : f.days.first.max,
        min: f.days.isEmpty ? f.temp : f.days.first.min,
        sky: f.kind,
        desc: f.description,
      );

  /// وصف عربي (نفس وصف شاشة الطقس).
  String get description => _desc ?? wxDescription(code, isDay, 0);

  /// نوع المشهد الحي: clear partly cloudy fog drizzle rain storm snow dust
  String get sky => _sky ?? wxKind(code, null);

  /// نوع الأيقونة المختصر: sun / moon / cloud / rain / storm / fog / dust
  String get kind => switch (sky) {
        'clear' => isDay ? 'sun' : 'moon',
        'partly' || 'cloudy' => 'cloud',
        'fog' => 'fog',
        'dust' => 'dust',
        'storm' => 'storm',
        _ => 'rain',
      };
}

/// يجلب الطقس المختصر من Open-Meteo (مجاني وبدون مفتاح).
class WeatherService {
  static const _timeout = Duration(seconds: 12);

  static Future<Weather?> fetch({String? city}) async {
    try {
      WxCity? loc;
      if (city != null && city.trim().isNotEmpty) {
        final r = await WeatherHub.search(city.trim());
        loc = r.isEmpty ? null : r.first;
      } else {
        // نفس أول مدينة بشاشة الطقس (موقعك أو أول مدينة محفوظة)
        final list = WeatherHub.cities;
        loc = list.isNotEmpty ? list.first : await WeatherHub.locate();
      }
      if (loc == null) return null;
      final f = await WeatherHub.load(loc);
      if (f == null) return null;
      return Weather.fromForecast(f);
    } catch (_) {
      return null;
    }
  }

  static Duration get timeout => _timeout;
}

// ═══════════════════ النموذج الكامل ═══════════════════

/// مدينة محفوظة أو الموقع الحالي.
class WxCity {
  final String name, region;
  final double lat, lon;
  final bool auto;
  const WxCity(this.name, this.lat, this.lon, {this.region = '', this.auto = false});

  String get key => auto ? 'auto' : '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

  Map<String, Object> toJson() => {'n': name, 'r': region, 'a': lat, 'o': lon};

  static WxCity? fromJson(Object? j) {
    if (j is! Map) return null;
    final a = j['a'], o = j['o'];
    if (a is! num || o is! num) return null;
    return WxCity('${j['n'] ?? ''}', a.toDouble(), o.toDouble(), region: '${j['r'] ?? ''}');
  }
}

class WxHour {
  final DateTime t;
  final int temp, code, pop;
  final bool day;
  final double visKm;
  final int? pm10;
  const WxHour(this.t, this.temp, this.code, this.pop, this.day, this.visKm, this.pm10);
}

class WxDay {
  final DateTime d;
  final int code, max, min, pop, uv;
  final double rain;
  final DateTime? sunrise, sunset;
  const WxDay(this.d, this.code, this.max, this.min, this.pop, this.rain, this.uv, this.sunrise, this.sunset);
}

/// توقعات مدينة كاملة.
class Forecast {
  final WxCity city;
  final DateTime fetched, local; // local = وقت المدينة نفسها
  final int temp, feels, code, humidity, pop, uv, pressure;
  final bool isDay;
  final double wind, gust, windFrom, visKm, rainNow;
  final int? aqi, pm10, dust;
  final List<WxHour> hours;
  final List<WxDay> days;
  final List<double> next2h; // ٨ قيم كل ربع ساعة (ملم)

  const Forecast({
    required this.city,
    required this.fetched,
    required this.local,
    required this.temp,
    required this.feels,
    required this.code,
    required this.humidity,
    required this.pop,
    required this.uv,
    required this.pressure,
    required this.isDay,
    required this.wind,
    required this.gust,
    required this.windFrom,
    required this.visKm,
    required this.rainNow,
    required this.aqi,
    required this.pm10,
    required this.dust,
    required this.hours,
    required this.days,
    required this.next2h,
  });

  /// نوع المشهد: clear partly cloudy fog drizzle rain storm snow dust
  String get kind => wxKind(code, _dusty ? 300 : null);

  /// العجاج الحقيقي: نماذج الغبار تبالغ كثير بالعراق حتى والسماء صافية، فما نعتبرها
  /// عجاج إلا إذا الرؤية نفسها قلّت فعلاً (مثل ما تشوفه من الشباك).
  bool get _dusty {
    final d = dust ?? 0, p = pm10 ?? 0;
    return (visKm < 5 && (d >= 100 || p >= 250)) || (visKm < 8 && (d >= 400 || p >= 500));
  }
  String get description => kind == 'dust' ? 'غبار وعجاج' : wxDescription(code, isDay, rainNow);

  /// اتجاه حركة الغيوم على الشاشة: +١ يمين (شرقاً)، −١ يسار (غرباً).
  double get screenDir {
    final s = math.sin(windFrom * math.pi / 180);
    if (s.abs() < 0.2) return 1;
    return s < 0 ? 1 : -1;
  }

  /// قوة الريح للحركة (٠٫٤ هادئ … ١٫٨ عاصف).
  double get windK => (0.4 + wind / 30).clamp(0.4, 1.8);

  /// شدة الهطول للمشهد (٠ … ١٫٥).
  double get intensity {
    if (kind == 'storm') return 1.5;
    if (kind == 'drizzle') return 0.35;
    if (kind != 'rain' && kind != 'snow') return 0;
    final r = math.max(rainNow, next2h.isEmpty ? 0.0 : next2h.reduce(math.max) * 4);
    if (r <= 0) return 0.6;
    return (0.4 + r / 6).clamp(0.4, 1.4);
  }

  String get windFromName => wxWindName(windFrom);
}

// ═══════════════════ التصنيف والنصوص ═══════════════════

String wxKind(int code, int? dust) {
  var k = switch (code) {
    0 || 1 => 'clear',
    2 => 'partly',
    3 => 'cloudy',
    45 || 48 => 'fog',
    >= 51 && <= 57 => 'drizzle',
    >= 61 && <= 67 => 'rain',
    >= 80 && <= 82 => 'rain',
    >= 71 && <= 77 => 'snow',
    85 || 86 => 'snow',
    >= 95 => 'storm',
    _ => 'cloudy',
  };
  if (dust != null && dust > 150 && (k == 'clear' || k == 'partly' || k == 'cloudy')) k = 'dust';
  return k;
}

String wxDescription(int code, bool day, double rainNow) {
  if (code == 0) return day ? 'مشمس وصافي' : 'صافي ونجوم';
  if (code == 1) return day ? 'مشمس' : 'صافي';
  if (code == 2) return 'غائم جزئياً';
  if (code == 3) return 'غائم';
  if (code == 45 || code == 48) return 'ضباب';
  if (code >= 51 && code <= 57) return 'رذاذ خفيف';
  if (code >= 80 && code <= 82) return 'زخات مطر';
  if (code >= 61 && code <= 67) {
    if (code == 65 || rainNow >= 7.6) return 'مطر غزير';
    if (code == 63 || rainNow >= 2.5) return 'مطر متوسط';
    return 'مطر خفيف';
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return 'ثلج';
  if (code >= 95) return 'عاصفة رعدية';
  return 'متقلب';
}

String wxWindName(double from) {
  const names = ['شمالية', 'شمالية شرقية', 'شرقية', 'جنوبية شرقية', 'جنوبية', 'جنوبية غربية', 'غربية', 'شمالية غربية'];
  return names[((from % 360) / 45).round() % 8];
}

/// اسم أيقونة Lucide المناسبة للحالة.
String wxIconName(String kind, bool day) => switch (kind) {
      'clear' => day ? 'sun-medium' : 'moon',
      'partly' => day ? 'cloud-sun' : 'cloud-moon',
      'cloudy' => 'cloudy',
      'fog' => 'cloud-fog',
      'drizzle' => 'cloud-drizzle',
      'rain' => day ? 'cloud-rain' : 'cloud-moon-rain',
      'storm' => 'cloud-lightning',
      'snow' => 'cloud-snow',
      'dust' => 'haze',
      _ => 'cloudy',
    };

String wxHourLabel(DateTime t, {bool first = false}) {
  if (first) return 'الآن';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final p = t.hour == 12 ? 'ظ' : (t.hour < 12 ? 'ص' : 'م');
  return '${Ar.n(h)} $p';
}

String wxTime(DateTime t) => '${Ar.time(t)} ${t.hour < 12 ? 'ص' : 'م'}';

// ═══════════════════ المركز: المدن والتحميل والتخزين المؤقت ═══════════════════

class WeatherHub {
  static const _timeout = Duration(seconds: 14);
  static final ValueNotifier<int> rev = ValueNotifier(0);
  static final Map<String, Forecast> data = {};
  static final Set<String> _loading = {};
  static WxCity? here;
  static bool offline = false;
  static Timer? _timer;

  static List<WxCity> get saved {
    try {
      final l = jsonDecode(AppState.I.cfg.s('weather.cities'));
      if (l is List) return l.map(WxCity.fromJson).whereType<WxCity>().toList();
    } catch (_) {}
    return [];
  }

  static void setSaved(List<WxCity> l) {
    AppState.I.set('weather.cities', jsonEncode([for (final c in l) c.toJson()]));
    rev.value++;
  }

  /// المدن بالترتيب: الموقع الحالي أولاً ثم المحفوظة.
  static List<WxCity> get cities {
    final out = <WxCity>[];
    if (AppState.I.cfg.b('weather.auto') && here != null) out.add(here!);
    for (final c in saved) {
      if (here != null && (c.lat - here!.lat).abs() < 0.05 && (c.lon - here!.lon).abs() < 0.05 && out.isNotEmpty) continue;
      out.add(c);
    }
    return out;
  }

  /// التحديث كل [weather.refresh] دقيقة (الأصل ١٥، والحد الأقصى ساعة).
  static void start() {
    restartTimer();
    refreshAll();
  }

  static void restartTimer() {
    _timer?.cancel();
    final m = AppState.I.cfg.i('weather.refresh').clamp(5, 60);
    _timer = Timer.periodic(Duration(minutes: m), (_) => refreshAll());
  }

  /// آخر تحديث فعلي (لأي مدينة).
  static DateTime? get lastUpdate {
    DateTime? t;
    for (final f in data.values) {
      if (t == null || f.fetched.isAfter(t)) t = f.fetched;
    }
    return t;
  }

  static Future<void> refreshAll() async {
    if (AppState.I.cfg.b('weather.auto')) await locate();
    for (final c in cities) {
      await load(c, force: true);
    }
    unawaited(AppState.I.refreshWeather());
  }

  /// الموقع الحالي من عنوان الإنترنت (الستريمر ما بيه GPS).
  static Future<WxCity?> locate() async {
    try {
      final res = await http.get(Uri.parse('https://ipwho.is/?lang=ar')).timeout(_timeout);
      if (res.statusCode != 200) return here;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['success'] != true) return here;
      final city = (j['city'] as String?) ?? '';
      final region = (j['region'] as String?) ?? '';
      final country = (j['country'] as String?) ?? '';
      here = WxCity(city.isEmpty ? region : city, (j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble(),
          region: [region, country].where((e) => e.isNotEmpty && e != city).join('، '), auto: true);
      offline = false;
      rev.value++;
      return here;
    } catch (_) {
      return here;
    }
  }

  /// بحث بالاسم (عربي أو إنكليزي).
  static Future<List<WxCity>> search(String q) async {
    if (q.trim().length < 2) return [];
    try {
      final uri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(q.trim())}&count=8&language=ar');
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return [];
      final results = (jsonDecode(res.body) as Map<String, dynamic>)['results'] as List?;
      offline = false;
      if (results == null) return [];
      return [
        for (final r in results.cast<Map<String, dynamic>>())
          WxCity(
            '${r['name'] ?? ''}',
            (r['latitude'] as num).toDouble(),
            (r['longitude'] as num).toDouble(),
            region: [r['admin1'], r['country']].whereType<String>().where((e) => e.isNotEmpty && e != r['name']).join('، '),
          ),
      ];
    } catch (_) {
      offline = true;
      rev.value++;
      return [];
    }
  }

  static Forecast? of(WxCity c) => data[c.key];

  static Future<Forecast?> load(WxCity c, {bool force = false}) async {
    final old = data[c.key];
    if (!force && old != null && DateTime.now().difference(old.fetched).inMinutes < 10) return old;
    if (_loading.contains(c.key)) return old;
    _loading.add(c.key);
    try {
      final f = await _fetch(c);
      if (f != null) {
        data[c.key] = f;
        offline = false;
      }
      return f ?? old;
    } catch (_) {
      offline = true;
      return old;
    } finally {
      _loading.remove(c.key);
      rev.value++;
    }
  }

  static int _i(Object? v) => v is num ? v.round() : 0;
  static double _d(Object? v) => v is num ? v.toDouble() : 0;

  static Future<Forecast?> _fetch(WxCity c) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${c.lat}&longitude=${c.lon}'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,precipitation'
        '&hourly=temperature_2m,weather_code,precipitation_probability,visibility,is_day,uv_index'
        '&minutely_15=precipitation&forecast_minutely_15=8'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,sunrise,sunset,uv_index_max'
        '&timezone=auto&forecast_days=10');
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final offset = _i(j['utc_offset_seconds']);
    final local = DateTime.now().toUtc().add(Duration(seconds: offset));
    final localNaive = DateTime(local.year, local.month, local.day, local.hour, local.minute);
    final cur = (j['current'] as Map<String, dynamic>?) ?? const {};
    final h = (j['hourly'] as Map<String, dynamic>?) ?? const {};
    final d = (j['daily'] as Map<String, dynamic>?) ?? const {};
    final m15 = (j['minutely_15'] as Map<String, dynamic>?) ?? const {};

    // جودة الهواء والغبار (اختياري)
    int? aqi, pm10, dust;
    final pmHourly = <String, int>{};
    try {
      final aq = await http
          .get(Uri.parse('https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${c.lat}&longitude=${c.lon}&current=us_aqi,pm10,dust&hourly=pm10&timezone=auto&forecast_days=2'))
          .timeout(_timeout);
      if (aq.statusCode == 200) {
        final a = jsonDecode(aq.body) as Map<String, dynamic>;
        final ac = (a['current'] as Map<String, dynamic>?) ?? const {};
        aqi = ac['us_aqi'] is num ? _i(ac['us_aqi']) : null;
        pm10 = ac['pm10'] is num ? _i(ac['pm10']) : null;
        dust = ac['dust'] is num ? _i(ac['dust']) : null;
        final ah = (a['hourly'] as Map<String, dynamic>?) ?? const {};
        final at = (ah['time'] as List?) ?? const [];
        final ap = (ah['pm10'] as List?) ?? const [];
        for (var i = 0; i < at.length && i < ap.length; i++) {
          if (ap[i] is num) pmHourly['${at[i]}'] = _i(ap[i]);
        }
      }
    } catch (_) {}

    final times = (h['time'] as List?) ?? const [];
    var start = 0;
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t != null && !t.isBefore(DateTime(localNaive.year, localNaive.month, localNaive.day, localNaive.hour))) {
        start = i;
        break;
      }
    }
    List<dynamic> hl(String k) => (h[k] as List?) ?? const [];
    final hours = <WxHour>[];
    for (var i = start; i < times.length && hours.length < 24; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t == null) continue;
      hours.add(WxHour(
        t,
        _i(hl('temperature_2m').elementAtOrNull(i)),
        _i(hl('weather_code').elementAtOrNull(i)),
        _i(hl('precipitation_probability').elementAtOrNull(i)),
        _i(hl('is_day').elementAtOrNull(i)) == 1,
        // الرؤية إذا ما وصلت نعتبرها مفتوحة (٢٤ كم) حتى ما تطلع عجاج أو ضباب بالغلط
        (hl('visibility').elementAtOrNull(i) is num) ? _d(hl('visibility').elementAtOrNull(i)) / 1000 : 24.0,
        pmHourly['${times[i]}'],
      ));
    }
    List<dynamic> dl(String k) => (d[k] as List?) ?? const [];
    final days = <WxDay>[];
    final dt = dl('time');
    for (var i = 0; i < dt.length; i++) {
      final t = DateTime.tryParse('${dt[i]}');
      if (t == null) continue;
      days.add(WxDay(
        t,
        _i(dl('weather_code').elementAtOrNull(i)),
        _i(dl('temperature_2m_max').elementAtOrNull(i)),
        _i(dl('temperature_2m_min').elementAtOrNull(i)),
        _i(dl('precipitation_probability_max').elementAtOrNull(i)),
        _d(dl('precipitation_sum').elementAtOrNull(i)),
        _i(dl('uv_index_max').elementAtOrNull(i)),
        DateTime.tryParse('${dl('sunrise').elementAtOrNull(i)}'),
        DateTime.tryParse('${dl('sunset').elementAtOrNull(i)}'),
      ));
    }
    final next2h = [for (final v in (m15['precipitation'] as List?) ?? const []) _d(v)];
    return Forecast(
      city: c,
      fetched: DateTime.now(),
      local: localNaive,
      temp: _i(cur['temperature_2m']),
      feels: _i(cur['apparent_temperature']),
      code: _i(cur['weather_code']),
      humidity: _i(cur['relative_humidity_2m']),
      pop: hours.isEmpty ? 0 : hours.first.pop,
      uv: _i(hl('uv_index').elementAtOrNull(start)),
      pressure: _i(cur['surface_pressure']),
      isDay: _i(cur['is_day']) == 1,
      wind: _d(cur['wind_speed_10m']),
      gust: _d(cur['wind_gusts_10m']),
      windFrom: _d(cur['wind_direction_10m']),
      visKm: hours.isEmpty ? 10 : hours.first.visKm,
      rainNow: _d(cur['precipitation']),
      aqi: aqi,
      pm10: pm10,
      dust: dust,
      hours: hours,
      days: days,
      next2h: next2h,
    );
  }
}
