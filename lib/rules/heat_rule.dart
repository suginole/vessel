import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class HeatRule extends FieldRule {
  @override
  String get name => 'heat';

  @override
  RenderConfig get renderConfig => RenderConfig(pixel: (u, m, ch) {
    // 熱分布カラーマップ: 黒 -> 赤 -> 黄 -> 白
    final v = u.clamp(0.0, 1.0);
    int r, g, b;
    if (v < 0.33) {
      r = (v / 0.33 * 255).toInt();
      g = 0;
      b = 0;
    } else if (v < 0.66) {
      r = 255;
      g = ((v - 0.33) / 0.33 * 255).toInt();
      b = 0;
    } else {
      r = 255;
      g = 255;
      b = ((v - 0.66) / 0.34 * 255).toInt();
    }
    final rgb = [r, g, b];
    return (rgb[ch] * m).toInt().clamp(0, 255);
  });

  @override
  List<RuleParam> get params => [
    const RuleParam(key: 'alpha', label: 'Diffusion', min: 0.01, max: 0.5, defaultValue: 0.2),
  ];

  double alpha = 0.2;

  @override
  void init(Grid grid) {
    grid.u.fillRange(0, grid.u.length, 0.0);
  }

  @override
  void setParam(String key, double value) {
    if (key == 'alpha') alpha = value;
  }

  @override
  void step(Grid grid, double dt) {
    final w = grid.w;
    final h = grid.h;
    final u = grid.u;
    final mask = grid.mask;
    final next = Float32List(w * h);

    // 熱拡散方程式: dT/dt = alpha * laplacian(T)
    // 前進オイラー法
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (mask[i] == 0) continue;

        final lap = u[i + 1] + u[i - 1] + u[i + w] + u[i - w] - 4.0 * u[i];
        next[i] = (u[i] + alpha * lap) * mask[i];
      }
    }
    u.setAll(0, next);
  }

  @override
  void onTouchStart(Grid grid, Offset p) => _heat(grid, p, 1.0);

  @override
  void onTouchMove(Grid grid, Offset p) => _heat(grid, p, 1.0);

  void _heat(Grid grid, Offset p, double val) {
    final x = p.dx.toInt();
    final y = p.dy.toInt();
    const int r = 4;
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 || nx >= grid.w || ny < 0 || ny >= grid.h) continue;
        final d2 = dx * dx + dy * dy;
        if (d2 > r * r) continue;
        final i = ny * grid.w + nx;
        if (grid.mask[i] > 0) {
          grid.u[i] = (grid.u[i] + val * (1.0 - sqrt(d2) / r)).clamp(0.0, 1.0);
        }
      }
    }
  }
}
