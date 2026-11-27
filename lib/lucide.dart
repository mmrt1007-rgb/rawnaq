import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'lucide_paths.dart';

/// أيقونة Lucide الأصلية بالاسم — نفس مكتبة فيكما "04 · الأيقونات" بالضبط (١٦٩ أيقونة).
/// قاعدة موحدة لكل الثيم: خط ٢، زوايا مدورة، شبكة ٢٤. بدون نجوم ولا رموز ذكاء اصطناعي.
@immutable
class Lu {
  final String name;
  const Lu(this.name);

  /// الاسم العربي للأيقونة.
  String get label => lucideLabels[name]?.$1 ?? name;

  static const square = Lu('square'), squircle = Lu('squircle'), circle = Lu('circle'), bannerShape = Lu('rectangle-horizontal');
  static const textSize = Lu('a-large-small'), rabbit = Lu('rabbit'), turtle = Lu('turtle'), zap = Lu('zap'), wand = Lu('wand'), timerReset = Lu('timer-reset');
  static const house = Lu('house'), grid = Lu('layout-grid'), dashboard = Lu('layout-dashboard'), layoutTop = Lu('layout-panel-top');
  static const panelsTopLeft = Lu('panels-top-left'), appWindow = Lu('app-window'), layoutList = Lu('layout-list'), rows = Lu('rows-3');
  static const columns3 = Lu('columns-3'), gallery = Lu('gallery-horizontal-end'), squareStack = Lu('square-stack'), panelLeft = Lu('panel-left');
  static const settings = Lu('settings'), sliders = Lu('sliders-horizontal'), search = Lu('search'), plus = Lu('plus');
  static const x = Lu('x'), check = Lu('check'), circleCheck = Lu('circle-check'), circleMinus = Lu('circle-minus');
  static const chevronLeft = Lu('chevron-left'), chevronRight = Lu('chevron-right'), chevronUp = Lu('chevron-up'), chevronDown = Lu('chevron-down');
  static const arrowLeftRight = Lu('arrow-left-right'), sortAz = Lu('arrow-down-a-z'), move = Lu('move'), rotateCcw = Lu('rotate-ccw');
  static const refresh = Lu('refresh-cw'), pencil = Lu('pencil'), trash = Lu('trash'), info = Lu('info');
  static const lock = Lu('lock'), lockOpen = Lu('lock-open'), eye = Lu('eye'), eyeOff = Lu('eye-off');
  static const pin = Lu('pin'), heart = Lu('heart'), bell = Lu('bell'), power = Lu('power');
  static const logOut = Lu('log-out'), maximize = Lu('maximize'), minimize = Lu('minimize'), tv = Lu('tv');
  static const tvPlay = Lu('tv-minimal-play'), monitor = Lu('monitor'), monitorPlay = Lu('monitor-play'), cast = Lu('cast');
  static const wifi = Lu('wifi'), wifiOff = Lu('wifi-off'), network = Lu('network'), bluetooth = Lu('bluetooth');
  static const volume = Lu('volume-2'), volumeOff = Lu('volume-x'), cpu = Lu('cpu'), memory = Lu('memory-stick');
  static const drive = Lu('hard-drive'), usb = Lu('usb'), gauge = Lu('gauge'), timer = Lu('timer');
  static const hourglass = Lu('hourglass'), download = Lu('download'), upload = Lu('upload'), keyboard = Lu('keyboard');
  static const gamepad = Lu('gamepad-2'), smartphone = Lu('smartphone'), scanEye = Lu('scan-eye'), palette = Lu('palette');
  static const swatchBook = Lu('swatch-book'), type = Lu('type'), textInput = Lu('text-cursor-input'), image = Lu('image');
  static const imageOff = Lu('image-off'), images = Lu('images'), frame = Lu('frame'), layers = Lu('layers');
  static const droplet = Lu('droplet'), contrast = Lu('contrast'), sunMoon = Lu('sun-moon'), shapes = Lu('shapes');
  static const crown = Lu('crown'), clock = Lu('clock'), calendar = Lu('calendar'), calendarDays = Lu('calendar-days');
  static const sunrise = Lu('sunrise'), sun = Lu('sun'), sunset = Lu('sunset'), moon = Lu('moon');
  static const cloud = Lu('cloud'), cloudSun = Lu('cloud-sun'), cloudMoon = Lu('cloud-moon'), cloudRain = Lu('cloud-rain');
  static const cloudLightning = Lu('cloud-lightning'), cloudFog = Lu('cloud-fog'), cloudSnow = Lu('cloud-snow'), wind = Lu('wind');
  static const thermometer = Lu('thermometer'), droplets = Lu('droplets'), landmark = Lu('landmark'), compass = Lu('compass');
  static const mapPin = Lu('map-pin'), play = Lu('play'), film = Lu('film'), clapperboard = Lu('clapperboard');
  static const book = Lu('book-open'), trophy = Lu('trophy'), folder = Lu('folder'), radio = Lu('radio');
  static const audio = Lu('audio-lines'), newspaper = Lu('newspaper'), globe = Lu('globe'), shoppingBag = Lu('shopping-bag');
  static const camera = Lu('camera'), presentation = Lu('presentation'), coffee = Lu('coffee'), mountain = Lu('mountain-snow');
  static const trees = Lu('trees'), waves = Lu('waves-horizontal'), flower = Lu('flower-2'), paw = Lu('paw-print');
  static const bird = Lu('bird'), utensils = Lu('utensils'), building = Lu('building'), telescope = Lu('telescope');
  static const deviceSettings = Lu('monitor-cog'), shieldCheck = Lu('shield-check'), mic = Lu('mic'), bellRing = Lu('bell-ring');
  static const bellDot = Lu('bell-dot'), bellOff = Lu('bell-off'), cloudDownload = Lu('cloud-download'), package = Lu('package');
  static const rocket = Lu('rocket'), badgeCheck = Lu('badge-check'), users = Lu('users'), baby = Lu('baby'), userRound = Lu('user-round');
  static const key = Lu('key-round'), star = Lu('star'), plug = Lu('plug'), plugZap = Lu('plug-zap'), cable = Lu('cable'), hdmi = Lu('hdmi-port');
  static const router = Lu('router'), speaker = Lu('speaker'), smartHome = Lu('house-plug'), lightbulb = Lu('lightbulb'), moonStar = Lu('moon-star');
  static const scaling = Lu('scaling'), zoomIn = Lu('zoom-in'), sparkles = Lu('sparkles'), penLine = Lu('pen-line'), arrowUpDown = Lu('arrow-up-down'), scan = Lu('scan'), shuffle = Lu('shuffle'), sunDim = Lu('sun-dim'), penTool = Lu('pen-tool'), loaderCircle = Lu('loader-circle'), listChecks = Lu('list-checks'), circleX = Lu('circle-x');
  static const quote = Lu('quote'), calendarHeart = Lu('calendar-heart');
  static const palm = Lu('tree-palm'), leaf = Lu('leaf'), car = Lu('car'), plane = Lu('plane');
  static const umbrella = Lu('umbrella'), locate = Lu('locate-fixed'), navigation = Lu('navigation'), haze = Lu('haze'), cloudDrizzle = Lu('cloud-drizzle');
  static const cloudSunRain = Lu('cloud-sun-rain'), cloudMoonRain = Lu('cloud-moon-rain'), cloudy = Lu('cloudy'), sunMedium = Lu('sun-medium');
  static const feelsLike = Lu('thermometer-sun'), mapPinned = Lu('map-pinned'), arrowUp = Lu('arrow-up'), arrowDown = Lu('arrow-down');
  static const scrollText = Lu('scroll-text'), searchX = Lu('search-x'), chart = Lu('chart-column'), devices = Lu('monitor-smartphone');
  static const thanks = Lu('heart-handshake'), userPen = Lu('user-round-pen'), calendarRange = Lu('calendar-range'), backspace = Lu('delete'), handHeart = Lu('hand-heart');

