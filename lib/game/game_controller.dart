import 'dart:ui';
import 'grid.dart';
import 'boundary.dart';
import '../rules/field_rule.dart';
import '../rules/wave_rule.dart';
import '../rules/gravity_rule.dart';
import '../rules/field_rule.dart';

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
    // 後で追加
  };

  void restart(int vertexCount, FieldRule newRule) {
    rule     = newRule;
    boundary = Boundary(vertexCount, cx: kW / 2, cy: kH / 2, r: kW * 0.38);
    grid     = Grid(kW, kH);
    grid.mask = boundary.buildMask(kW, kH);
    rule.init(grid);
  }

  void update(double dt) {
    if (boundary.dirty) {
      grid.mask = boundary.buildMask(kW, kH);
    }
    rule.step(grid, dt);
  }

  void onTouchStart(Offset gridPos) {
    _dragVertex = boundary.nearestVertex(gridPos);
    if (_dragVertex == null) {
      // インパルス1発
      rule.onPoint(grid, gridPos);
      _lastImpulsePos = gridPos;
    }
  }

  void onTouchMove(Offset gridPos) {
    if (_dragVertex != null) {
      boundary.moveVertex(_dragVertex!, gridPos);
    } else {
      // 4px以上移動したときだけ追加インパルス
      if (_lastImpulsePos == null ||
          (gridPos - _lastImpulsePos!).distance >= 4.0) {
        rule.onPoint(grid, gridPos);
        _lastImpulsePos = gridPos;
      }
    }
  }

  void onTouchEnd() {
    if (_dragVertex == null) {
      rule.onTouchEnd(grid, Offset.zero);
    }
    _dragVertex     = null;
    _lastImpulsePos = null;
  }
}