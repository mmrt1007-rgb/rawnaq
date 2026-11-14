import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_drawing/path_drawing.dart';

import 'lucide_paths.dart';
import 'state.dart';

// ═══════════════════════════════════════════════════════════════════════
//  مشهد الطقس الحي — نفس محرك المعاينة الحية بتصميم فيكما (صفحة ١٤):
//  غيوم بثلاث طبقات تمشي ويا الريح، مطر بعمق، قطرات تنزلق على الزجاج،
//  برق متفرع، شمس بأشعة ووهج، ليل بنجوم وقمر، ضباب ونخيل، وعجاج.
// ═══════════════════════════════════════════════════════════════════════

double _pw(num b, num e) => math.pow(b, e).toDouble();
Color _c(int v) => Color(v);
Color _a(Color c, double a) => c.withValues(alpha: (c.a * a).clamp(0.0, 1.0));

class _Look {
  final List<Color> sky;
  final List<List<Color>>? tones;
  final List<int> counts;
  final double rain;
  final bool storm, stars, sun, fog, dust, palms, rays, shafts, snow, moonDim;
  final Color? glow;
  const _Look(this.sky,
      {this.tones,
      this.counts = const [6, 5, 4],
      this.rain = 0,
      this.storm = false,
      this.stars = false,
      this.sun = false,
      this.fog = false,
      this.dust = false,
      this.palms = false,
      this.rays = false,
      this.shafts = false,
      this.snow = false,
      this.moonDim = false,
      this.glow});
}

_Look _lookFor(String kind, bool n) {
  List<Color> l(List<int> v) => v.map(_c).toList();
  List<List<Color>> t(List<List<int>> v) => v.map(l).toList();
  switch (kind) {
    case 'rain':
    case 'drizzle':
      return _Look(
        n ? l([0xFF173438, 0xFF0C2120, 0xFF06120E]) : l([0xFFA3B3B6, 0xFFCBD3D0, 0xFFE9E7E0]),
        tones: n
            ? t([[0xFF56767C, 0xFF2B4347, 0xFF132527], [0xFF4B6A70, 0xFF1E3337, 0xFF0B1A1C], [0xFF34494D, 0xFF132325, 0xFF060F10]])
            : t([[0xFFFFFFFF, 0xFFD6DEDE, 0xFFA6B4B7], [0xFFF7F9F8, 0xFFBCC7C8, 0xFF7F9196], [0xFFE6EBEA, 0xFFA2B0B3, 0xFF64767C]]),
        rain: kind == 'drizzle' ? 0.35 : 1,
        shafts: kind == 'rain',
        glow: n ? _c(0xFF1F7A5C) : Colors.white,
      );
    case 'storm':
      return _Look(
        n ? l([0xFF1B1A30, 0xFF121A24, 0xFF06120E]) : l([0xFF8A8EA3, 0xFFB6B9C6, 0xFFE6E4DE]),
        tones: n
            ? t([[0xFF605F86, 0xFF2C2C48, 0xFF14141F], [0xFF504F76, 0xFF1F1F36, 0xFF0B0B14], [0xFF3C3D5C, 0xFF16162C, 0xFF06060C]])
            : t([[0xFFF4F4F8, 0xFFC3C5D2, 0xFF9396AA], [0xFFE6E7EE, 0xFFA3A6B9, 0xFF6E7288], [0xFFD2D4DE, 0xFF83879C, 0xFF50546A]]),
        rain: 1.5,
        storm: true,
        shafts: true,
        glow: n ? _c(0xFF2A2850) : _c(0xFFECEBF2),
      );
    case 'cloudy':
    case 'snow':
      return _Look(
        n ? l([0xFF1C2A33, 0xFF132022, 0xFF06120E]) : l([0xFF93ADBF, 0xFFC6D3DA, 0xFFEFEDE6]),
        tones: n
            ? t([[0xFF5E727C, 0xFF2C3C44, 0xFF151F24], [0xFF56697A, 0xFF24333B, 0xFF10191C], [0xFF475A63, 0xFF1C2930, 0xFF0A1114]])
            : t([[0xFFFFFFFF, 0xFFDCE3E6, 0xFFAEBCC3], [0xFFFFFFFF, 0xFFCFD8DC, 0xFF96A7AF], [0xFFF6F8F9, 0xFFBAC6CB, 0xFF7E9098]]),
        rays: kind == 'cloudy',
        snow: kind == 'snow',
        glow: n ? _c(0xFFD8B467) : _c(0xFFFFF3D6),
      );
    case 'partly':
      return _Look(
        n ? l([0xFF0A1D2A, 0xFF081A1A, 0xFF06120E]) : l([0xFF6FAEDB, 0xFFA9D1EC, 0xFFF6EFE2]),
        tones: n
            ? t([[0xFF4A5E6C, 0xFF223440, 0xFF101C24], [0xFF4A5E6C, 0xFF223440, 0xFF101C24], [0xFF4A5E6C, 0xFF223440, 0xFF101C24]])
            : t([[0xFFFFFFFF, 0xFFEEF3F6, 0xFFC9D6DF], [0xFFFFFFFF, 0xFFE6EDF1, 0xFFBCCAD4], [0xFFFFFFFF, 0xFFE6EDF1, 0xFFBCCAD4]]),
        counts: const [4, 3, 0],
        stars: n,
        sun: !n,
      );
    case 'fog':
      return _Look(n ? l([0xFF1E2B2C, 0xFF162221, 0xFF0B1513]) : l([0xFFC4CCCB, 0xFFDADFDD, 0xFFF2F1EC]), fog: true, palms: true, moonDim: true);
    case 'dust':
      return _Look(n ? l([0xFF3A2A16, 0xFF22190E, 0xFF0E0B07]) : l([0xFFC49C62, 0xFFDEC496, 0xFFF2E9D8]), dust: true, palms: true, moonDim: true);
    default: // clear
      return _Look(
        n ? l([0xFF0A1D2A, 0xFF081A1A, 0xFF06120E]) : l([0xFF6FAEDB, 0xFFA9D1EC, 0xFFF6EFE2]),
        tones: n ? null : t([[0xFFFFFFFF, 0xFFEEF3F6, 0xFFD3DEE6], [0xFFFFFFFF, 0xFFEEF3F6, 0xFFD3DEE6], [0xFFFFFFFF, 0xFFEEF3F6, 0xFFD3DEE6]]),
        counts: const [3, 0, 0],
        stars: n,
        sun: !n,
      );
  }
}

