import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'build_info.dart';

/// محرك الإعدادات: كل خاصية بالواجهة لها مفتاح وقيمة افتراضية.
/// يُحفظ فقط ما يختلف عن الافتراضي، فإعادة الضبط = حذف المفتاح.
class Config {
  final Map<String, Object> _v = {};
  SharedPreferences? _p;

  static final Map<String, Object> defaults = {..._base, ..._freeLayout()};

  /// مواضع العناصر الافتراضية بالتخطيط الحر لشاشة السكون (x,y من −١ إلى ١، والحجم).
  static Map<String, Object> _freeLayout() {
    const pos = {
      'day': (0.92, 0.05),
      'clock': (0.92, 0.32),
      'date': (0.92, 0.56),
      'hijri': (0.92, 0.66),
      'next': (0.92, 0.80),
      'prayers': (0.0, 1.0),
      'weather': (-0.92, -1.0),
      'text': (0.0, -1.0),
      'countdown': (-0.92, 0.70),
    };
    return {
      for (final e in pos.entries) ...{
        'saver.el.${e.key}.x': e.value.$1,
        'saver.el.${e.key}.y': e.value.$2,
        'saver.el.${e.key}.scale': 1.0,
      },
    };
  }

  static const Map<String, Object> _base = {
    // ---- الثيم ----
    'theme.mode': 'auto', // auto (الشروق والغروب) | hours (حسب الساعات) | day | night
    'theme.dayStart': 7,
    'theme.nightStart': 19,
    'theme.preset': 'muhammadi',
    'day.bg': 0xFFF9F4EA,
    'day.surface': 0xFFFEFEFE,
    'day.ink': 0xFF142318,
    'day.muted': 0xFF515F54,
    'day.accent': 0xFF277443,
    'day.ring': 0xFFA37D1E,
    'day.line': 0xFFE2DCCE,
    'night.bg': 0xFF050F08,
    'night.surface': 0xFF101D13,
    'night.ink': 0xFFEBF2ED,
    'night.muted': 0xFF9EB1A2,
    'night.accent': 0xFF5FBC7C,
    'night.ring': 0xFFE0B861,
    'night.line': 0xFF253529,

    // ---- نمط الواجهة ----
    'ui.style': 'modern', // classic | glass | cinema | ribbons | liquid | minimal | magazine
    'cfg.rev': 0, // رقم ترقية الإعدادات
    'theme.withLayout': true,
    'setup.done': false, // معالج الإعداد الأول
    'migrated.rawnaq': false, // انتقال الإعدادات من الاسم القديم (الحافظ)
    'backup.auto': true, // نسخة احتياطية يومية تلقائية
    'backup.last': 0, // وقت آخر نسخة (مللي ثانية)
    'sched.off': false, // إطفاء تلقائي
    'sched.offAt': 60, // دقائق من منتصف الليل (١:٠٠)
    'sched.warn': true, // تنبيه قبل الإطفاء بدقيقة
    'sched.waitVideo': true, // لا تطفي إذا تطبيق ثاني شغّال
    'sched.quiet': false, // ساعات الهدوء
    'sched.quietFrom': 1320, // ١٠ مساءً
    'sched.quietTo': 420, // ٧ صباحاً // تطبيق ترتيب الواجهة الملكي مع ألوان الثيم
    // ---- ما بعد واجهة كوكل (فيكما صفحة 11) ----
    'guard.on': true, // حارس زر الهوم
    'notif.apps': true, // تنبيهات التطبيقات بمركز التنبيهات
    'notif.badge': true, // رقم فوق زر الجرس
    'notif.quietMute': true, // كتم بساعات الهدوء
    'notif.popup': false, // تنبيه منبثق أعلى الشاشة
    'notif.seen': 0, // آخر وقت فتحت بيه مركز التنبيهات
    'update.url': kUpdateUrl, // رابط ملف التحديث (JSON) — يكتبه البناء من GitHub
    'update.auto': true, // فحص يومي
    'update.quiet': true, // التثبيت بساعات الهدوء
    'update.backup': true, // نسخة احتياطية قبل التحديث
    'update.last': 0, // آخر فحص
    'profile.active': 'family', // family | kids | guest
    'profile.askOnStart': false, // اختيار الملف عند التشغيل
    'kids.apps': '', // تطبيقات الأطفال (مفصولة بفاصلة)
    'kids.limit': 120, // دقائق المشاهدة اليومية (٠ = بلا حد)
    'kids.bed': 1230, // وقت النوم (٨:٣٠ مساءً)، -1 = بلا وقت نوم
    'kids.used': 0, // دقائق اليوم
    'kids.day': '', // تاريخ عداد اليوم
    'kids.extra': 0, // دقائق إضافية منحها الأهل اليوم
    'power.method': 'cec', // cec | plug | both
    'plug.kind': 'shelly2', // shelly2 | shelly1 | tasmota
    'plug.ip': '',
    'plug.wait': 10, // ثوانٍ قبل قطع الكهرباء
    'star.action': 'quick', // quick | prayer | saver | search | home
    'smart.mode': 'hide', // hide (إخفاء مع الحارس) | disable (إيقاف كامل)
    'daily.on': true, // المحتوى اليومي
    'daily.kind': 'ayah', // ayah | hadith | dua
    'daily.where': 'both', // both | home | saver
    'daily.size': 'large', // medium | large
    'daily.kids': true,
    'daily.shown': '', // آخر يوم ظهر بيه بالواجهة
    'ui.radius': 'normal', // sharp | normal | round — استدارة كل الأسطح
    'ui.scale': 'medium', // small | medium | large
    'ui.fastStart': true, // الواجهة تفتح قبل الخلفيات
    // ---- حركة الشعار (فيكما صفحة ١٥ «الكتابة بخط اليد» وصفحة ١٦ رقم ١٣) ----
    'loader.write': true, // الشعار ينكتب بخط اليد (مطفأ = يظهر كاملاً والحلقة وحدها تتحرك)
    'loader.speed': 'normal', // calm | normal | brisk
    'loader.pen': true, // رأس القلم المضيء
    'loader.wet': true, // لمعة الحبر الطري خلف القلم
    'loader.ring': true, // الحلقة تمشي مع التحميل
    'loader.shine': true, // اللمعة الختامية
    'loader.waitBoot': 'cold', // انتظار اكتمال الكتابة: cold = أول تشغيل للجهاز فقط · always · off
    'home.showSearch': true,
    'home.showBell': true,
    'home.showProfile': true,
    'home.showDevice': true, // زر إعدادات الجهاز (Google TV)
    'recent.list': '', // آخر ما فتحته: pkg|وقت,…
    // ---- الطقس الحي (فيكما صفحة ١٤) ----
    'weather.cities': '', // المدن المحفوظة (JSON)
    'weather.auto': true, // الموقع الحالي من شبكة البيت أول مدينة
    'weather.refresh': 15, // دقائق بين كل تحديث للطقس (٥–٦٠)
    'weather.motion': 'full', // full | light | off
    'weather.glass': true, // قطرات وتكاثف على الزجاج
    'weather.homeChip': true, // زر الطقس الحي بأعلى الواجهة
    'weather.tile': true, // بلاطة «الطقس» الحية بالمفضلة
    'weather.saverCard': true, // ويدجت الطقس بشاشة السكون
    'weather.saverRain': true, // مطر هادئ على شاشة السكون وقت المطر
    // ---- الأمان ورمز الأهل (صفحة ١٣) ----
    'pin.warned': false, // نبّهنا على الرمز الافتراضي
    'pin.attempts': 3, // محاولات قبل القفل المؤقت
    'pin.lockMins': 5, // مدة القفل بالدقائق
    'pin.fails': 0,
    'pin.until': 0, // نهاية القفل المؤقت
    'pin.settings': true, // إعدادات رونق تحتاج الرمز
    'pin.profiles': true, // تبديل الملف يحتاج الرمز
    'pin.uninstall': true, // إزالة التطبيقات تحتاج الرمز
    // ---- ملف الأطفال (صفحة ١٢ و١٣) ----
    'kids.name': 'الأبطال',
    'kids.weekend': 180, // دقائق أيام العطلة (٠ = نفس الأيام العادية)
    'kids.weekendDays': '5,6', // الجمعة والسبت
    'kids.step': 30, // مدة التمديد بالرمز
    'kids.style': 'warm', // warm | sky | mint
    'kids.setup': false, // اكتمل معالج الإعداد
    'kids.log': '', // سجل الأيام: {اليوم: دقائق}
    'kids.appLog': '', // سجل التطبيقات: {pkg: دقائق}
    'guest.hours': 0, // رجوع تلقائي لملف العائلة بعد ساعات (٠ = بلا)
    'guest.since': 0,
    // ---- الإطفاء والتنبيهات ----
    'power.countdown': 10, // عد تنازلي قبل الإطفاء (ثواني)
    'daily.secs': 20, // مدة آية اليوم بالواجهة
    'notif.popupSecs': 6,
    'notif.muted': '', // تطبيقات مكتومة
    'update.every': 15, // كل كم دقيقة يفحص عن نسخة جديدة
    'update.autoInstall': true, // ينزّل وينصب وحده أول ما يلگى نسخة جديدة
    // ---- المناسبات ورمضان ----
    'occ.mode': true, // وضع المناسبات
    'occ.theme': true, // ثيم صاحب المناسبة بمواليد ووفيات المعصومين (ع)، والحسيني بمحرم والأربعين
    'occ.applied': '',
    'occ.active': '',
    'occ.welcome': true, // ترحيب يوم المناسبة
    'occ.shown': '', // آخر ترحيب ظهر
    'occ.prevPreset': '', // الثيم قبل المناسبة
    'ramadan.mode': 'auto', // auto | on | off
    'ramadan.banner': true, // الإمساك والإفطار بالواجهة
    // ---- الأجهزة والمزامنة وسجل النشاط ----
    'sync.on': false, // تفعيل المزامنة بالشبكة
    'sync.name': 'شاشة الصالة',
    'sync.peers': '', // أجهزة معروفة (JSON)
    'sync.theme': true,
    'sync.favorites': true,
    'sync.profiles': true,
    'sync.last': 0,
    'activity.log': '', // سجل النشاط (JSON)
    'pin.changed': 0, // آخر تغيير للرمز
    'update.prompted': '', // آخر إصدار انعرض عنه تنبيه
    'ui.blur': 28.0,
    'ui.tint': 0.5,
    'ui.performance': 'auto', // auto | quality | fast

    // ---- الخطوط ----
    'font.ui': 'IBM Plex Sans Arabic',
    'font.title': 'Noto Kufi Arabic',
    'font.clock': 'Alexandria',
    'font.scale': 1.0,
    'font.weight': 400,

    // ---- الواجهة الرئيسية ----
    'home.layout': 'modern', // row | grid | pages | column | liquid | dock | hero | split ...
    'home.cols': 6,
    'home.rows': 2,
    'home.align': 'start', // start | center
    'home.showBrand': true,
    'home.brand': 'رونق',
    'home.showGreeting': true,
    'home.showClock': true,
    'home.showDate': true,
    'home.showHijri': true,
    'home.showWeather': true,
    'home.showHint': true,
    'home.clockSize': 200.0,
    'home.dateSize': 30.0,
    'home.clock24': false,
    'home.sectionTitle': 'المفضلة',
    'home.bg': 'solid', // solid | gradient | art | image
    'home.art': 'dunes',
    'home.image': '',
    'home.dim': 0.35,
    // صور الواجهة المتغيرة (فيكما صفحة ١٦ رقم ١٥–١٧): تشتغل فوق أي ثيم، والثيم يتحكم بالطبقة بس
    'home.slides': false,
    'home.slides.source': 'all', // all | library (مكتبة رونق) | mine (صوري) | pick (أختارها)
    'home.slides.cats': '', // فئات المكتبة للواجهة (فارغ = كل الفئات المفعّلة)
    'home.slides.set': '', // أسماء الصور المختارة مفصولة بـ | · فارغ = كل الصور · none = ولا صورة
    'home.slides.interval': 60, // ثواني
    'home.slides.motion': 'kenburns', // fade | kenburns
    'home.slides.shuffle': true,
    'home.slides.tint': true, // لون خلفية الثيم فوق الصورة (وإلا أسود)
    'home.slides.dim': 0.35,
    'home.padX': 112.0,
    'home.padY': 72.0,

    // ---- التطبيقات ----
    'tile.style': 'banner', // banner | icon | circle
    'tile.size': 240.0,
    'tile.radius': 22.0,
    'tile.gap': 28.0,
    'tile.labels': 'all', // all | focus | none
    'tile.labelSize': 22.0,
    'tile.focusScale': 1.10,
    'tile.ringWidth': 4.0,
    'tile.shape': 'rounded', // sharp | rounded | squircle | circle | pill | leaf
    'tile.bg': 'art', // art (الأصلية) | soft (هادئة) | mono (أحادية ذهبية)
    'tile.focus': 'ring', // ring (تكبير وإطار) | glow (توهج) | lift (رفع وظل) | zoom (تكبير بلا إطار)
    'motion.style': 'soft', // soft | spring | elegant | swift | off
    'motion.page': 'royal', // royal | fade | slide | zoom
    'font.pair': 'royal', // royal | classic | modern | calm | bold | naskh | custom
    'tile.shadow': true,
    'tile.glint': true,
    'tile.showAdd': true,
    'tile.showAll': true,

    // ---- شاشة السكون ----
    'saver.minutes': 5,
    'saver.bg': 'stars', // stars | black | solid | gradient | art | image | slideshow
    'saver.art': 'stars',
    'saver.color': 0xFF05070D,
    'saver.image': '',
    'saver.interval': 30,
    'saver.kenburns': true,
    'saver.dim': 0.40,
    'saver.drift': true,
    'saver.position': 'center', // center | bottomStart | bottomEnd | topStart | topEnd
    'saver.showDay': true,
    'saver.showClock': true,
    'saver.showPeriod': true,
    'saver.showDate': true,
    'saver.showHijri': true,
    'saver.showWeather': true,
    'saver.clock24': false,
    'saver.font': 'Readex Pro',
    'saver.textFont': 'Readex Pro',
    'saver.clockSize': 300.0,
    'saver.dateSize': 56.0,
    'saver.textSize': 28.0,
    'saver.clockColor': 0xFFE8D3A4,
    'saver.textColor': 0xFFEDE6D6,
    'saver.mutedColor': 0xFF8A93AA,
    'saver.accentColor': 0xFFD8B467,

    // ---- شاشة السكون (إضافات) ----
    'saver.posX': 0.0, // للمكان المخصص: −١ يسار … +١ يمين
    'saver.posY': 0.0, // −١ أعلى … +١ أسفل
    'saver.colorMode': 'auto', // auto | manual
    'saver.showPrayers': true,
    'saver.showNextPrayer': true,
    'saver.prayerSize': 26.0,
    'saver.showText': false,
    'saver.text': 'اللهم صل على محمد وآل محمد',
    'saver.align': 'auto', // auto | start | center | end (محاذاة الأسطر)
    'saver.keys': true, // ◀ ▶ يبدّل التخطيط داخل شاشة السكون، ▲ الدليل
    'saver.frame': true, // إطار الزوايا الذهبية بالتخطيط الملكي
    'saver.layout': 'royal', // royal (ملكي) | calm (هادئ بالوسط) | elegant (أنيق سينمائي) | minimal (ساعة فقط) | stack (مجمّع) | free (حر)
    'saver.style': 'stars', // النمط المختار من معرض شاشات السكون

    // ---- سماء النجوم المتحركة ----
    'saver.stars.density': 280, // عدد النجوم
    'saver.stars.speed': 0.2, // سرعة الانجراف ٠–١
    'saver.stars.twinkle': 0.45, // التلألؤ ٠–١
    'saver.stars.shooting': 60, // ثواني بين الشهب (٠ = بدون)
    'saver.stars.layers': 3, // عمق الطبقات ١–٣
    'saver.stars.nebula': 0.2, // توهج السديم ٠–٠٫٥
    'saver.stars.palette': 'theme', // theme | emerald | gold | silver | dawn
    'saver.showCountdown': false,
    'saver.cdTitle': 'شهر رمضان المبارك',
    'saver.cdYear': 2027,
    'saver.cdMonth': 2,
    'saver.cdDay': 8,
    'saver.cdHour': 0,

    // ---- مواقيت الصلاة ----
    'prayer.city': 'amarah',
    'prayer.fajrAngle': 16.0,
    'prayer.maghribAngle': 4.0,
    'prayer.imsakMinutes': 10,
    'prayer.adj.fajr': 0,
    'prayer.adj.sunrise': 0,
    'prayer.adj.dhuhr': 0,
    'prayer.adj.sunset': 0,
    'prayer.adj.maghrib': 0,
    'prayer.adj.midnight': 0,
    'prayer.shown': 'imsak,fajr,sunrise,dhuhr,maghrib,midnight',
    'home.showPrayers': true,
    'home.showNextPrayer': true,

    // ---- تحديث الخلفيات تلقائياً ----
    'walls.auto': true, // التحديث التلقائي من مكتبة ويكيميديا كومنز
    'walls.count': 60, // عدد الصور التلقائية (١٠–١٠٠)
    'walls.days': 7, // التجديد كل كم يوم (أسبوعياً افتراضياً)
    'walls.hours': 12, // (قديم، ما يُستعمل)
    'walls.last': 0,
    'walls.cats': 'landscapes,mountains,coasts,water,waterfalls,sunsets,plants,night,astronomy,mosques',
    'saver.showCredit': true, // اسم المصوّر والرخصة أسفل شاشة السكون

    // ---- عام ----
    // ---- الزجاج السائل ----
    'liquid.blur': 24.0, // الغواش
    'liquid.tint': 0.12, // كثافة الزجاج
    'liquid.edge': 0.7, // لمعة الحواف
    'liquid.sat': 1.4, // تشبّع الألوان خلف الزجاج
    'liquid.radius': 40.0, // استدارة الزوايا
    'liquid.tone': 'light', // light | dark
    'liquid.adaptive': true, // يتكيف مع الخلفية

    // ---- الريموت والتنقل ----
    'remote.repeat': 140, // أقل فترة (مللي ثانية) بين حركتين عند الضغط المستمر
    'remote.longPress': 550, // مدة الضغطة الطويلة
    'remote.wrap': true, // الالتفاف بنهاية الصف
    'remote.confirmExit': false, // تأكيد قبل الخروج من الإعدادات
    'remote.motion': 'full', // none | soft | full — حركة التركيز
    'remote.ring': 'gold', // thin | gold | glow — إطار التركيز

    'misc.forceLandscape': false,
    'misc.blockSystemSaver': true,
    'misc.overscan': 0,
    'profile.classic': '',
    'profile.glass': '',
    'profile.cinema': '',
    'profile.ribbons': '',
    'profile.liquid': '',
    'profile.minimal': '',
    'profile.modern': '',
    'profile.soft': '',
    'profile.magazine': '',
    'misc.hijriOffset': 0,
    'misc.city': '',
    'misc.pin': '0000',
    'misc.animSpeed': 1.0,
    'misc.reduceMotion': false,
    'misc.dnd': false, // عدم الإزعاج: توقف شاشة السكون التلقائية
    'a11y.textScale': 1.0, // حجم النص العام
    'a11y.contrast': false, // تباين عالٍ
    'a11y.thickRing': false, // إطار تركيز سميك
  };

