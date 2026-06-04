import 'dart:math';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

const int kW = 256;
const int kH = 256;

class GameController {
  late Grid      grid;
  late Boundary  boundary;
  late FieldRule rule;

  int?    _dragVertex;
  Offset? _lastImpulsePos;

  GameController() {
    restart(6, WaveRule());
  }

  static final Map<String, FieldRule Function()> ruleRegistry = {
    'wave'    : () => WaveRule(),
    'gravity' : () => GravityRule(),
  };

  void restart(int vertexCount, FieldRule newRule) {
    rule     = newRule;
    boundary = Boundary(vertexCount, cx: kW / 2, cy: kH / 2, r: kW * 0.38);
    grid     = Grid(kW, kH);
    grid.mask = boundary.buildMask(kW, kH);
    rule.init(grid);
    _dragVertex     = null;
    _lastImpulsePos = null;
  }

  void clean() {
    rule.clean(grid);
    _dragVertex     = null;
    _lastImpulsePos = null;
  }

  void setParam(String key, double value) {
    rule.setParam(key, value);
  }

  void update(double dt) {
    if (boundary.dirty) {
      grid.mask = boundary.buildMask(kW, kH);
    }
    rule.step(grid, dt);
  }

  void onTouchStart(Offset gridPos) {
    // 頂点ドラッグ判定
    _dragVertex = boundary.nearestVertex(gridPos);
    if (_dragVertex != null) return;

    // ルールにタッチ開始を委譲
    rule.onTouchStart(grid, gridPos);
    _lastImpulsePos = gridPos;
  }

  void onTouchMove(Offset gridPos) {
    if (_dragVertex != null) {
      boundary.moveVertex(_dragVertex!, gridPos,
          maxW: kW.toDouble(), maxH: kH.toDouble());
      return;
    }

    // Wave系：距離間引き。Gravity系：毎回委譲
    final needsSampling = rule is WaveRule;
    if (needsSampling) {
      if (_lastImpulsePos == null ||
          (gridPos - _lastImpulsePos!).distance >= 4.0) {
        rule.onTouchMove(grid, gridPos);
        _lastImpulsePos = gridPos;
      }
    } else {
      rule.onTouchMove(grid, gridPos);
    }
  }

  void onTouchEnd(Offset gridPos) {
    if (_dragVertex == null) {
      rule.onTouchEnd(grid, gridPos);
    }
    _dragVertex     = null;
    _lastImpulsePos = null;
  }
}