class _Sprite {
  ui.Image? img;
  double x, y, w, h, speed, ph;
  _Sprite(this.x, this.y, this.w, this.h, this.speed, this.ph);
}

class _Streak {
  double x, y, l, w, a, v;
  final int layer;
  _Streak(this.x, this.y, this.l, this.w, this.a, this.v, this.layer);
}

class _Drop {
  double x, y, r, vy = 0, trail = 0, hold = 0;
  bool slide = false;
  final double wob;
  _Drop(this.x, this.y, this.r, this.wob);
}

class _Dot {
  double x, y, r, v, ph, a;
  _Dot(this.x, this.y, this.r, this.v, this.ph, this.a);
}

/// النموذج: يحسب الحركة كل إطار ويبلّغ الرسامين.
class _SkyModel extends ChangeNotifier {
  final math.Random rnd = math.Random();
  double r(double a, double b) => a + rnd.nextDouble() * (b - a);

  String kind = 'clear';
  bool night = true, glass = true, compact = false, overlay = false;
  double dir = 1, windK = 1, intensity = 1;
  String motion = 'full';
  late _Look look;
  Size size = Size.zero;
  double t = 0, dt = 0;
  int _gen = 0;

  final layers = <List<_Sprite>>[[], [], []];
  final fogs = <_Sprite>[];
  final bands = <_Sprite>[];
  final shafts = <_Sprite>[];
  final streaks = <_Streak>[];
  final stars = <_Dot>[];
  final dust = <_Dot>[];
  final flakes = <_Dot>[];
  final drops = <_Drop>[];
  ui.Image? mist;
  Path? palmTrunks, palmFronds;
  List<List<Offset>>? bolt;
  double flash = 0, boltLife = 0, nextBolt = 2, boltX = 0;
  Offset? shoot;
  double shootP = 0, nextShoot = 4;

  bool get light => motion == 'light' || AppState.I.lite;

  void configure({required String kind, required bool night, required double dir, required double windK, required double intensity, required bool glass, required bool compact, bool overlay = false}) {
    final changed = kind != this.kind || night != this.night || compact != this.compact || glass != this.glass || overlay != this.overlay;
    this.overlay = overlay;
    this.kind = kind;
    this.night = night;
    this.dir = dir;
    this.windK = windK;
    this.intensity = intensity;
    this.glass = glass;
    this.compact = compact;
    motion = AppState.I.cfg.s('weather.motion');
    look = _lookFor(kind, night);
    if (changed && size != Size.zero) _build();
  }

  void resize(Size s) {
    if (s == size || s.isEmpty) return;
    size = s;
    _build();
  }

  double get _k => compact ? 0.28 : (light ? 0.6 : 1.0);

