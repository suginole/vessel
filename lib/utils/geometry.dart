// utils/geometry.dart
import 'dart:ui';

/// 点が単純多角形の内部か判定（Ray casting）
bool isInsidePolygon(Offset p, List<Offset> vertices) {
  int n = vertices.length;
  bool inside = false;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final vi = vertices[i];
    final vj = vertices[j];
    if ((vi.dy > p.dy) != (vj.dy > p.dy) &&
        p.dx < (vj.dx - vi.dx) * (p.dy - vi.dy) / (vj.dy - vi.dy) + vi.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// 点Pから線分ABへの最短距離
double distToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return (p - a).distance;
  double t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + t * dx, a.dy + t * dy);
  return (p - proj).distance;
}

/// 線分AB・CDが交差するか（端点共有は除く）
bool segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
  double cross(Offset o, Offset u, Offset v) =>
      (u.dx - o.dx) * (v.dy - o.dy) - (u.dy - o.dy) * (v.dx - o.dx);
  final d1 = cross(c, d, a);
  final d2 = cross(c, d, b);
  final d3 = cross(a, b, c);
  final d4 = cross(a, b, d);
  if (d1 * d2 < 0 && d3 * d4 < 0) return true;
  return false;
}