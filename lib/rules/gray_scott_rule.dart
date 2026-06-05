import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class GrayScottRule extends FieldRule {
  @override
  String get name => 'gray-scott';

  @override
  RenderConfig get renderConfig => RenderConfig.bio();

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'feed', label: 'Feed', min: 0.01, max: 0.1, defaultValue: 0.055, getCurrentValue: () => feed),
    RuleParam(key: 'kill', label: 'Kill', min: 0.04, max: 0.07, defaultValue: 0.062, getCurrentValue: () => kill),
  ];

  double feed = 0.055;
  double kill = 0.062;
  final double du = 0.2;
  final double dv = 0.1;

  @override
  void init(Grid grid) {
    final rng = Random();
    // U=1.0均一、V=0.0均一
    grid.u.fillRange(0, grid.u.length, 1.0);
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0);

    // 全域にランダムな小擾乱を複数箇所
    for (int n = 0; n < 20; n++) {
      final cx = 10 + rng.nextInt(grid.w - 20);
      final cy = 10 + rng.nextInt(grid.h - 20);
      for (int dy = -3; dy <= 3; dy++) {
        for (int dx = -3; dx <= 3; dx++) {
          final i = grid.idx(cx + dx, cy + dy);
          if (grid.mask[i] > 0) {
            grid.u[i] = 0.5 + rng.nextDouble() * 0.1;
            grid.uPrev[i] = 0.25 + rng.nextDouble() * 0.1;
          }
        }
      }
    }
  }

  @override
  void setParam(String key, double value) {
    if (key == 'feed') feed = value;
    if (key == 'kill') kill = value;
  }

  @override
  void step(Grid grid, double dt) {
    final w = grid.w;
    final h = grid.h;
    final u = grid.u;
    final v = grid.uPrev;
    final mask = grid.mask;

    final nextU = Float32List(w * h);
    final nextV = Float32List(w * h);

    // Gray-Scott標準: dt=1.0固定、1フレーム1ステップ
    const double fixedDt = 1.0;

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (mask[i] == 0) {
          nextU[i] = u[i];
          nextV[i] = v[i];
          continue;
        }

        // Neumann境界（境界外は自セルの値で補完）
        final uR = mask[y*w+(x+1)] > 0 ? u[i+1] : u[i];
        final uL = mask[y*w+(x-1)] > 0 ? u[i-1] : u[i];
        final uD = mask[(y+1)*w+x] > 0 ? u[i+w] : u[i];
        final uU = mask[(y-1)*w+x] > 0 ? u[i-w] : u[i];
        final vR = mask[y*w+(x+1)] > 0 ? v[i+1] : v[i];
        final vL = mask[y*w+(x-1)] > 0 ? v[i-1] : v[i];
        final vD = mask[(y+1)*w+x] > 0 ? v[i+w] : v[i];
        final vU = mask[(y-1)*w+x] > 0 ? v[i-w] : v[i];

        final lu = uR + uL + uD + uU - 4.0 * u[i];
        final lv = vR + vL + vD + vU - 4.0 * v[i];

        final uv2 = u[i] * v[i] * v[i];

        nextU[i] = (u[i] + fixedDt * (du * lu - uv2 + feed * (1.0 - u[i]))).clamp(0.0, 1.0);
        nextV[i] = (v[i] + fixedDt * (dv * lv + uv2 - (feed + kill) * v[i])).clamp(0.0, 1.0);
      }
    }

    u.setAll(0, nextU);
    v.setAll(0, nextV);
  }

  @override
  void onTouchStart(Grid grid, Offset p) => _seed(grid, p);

  @override
  void onTouchMove(Grid grid, Offset p) => _seed(grid, p);

  void _seed(Grid grid, Offset p) {
    final x = p.dx.toInt();
    final y = p.dy.toInt();
    const r = 4;
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= grid.w || ny < 0 || ny >= grid.h) continue;
        final i = grid.idx(nx, ny);
        if (grid.mask[i] > 0) {
          grid.uPrev[i] = 0.5; // V成分を注入
        }
      }
    }
  }
}
