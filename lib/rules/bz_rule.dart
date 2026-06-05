import 'dart:typed_data';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class BZRule extends FieldRule {
  @override
  String get name => 'bz';

  @override
  RenderConfig get renderConfig => RenderConfig.bz(); // 活性変数uを可視化

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'epsilon', label: 'Epsilon', min: 0.05, max: 0.2, defaultValue: 0.1, getCurrentValue: () => epsilon),
    RuleParam(key: 'beta', label: 'Beta', min: 0.5, max: 1.5, defaultValue: 1.0, getCurrentValue: () => beta),
  ];

  double epsilon = 0.1;
  double beta = 1.0;
  final double gamma = 0.5;
  final double du = 0.2;
  final double dv = 0.05;

  @override
  void init(Grid grid) {
    grid.u.fillRange(0, grid.u.length, 0.0);
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0);
    
    // ランダムなノイズを少し入れる
    final rand = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    for (int i = 0; i < grid.u.length; i++) {
      if (grid.mask[i] > 0) {
        grid.u[i] = (i % 10 == 0) ? rand : 0.0;
      }
    }
  }

  @override
  void setParam(String key, double value) {
    if (key == 'epsilon') epsilon = value;
    if (key == 'beta') beta = value;
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

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (mask[i] == 0) continue;

        final lu = u[i + 1] + u[i - 1] + u[i + w] + u[i - w] - 4.0 * u[i];
        final lv = v[i + 1] + v[i - 1] + v[i + w] + v[i - w] - 4.0 * v[i];

        // FitzHugh-Nagumo 近似
        // ∂u/∂t = Du∇²u + u - u³/3 - v + I
        // ∂v/∂t = ε(u - γv + β)
        
        final duDt = du * lu + (u[i] - (u[i] * u[i] * u[i]) / 3.0 - v[i] + 0.5);
        final dvDt = dv * lv + epsilon * (u[i] - gamma * v[i] + beta); // lvを使用して拡散を追加

        nextU[i] = u[i] + duDt * 0.5; // タイムステップ調整
        nextV[i] = v[i] + dvDt * 0.5;
        
        nextU[i] = nextU[i].clamp(-2.0, 2.0);
        nextV[i] = nextV[i].clamp(-2.0, 2.0);
      }
    }

    u.setAll(0, nextU);
    v.setAll(0, nextV);
  }

  @override
  void onTouchStart(Grid grid, Offset p) => _stimulate(grid, p);

  @override
  void onTouchMove(Grid grid, Offset p) => _stimulate(grid, p);

  void _stimulate(Grid grid, Offset p) {
    final x = p.dx.toInt();
    final y = p.dy.toInt();
    const r = 5;
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= grid.w || ny < 0 || ny >= grid.h) continue;
        final i = grid.idx(nx, ny);
        if (grid.mask[i] > 0) {
          grid.u[i] = 1.5; // 活性化
        }
      }
    }
  }
}