  void _build() {
    final gen = ++_gen;
    final w = size.width, h = size.height;
    for (final l in layers) {
      l.clear();
    }
    fogs.clear();
    bands.clear();
    shafts.clear();
    streaks.clear();
    stars.clear();
    dust.clear();
    flakes.clear();
    drops.clear();
    mist = null;
    bolt = null;
    palmTrunks = palmFronds = null;
    final L = look;
    final tones = L.tones;
    if (tones != null && !overlay) {
      final counts = compact ? [math.min(L.counts[0], 2), math.min(L.counts[1], 2), math.min(L.counts[2], 1)] : L.counts;
      final spec = [
        (0.34, 0.46, 0.20, 0.27, 12.0),
        (0.20, 0.30, 0.30, 0.40, 28.0),
        (0.0, 0.06, 0.44, 0.58, 55.0),
      ];
      for (var li = 0; li < 3; li++) {
        final n = counts[li];
        for (var i = 0; i < n; i++) {
          final cw = w * r(spec[li].$3, spec[li].$4), ch = cw * r(0.3, 0.38);
          final sp = _Sprite(-cw * 0.5 + (i + r(0, 0.8)) * (w + cw) / math.max(1, n), r(spec[li].$1, spec[li].$2) * h - ch * 0.4, cw, ch, spec[li].$5 * w / 1280, r(0, 6));
          layers[li].add(sp);
          _cloudImage(cw, ch, tones[li], (li == 0 ? 16.0 : li == 1 ? 18.0 : 22.0) * w / 1280).then((img) {
            if (gen == _gen) sp.img = img;
          });
        }
      }
      if (L.shafts && !compact) {
        for (var i = 0; i < 3; i++) {
          shafts.add(_Sprite(r(0.05, 0.9) * w, h * 0.3, r(70, 160) * w / 1280, h * 0.7, 0, r(0.08, 0.16)));
        }
      }
    }
    if (L.rain > 0) {
      final k = L.rain * intensity.clamp(0.3, 1.5) * _k;
      final spec = [
        (150.0, 1, 10.0, 26.0, 0.7, 1.1, 0.28, 620.0),
        (80.0, 2, 24.0, 60.0, 1.1, 1.6, 0.36, 980.0),
        (16.0, 3, 110.0, 190.0, 2.4, 3.4, 0.14, 1500.0),
      ];
      final sc = h / 720;
      for (final s in spec) {
        for (var i = 0; i < (s.$1 * k).round(); i++) {
          streaks.add(_Streak(r(-100, w + 200), r(-h, h), r(s.$3, s.$4) * sc, r(s.$5, s.$6) * sc, s.$7 * r(0.4, 1), s.$8 * sc * r(0.8, 1.2), s.$2));
        }
      }
    }
    if (L.stars) {
      for (var i = 0; i < (260 * _k).round(); i++) {
        stars.add(_Dot(r(0, w), r(0, h * 0.8), _pw(rnd.nextDouble(), 3) * 1.6 * h / 720 + 0.4, r(0.6, 2.2), r(0, 6), rnd.nextDouble() < 0.15 ? 1 : 0));
      }
    }
    if (L.snow) {
      for (var i = 0; i < (180 * _k).round(); i++) {
        flakes.add(_Dot(r(0, w), r(0, h), r(1, 3.2) * h / 720, r(30, 80) * h / 720, r(0, 6), r(0.5, 0.95)));
      }
    }
    if (L.dust) {
      for (var i = 0; i < (520 * _k).round(); i++) {
        dust.add(_Dot(r(0, w), r(0, h), (_pw(rnd.nextDouble(), 2) * 1.5 + 0.4) * h / 720, r(60, 190) * w / 1280, r(0, 6), r(0.25, 0.7)));
      }
      for (var i = 0; i < (compact ? 3 : 7); i++) {
        final sp = _Sprite(r(-0.3, 1) * w, r(0.15, 0.95) * h, r(0.7, 1.15) * w, r(60, 120) * h / 720, r(20, 60) * w / 1280, 0);
        bands.add(sp);
        _blobImage(sp.w, sp.h, night ? _c(0xFF8A6A3A) : _c(0xFFC08A45), night ? 0.5 : 0.45, 22 * w / 1280).then((img) {
          if (gen == _gen) sp.img = img;
        });
      }
    }
    if (L.fog) {
      final col = night ? _c(0xFFA6B8B9) : Colors.white;
      final spec = [(0.18, 0.4, 0.1, 10.0, 6, night ? 0.22 : 0.55), (0.35, 0.7, 0.14, 22.0, 5, night ? 0.25 : 0.6), (0.55, 1.0, 0.2, 40.0, 4, night ? 0.3 : 0.7)];
      for (var li = 0; li < 3; li++) {
        final s = spec[li];
        for (var i = 0; i < (compact ? 2 : s.$5); i++) {
          final sp = _Sprite(r(-0.4, 1) * w, r(s.$1, s.$2) * h, r(0.7, 1.15) * w, s.$3 * h, s.$4 * r(0.7, 1.3) * w / 1280, li.toDouble());
          fogs.add(sp);
          _blobImage(sp.w, sp.h, col, s.$6, (24 + li * 8) * w / 1280).then((img) {
            if (gen == _gen) sp.img = img;
          });
        }
      }
    }
    if (L.palms && !overlay) _buildPalms();
    if (glass && (L.rain > 0 || L.fog || L.dust || kind == 'cloudy')) {
      _mistImage().then((img) {
        if (gen == _gen) mist = img;
      });
      if (L.rain > 0) {
        for (var i = 0; i < (compact ? 7 : 70); i++) {
          drops.add(_Drop(r(0, w), r(0, h), (_pw(rnd.nextDouble(), 2.4) * 6 + 1.2) * h / 720, r(0, 6)));
        }
      } else if (L.fog) {
        for (var i = 0; i < (compact ? 2 : 12); i++) {
          drops.add(_Drop(r(0, w), r(0, h), r(1.5, 4.5) * h / 720, r(0, 6)));
        }
      }
    }
    nextBolt = r(1.2, 3);
    nextShoot = r(3, 7);
  }

  void _buildPalms() {
    final w = size.width, h = size.height;
    final trunks = Path(), fronds = Path();
    const spec = [(.52, .62, .24, .04), (.57, .62, .19, -.05), (.64, .62, .27, .06), (.69, .62, .18, -.03), (.02, .62, .2, .05), (.985, .62, .2, -.06), (.31, .62, .16, .03), (.22, .62, .14, -.04)];
    for (final s in spec) {
      final x = s.$1 * w, b = s.$2 * h, ph = s.$3 * h, tx = x + s.$4 * ph, ty = b - ph;
      final tw = ph * 0.025;
      trunks
        ..moveTo(x - tw, b)
        ..quadraticBezierTo(x + s.$4 * ph * 0.2 - tw * 0.6, b - ph * 0.5, tx - tw * 0.5, ty)
        ..lineTo(tx + tw * 0.5, ty)
        ..quadraticBezierTo(x + s.$4 * ph * 0.2 + tw * 0.6, b - ph * 0.5, x + tw, b)
        ..close();
      for (final dg in const [-165, -140, -115, -92, -68, -42, -18, 12, 168, 32, 148]) {
        final a = dg * math.pi / 180, L = ph * r(0.34, 0.46), ca = math.cos(a).abs();
        final ex = tx + math.cos(a) * L, ey = ty + math.sin(a) * L * 0.7 + L * 0.38 * ca;
        final mx = tx + math.cos(a) * L * 0.5, my = ty + math.sin(a) * L * 0.38 + L * 0.1 * ca;
        final pw = L * 0.09, px = -math.sin(a) * pw, py = math.cos(a) * pw;
        fronds
          ..moveTo(tx, ty)
          ..quadraticBezierTo(mx + px * 2, my + py * 2, ex, ey)
          ..quadraticBezierTo(mx - px * 2, my - py * 2, tx, ty)
          ..close();
      }
    }
    palmTrunks = trunks;
    palmFronds = fronds;
  }

  Future<ui.Image> _cloudImage(double w, double h, List<Color> tone, double blur) {
    final pad = blur * 3;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final mf = MaskFilter.blur(BlurStyle.normal, blur);
    final base = Rect.fromCenter(center: Offset(pad + w / 2, pad + h * 0.74), width: w * 0.92, height: h * 0.48);
    c.drawOval(base, Paint()..maskFilter = mf..shader = ui.Gradient.linear(Offset(0, pad + h * 0.45), Offset(0, pad + h), [tone[1], tone[2]]));
    for (var i = 0; i < 18; i++) {
      final pw = w * r(0.14, 0.3), x = pad + r(0, w - pw);
      final mid = 1 - ((x + pw / 2 - pad) / w - 0.5).abs() * 1.7;
      final cy = pad + h * 0.72 - pw * r(0.2, 0.45) * (0.5 + math.max(0.1, mid));
      c.drawCircle(
          Offset(x + pw / 2, cy),
          pw / 2,
          Paint()
            ..maskFilter = mf
            ..shader = ui.Gradient.linear(Offset(0, cy - pw / 2), Offset(0, cy + pw / 2), [tone[0], tone[1], tone[2]], const [0, 0.62, 1]));
    }
    return rec.endRecording().toImage((w + pad * 2).ceil(), (h + pad * 2).ceil());
  }