  void load(SharedPreferences p) {
    _p = p;
    final raw = p.getString('config');
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.forEach((k, v) {
        if (defaults.containsKey(k) && v != null && _sameType(defaults[k], v)) _v[k] = v as Object;
      });
    } catch (_) {}
  }

  /// قيمة محفوظة من نسخة قديمة بنوع مختلف (مثلاً صح/غلط صار نص) تنترك، حتى ما يوگف التشغيل.
  static bool _sameType(Object? def, Object v) => def == null || (def is num && v is num) || def.runtimeType == v.runtimeType;

  T get<T>(String key) {
    final v = _v[key] ?? defaults[key];
    if (T == double && v is int) return v.toDouble() as T;
    if (T == int && v is double) return v.round() as T;
    if (v is T) return v;
    // نوع غلط (قيمة قديمة): نرجع للأصل بدل ما ينكسر الإقلاع
    final def = defaults[key];
    if (T == double && def is int) return def.toDouble() as T;
    return def as T;
  }

  double d(String k) => get<double>(k);
  int i(String k) => get<int>(k);
  bool b(String k) => get<bool>(k);
  String s(String k) => get<String>(k);
  Color c(String k) => Color(get<int>(k));

  void set(String key, Object value) {
    final def = defaults[key];
    if (def == value || (def is num && value is num && def.toDouble() == value.toDouble())) {
      _v.remove(key);
    } else {
      _v[key] = value;
    }
    _save();
  }

  bool isDefault(String key) => !_v.containsKey(key);

  /// إعادة كل المفاتيح اللي تبدأ بالبادئة لقيمها الافتراضية.
  void resetPrefix(List<String> prefixes) {
    _v.removeWhere((k, _) => prefixes.any(k.startsWith));
    _save();
  }

  // ---------- ملفات الترتيب لكل نمط ----------
  /// ترتيب الواجهة والتطبيقات وشاشة السكون يُحفظ لكل نمط على حدة.
  static const profilePrefixes = ['home.', 'tile.', 'saver.'];
  static const profileExclude = {'saver.minutes'};

  static bool isProfileKey(String k) => profilePrefixes.any(k.startsWith) && !profileExclude.contains(k);

  /// القيم المعدّلة الحالية لمفاتيح الترتيب.
  Map<String, Object> snapshot() => {
        for (final e in _v.entries)
          if (isProfileKey(e.key)) e.key: e.value,
      };

  /// تحميل ترتيب: يرجع كل مفاتيح الترتيب للأصل ثم يطبق القيم المحفوظة.
  void loadSnapshot(Map<String, dynamic> m) {
    _v.removeWhere((k, _) => isProfileKey(k));
    m.forEach((k, v) {
      if (defaults.containsKey(k) && isProfileKey(k) && v != null) _v[k] = v as Object;
    });
    _save();
  }

  /// كل الإعدادات المعدّلة (للنسخ الاحتياطي).
  Map<String, Object> dump() => Map.of(_v);

  /// استعادة نسخة احتياطية: يرجع الكل للأصل ثم يطبّق القيم المعروفة فقط.
  void restore(Map<String, dynamic> m) {
    _v.clear();
    m.forEach((k, v) {
      if (defaults.containsKey(k) && v != null) _v[k] = v as Object;
    });
    _save();
  }

  void resetAll() {
    _v.clear();
    _save();
  }

  /// تطبيق ثيم ملكي: ألوانه النهارية والليلية وخطوطه الثلاثة.
  void applyPreset(ThemePreset p, {bool fonts = true}) {
    p.day.forEach((k, v) => set('day.$k', v));
    p.night.forEach((k, v) => set('night.$k', v));
    if (fonts) {
      set('font.title', p.titleFont);
      set('font.ui', p.bodyFont);
      set('font.clock', p.clockFont);
      set('saver.font', p.clockFont);
      set('saver.textFont', p.bodyFont);
    }
    // الترتيب الملكي للثيم (يمكن إيقافه من الإعدادات)
    if (b('theme.withLayout')) {
      set('home.layout', p.layout);
      set('tile.shape', p.shape);
      set('home.bg', p.bg);
    }
    set('theme.preset', p.id);
  }

  void _save() => _p?.setString('config', jsonEncode(_v));
}

