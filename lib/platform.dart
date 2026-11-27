import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show RouteObserver, ModalRoute;
import 'package:flutter/services.dart';

/// تطبيق مثبت على الشاشة.
class InstalledApp {
  final String package;
  final String label;
  final bool isTv;

  const InstalledApp({required this.package, required this.label, required this.isTv});

  factory InstalledApp.fromMap(Map<dynamic, dynamic> m) => InstalledApp(
        package: m['package'] as String,
        label: m['label'] as String,
        isTv: (m['isTv'] as bool?) ?? false,
      );
}

/// الأيقونة الرسمية والبانر الأفقي لتطبيق.
class AppArt {
  final Uint8List? banner;
  final Uint8List? icon;
  const AppArt({this.banner, this.icon});
}

/// الجسر مع طبقة أندرويد (MainActivity.kt).
/// يرن كل ما ينضغط زر الهوم والواجهة مفتوحة (للرجوع لأول تطبيق).
final ValueNotifier<int> homeSignal = ValueNotifier(0);

/// يرن لما تنضغط نجمة الريموت ورونق قدامك (الإجراء من شاشة «زر النجمة»).
final ValueNotifier<int> starSignal = ValueNotifier(0);

/// يراقب فتح وإغلاق الشاشات (حتى ترجع الواجهة لأول تطبيق عند العودة لها).
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class NativeBridge {
  static const _ch = MethodChannel('rawnaq/apps');

  /// يستقبل الأحداث القادمة من أندرويد.
  static void listen() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'homePressed') homeSignal.value++;
      if (call.method == 'starPressed') {
        final front = (call.arguments as Map?)?['wasFront'] == true;
        if (front) {
          starSignal.value++;
        } else {
          homeSignal.value++;
        }
      }
      return null;
    });
  }
  static const _events = EventChannel('rawnaq/app_events');

  static Future<List<InstalledApp>> getApps() async {
    final raw = await _ch.invokeMethod<List<dynamic>>('getApps') ?? const [];
    return raw.map((e) => InstalledApp.fromMap(e as Map)).toList();
  }

  static Future<AppArt> getArt(String package) async {
    final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('getIcons', {'package': package});
    if (m == null) return const AppArt();
    return AppArt(banner: m['banner'] as Uint8List?, icon: m['icon'] as Uint8List?);
  }

  /// يُستدعى مع كل فتح تطبيق (لصف «آخر ما فتحته»).
  static void Function(String package)? onLaunch;

  static Future<bool> launch(String package) async {
    final ok = await _ch.invokeMethod<bool>('launch', {'package': package}) ?? false;
    if (ok) onLaunch?.call(package);
    return ok;
  }

  static Future<void> appInfo(String package) => _ch.invokeMethod('appInfo', {'package': package});

  static Future<void> uninstall(String package) => _ch.invokeMethod('uninstall', {'package': package});

  static Future<void> systemSettings() => _ch.invokeMethod('systemSettings');

  /// ثيم شاشة رونق الأولى المحفوظ ومدة تشغيل الجهاز (لمعرفة أول تشغيل).
  static Future<({bool day, int uptimeMs})> splashInfo() async {
    final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('splashInfo') ?? const {};
    return (day: m['day'] == true, uptimeMs: (m['uptime'] as num?)?.toInt() ?? 0);
  }

  /// يثبت ثيم أول لقطة للتشغيل الجاي (أندرويد ١٣+).
  static Future<bool> setSplashTheme(bool day) async => await _ch.invokeMethod<bool>('setSplashTheme', {'day': day}) ?? false;

  static Future<void> wifiSettings() => _ch.invokeMethod('wifiSettings');

  static Future<void> bluetoothSettings() => _ch.invokeMethod('bluetoothSettings');

  static Future<void> displaySettings() => _ch.invokeMethod('displaySettings');

  static Future<void> soundSettings() => _ch.invokeMethod('soundSettings');

  /// حجب الإعلانات بكل الجهاز (DNS خاص). يرجع false إذا الصلاحية مو ممنوحة.
  static Future<bool> setPrivateDns(bool on) async {
    try {
      return await _ch.invokeMethod<bool>('setPrivateDns', {'on': on}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setMute(bool on) async {
    try {
      await _ch.invokeMethod('setMute', {'on': on});
    } catch (_) {}
  }

  /// مجلد الخلفيات الخاص بالتطبيق (يُنسخ له من الحاسبة أو الفلاشة).
  static Future<String> wallpaperDir() async => await _ch.invokeMethod<String>('wallpaperDir') ?? '';

  static Future<List<String>> listImages(String dir) async =>
      (await _ch.invokeMethod<List<dynamic>>('listImages', {'dir': dir}) ?? const []).cast<String>();

  static Future<List<String>> usbDirs() async {
    try {
      return ((await _ch.invokeMethod<List>('usbDirs')) ?? const []).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> deleteFile(String path) => _ch.invokeMethod('deleteFile', {'path': path});

  static Future<bool> requestStorage() async => await _ch.invokeMethod<bool>('requestStorage') ?? false;

  /// ينسخ الصور من الفلاشة والذاكرة إلى مجلد الخلفيات. يرجع عدد الصور المنسوخة.
  static Future<int> importImages() async => await _ch.invokeMethod<int>('importImages') ?? 0;

  static Future<Map<String, dynamic>> deviceInfo() async {
    try {
      final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('deviceInfo');
      return Map<String, dynamic>.from(m ?? const {});
    } catch (_) {
      return const {};
    }
  }

  /// حالة النظام للوحة السريعة: الشبكة، المساحة، الذاكرة، الصوت.
  static Future<Map<String, dynamic>> systemStatus() async {
    try {
      return Map<String, dynamic>.from(await _ch.invokeMethod<Map<dynamic, dynamic>>('systemStatus') ?? const {});
    } catch (_) {
      return const {};
    }
  }

  /// يرجع الذاكرة المحررة بالميغابايت.
  static Future<int> cleanMemory() async => await _ch.invokeMethod<int>('cleanMemory') ?? 0;

  static Future<int> setVolume(int v) async => await _ch.invokeMethod<int>('setVolume', {'value': v}) ?? v;

  /// يطفي الشاشة (وضع الاستعداد). يرجع false إذا الصلاحية مو مفعلة.
  static Future<bool> sleepNow() async => await _ch.invokeMethod<bool>('sleepNow') ?? false;

  static Future<void> keepScreenOn(bool on) => _ch.invokeMethod('keepScreenOn', {'on': on});

  /// يوقف شاشة سكون النظام (Daydream) حتى تشتغل شاشة سكون رونق فقط.
  static Future<bool> disableSystemSaver() async => await _ch.invokeMethod<bool>('disableSystemSaver') ?? false;

  /// يرجع: on | off | no_permission
  static Future<String> setForceLandscape(bool on) async =>
      await _ch.invokeMethod<String>('setForceLandscape', {'on': on}) ?? 'off';

  /// يطلق حدث عند تثبيت أو حذف أو تحديث أي تطبيق.
  static Stream<dynamic> get packageEvents => _events.receiveBroadcastStream();
}


/// قناة الستريمر (StreamerBridge.kt): الحارس، التنبيهات، الطاقة، البحث، العرض، التحديث.
class Streamer {
  static const _ch = MethodChannel('rawnaq/streamer');

  static Future<T?> _call<T>(String m, [Map<String, Object?>? a]) async {
    try {
      return await _ch.invokeMethod<T>(m, a);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _map(String m, [Map<String, Object?>? a]) async =>
      Map<String, dynamic>.from(await _call<Map<dynamic, dynamic>>(m, a) ?? const {});

  // الحارس
  static Future<Map<String, dynamic>> guardStatus() => _map('guardStatus');
  static Future<bool> guardSet(bool on) async => await _call<bool>('guardSet', {'on': on}) ?? false;
  static Future<bool> guardPause(int minutes) async => await _call<bool>('guardPause', {'minutes': minutes}) ?? false;
  static Future<void> accessibilitySettings() => _call('accessibilitySettings');
  static Future<void> toFront() => _call('toFront');

  // التنبيهات
  static Future<bool> notifAccess() async => await _call<bool>('notifAccess') ?? false;
  static Future<bool> notifEnable() async => await _call<bool>('notifEnable') ?? false;
  static Future<void> notifSettings() => _call('notifSettings');
  static Future<List<Map<String, dynamic>>> notifications() async =>
      [for (final m in (await _call<List<dynamic>>('notifications') ?? const [])) Map<String, dynamic>.from(m as Map)];
  static Future<void> notifClear() => _call('notifClear');

  // الطاقة
  static Future<void> powerConfig({required String method, required String off, required String on, required int wait}) =>
      _call('powerConfig', {'method': method, 'off': off, 'on': on, 'wait': wait});
  static Future<Map<String, dynamic>> powerStatus() => _map('powerStatus');

  // إعدادات النظام
  static Future<String?> getSetting(String ns, String key) => _call<String>('getSetting', {'ns': ns, 'key': key});
  static Future<bool> putSetting(String ns, String key, String value) async =>
      await _call<bool>('putSetting', {'ns': ns, 'key': key, 'value': value}) ?? false;

  // البحث
  static Future<bool> webSearch(String q) async => await _call<bool>('webSearch', {'q': q}) ?? false;
  static Future<bool> voiceSearch() async => await _call<bool>('voiceSearch') ?? false;

  // العرض والصوت
  static Future<Map<String, dynamic>> displayInfo() => _map('displayInfo');

  // التحديث
  static Future<String> installSource() async => await _call<String>('installSource') ?? '';
  static Future<bool> installApk(String path) async => await _call<bool>('installApk', {'path': path}) ?? false;
  static Future<String> silentMode() async => await _call<String>('silentMode') ?? 'ask';
  static Future<bool> releaseOwner() async => await _call<bool>('releaseOwner') ?? false;
  static Future<bool> confirmInstall() async => await _call<bool>('confirmInstall') ?? false;
  static Future<Map<dynamic, dynamic>?> updateStatus() => _call<Map<dynamic, dynamic>>('updateStatus');
  static Future<bool> hasPackage(String pkg) async => await _call<bool>('hasPackage', {'package': pkg}) ?? false;
}