  Future<ui.Image> _blobImage(double w, double h, Color col, double a, double blur) {
    final pad = blur * 3;
    final rec = ui.PictureRecorder();
    Canvas(rec).drawOval(Rect.fromLTWH(pad, pad, w, h), Paint()..color = _a(col, a)..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
    return rec.endRecording().toImage((w + pad * 2).ceil(), (h + pad * 2).ceil());
  }

  Future<ui.Image> _mistImage() {
    final w = size.width, h = size.height;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final dustGlass = look.dust;
    final n = ((look.fog ? 2600 : dustGlass ? 500 : look.rain > 0 ? 900 : 500) * (compact ? 0.15 : 1)).round();
    final cl = [Offset(w * 0.05, h * 0.94), Offset(w * 0.94, h * 0.96), Offset(w * 0.03, h * 0.07), Offset(w * 0.95, h * 0.06)];
    for (var i = 0; i < n; i++) {
      Offset p;
      if (rnd.nextDouble() < 0.7) {
        final o = cl[rnd.nextInt(4)];
        final a = r(0, 6.28), d = _pw(rnd.nextDouble(), 1.6) * w * 0.22;
        p = Offset(o.dx + math.cos(a) * d, o.dy + math.sin(a) * d * 0.6);
      } else {
        p = Offset(r(0, w), r(0, h));
      }
      final rr = (0.35 + _pw(rnd.nextDouble(), 2.2) * (look.fog ? 1.4 : 1.1)) * h / 720;
      if (dustGlass) {
        c.drawCircle(p, rr, Paint()..color = night ? _c(0xFFE2C28C).withValues(alpha: r(0.25, 0.6)) : _c(0xFF6E4E22).withValues(alpha: r(0.25, 0.55)));
        continue;
      }
      c.drawOval(
          Rect.fromCenter(center: p, width: rr * 2, height: rr * 2.16),
          Paint()
            ..shader = ui.Gradient.linear(p.translate(0, -rr), p.translate(0, rr),
                night ? [Colors.black.withValues(alpha: 0.22), const Color(0x73E6F4FF)] : [const Color(0x1F23343A), Colors.white.withValues(alpha: 0.95)]));
    }
    return rec.endRecording().toImage(w.ceil(), h.ceil());
  }

  // ---------- الحركة ----------
  void step(double seconds) {
    if (size.isEmpty) return;
    dt = math.min(0.05, seconds - t).clamp(0.0, 0.05);
    t = seconds;
    final w = size.width, h = size.height;
    final gust = 1 + 0.25 * math.sin(t * 0.23) + 0.12 * math.sin(t * 0.71);
    final slow = motion == 'off' ? 0.0 : 1.0;
    for (var li = 0; li < 3; li++) {
      for (final s in layers[li]) {
        s.x += dir * s.speed * windK * gust * dt * slow;
        if (dir > 0 && s.x > w + 40) s.x = -s.w - 40;
        if (dir < 0 && s.x < -s.w - 40) s.x = w + 40;
      }
    }
    for (final s in shafts) {
      s.x += dir * 28 * w / 1280 * windK * gust * dt * slow;
      if (s.x > w + 200) s.x = -200;
      if (s.x < -260) s.x = w + 180;
    }
    for (final f in fogs) {
      f.x += dir * f.speed * dt * slow;
      if (f.x > w + 100) f.x = -f.w;
      if (f.x < -f.w - 100) f.x = w;
    }
    for (final b in bands) {
      b.x += dir * b.speed * gust * dt * slow;
      if (b.x < -b.w) b.x = w;
      if (b.x > w) b.x = -b.w;
    }
    for (final p in dust) {
      p.x += dir * p.v * gust * dt * slow;
      p.y += math.sin(t * 1.3 + p.ph) * 0.4 * slow;
      if (p.x < -4 && dir < 0) {
        p.x = w + 4;
        p.y = r(0, h);
      }
      if (p.x > w + 4 && dir > 0) {
        p.x = -4;
        p.y = r(0, h);
      }
    }
    final wind = -0.16 * look.rain.clamp(0.0, 1.5) * (dir < 0 ? 1 : -1) * gust;
    for (final d in streaks) {
      d.y += d.v * dt * slow;
      d.x += d.v * wind * dt * slow;
      if (d.y - d.l > h) {
        d.y = r(-200, -20);
        d.x = r(-100, w + 200);
      }
      if (d.x < -200) d.x = w + 100;
      if (d.x > w + 200) d.x = -100;
    }
    for (final f in flakes) {
      f.y += f.v * dt * slow;
      f.x += (math.sin(t + f.ph) * 12 + dir * 18) * dt * slow;
      if (f.y > h + 4) {
        f.y = -4;
        f.x = r(0, w);
      }
    }
    for (final s in stars) {
      s.x += dir * 2.2 * dt * slow;
      if (s.x > w) s.x -= w;
      if (s.x < 0) s.x += w;
    }
    if (look.storm && slow > 0) {
      nextBolt -= dt;
      if (nextBolt < 0) {
        boltX = r(0.35, 0.75) * w;
        bolt = _makeBolt(Offset(boltX, h * 0.1), Offset(boltX + r(-120, 120) * w / 1280, h * r(0.45, 0.6)));
        flash = 1;
        boltLife = 0.42;
        nextBolt = r(2.6, 6.5);
      }
      if (bolt != null) {
        boltLife -= dt;
        if (boltLife < 0) bolt = null;
      }
      flash = math.max(0, flash - dt * 2.4);
    }
    if (look.stars && slow > 0) {
      nextShoot -= dt;
      if (shoot == null && nextShoot < 0) {
        shoot = Offset(r(0.1, 0.5) * w, r(0.05, 0.25) * h);
        shootP = 0;
        nextShoot = r(5, 11);
      }
      if (shoot != null) {
        shootP += dt * 1.1;
        if (shootP > 1) shoot = null;
      }
    }
    if (glass && !light && slow > 0) _stepDrops(w, h, wind);
    notifyListeners();
  }

  void _stepDrops(double w, double h, double wind) {
    final sc = h / 720;
    final k = look.rain > 0 ? look.rain * intensity.clamp(0.3, 1.5) : (look.fog ? 0.08 : 0);
    if (k <= 0) return;
    if (rnd.nextDouble() < 0.55 * k * (compact ? 0.25 : 1)) drops.add(_Drop(r(0, w), r(0, h), (_pw(rnd.nextDouble(), 2.8) * 5 + 1) * sc, r(0, 6)));
    final maxN = compact ? 26 : 260;
    if (drops.length > maxN) {
      final i = drops.indexWhere((d) => !d.slide);
      if (i >= 0) drops.removeAt(i);
    }
    for (var i = drops.length - 1; i >= 0; i--) {
      if (i >= drops.length) continue;
      final d = drops[i];
      if (!d.slide && d.r > 5.4 * sc && rnd.nextDouble() < 0.02) d.slide = true;
      if (!d.slide) continue;
      if (d.hold > 0) {
        d.hold -= dt;
        continue;
      }
      d.vy = math.min(d.vy + (0.6 + d.r / sc * 0.08) * dt * 1.2, d.r * 0.55);
      if (rnd.nextDouble() < 0.012) d.hold = r(0.15, 0.6);
      final dy = d.vy * dt * 60;
      d.y += dy;
      d.x += math.sin(d.y * 0.04 / sc + d.wob) * 0.25 * sc + wind * 0.6 * sc;
      d.trail += dy;
      if (d.trail > d.r * 1.3) {
        d.trail = 0;
        if (rnd.nextDouble() < 0.75) {
          drops.add(_Drop(d.x + r(-0.6, 0.6) * sc, d.y - d.r * 0.9, d.r * r(0.16, 0.32), r(0, 6)));
          d.r *= 0.985;
        }
      }
      for (var j = drops.length - 1; j >= 0; j--) {
        final o = drops[j];
        if (identical(o, d) || o.slide) continue;
        final dx = o.x - d.x, dy2 = o.y - d.y;
        final lim = d.r + o.r * 0.6;
        if (dx * dx + dy2 * dy2 < lim * lim && dy2 > -d.r) {
          d.r = math.min(14 * sc, math.sqrt(d.r * d.r + o.r * o.r));
          drops.removeAt(j);
          if (j < i) i--;
        }
      }
      if (d.y - d.r * 3 > h) {
        final idx = drops.indexOf(d);
        if (idx >= 0) drops.removeAt(idx);
      }
    }
  }

  List<List<Offset>> _makeBolt(Offset a, Offset b) {
    final segs = <List<Offset>>[];
    void mid(Offset p, Offset q, double d, int depth, List<Offset> out) {
      if (depth == 0) {
        out.add(q);
        return;
      }
      final m = Offset((p.dx + q.dx) / 2 + r(-d, d), (p.dy + q.dy) / 2 + r(-d, d) * 0.3);
      mid(p, m, d / 2, depth - 1, out);
      mid(m, q, d / 2, depth - 1, out);
    }

    final sc = size.width / 1280;
    final main = <Offset>[a];
    mid(a, b, 120 * sc, 6, main);
    segs.add(main);
    for (var i = 0; i < 4; i++) {
      final s = main[(r(0.2, 0.7) * main.length).floor()];
      final br = <Offset>[s];
      mid(s, s.translate(r(-110, 110) * sc, r(60, 130) * sc), 50 * sc, 4, br);
      segs.add(br);
    }
    return segs;
  }
}

/// المشهد الحي كاملاً. [compact] للأيقونات والبطاقات الصغيرة.
class WeatherSky extends StatefulWidget {
  final String kind;
  final bool night, glass, compact;
  /// مطر وقطرات فقط فوق خلفية ثانية (شاشة السكون).
  final bool overlay;
  final double dir, windK, intensity;
  const WeatherSky({super.key, required this.kind, required this.night, this.dir = 1, this.windK = 1, this.intensity = 1, this.glass = true, this.compact = false, this.overlay = false});