/// الثيمات الملكية: لكل ثيم ألوانه النهارية والليلية وخطوطه الخاصة (مطابقة لفيكما).
class ThemePreset {
  final String id, name, sub;
  final Map<String, int> day, night;
  final String titleFont, bodyFont, clockFont;

  /// الترتيب الملكي الخاص بالثيم (فيكما صفحة 09): ترتيب الواجهة، شكل الأيقونات، والخلفية.
  final String layout, shape, bg;
  const ThemePreset(this.id, this.name, this.sub, this.day, this.night,
      {required this.titleFont, required this.bodyFont, required this.clockFont, this.layout = 'modern', this.shape = 'squircle', this.bg = 'aurora'});

  static ThemePreset byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static const all = [
    // ── ثيمات المعصومين الأربعة عشر (ع) والزينبي والعباسي: لكل ثيم ألوانه المولّدة بتباين محسوب ──
    ThemePreset('muhammadi', 'المحمدي', 'نور النبوة ﷺ · أخضر نبوي وذهب', {'bg': 0xFFF9F4EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF142318, 'muted': 0xFF515F54, 'accent': 0xFF277443, 'ring': 0xFFA37D1E, 'line': 0xFFE2DCCE}, {'bg': 0xFF050F08, 'surface': 0xFF101D13, 'ink': 0xFFEBF2ED, 'muted': 0xFF9EB1A2, 'accent': 0xFF5FBC7C, 'ring': 0xFFE0B861, 'line': 0xFF253529},
        titleFont: 'Noto Kufi Arabic', bodyFont: 'IBM Plex Sans Arabic', clockFont: 'Alexandria', layout: 'modern', shape: 'arch', bg: 'aurora'),
    ThemePreset('alawi', 'العلوي', 'أمير المؤمنين (ع) · ذهب القبة ولازورد', {'bg': 0xFFEFF5FE, 'surface': 0xFFFEFEFE, 'ink': 0xFF261E0E, 'muted': 0xFF615A4B, 'accent': 0xFF7D5E08, 'ring': 0xFF5484C7, 'line': 0xFFD4DDEA}, {'bg': 0xFF110B03, 'surface': 0xFF1F180B, 'ink': 0xFFF3F0E9, 'muted': 0xFFB4AA96, 'accent': 0xFFC99E3A, 'ring': 0xFF94C0FE, 'line': 0xFF372F1F},
        titleFont: 'El Messiri', bodyFont: 'Almarai', clockFont: 'Alexandria', layout: 'hero', shape: 'octagon', bg: 'gradient'),
    ThemePreset('fatimi', 'الفاطمي', 'الزهراء (ع) · لؤلؤ ووردٌ هادئ', {'bg': 0xFFFAF4EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF2B191F, 'muted': 0xFF67555B, 'accent': 0xFF8C4C64, 'ring': 0xFF9C7E4B, 'line': 0xFFE4DBCE}, {'bg': 0xFF14080C, 'surface': 0xFF23141A, 'ink': 0xFFF6EDF0, 'muted': 0xFFBCA3AB, 'accent': 0xFFDC86A5, 'ring': 0xFFD9B884, 'line': 0xFF3D2A30},
        titleFont: 'El Messiri', bodyFont: 'Readex Pro', clockFont: 'Readex Pro', layout: 'modern', shape: 'squircle', bg: 'aurora'),
    ThemePreset('hasani', 'الحسني', 'كريم أهل البيت (ع) · زمرد وفضة', {'bg': 0xFFEBF8F4, 'surface': 0xFFFBFFFD, 'ink': 0xFF0F241E, 'muted': 0xFF4D605A, 'accent': 0xFF18735F, 'ring': 0xFF7A858F, 'line': 0xFFD0E1DB}, {'bg': 0xFF030F0B, 'surface': 0xFF0C1D18, 'ink': 0xFFEAF2EF, 'muted': 0xFF98B1A9, 'accent': 0xFF4EBB9F, 'ring': 0xFFB4BFCB, 'line': 0xFF20352F},
        titleFont: 'Noto Kufi Arabic', bodyFont: 'Tajawal', clockFont: 'IBM Plex Sans Arabic', layout: 'split', shape: 'leaf', bg: 'gradient'),
    ThemePreset('husaini', 'الحسيني', 'سيد الشهداء (ع) · عقيق وذهب', {'bg': 0xFFF9F4EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF2C1A18, 'muted': 0xFF685654, 'accent': 0xFFA73735, 'ring': 0xFFA27D28, 'line': 0xFFE3DCCE}, {'bg': 0xFF150808, 'surface': 0xFF241513, 'ink': 0xFFF7EEED, 'muted': 0xFFBDA4A1, 'accent': 0xFFF97770, 'ring': 0xFFDFB867, 'line': 0xFF3E2A29},
        titleFont: 'Reem Kufi', bodyFont: 'Cairo', clockFont: 'Alexandria', layout: 'dock', shape: 'arch', bg: 'aurora'),
    ThemePreset('sajjadi', 'السجّادي', 'زين العابدين (ع) · زيتون السجود وذهب قديم', {'bg': 0xFFFAF3EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF1D2111, 'muted': 0xFF595D4D, 'accent': 0xFF5D6B23, 'ring': 0xFFA87A2D, 'line': 0xFFE4DBCE}, {'bg': 0xFF0B0E04, 'surface': 0xFF181B0D, 'ink': 0xFFEFF1EA, 'muted': 0xFFA8AE99, 'accent': 0xFF9CAF56, 'ring': 0xFFE5B46B, 'line': 0xFF2E3321},
        titleFont: 'Noto Kufi Arabic', bodyFont: 'Tajawal', clockFont: 'Readex Pro', layout: 'row', shape: 'leaf', bg: 'gradient'),
    ThemePreset('baqiri', 'الباقري', 'باقر العلوم (ع) · لازورد المعرفة وذهب', {'bg': 0xFFF9F4EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF181F2E, 'muted': 0xFF545B69, 'accent': 0xFF3D5EB1, 'ring': 0xFFA17D34, 'line': 0xFFE3DBCE}, {'bg': 0xFF080C16, 'surface': 0xFF141926, 'ink': 0xFFEDF0F7, 'muted': 0xFFA2ABBE, 'accent': 0xFF79A1FE, 'ring': 0xFFDEB870, 'line': 0xFF293040},
        titleFont: 'Alexandria', bodyFont: 'Almarai', clockFont: 'Noto Kufi Arabic', layout: 'hero', shape: 'arch', bg: 'gradient'),
    ThemePreset('sadiqi', 'الصادقي', 'الإمام الصادق (ع) · عنبر وزعفران', {'bg': 0xFFFEF1F1, 'surface': 0xFFFEFEFE, 'ink': 0xFF2A1B11, 'muted': 0xFF66574E, 'accent': 0xFF954D04, 'ring': 0xFFC86266, 'line': 0xFFE9D7D7}, {'bg': 0xFF130A04, 'surface': 0xFF23160E, 'ink': 0xFFF6EFEA, 'muted': 0xFFBAA699, 'accent': 0xFFEA8838, 'ring': 0xFFFDA1A1, 'line': 0xFF3C2C22},
        titleFont: 'Changa', bodyFont: 'Cairo', clockFont: 'Changa', layout: 'hero', shape: 'rounded', bg: 'aurora'),
    ThemePreset('kadhimi', 'الكاظمي', 'باب الحوائج (ع) · أسود وذهب القبتين', {'bg': 0xFFF4F4F4, 'surface': 0xFFFEFEFE, 'ink': 0xFF1F1F1F, 'muted': 0xFF5B5B5B, 'accent': 0xFF7D5E0C, 'ring': 0xFF9F7E36, 'line': 0xFFDCDCDC}, {'bg': 0xFF0C0C0C, 'surface': 0xFF191919, 'ink': 0xFFF0F0F0, 'muted': 0xFFABABAB, 'accent': 0xFFC79E43, 'ring': 0xFFDBB972, 'line': 0xFF303030},
        titleFont: 'Alexandria', bodyFont: 'Almarai', clockFont: 'Alexandria', layout: 'hero', shape: 'cut', bg: 'aurora'),
    ThemePreset('ridawi', 'الرضوي', 'الإمام الرؤوف (ع) · فيروز وذهب', {'bg': 0xFFF9F4EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF0B2326, 'muted': 0xFF4B5F61, 'accent': 0xFF07717A, 'ring': 0xFFA37D1E, 'line': 0xFFE2DCCE}, {'bg': 0xFF020F11, 'surface': 0xFF091D1F, 'ink': 0xFFE9F2F3, 'muted': 0xFF96B1B4, 'accent': 0xFF39B8C5, 'ring': 0xFFE0B861, 'line': 0xFF1D3538},
        titleFont: 'Reem Kufi', bodyFont: 'Tajawal', clockFont: 'Readex Pro', layout: 'modern', shape: 'arch', bg: 'aurora'),
    ThemePreset('jawadi', 'الجوادي', 'باب المراد (ع) · سماوي وذهب', {'bg': 0xFFEFF7FD, 'surface': 0xFFFDFDFD, 'ink': 0xFF11212C, 'muted': 0xFF4E5D67, 'accent': 0xFF056B9A, 'ring': 0xFFAB7D30, 'line': 0xFFD2DEE7}, {'bg': 0xFF040E14, 'surface': 0xFF0D1B24, 'ink': 0xFFEAF1F6, 'muted': 0xFF9AAEBC, 'accent': 0xFF47AFEC, 'ring': 0xFFE5B46A, 'line': 0xFF22333E},
        titleFont: 'Noto Kufi Arabic', bodyFont: 'Readex Pro', clockFont: 'Alexandria', layout: 'hero', shape: 'octagon', bg: 'gradient'),
    ThemePreset('naqawi', 'النقوي', 'الإمام الهادي (ع) · طين سامراء وذهب', {'bg': 0xFFFAF3EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF2B1B13, 'muted': 0xFF67574F, 'accent': 0xFF974A25, 'ring': 0xFFAB7825, 'line': 0xFFE4DBCE}, {'bg': 0xFF140905, 'surface': 0xFF24160F, 'ink': 0xFFF6EEEB, 'muted': 0xFFBCA59C, 'accent': 0xFFE9875A, 'ring': 0xFFE9B365, 'line': 0xFF3D2C24},
        titleFont: 'Reem Kufi', bodyFont: 'Almarai', clockFont: 'Alexandria', layout: 'dock', shape: 'arch', bg: 'aurora'),
    ThemePreset('askari', 'العسكري', 'الإمام الزكي (ع) · فضة وذهب', {'bg': 0xFFF9F4EA, 'surface': 0xFFFEFEFE, 'ink': 0xFF171F2E, 'muted': 0xFF535B69, 'accent': 0xFF586478, 'ring': 0xFF9E7E34, 'line': 0xFFE2DCCE}, {'bg': 0xFF070C16, 'surface': 0xFF121A26, 'ink': 0xFFECF0F7, 'muted': 0xFFA0ACBE, 'accent': 0xFF91A6C8, 'ring': 0xFFDBB970, 'line': 0xFF273140},
        titleFont: 'IBM Plex Sans Arabic', bodyFont: 'IBM Plex Sans Arabic', clockFont: 'Readex Pro', layout: 'modern', shape: 'sharp', bg: 'solid'),
    ThemePreset('mahdawi', 'المهدوي', 'صاحب الزمان (عج) · ليل الانتظار وفجر ذهبي', {'bg': 0xFFF5F5FE, 'surface': 0xFFFDFDFD, 'ink': 0xFF1E1D2D, 'muted': 0xFF595969, 'accent': 0xFF5D52B4, 'ring': 0xFFA17E24, 'line': 0xFFDBDBE8}, {'bg': 0xFF0B0B15, 'surface': 0xFF181825, 'ink': 0xFFEFEFF7, 'muted': 0xFFA8A9BE, 'accent': 0xFF9C95FE, 'ring': 0xFFDDB964, 'line': 0xFF2E2E3F},
        titleFont: 'Alexandria', bodyFont: 'Readex Pro', clockFont: 'Readex Pro', layout: 'modern', shape: 'squircle', bg: 'aurora'),
    ThemePreset('zainabi', 'الزينبي', 'عقيلة بني هاشم (ع) · أرجوان الصبر وذهب', {'bg': 0xFFFCF3F8, 'surface': 0xFFFDFDFD, 'ink': 0xFF291A23, 'muted': 0xFF65555F, 'accent': 0xFF943F78, 'ring': 0xFFA37D1E, 'line': 0xFFE5D8E0}, {'bg': 0xFF13080F, 'surface': 0xFF22151D, 'ink': 0xFFF5EEF2, 'muted': 0xFFB9A4B0, 'accent': 0xFFE47BBF, 'ring': 0xFFE0B861, 'line': 0xFF3B2A35},
        titleFont: 'El Messiri', bodyFont: 'Readex Pro', clockFont: 'Alexandria', layout: 'dock', shape: 'arch', bg: 'aurora'),
    ThemePreset('abbasi', 'العباسي', 'قمر بني هاشم (ع) · راية خضراء وفضة القمر', {'bg': 0xFFF2F8F0, 'surface': 0xFFFCFEFB, 'ink': 0xFF192314, 'muted': 0xFF545E50, 'accent': 0xFF397416, 'ring': 0xFF7B848F, 'line': 0xFFD7DFD4}, {'bg': 0xFF080E06, 'surface': 0xFF141C10, 'ink': 0xFFEDF2EB, 'muted': 0xFFA2B09D, 'accent': 0xFF73BB51, 'ring': 0xFFB5BFCB, 'line': 0xFF293425},
        titleFont: 'Alexandria', bodyFont: 'Tajawal', clockFont: 'Alexandria', layout: 'split', shape: 'leaf', bg: 'gradient'),
  ];
}