  /// كل الأيقونات بالترتيب (لمنتقي الأيقونات).
  static List<Lu> get all => [for (final k in lucidePaths.keys) Lu(k)];
}

final Map<String, Path> _cache = {};

Path _pathFor(String name) => _cache.putIfAbsent(name, () {
      final p = Path();
      for (final d in lucidePaths[name] ?? const <String>[]) {
        p.addPath(parseSvgPathData(d), Offset.zero);
      }
      return p;
    });

/// يرسم أيقونة Lucide الأصلية (بدون أي أيقونات مولّدة أو Material).
class AppIcon extends StatelessWidget {
  final Object icon;
  final double? size;
  final Color? color;
  final List<Shadow>? shadows;
  final double strokeWidth;
  const AppIcon(this.icon, {super.key, this.size, this.color, this.shadows, this.strokeWidth = 2});

  @override
  Widget build(BuildContext context) {
    final s = size ?? IconTheme.of(context).size ?? 24;
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    final i = icon;
    final name = i is Lu ? i.name : i.toString();
    Widget paint(Color col) => CustomPaint(size: Size.square(s), painter: _LucidePainter(name, col, strokeWidth));
    // الأيقونة بحجمها بالضبط دائماً: حتى لو الأب فرض مساحة أكبر أو غير مربعة ما تكبر وتغطي النص اللي يمها
    if (shadows == null || shadows!.isEmpty) return fixedBox(s, s, RepaintBoundary(child: paint(c)));
    final sh = shadows!.first;
    return fixedBox(s, s, Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Transform.translate(
            offset: sh.offset,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sh.blurRadius / 3, sigmaY: sh.blurRadius / 3),
              child: paint(sh.color),
            ),
          ),
        ),
        paint(c),
      ]));
  }
}

/// صندوق بحجم ثابت ما يتمدد ويه قيود الأب: إذا الأب فرض مساحة أكبر، المحتوى يبقى بحجمه ويتوسط.
Widget fixedBox(double w, double h, Widget child) =>
    Center(widthFactor: 1, heightFactor: 1, child: SizedBox(width: w, height: h, child: child));

class _LucidePainter extends CustomPainter {
  final String name;
  final Color color;
  final double stroke;
  _LucidePainter(this.name, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final k = side / 24;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(k, k);
    canvas.drawPath(
      _pathFor(name),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LucidePainter o) => o.name != name || o.color != color || o.stroke != stroke;
}