  @override
  State<WeatherSky> createState() => _WeatherSkyState();
}

class _WeatherSkyState extends State<WeatherSky> with SingleTickerProviderStateMixin {
  final _m = _SkyModel();
  late final Ticker _ticker;

  void _cfg() => _m.configure(
      kind: widget.kind,
      night: widget.night,
      dir: widget.dir,
      windK: widget.windK,
      intensity: widget.intensity,
      glass: widget.glass && AppState.I.cfg.b('weather.glass'),
      compact: widget.compact,
      overlay: widget.overlay);

  @override
  void initState() {
    super.initState();
    _cfg();
    _ticker = createTicker((e) => _m.step(e.inMicroseconds / 1e6));
    if (AppState.I.cfg.s('weather.motion') != 'off' && !AppState.I.cfg.b('misc.reduceMotion')) {
      _ticker.start();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _m.step(1));
    }
  }

  @override
  void didUpdateWidget(WeatherSky old) {
    super.didUpdateWidget(old);
    _cfg();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blurBack = !widget.compact && !widget.overlay && _m.glass && !_m.light && (_m.look.rain > 0 || _m.look.fog);
    return LayoutBuilder(builder: (context, cons) {
      _m.resize(Size(cons.maxWidth, cons.maxHeight));
      Widget sky = CustomPaint(painter: _SkyPainter(_m), size: Size.infinite);
      if (blurBack) {
        sky = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: _m.look.fog ? 3.2 : 1.8, sigmaY: _m.look.fog ? 3.2 : 1.8), child: sky);
      }
      return ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: sky),
          RepaintBoundary(child: CustomPaint(painter: _GlassPainter(_m), size: Size.infinite)),
        ]),
      );
    });
  }
}

