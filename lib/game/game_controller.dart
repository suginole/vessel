import 'dart:ui';
import 'grid.dart';
import 'boundary.dart';
import '../rules/field_rule.dart';
import '../rules/wave_rule.dart';
import '../rules/gravity_rule.dart';
import '../rules/heat_rule.dart';
import '../rules/gray_scott_rule.dart';
import '../rules/bz_rule.dart';
import '../rules/life_rule.dart';

const int kW = 256;
const int kH = 256;

class GameController {
  late Grid     grid;
  late Boundary boundary;
  late FieldRule rule;

  int?   _dragVertex;
  Offset? _lastImpulsePos;

  GameController() {
    restart(6, WaveRule());
  }

  static final Map<String, FieldRule Function()> ruleRegistry = {
    'wave'    : () => WaveRule(),
    'gravity' : () => GravityRule(),
    'heat'    : () => HeatRule(),
    'gray-scott': () => GrayScottRule(),
    'bz': () => BZRule(),
    'life': () => LifeRule(),
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
    _dragVertex = boundary.nearestVertex(gridPos);
    if (_dragVertex != null) return;

    rule.onTouchStart(grid, gridPos);
    _lastImpulsePos = gridPos;
  }

  void onTouchMove(Offset gridPos) {
    if (_dragVertex != null) {
      boundary.moveVertex(_dragVertex!, gridPos);
      return;
    }

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

  void onTouchEnd() {
    if (_dragVertex == null) {
      rule.onTouchEnd(grid, _lastImpulsePos ?? Offset.zero);
    }
    _dragVertex     = null;
    _lastImpulsePos = null;
  }
}
