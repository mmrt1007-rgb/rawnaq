import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// تحليل الصورة: يقسمها لشبكة ٣×٣ ويقيس إضاءة وزحمة كل منطقة،
/// حتى نختار أهدأ مكان للساعة ولوناً يبرز فوقه.
class ImageStats {
  final List<double> lum; // ٩ قيم ٠..١
  final List<double> busy; // ٩ قيم (تباين داخل المنطقة)
  const ImageStats(this.lum, this.busy);

  double lumAt(Alignment a) => lum[_cell(a)];

  static int _cell(Alignment a) {
    final x = ((a.x + 1) * 1.5).floor().clamp(0, 2);
    final y = ((a.y + 1) * 1.5).floor().clamp(0, 2);
    return y * 3 + x;
  }

  /// أهدأ موضع بين الزوايا والجوانب (الوسط مستبعد حتى ما نغطي موضوع الصورة).
  Alignment bestPosition() {
    const candidates = [
      Alignment.bottomLeft,
      Alignment.bottomRight,
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.centerRight,
      Alignment.bottomCenter,
    ];
    Alignment best = candidates.first;
    var score = double.infinity;
    for (final a in candidates) {
      final i = _cell(a);
      // نفضّل الأسفل قليلاً لأنه أريح للعين
      final s = busy[i] - (a.y > 0 ? 0.01 : 0);
      if (s < score) {
        score = s;
        best = a;
      }
    }
    return best;
  }
}

class ImageAnalyzer {
  static final Map<String, ImageStats> _cache = {};

  static Future<ImageStats?> analyze(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 48, targetHeight: 27);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (data == null) return null;
      const w = 48, h = 27;
      final sums = List<double>.filled(9, 0), sq = List<double>.filled(9, 0), counts = List<int>.filled(9, 0);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final o = (y * w + x) * 4;
          final l = (0.2126 * data.getUint8(o) + 0.7152 * data.getUint8(o + 1) + 0.0722 * data.getUint8(o + 2)) / 255;
          final cell = (y * 3 ~/ h) * 3 + (x * 3 ~/ w);
          sums[cell] += l;
          sq[cell] += l * l;
          counts[cell]++;
        }
      }
      final lum = <double>[], busy = <double>[];
      for (var i = 0; i < 9; i++) {
        final m = sums[i] / counts[i];
        lum.add(m);
        busy.add(math.sqrt(math.max(0, sq[i] / counts[i] - m * m)));
      }
      final stats = ImageStats(lum, busy);
      if (_cache.length > 80) _cache.clear();
      _cache[path] = stats;
      return stats;
    } catch (_) {
      return null;
    }
  }
}