class _SkyPainter extends CustomPainter {
  final _SkyModel m;
  _SkyPainter(this.m) : super(repaint: m);

  void _glow(Canvas c, Offset o, double r, Color col, double a, {BlendMode? mode}) {
    if (a <= 0) return;
    final p = Paint()..shader = ui.Gradient.radial(o, r, [_a(col, a), _a(col, 0)]);
    if (mode != null) p.blendMode = mode;
    c.drawCircle(o, r, p);
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, t = m.t, n = m.night, L = m.look, sc = w / 1280;
    if (m.overlay) {
      _precip(c, s);
      return;
    }
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), L.sky, const [0, 0.5, 1]));
    if (L.glow != null) _glow(c, Offset(w * 0.2, h * 0.95), w * 0.45, L.glow!, n ? 0.35 : 0.5);

    // النجوم والقمر
    if (L.stars) {
      final sp = Paint();
      for (final st in m.stars) {
        final a = 0.35 + 0.65 * math.sin(t * st.v + st.ph).abs();
        sp.color = (st.a > 0 ? const Color(0xFFF2E2B5) : Colors.white).withValues(alpha: a);
        c.drawCircle(Offset(st.x, st.y), st.r, sp);
        if (st.r > 1.6 * h / 720) {
          sp.color = Colors.white.withValues(alpha: a * 0.6);
          c.drawRect(Rect.fromCenter(center: Offset(st.x, st.y), width: st.r * 8, height: 0.8), sp);
          c.drawRect(Rect.fromCenter(center: Offset(st.x, st.y), width: 0.8, height: st.r * 8), sp);
        }
      }
      for (var i = 0; i < 8; i++) {
        final u = i / 7;
        _glow(c, Offset((-60 + u * 1400) * sc, (610 - u * 560) * h / 720), 170 * sc, const Color(0xFF8FB0C4), 0.06);
      }
      final mo = Offset(w * 0.6, h * 0.17), mr = 36 * sc;
      _glow(c, mo, mr * 4.2, const Color(0xFFF3E7C2), 0.28);
      c.drawCircle(mo, mr * 3.3 + math.sin(t * 0.4) * 3, Paint()..style = PaintingStyle.stroke..strokeWidth = 8 * sc..color = const Color(0x14E9E1C8));
      c.drawCircle(mo, mr, Paint()..shader = ui.Gradient.linear(mo.translate(-mr, -mr), mo.translate(mr, mr), const [Color(0xFFFFFCF2), Color(0xFFE2D3A8)]));
      final crater = Paint()..color = const Color(0x66BFAE83);
      for (final q in const [(-12.0, -8.0, 10.0), (10.0, 4.0, 8.0), (-2.0, 14.0, 9.0), (14.0, -14.0, 5.0)]) {
        c.drawOval(Rect.fromCenter(center: mo.translate(q.$1 * sc, q.$2 * sc), width: q.$3 * 2 * sc, height: q.$3 * 1.6 * sc), crater);
      }
      c.drawCircle(mo, mr, Paint()..shader = ui.Gradient.linear(mo.translate(-mr, 0), mo.translate(mr * 0.3, 0), const [Color(0x8C0A1D2A), Color(0x000A1D2A)]));
      final sh = m.shoot;
      if (sh != null) {
        final p = m.shootP;
        final end = sh.translate(p * 420 * sc, p * 150 * sc);
        final a = math.sin(math.min(1, p) * math.pi);
        c.drawLine(end.translate(-160 * sc, -57 * sc), end,
            Paint()
              ..strokeWidth = 1.6
              ..shader = ui.Gradient.linear(end.translate(-160 * sc, -57 * sc), end, [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: a)]));
      }
    }

    // الشمس
    if (L.sun) {
      final so = Offset(w * 0.6 + math.sin(t * 0.05) * 6, h * 0.15);
      _glow(c, so, 420 * sc, const Color(0xFFFFE6A6), 0.5);
      _glow(c, so, 160 * sc, const Color(0xFFFFF2CF), 0.9);
      c.save();
      c.translate(so.dx, so.dy);
      c.rotate(t * 0.02 * m.dir);
      for (var i = 0; i < 14; i++) {
        c.rotate(math.pi * 2 / 14);
        final a = 0.02 + 0.022 * math.sin(t * 0.7 + i * 1.7);
        c.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(1000 * sc, -40 * sc)
              ..lineTo(1000 * sc, 40 * sc)
              ..close(),
            Paint()
              ..color = const Color(0xFFFFF6DE).withValues(alpha: a.clamp(0.0, 1.0))
              ..blendMode = BlendMode.plus);
      }
      c.restore();
      c.drawCircle(so, 38 * sc, Paint()..shader = ui.Gradient.radial(so.translate(-8 * sc, -8 * sc), 44 * sc, const [Color(0xFFFFFFFF), Color(0xFFFFF0C2), Color(0xFFFFCF66)], const [0, 0.6, 1]));
      final d = Offset(w * 0.5, h * 0.85) - so;
      for (final f in const [(.25, 24.0, 0xFFFFE6A0, .18), (.42, 10.0, 0xFFFFFFFF, .22), (.6, 46.0, 0xFFA8E2FF, .1), (.78, 16.0, 0xFFFFD27A, .16), (.95, 70.0, 0xFFFFFFFF, .07)]) {
        c.drawCircle(so + d * f.$1, f.$2 * sc, Paint()..color = Color(f.$3).withValues(alpha: f.$4));
      }
    }
    if (L.dust || L.fog) {
      final so = Offset(w * 0.6, h * 0.16);
      if (L.dust) {
        _glow(c, so, 220 * sc, n ? const Color(0xFFE8C98E) : const Color(0xFFFFE6B0), n ? 0.25 : 0.5);
        c.drawCircle(so, 30 * sc, Paint()..color = (n ? const Color(0xFFE8C98E) : const Color(0xFFFBEBC9)).withValues(alpha: n ? 0.45 : 0.8));
      } else {
        _glow(c, so, 180 * sc, n ? const Color(0xFFD9E2E0) : Colors.white, n ? 0.15 : 0.8);
      }
    }
    if (L.rays) {
      final so = Offset(w * 0.6, h * 0.13);
      _glow(c, so, 300 * sc, n ? const Color(0xFFF3E7C2) : const Color(0xFFFFF3D6), n ? 0.2 : 0.8);
      if (!n) {
        for (var i = 0; i < 7; i++) {
          final a = 0.05 + 0.05 * math.sin(t * 0.35 + i * 0.9).abs();
          final x0 = so.dx + (-60 + i * 24) * sc;
          c.drawPath(
              Path()
                ..moveTo(x0, so.dy + 40 * sc)
                ..lineTo(x0 + 16 * sc, so.dy + 40 * sc)
                ..lineTo(x0 + (16 + (i - 3) * 90 + 140) * sc, h)
                ..lineTo(x0 + ((i - 3) * 90 - 40) * sc, h)
                ..close(),
              Paint()
                ..blendMode = BlendMode.plus
                ..shader = ui.Gradient.linear(Offset(0, so.dy), Offset(0, h), [Colors.white.withValues(alpha: a), Colors.white.withValues(alpha: 0)]));
        }
      }
    }

    void layer(List<_Sprite> l) {
      for (final it in l) {
        final img = it.img;
        if (img == null) continue;
        final br = 1 + 0.012 * math.sin(t * 0.2 + it.ph);
        final bob = math.sin(t * 0.13 + it.ph) * 4 * sc;
        final iw = img.width.toDouble() * br, ih = img.height.toDouble() * br;
        c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromLTWH(it.x - (iw - img.width) / 2 - (img.width - it.w) / 2, it.y + bob - (img.height - it.h) / 2, iw, ih), Paint()..filterQuality = FilterQuality.low);
      }
    }

    layer(m.layers[0]);
    if (m.flash > 0) _glow(c, Offset(m.boltX, h * 0.25), 420 * sc, const Color(0xFFD9D2FF), math.min(0.9, m.flash * 0.9));
    for (final sh in m.shafts) {
      final a = sh.ph * (0.7 + 0.3 * math.sin(t * 0.5 + sh.x));
      final col = n ? const Color(0xFF9FC3CC) : const Color(0xFF5F6E78);
      c.save();
      c.translate(sh.x, sh.y);
      c.skew(-0.12 * m.dir, 0);
      c.drawRect(Rect.fromLTWH(0, 0, sh.w, sh.h), Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, sh.h), [col.withValues(alpha: a), col.withValues(alpha: 0)]));
      c.restore();
    }
    layer(m.layers[1]);

    // النخيل
    if (m.palmFronds != null) {
      final col = L.dust ? (n ? const Color(0xD9140E07) : const Color(0x736A4A22)) : (n ? const Color(0x9E081210) : const Color(0x57505C5A));
      final sw = (0.018 * math.sin(t * 0.8) + 0.01) * m.dir * m.windK, b = h * 0.62;
      c.save();
      c.translate(0, b);
      c.skew(sw, 0);
      c.translate(0, -b);
      final pp = Paint()..color = col..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      c.drawPath(m.palmTrunks!, pp);
      c.drawPath(m.palmFronds!, pp);
      c.restore();
    }
    void blob(_Sprite f) {
      final img = f.img;
      if (img == null) return;
      c.drawImage(img, Offset(f.x - (img.width - f.w) / 2, f.y - img.height / 2), Paint());
    }

    for (final f in m.fogs) {
      if (f.ph < 2) blob(f);
    }

    // البرق
    final bolt = m.bolt;
    if (bolt != null && m.boltLife > 0 && !(m.boltLife < 0.33 && m.boltLife > 0.27)) {
      final glowP = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCC9BEFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * sc);
      final core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.95);
      for (final (i, seg) in bolt.indexed) {
        final p = Path()..addPolygon(seg, false);
        c.drawPath(p, glowP..strokeWidth = (i == 0 ? 8 : 4) * sc);
        c.drawPath(p, core..strokeWidth = (i == 0 ? 2.6 : 1.2) * sc);
      }
    }
    layer(m.layers[2]);

    // العجاج
    for (final b in m.bands) {
      blob(b);
    }
    if (m.dust.isNotEmpty) {
      final dp = Paint()..color = n ? const Color(0xFFE2C28C) : const Color(0xFF6E4E22);
      for (final p in m.dust) {
        dp.color = dp.color.withValues(alpha: p.a);
        c.drawRect(Rect.fromLTWH(p.x, p.y, p.r * 2 + p.v * 0.03, p.r * 1.4), dp);
      }
    }
    _precip(c, s);
    for (final f in m.fogs) {
      if (f.ph >= 2) blob(f);
    }
    if (m.flash > 0) c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE1DAFF).withValues(alpha: m.flash * (n ? 0.22 : 0.18)));
  }

  void _precip(Canvas c, Size s) {
    final n = m.night, L = m.look;
    if (m.streaks.isNotEmpty) {
      final wind = -0.16 * L.rain.clamp(0.0, 1.5) * (m.dir < 0 ? 1 : -1);
      final sp = Paint()..strokeCap = StrokeCap.round;
      final base = n ? const Color(0xFFDCEFFF) : const Color(0xFF2B4753);
      for (final d in m.streaks) {
        sp
          ..color = base.withValues(alpha: d.a)
          ..strokeWidth = d.w;
        c.drawLine(Offset(d.x, d.y), Offset(d.x - wind * d.l, d.y - d.l), sp);
      }
    }
    if (m.flakes.isNotEmpty) {
      final fp = Paint();
      for (final f in m.flakes) {
        fp.color = Colors.white.withValues(alpha: f.a);
        c.drawCircle(Offset(f.x, f.y), f.r, fp);
      }
    }
    if (m.overlay && m.flash > 0) c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE1DAFF).withValues(alpha: m.flash * 0.18));
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}

