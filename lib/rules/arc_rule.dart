import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class ArcRule extends FieldRule {
  @override
  String get name => 'arc';

  @override
  RenderConfig get renderConfig => RenderConfig.arc();

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'eta', label: 'Eta (Branch)', min: 1.0, max: 5.0, defaultValue: 2.0, getCurrentValue: () => eta),
    RuleParam(key: 'voltage', label: 'Voltage', min: 0.5, max: 2.0, defaultValue: 1.0, getCurrentValue: () => voltage),
    RuleParam(key: 'decay', label: 'Decay', min: 0.9, max: 1.0, defaultValue: 0.95, getCurrentValue: () => decay),
    RuleParam(key: 'speed', label: 'Speed', min: 1.0, max: 10.0, defaultValue: 5.0, getCurrentValue: () => speed),
  ];

  double eta = 2.0;
  double voltage = 1.0;
  double decay = 0.95;
  double speed = 5.0;
  int relax = 10;

  Offset? touchPos;
  bool isDischarged = false;
  double flashAlpha = 0.0;
  final Random _rng = Random();

  @override
  void init(Grid grid) {
    grid.u.fillRange(0, grid.u.length, 0.0); // 電位
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0); // 破壊状態
    isDischarged = false;
    flashAlpha = 0.0;
  }

  @override
  void setParam(String key, double value) {
    if (key == 'eta') eta = value;
    if (key == 'voltage') voltage = value;
    if (key == 'decay') decay = value;
    if (key == 'speed') speed = value;
  }

  @override
  void step(Grid grid, double dt) {
    final w = grid.w;
    final h = grid.h;
    final phi = grid.u;
    final broken = grid.uPrev;
    final mask = grid.mask;

    // 1. Laplace方程式を解く (Gauss-Seidel)
    for (int r = 0; r < relax; r++) {
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final i = y * w + x;
          if (mask[i] == 0) {
            phi[i] = voltage; // 境界は高電圧源 (+)
            continue;
          }
          if (touchPos != null && (x == touchPos!.dx.toInt() && y == touchPos!.dy.toInt())) {
            phi[i] = -1.0; // タッチ点はアース (-)
            continue;
          }
          if (broken[i] > 0.5) {
            phi[i] = -1.0; // 破壊済みセルは導体 (アース)
          } else {
            // 絶縁体: ∇²φ = 0
            phi[i] = (phi[i + 1] + phi[i - 1] + phi[i + w] + phi[i - w]) * 0.25;
          }
        }
      }
    }

    // 2. 破壊の進行
    if (touchPos != null && !isDischarged) {
      for (int s = 0; s < speed.toInt(); s++) {
        final frontier = <int>[];
        final probs = <double>[];
        double sumP = 0;

        for (int y = 1; y < h - 1; y++) {
          for (int x = 1; x < w - 1; x++) {
            final i = y * w + x;
            if (mask[i] > 0 && broken[i] < 0.5) {
              bool isNear = false;
              if (touchPos != null && (x - touchPos!.dx).abs() <= 1 && (y - touchPos!.dy).abs() <= 1) {
                isNear = true;
              } else if (broken[i + 1] > 0.5 || broken[i - 1] > 0.5 || broken[i + w] > 0.5 || broken[i - w] > 0.5) {
                isNear = true;
              }

              if (isNear) {
                frontier.add(i);
                // 電位勾配 |∇φ| に基づく破壊確率
                double dPhiX = phi[i + 1] - phi[i - 1];
                double dPhiY = phi[i + w] - phi[i - w];
                double gradMag = sqrt(dPhiX * dPhiX + dPhiY * dPhiY);
                double p = pow(gradMag, eta).toDouble();
                probs.add(p);
                sumP += p;
              }
            }
          }
        }

        if (frontier.isNotEmpty && sumP > 0) {
          double r = _rng.nextDouble() * sumP;
          double currentSum = 0;
          for (int i = 0; i < frontier.length; i++) {
            currentSum += probs[i];
            if (r <= currentSum) {
              final idx = frontier[i];
              broken[idx] = 1.0;
              // 境界到達チェック (境界付近は高電圧なので phi が大きい)
              if (phi[idx] >= voltage * 0.9) {
                isDischarged = true;
                flashAlpha = 1.0;
              }
              break;
            }
          }
        }
      }
    }

    // 3. 減衰とフラッシュ
    if (touchPos == null) {
      for (int i = 0; i < broken.length; i++) {
        broken[i] *= decay;
      }
      isDischarged = false;
    }
    flashAlpha *= 0.8;

    // 可視化用に phi と broken を合成して u に入れる
    // phi をベースに、broken な部分は強く発光させる
    for (int i = 0; i < grid.u.length; i++) {
      if (mask[i] > 0) {
        if (broken[i] > 0.1) {
          grid.u[i] = broken[i] + flashAlpha; // 破壊部分は白く光る
        } else {
          grid.u[i] = phi[i] * 0.5; // 電位場は控えめに
        }
      }
    }
  }

  @override
  void onTouchStart(Grid grid, Offset p) {
    touchPos = p;
    isDischarged = false;
  }

  @override
  void onTouchMove(Grid grid, Offset p) {
    touchPos = p;
  }

  @override
  void onTouchEnd(Grid grid, Offset p) {
    touchPos = null;
  }
}
