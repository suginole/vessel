import 'dart:typed_data';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class WaveRule extends FieldRule {
  @override
  String get name => 'wave';

  @override
  RenderConfig get renderConfig => RenderConfig.blueRed();

  @override
  void onTouchStart(Grid grid, Offset p) => onPoint(grid, p);

  @override
  void onTouchMove(Grid grid, Offset p)  => onPoint(grid, p);

  @override
  void onTouchEnd(Grid grid, Offset p)   {}
  final double c; // 波速 [cell/s]
  WaveRule({this.c = 45.0});  // 60.0 * 0.75

  @override
  void init(Grid grid) {
    grid.u.fillRange(0, grid.u.length, 0.0);
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0);
  }

  @override
  void step(Grid grid, double dt) {
    final w = grid.w;
    final h = grid.h;
    final u     = grid.u;
    final uPrev = grid.uPrev;
    final mask  = grid.mask;

    // 固定r=0.5でサブステップ数を決定
    const double r   = 0.5;          // c*dt_sub/dx, dx=1固定
    const double r2  = r * r;        // 0.25
    final double dtSub  = r / c;     // 1サブステップの時間
    final int    nSteps = (dt / dtSub).ceil().clamp(1, 8);

    final next = Float32List(w * h);

    for (int s = 0; s < nSteps; s++) {
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final i = y * w + x;

          // 固定端：mask==0 は常にゼロ
          if (mask[i] == 0.0) {
            next[i] = 0.0;
            continue;
          }

          // 5点ラプラシアン
          final lap = u[i + 1] + u[i - 1]
                    + u[i + w] + u[i - w]
                    - 4.0 * u[i];

          // 更新式: u_next = 2u - u_prev + r²*lap
          // 境界セル(mask<1)はmask乗算で滑らか減衰 → 固定端反射
          next[i] = (2.0 * u[i] - uPrev[i] + r2 * lap)
            * 0.9999   // 1.0 → 0.9999 ほぼ減衰なし、長持ち
            * mask[i];
        }
      }

      // 外周は常にゼロ（グリッド端固定端）
      for (int x = 0; x < w; x++) {
        next[x]               = 0.0; // y=0
        next[(h - 1) * w + x] = 0.0; // y=h-1
      }
      for (int y = 0; y < h; y++) {
        next[y * w]           = 0.0; // x=0
        next[y * w + (w - 1)] = 0.0; // x=w-1
      }

      uPrev.setAll(0, u);
      u.setAll(0, next);
    }
  }

  // 単位インパルス：u=A, uPrev=A → 速度ゼロ、変位のみ
  void impulse(Grid grid, int x, int y, {double amp = 3.0}) {
    if (x < 1 || x >= grid.w - 1) return;
    if (y < 1 || y >= grid.h - 1) return;
    final i = grid.idx(x, y);
    if (grid.mask[i] == 0.0) return;
    // 周囲5x5に広げて重い波源に
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 1 || nx >= grid.w - 1) continue;
        if (ny < 1 || ny >= grid.h - 1) continue;
        final ni = grid.idx(nx, ny);
        if (grid.mask[ni] == 0.0) continue;
        final dist = (dx * dx + dy * dy).toDouble();
        final weight = amp * (1.0 - dist / 10.0).clamp(0.0, 1.0);
        grid.u[ni]     = weight;
        grid.uPrev[ni] = weight;
      }
    }
  }

  @override
  void onPoint(Grid grid, Offset p) {
    impulse(grid, p.dx.toInt(), p.dy.toInt());
  }

  @override
  void onStroke(Grid grid, List<Offset> points) {
    for (final p in points) {
      impulse(grid, p.dx.toInt(), p.dy.toInt());
    }
  }
}