/// الزجاج: التكاثف والقطرات (فوق المشهد وتحت النصوص).
class _GlassPainter extends CustomPainter {
  final _SkyModel m;
  _GlassPainter(this.m) : super(repaint: m);

  @override
  void paint(Canvas c, Size s) {
    if (!m.glass) return;
    final n = m.night;
    if (m.look.rain > 0 || m.look.fog) {
      c.drawRect(Offset.zero & s, Paint()..color = n ? const Color(0xFFCFE3E6).withValues(alpha: m.look.fog ? 0.08 : 0.04) : Colors.white.withValues(alpha: m.look.fog ? 0.24 : 0.12));
    }
    final mist = m.mist;
    if (mist != null) c.drawImage(mist, Offset.zero, Paint());
    for (final d in m.drops) {
      drawGlassDrop(c, Offset(d.x, d.y), d.r, n, sliding: d.slide);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) => false;
}

/// قطرة على الزجاج: ظل، جسم بانكسار، حافة مضيئة، ولمعة.
void drawGlassDrop(Canvas c, Offset o, double r, bool night, {bool sliding = false}) {
  final ry = sliding ? r * 1.18 : r * 1.02;
  if (sliding && r > 3) {
    c.drawOval(Rect.fromCenter(center: o.translate(0, -r * 2.2), width: r * 0.64, height: r * 4.4), Paint()..color = night ? const Color(0x0FCFE6EA) : const Color(0x59FFFFFF));
  }
  final rect = Rect.fromCenter(center: o, width: r * 2, height: ry * 2);
  c.drawOval(rect.shift(Offset(r * 0.1, r * 0.24)), Paint()..color = night ? const Color(0x47000000) : const Color(0x241E2C30));
  c.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset(o.dx, o.dy - ry), Offset(o.dx, o.dy + ry),
            night ? const [Color(0x6B02100E), Color(0x08FFFFFF), Color(0x52E6F4FF)] : const [Color(0x3323343A), Color(0x08FFFFFF), Color(0xCCFFFFFF)], const [0, 0.5, 1]));
  if (r > 2.4) {
    c.drawArc(Rect.fromCenter(center: o, width: r * 1.64, height: ry * 1.64), math.pi * 0.2, math.pi * 0.6, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.5, r * 0.08)
          ..color = night ? const Color(0x73FFFFFF) : const Color(0xE6FFFFFF));
  }
  c.save();
  c.translate(o.dx - r * 0.35, o.dy - ry * 0.45);
  c.rotate(-0.5);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: math.max(1.2, r * 0.44), height: math.max(0.8, r * 0.24)), Paint()..color = const Color(0xEBFFFFFF));
  c.restore();
}

