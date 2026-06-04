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
    grid.u.fillRange(0, grid.u.length, 1.0); // U成分は1.0で初期化
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0); // V成分は0.0で初期化
    
    // 中央に少し種をまく
    final cx = grid.w ~/ 2;
    final cy = grid.h ~/ 2;
    for (int dy = -5; dy <= 5; dy++) {
      for (int dx = -5; dx <= 5; dx++) {
        final i = grid.idx(cx + dx, cy + dy);
        grid.u[i] = 0.5;
        grid.uPrev[i] = 0.25;
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

    // 反応拡散系の計算 (Euler法)
    // 頂点位置をV成分の自動投下点とする
    // ※ 頂点情報は Boundary にあるが、ここでは簡略化

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (mask[i] == 0) continue;

        final lu = u[i + 1] + u[i - 1] + u[i + w] + u[i - w] - 4.0 * u[i];
        final lv = v[i + 1] + v[i - 1] + v[i + w] + v[i - w] - 4.0 * v[i];

        final uv2 = u[i] * v[i] * v[i];
        
        nextU[i] = u[i] + (du * lu - uv2 + feed * (1.0 - u[i]));
        nextV[i] = v[i] + (dv * lv + uv2 - (feed + kill) * v[i]);
        
        nextU[i] = nextU[i].clamp(0.0, 1.0);
        nextV[i] = nextV[i].clamp(0.0, 1.0);
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
