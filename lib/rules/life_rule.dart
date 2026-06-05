import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class LifeRule extends FieldRule {
  @override
  String get name => 'life';

  @override
  RenderConfig get renderConfig => RenderConfig.life();

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'speed', label: 'Speed', min: 1.0, max: 20.0, defaultValue: 10.0, getCurrentValue: () => speed),
    RuleParam(key: 'density', label: 'Density', min: 0.1, max: 0.8, defaultValue: 0.3, getCurrentValue: () => density),
    RuleParam(key: 'penRadius', label: 'Pen Radius', min: 2.0, max: 10.0, defaultValue: 4.0, getCurrentValue: () => penRadius),
  ];

  double speed = 10.0;
  double density = 0.3;
  double penRadius = 4.0;
  
  double _accumulator = 0.0;
  final Random _rng = Random();
  final List<Offset> _penMask = [];

  @override
  void init(Grid grid) {
    grid.u.fillRange(0, grid.u.length, 0.0);
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0);

    // 頂点近傍にランダムパターンを配置 (核)
    // ※ 頂点情報は Boundary にあるが、ここでは簡略化して全域に少し蒔く
    for (int i = 0; i < grid.u.length; i++) {
      if (grid.mask[i] > 0) {
        if (_rng.nextDouble() < density * 0.2) {
          grid.u[i] = 1.0;
        }
      }
    }
  }

  @override
  void setParam(String key, double value) {
    if (key == 'speed') speed = value;
    if (key == 'density') density = value;
    if (key == 'penRadius') penRadius = value;
  }

  @override
  void step(Grid grid, double dt) {
    _accumulator += dt;
    final double interval = 1.0 / speed;

    while (_accumulator >= interval) {
      _golStep(grid);
      _accumulator -= interval;
    }
  }

  void _golStep(Grid grid) {
    final w = grid.w;
    final h = grid.h;
    final u = grid.u;
    final next = grid.uPrev;
    final mask = grid.mask;

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (mask[i] == 0) {
          next[i] = 0.0;
          continue;
        }

        // 近傍の生存数カウント
        int neighbors = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (u[(y + dy) * w + (x + dx)] > 0.5) {
              neighbors++;
            }
          }
        }

        // ライフゲームのルール
        if (u[i] > 0.5) {
          // 生存
          next[i] = (neighbors == 2 || neighbors == 3) ? 1.0 : 0.0;
        } else {
          // 誕生
          next[i] = (neighbors == 3) ? 1.0 : 0.0;
        }
      }
    }

    u.setAll(0, next);
  }

  @override
  void onTouchStart(Grid grid, Offset p) {
    _generatePenShape(penRadius.toInt());
    _applyPen(grid, p);
  }

  @override
  void onTouchMove(Grid grid, Offset p) {
    _applyPen(grid, p);
  }

  @override
  void onTouchEnd(Grid grid, Offset p) {
    _penMask.clear();
  }

  void _generatePenShape(int r) {
    _penMask.clear();
    final p = 0.4 + _rng.nextDouble() * 0.4;
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy <= r * r) {
          if (_rng.nextDouble() < p) {
            _penMask.add(Offset(dx.toDouble(), dy.toDouble()));
          }
        }
      }
    }
  }

  void _applyPen(Grid grid, Offset p) {
    for (var offset in _penMask) {
      final nx = (p.dx + offset.dx).toInt();
      final ny = (p.dy + offset.dy).toInt();
      if (nx >= 0 && nx < grid.w && ny >= 0 && ny < grid.h) {
        final i = grid.idx(nx, ny);
        if (grid.mask[i] > 0) {
          grid.u[i] = 1.0;
        }
      }
    }
  }
}