// ═══════════════════ أيقونة الطقس الملوّنة (Lucide بألوان طبيعية) ═══════════════════

const _wxMap = {
  'cloud-rain': 'crrr',
  'cloud-drizzle': 'crrrrrr',
  'cloud-sun': 'sssssc',
  'cloud-sun-rain': 'ssssscrr',
  'cloud-moon': 'cm',
  'cloud-moon-rain': 'rmcr',
  'cloud-lightning': 'cb',
  'cloud-fog': 'cff',
  'cloud-snow': 'c',
  'cloudy': 'cC',
  'haze': 'ssssddss',
  'sunrise': 'ssssshss',
  'sunset': 'ssssshss',
};

Color _wxColor(String t, bool night) => switch (t) {
      'r' => night ? const Color(0xFF7CC8FF) : const Color(0xFF1F7BC0),
      's' => night ? const Color(0xFFFFC94D) : const Color(0xFFE5940C),
      'm' => night ? const Color(0xFFF3E3B0) : const Color(0xFFA9802A),
      'b' => night ? const Color(0xFFFFD54A) : const Color(0xFFE0A100),
      'f' => night ? const Color(0xFFB9C7C9) : const Color(0xFF6F7D7F),
      'd' => night ? const Color(0xFFE0B36A) : const Color(0xFFA6721F),
      'h' || 'C' => night ? const Color(0xFF9FB3B6) : const Color(0xFF8A9A9D),
      _ => night ? const Color(0xFFEEF4F2) : const Color(0xFF34474D),
    };

final Map<String, List<Path>> _wxPathCache = {};

/// أيقونة طقس من Lucide، كل جزء بلونه: الغيمة بيضاء، المطر أزرق، الشمس ذهبية.
class WxIcon extends StatelessWidget {
  final String name;
  final double size;
  final bool night;
  final Color? mono;
  const WxIcon(this.name, {super.key, this.size = 32, required this.night, this.mono});

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _WxIconPainter(name, night, mono)));
}

class _WxIconPainter extends CustomPainter {
  final String name;
  final bool night;
  final Color? mono;
  _WxIconPainter(this.name, this.night, this.mono);

  @override
  void paint(Canvas c, Size s) {
    final paths = _wxPathCache.putIfAbsent(name, () => [for (final d in lucidePaths[name] ?? const <String>[]) parseSvgPathData(d)]);
    final map = _wxMap[name];
    final whole = name.startsWith('sun') || name == 'sunrise' || name == 'sunset' ? 's' : (name.startsWith('moon') ? 'm' : null);
    c.scale(s.width / 24);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < paths.length; i++) {
      final t = map != null && map.length == paths.length ? map[i] : (whole ?? 'c');
      p.color = mono ?? _wxColor(t, night);
      c.drawPath(paths[i], p);
    }
  }

  @override
  bool shouldRepaint(covariant _WxIconPainter o) => o.name != name || o.night != night || o.mono != mono;
}
