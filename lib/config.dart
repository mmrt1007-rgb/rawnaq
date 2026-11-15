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
    'theme.preset': 'emerald',
    'day.bg': 0xFFF7F4EE,
    'day.surface': 0xFFFFFFFF,
    'day.ink': 0xFF13201A,
    'day.muted': 0xFF56635C,
    'day.accent': 0xFF0D5C45,
    'day.ring': 0xFFA87A2E,
    'day.line': 0xFFE2DBCD,
    'night.bg': 0xFF06120E,
    'night.surface': 0xFF0D1E18,
    'night.ink': 0xFFEEF4EF,
    'night.muted': 0xFFA3B7AD,
    'night.accent': 0xFF3DBE8C,
    'night.ring': 0xFFD8B467,
    'night.line': 0xFF1D3A2F,

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
    'update.autoInstall': false, // تثبيت تلقائي بساعات الهدوء
    // ---- المناسبات ورمضان ----
    'occ.mode': true, // وضع المناسبات
    'occ.theme': true, // ثيم الدر الحسيني بمحرم وصفر
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
    'font.ui': 'Readex Pro',
    'font.title': 'Reem Kufi',
    'font.clock': 'Aref Ruqaa',
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
    'motion.page': 'fade', // fade | slide | zoom
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
    'saver.font': 'Aref Ruqaa',
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
    'saver.layout': 'calm', // calm (هادئ بالوسط) | elegant (أنيق سينمائي) | minimal (ساعة فقط) | stack (مجمّع) | free (حر)
    'saver.style': 'stars', // النمط المختار من معرض شاشات السكون

    // ---- سماء النجوم المتحركة ----
    'saver.stars.density': 280, // عدد النجوم
    'saver.stars.speed': 0.2, // سرعة الانجراف ٠–١
    'saver.stars.twinkle': 0.45, // التلألؤ ٠–١
    'saver.stars.shooting': 60, // ثواني بين الشهب (٠ = بدون)
    'saver.stars.layers': 3, // عمق الطبقات ١–٣
    'saver.stars.nebula': 0.2, // توهج السديم ٠–٠٫٥
    'saver.stars.palette': 'emerald', // emerald | gold | silver | dawn
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
    ThemePreset('emerald', 'الزمرد الملكي', 'أوف وايت وزمرد', {'bg': 0xFFF7F4EE, 'surface': 0xFFFFFFFF, 'ink': 0xFF13201A, 'muted': 0xFF56635C, 'accent': 0xFF0D5C45, 'ring': 0xFFA87A2E, 'line': 0xFFE2DBCD}, {'bg': 0xFF06120E, 'surface': 0xFF0D1E18, 'ink': 0xFFEEF4EF, 'muted': 0xFFA3B7AD, 'accent': 0xFF3DBE8C, 'ring': 0xFFD8B467, 'line': 0xFF1D3A2F},
        titleFont: 'Reem Kufi', bodyFont: 'Readex Pro', clockFont: 'Aref Ruqaa', layout: 'modern', shape: 'squircle', bg: 'aurora'),
    // ── ثيمات أهل البيت (ع): لكل ثيم لقب يليق بقدسيته ──
    ThemePreset('muhammadi', 'المحمدي', 'نور النبوة (ص)، أخضر نبوي وذهب', {'bg': 0xFFF5F6EF, 'surface': 0xFFFFFFFF, 'ink': 0xFF102016, 'muted': 0xFF55625A, 'accent': 0xFF1B6B3A, 'ring': 0xFFB8902F, 'line': 0xFFDFE3D6}, {'bg': 0xFF05100A, 'surface': 0xFF0B1C12, 'ink': 0xFFEDF5EF, 'muted': 0xFFA1B8A9, 'accent': 0xFF52C47A, 'ring': 0xFFE2C064, 'line': 0xFF1A3524},
        titleFont: 'Amiri', bodyFont: 'Readex Pro', clockFont: 'Aref Ruqaa', layout: 'modern', shape: 'arch', bg: 'aurora'),
    ThemePreset('alawi', 'العلوي', 'أمير المؤمنين (ع)، ذهب القبة ولازورد', {'bg': 0xFFF8F5EC, 'surface': 0xFFFFFFFF, 'ink': 0xFF1A1608, 'muted': 0xFF625B45, 'accent': 0xFF9A7416, 'ring': 0xFF1F4E8C, 'line': 0xFFE6DEC8}, {'bg': 0xFF07090F, 'surface': 0xFF101521, 'ink': 0xFFF5F0E2, 'muted': 0xFFB5AD95, 'accent': 0xFFE5BE55, 'ring': 0xFF6FA8FF, 'line': 0xFF25293A},
        titleFont: 'Reem Kufi', bodyFont: 'Almarai', clockFont: 'Amiri', layout: 'hero', shape: 'octagon', bg: 'gradient'),
    ThemePreset('fatimi', 'الفاطمي', 'سيدة نساء العالمين (ع)، لؤلؤ وورد', {'bg': 0xFFFBF8F6, 'surface': 0xFFFFFFFF, 'ink': 0xFF23161D, 'muted': 0xFF675860, 'accent': 0xFF8A4A62, 'ring': 0xFFB9975F, 'line': 0xFFECE3E2}, {'bg': 0xFF110A0E, 'surface': 0xFF1D1218, 'ink': 0xFFF7EEF2, 'muted': 0xFFC4ADB8, 'accent': 0xFFE79AB8, 'ring': 0xFFE6C98E, 'line': 0xFF35232C},
        titleFont: 'Scheherazade New', bodyFont: 'Readex Pro', clockFont: 'El Messiri', layout: 'modern', shape: 'squircle', bg: 'aurora'),
    ThemePreset('hasani', 'الحسني', 'كريم أهل البيت (ع)، زمرد وفضة', {'bg': 0xFFF3F6F4, 'surface': 0xFFFFFFFF, 'ink': 0xFF0F211C, 'muted': 0xFF52645E, 'accent': 0xFF0F6E5A, 'ring': 0xFF8E9AA6, 'line': 0xFFDCE4E0}, {'bg': 0xFF040F0C, 'surface': 0xFF0A1C17, 'ink': 0xFFEBF4F1, 'muted': 0xFF9DB8B0, 'accent': 0xFF46C9A6, 'ring': 0xFFC9D2DB, 'line': 0xFF16332B},
        titleFont: 'Markazi Text', bodyFont: 'Tajawal', clockFont: 'Amiri', layout: 'split', shape: 'leaf', bg: 'gradient'),
    ThemePreset('husaini', 'الدر الحسيني', 'سيد الشهداء (ع)، عقيق وذهب', {'bg': 0xFFF8F2F0, 'surface': 0xFFFFFFFF, 'ink': 0xFF2A0F10, 'muted': 0xFF6E5355, 'accent': 0xFF8B1A1E, 'ring': 0xFFA8822F, 'line': 0xFFE8D8D6}, {'bg': 0xFF0E0405, 'surface': 0xFF1C0A0C, 'ink': 0xFFF8ECEC, 'muted': 0xFFC9A6A8, 'accent': 0xFFE2585E, 'ring': 0xFFE0B865, 'line': 0xFF3A1719},
        titleFont: 'Aref Ruqaa', bodyFont: 'Cairo', clockFont: 'Reem Kufi', layout: 'dock', shape: 'arch', bg: 'aurora'),
    // ── الثيمات الملكية الأخرى ──
    ThemePreset('abbasid', 'العبّاسي', 'لازورد وذهب', {'bg': 0xFFF4F2EC, 'surface': 0xFFFFFFFF, 'ink': 0xFF141A2E, 'muted': 0xFF555C73, 'accent': 0xFF1E3A8A, 'ring': 0xFFB08A3E, 'line': 0xFFDEDBD2}, {'bg': 0xFF070B1C, 'surface': 0xFF0E1530, 'ink': 0xFFECEFF8, 'muted': 0xFFA2AAC6, 'accent': 0xFF7C9BFF, 'ring': 0xFFD9B868, 'line': 0xFF1C2650},
        titleFont: 'Amiri', bodyFont: 'Almarai', clockFont: 'El Messiri', layout: 'hero', shape: 'arch', bg: 'gradient'),
    ThemePreset('andalusi', 'الأندلسي', 'فيروز وطين', {'bg': 0xFFF6F1E8, 'surface': 0xFFFFFFFF, 'ink': 0xFF14262A, 'muted': 0xFF55666A, 'accent': 0xFF136A73, 'ring': 0xFFB35A2E, 'line': 0xFFE3DACB}, {'bg': 0xFF061416, 'surface': 0xFF0C2226, 'ink': 0xFFEAF5F5, 'muted': 0xFF9DB9BC, 'accent': 0xFF4CC3C9, 'ring': 0xFFE08A5A, 'line': 0xFF173A3F},
        titleFont: 'Markazi Text', bodyFont: 'Cairo', clockFont: 'Lateef', layout: 'split', shape: 'leaf', bg: 'art'),
    ThemePreset('blackgold', 'الذهب الأسود', 'أسود وذهب', {'bg': 0xFFF8F5EC, 'surface': 0xFFFFFFFF, 'ink': 0xFF161310, 'muted': 0xFF5F584C, 'accent': 0xFF8A6A1F, 'ring': 0xFF8A6A1F, 'line': 0xFFE4DCC8}, {'bg': 0xFF0A0907, 'surface': 0xFF15130F, 'ink': 0xFFF5EFE2, 'muted': 0xFFB8AE98, 'accent': 0xFFE2BE6A, 'ring': 0xFFE2BE6A, 'line': 0xFF2B261C},
        titleFont: 'Kufam', bodyFont: 'Almarai', clockFont: 'Rakkas', layout: 'hero', shape: 'cut', bg: 'aurora'),
    ThemePreset('pearl', 'اللؤلؤي', 'جمشت وشمبانيا', {'bg': 0xFFFAF8F4, 'surface': 0xFFFFFFFF, 'ink': 0xFF1C1826, 'muted': 0xFF5D5869, 'accent': 0xFF5E4A8E, 'ring': 0xFFB89B6A, 'line': 0xFFE7E2DA}, {'bg': 0xFF0E0C14, 'surface': 0xFF1A1724, 'ink': 0xFFF2EFF8, 'muted': 0xFFB0A9C2, 'accent': 0xFFB9A6F0, 'ring': 0xFFE1C78F, 'line': 0xFF2C2740},
        titleFont: 'Scheherazade New', bodyFont: 'Readex Pro', clockFont: 'Reem Kufi', layout: 'ribbons', shape: 'pill', bg: 'solid'),
    ThemePreset('saffron', 'الزعفراني', 'عنبر وعقيق', {'bg': 0xFFFBF4EA, 'surface': 0xFFFFFFFF, 'ink': 0xFF2B1A08, 'muted': 0xFF6F5A41, 'accent': 0xFFB5600E, 'ring': 0xFF8E2430, 'line': 0xFFEBDDC8}, {'bg': 0xFF140C04, 'surface': 0xFF21160A, 'ink': 0xFFF8EEDF, 'muted': 0xFFC7B193, 'accent': 0xFFF2A23C, 'ring': 0xFFF3D08A, 'line': 0xFF3A2814},
        titleFont: 'Changa', bodyFont: 'Cairo', clockFont: 'El Messiri', layout: 'hero', shape: 'rounded', bg: 'aurora'),
    ThemePreset('olive', 'الزيتوني', 'زيتون وذهب قديم', {'bg': 0xFFF5F5EC, 'surface': 0xFFFFFFFF, 'ink': 0xFF1E2412, 'muted': 0xFF5C634C, 'accent': 0xFF55631A, 'ring': 0xFFA87A2E, 'line': 0xFFE1E2D2}, {'bg': 0xFF0B0E06, 'surface': 0xFF151A0D, 'ink': 0xFFEEF1E2, 'muted': 0xFFAEB597, 'accent': 0xFFB8C964, 'ring': 0xFFD8B467, 'line': 0xFF2A321A},
        titleFont: 'Markazi Text', bodyFont: 'Tajawal', clockFont: 'Amiri', layout: 'row', shape: 'leaf', bg: 'gradient'),
    ThemePreset('desert', 'الصحراوي', 'رمل وطين محروق', {'bg': 0xFFF7EFE2, 'surface': 0xFFFFFBF4, 'ink': 0xFF2E2216, 'muted': 0xFF75644F, 'accent': 0xFFA0522D, 'ring': 0xFFB07D2B, 'line': 0xFFE6D9C3}, {'bg': 0xFF17110A, 'surface': 0xFF241A10, 'ink': 0xFFF3E9DA, 'muted': 0xFFBFAE95, 'accent': 0xFFE58A5A, 'ring': 0xFFE6C177, 'line': 0xFF3D2E1D},
        titleFont: 'El Messiri', bodyFont: 'Almarai', clockFont: 'Rakkas', layout: 'dock', shape: 'arch', bg: 'aurora'),
    ThemePreset('graphite', 'الغرافيت الفضي', 'فضة وذهب باهت', {'bg': 0xFFF3F4F6, 'surface': 0xFFFFFFFF, 'ink': 0xFF15181E, 'muted': 0xFF5B6270, 'accent': 0xFF2F3A4C, 'ring': 0xFFA9893F, 'line': 0xFFDDE0E6}, {'bg': 0xFF0B0C0F, 'surface': 0xFF15171C, 'ink': 0xFFEEF0F4, 'muted': 0xFFA7ADBA, 'accent': 0xFFC9D3E3, 'ring': 0xFFD4B46A, 'line': 0xFF262A33},
        titleFont: 'Qahiri', bodyFont: 'Mada', clockFont: 'Kufam', layout: 'modern', shape: 'sharp', bg: 'solid'),
    ThemePreset('ruby', 'الياقوتي', 'ياقوت وذهب', {'bg': 0xFFFBF5F4, 'surface': 0xFFFFFFFF, 'ink': 0xFF2A0E12, 'muted': 0xFF6E5054, 'accent': 0xFF9B1B30, 'ring': 0xFFB8892F, 'line': 0xFFEBD9D8}, {'bg': 0xFF120507, 'surface': 0xFF1E0A0E, 'ink': 0xFFF7ECEC, 'muted': 0xFFC7A4A8, 'accent': 0xFFE5485F, 'ring': 0xFFE3BC6E, 'line': 0xFF3B1A1F},
        titleFont: 'El Messiri', bodyFont: 'Cairo', clockFont: 'Aref Ruqaa', layout: 'hero', shape: 'octagon', bg: 'aurora'),
    ThemePreset('najaf', 'النجفي', 'فيروز القباب وذهبها', {'bg': 0xFFF4F7F5, 'surface': 0xFFFFFFFF, 'ink': 0xFF0F2426, 'muted': 0xFF4F6466, 'accent': 0xFF0E7C86, 'ring': 0xFFB8902F, 'line': 0xFFD9E4E2}, {'bg': 0xFF041214, 'surface': 0xFF0A2023, 'ink': 0xFFE8F4F4, 'muted': 0xFF9CBABC, 'accent': 0xFF3CC7CF, 'ring': 0xFFE6C468, 'line': 0xFF15383C},
        titleFont: 'Reem Kufi', bodyFont: 'Tajawal', clockFont: 'Amiri', layout: 'modern', shape: 'arch', bg: 'aurora'),
    ThemePreset('babylon', 'البابلي', 'لازورد عشتار ونحاس', {'bg': 0xFFF3F4F9, 'surface': 0xFFFFFFFF, 'ink': 0xFF0F1530, 'muted': 0xFF4E5675, 'accent': 0xFF1F3FA8, 'ring': 0xFFC79A2B, 'line': 0xFFDADDEA}, {'bg': 0xFF050A1E, 'surface': 0xFF0B1433, 'ink': 0xFFE9EDFA, 'muted': 0xFFA3ABCB, 'accent': 0xFF5C7CFF, 'ring': 0xFFF0C350, 'line': 0xFF1A2650},
        titleFont: 'Kufam', bodyFont: 'Almarai', clockFont: 'Rakkas', layout: 'split', shape: 'cut', bg: 'gradient'),
    ThemePreset('coral', 'المرجاني', 'مرجان وكحلي', {'bg': 0xFFFBF6F2, 'surface': 0xFFFFFFFF, 'ink': 0xFF1B2233, 'muted': 0xFF5E6577, 'accent': 0xFFD2553A, 'ring': 0xFF1F3A5F, 'line': 0xFFEADFD6}, {'bg': 0xFF0A0F1A, 'surface': 0xFF131B2B, 'ink': 0xFFF4EEE9, 'muted': 0xFFAAB2C3, 'accent': 0xFFFF7A5C, 'ring': 0xFFE8C27A, 'line': 0xFF24304A},
        titleFont: 'Changa', bodyFont: 'Mada', clockFont: 'Changa', layout: 'ribbons', shape: 'squircle', bg: 'solid'),
    ThemePreset('amethyst', 'البنفسجي الملكي', 'جمشت عميق وذهب', {'bg': 0xFFF7F5FA, 'surface': 0xFFFFFFFF, 'ink': 0xFF1D1430, 'muted': 0xFF5F5673, 'accent': 0xFF5B2C9E, 'ring': 0xFFB49450, 'line': 0xFFE4DFEC}, {'bg': 0xFF0B0714, 'surface': 0xFF160F26, 'ink': 0xFFF2EEF9, 'muted': 0xFFB3A8C8, 'accent': 0xFFA87BFF, 'ring': 0xFFE3C98A, 'line': 0xFF2B2142},
        titleFont: 'Markazi Text', bodyFont: 'Readex Pro', clockFont: 'El Messiri', layout: 'split', shape: 'squircle', bg: 'aurora'),
  ];
}
