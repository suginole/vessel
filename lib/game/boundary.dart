import 'dart:ui';
import 'dart:math';
import 'dart:typed_data';
import '../utils/geometry.dart';
import '../game/game_controller.dart';

class Boundary {
  List<Offset> vertices;
  bool dirty = true;

  Boundary(int n, {double cx = 128, double cy = 128, double r = 100})
      : vertices = List.generate(n, (i) {
          final angle = 2 * pi * i / n - pi / 2;
          return Offset(cx + r * cos(angle), cy + r * sin(angle));
        });

  void moveVertex(int idx, Offset pos) {
    // グリッド範囲内にクランプ
    final clamped = Offset(
      pos.dx.clamp(1.0, kW - 2.0),
      pos.dy.clamp(1.0, kH - 2.0),
    );
    final tentative = [...vertices]..[idx] = clamped;
    if (_isValid(tentative)) {
      vertices = tentative;
      dirty = true;
    }
  }

  bool _isValid(List<Offset> vs) {
    final n = vs.length;
    for (int i = 0; i < n; i++) {
      for (int j = i + 2; j < n; j++) {
        if (i == 0 && j == n - 1) continue;
        if (segmentsIntersect(vs[i], vs[(i+1)%n], vs[j], vs[(j+1)%n])) {
          return false;
        }
      }
    }
    return true;
  }

  Float32List buildMask(int w, int h) {
    final mask = Float32List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = Offset(x + 0.5, y + 0.5);
        if (!isInsidePolygon(p, vertices)) continue;
        double minDist = double.infinity;
        final n = vertices.length;
        for (int i = 0; i < n; i++) {
          minDist = min(minDist, distToSegment(p, vertices[i], vertices[(i+1)%n]));
        }
        mask[y * w + x] = minDist.clamp(0.0, 1.0);
      }
    }
    dirty = false;
    return mask;
  }

  int? nearestVertex(Offset p, {double threshold = 20}) {
    for (int i = 0; i < vertices.length; i++) {
      if ((vertices[i] - p).distance < threshold) return i;
    }
    return null;
  }

  // game/boundary.dart に追記
  void regularize(double cx, double cy, double r) {
    final n = vertices.length;
    vertices = List.generate(n, (i) {
      final angle = 2 * pi * i / n - pi / 2;
      return Offset(cx + r * cos(angle), cy + r * sin(angle));
    });
    dirty = true;
  }
}

