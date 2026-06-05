import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

// 1本の雷チャンネル
class _Channel {
  int    tipIdx;          // 現在の先端セルインデックス
  Offset tipDir;          // 直前の進行方向
  bool   reached = false; // 壁到達済み
  final List<int> cells = []; // チャンネルを構成するセル

  _Channel(this.tipIdx, this.tipDir);
}

class ArcRule extends FieldRule {
  @override
  String get name => 'arc';

  @override
  RenderConfig get renderConfig => RenderConfig.arc();

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'eta',      label: 'Eta',      min: 1.0, max: 6.0,  defaultValue: 3.0, getCurrentValue: () => eta),
    RuleParam(key: 'gamma',    label: 'Direct',   min: 0.0, max: 5.0,  defaultValue: 2.0, getCurrentValue: () => gamma),
    RuleParam(key: 'bolt',     label: 'Bolts',    min: 1.0, max: 16.0, defaultValue: 10.0, getCurrentValue: () => boltCount, divisions: 15),
    RuleParam(key: 'decay',    label: 'Decay',    min: 0.8, max: 1.0,  defaultValue: 0.92, getCurrentValue: () => decay),
  ];

  double eta        = 3.0;
  double gamma      = 2.0;
  double boltCount  = 10.0;
  double decay      = 0.92;

  Offset?          _touchPos;
  bool             _active     = false;
  double           _flashAlpha = 0.0;
  int              _relaxFrame = 0;
  final Random     _rng        = Random();
  final List<_Channel> _channels = [];

  late Float32List _phi;
  late Float32List _broken;
  bool _initialized = false;

  @override
  void init(Grid grid) {
    _phi        = Float32List(grid.w * grid.h);
    _broken     = Float32List(grid.w * grid.h);
    grid.u.fillRange(0, grid.u.length, 0.0);
    _touchPos   = null;
    _active     = false;
    _flashAlpha = 0.0;
    _channels.clear();
    _relaxFrame = 0;
    _initialized = true;
  }

  @override
  void clean(Grid grid) => init(grid);

  @override
  void setParam(String key, double value) {
    if (key == 'eta')   eta       = value;
    if (key == 'gamma') gamma     = value;
    if (key == 'bolt')  boltCount = value;
    if (key == 'decay') decay     = value;
  }

  @override
  void step(Grid grid, double dt) {
    if (!_initialized) init(grid);
    final w = grid.w, h = grid.h;
    final mask = grid.mask;

    // ── 1. Laplace（5フレームに1回）──────────
    if (_relaxFrame % 5 == 0) {
      _solveLaplace(grid, 30);
    }
    _relaxFrame++;

    // ── 2. チャンネル成長（毎フレーム）──────────
    if (_active && _touchPos != null) {
      // 全チャンネルが到達済みなら放電完了
      final allDone = _channels.isNotEmpty && _channels.every((c) => c.reached);
      if (allDone) {
        _flashAlpha = 1.0;
        _active = false;
      } else {
        // 1フレームで各チャンネル複数セル成長（雷速）
        const stepsPerFrame = 8;
        for (int s = 0; s < stepsPerFrame; s++) {
          for (final ch in _channels) {
            if (!ch.reached) _growChannel(ch, grid);
          }
        }
      }
    }

    // ── 3. 減衰 ───────────────────────────────
    if (!_active) {
      bool anyBroken = false;
      for (int i = 0; i < _broken.length; i++) {
        _broken[i] *= decay;
        if (_broken[i] > 0.01) anyBroken = true;
      }
      if (!anyBroken) _channels.clear();
    }
    _flashAlpha *= 0.8;

    // ── 4. 可視化 ─────────────────────────────
    for (int i = 0; i < grid.u.length; i++) {
      if (mask[i] == 0.0) { grid.u[i] = 0.0; continue; }
      if (_broken[i] > 0.05) {
        grid.u[i] = (_broken[i] + _flashAlpha).clamp(0.0, 2.0);
      } else {
        // 電位場を淡く背景表示
        grid.u[i] = ((_phi[i] + 1.0) / 2.0) * 0.2;
      }
    }
  }

  // Laplace ガウスザイデル
  void _solveLaplace(Grid grid, int iter) {
    final w = grid.w, h = grid.h;
    final mask = grid.mask;

    // 境界条件セット
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = y * w + x;
        if (mask[i] == 0.0) {
          _phi[i] = 1.0;   // 境界 = 高電圧
          continue;
        }
        if (_broken[i] > 0.5 || _isTouchCell(x, y)) {
          _phi[i] = -1.0;  // チャンネル・タッチ = アース
        }
      }
    }

    // 反復
    for (int r = 0; r < iter; r++) {
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final i = y * w + x;
          if (mask[i] == 0.0)      continue;
          if (_broken[i] > 0.5)    continue;
          if (_isTouchCell(x, y))  continue;
          _phi[i] = (_phi[i+1] + _phi[i-1] +
                     _phi[i+w] + _phi[i-w]) * 0.25;
        }
      }
    }
  }

  // 1チャンネルを1セル成長
  void _growChannel(_Channel ch, Grid grid) {
    final w = grid.w, h = grid.h;
    final mask = grid.mask;
    final ti = ch.tipIdx;
    final tx = ti % w;
    final ty = ti ~/ w;

    // 4近傍候補
    const dx = [1, -1, 0, 0];
    const dy = [0, 0, 1, -1];

    final candidates = <int>[];
    final probs      = <double>[];
    double sumP      = 0.0;

    for (int d = 0; d < 4; d++) {
      final nx = tx + dx[d];
      final ny = ty + dy[d];
      if (nx < 1 || nx >= w-1 || ny < 1 || ny >= h-1) continue;
      final ni = ny * w + nx;
      if (_broken[ni] > 0.5) continue; // 既破壊スキップ

      // 壁到達 → このセルを壁として破壊完了
      if (mask[ni] == 0.0) {
        ch.reached = true;
        return;
      }

      // 電界強度
      final dPhiX = _phi[ni+1] - _phi[ni-1];
      final dPhiY = _phi[ni+w] - _phi[ni-w];
      final grad  = sqrt(dPhiX*dPhiX + dPhiY*dPhiY) + 1e-6;

      // 直進性：直前方向との内積
      final ndx = dx[d].toDouble();
      final ndy = dy[d].toDouble();
      final dot = (ch.tipDir.dx * ndx + ch.tipDir.dy * ndy)
                    .clamp(-1.0, 1.0);
      final dirBonus = pow((dot + 1.0) / 2.0 + 0.05, gamma);

      final p = pow(grad, eta) * dirBonus;
      candidates.add(ni);
      probs.add(p.toDouble());
      sumP += p;
    }

    if (candidates.isEmpty || sumP == 0) return;

    // 確率的選択
    double r = _rng.nextDouble() * sumP;
    double cur = 0.0;
    for (int k = 0; k < candidates.length; k++) {
      cur += probs[k];
      if (r <= cur) {
        final ni = candidates[k];
        _broken[ni] = 1.0;
        ch.cells.add(ni);
        // 進行方向更新
        final nx = ni % w, ny = ni ~/ w;
        ch.tipDir = Offset(
          (nx - tx).toDouble(),
          (ny - ty).toDouble(),
        );
        ch.tipIdx = ni;
        break;
      }
    }
  }

  // タッチ開始：チャンネルを初期化して発射
  @override
  void onTouchStart(Grid grid, Offset p) {
    _touchPos = p;
    _broken.fillRange(0, _broken.length, 0.0);
    _channels.clear();
    _active     = true;
    _flashAlpha = 0.0;

    // タッチ点の近傍から boltCount 本のチャンネルを発射
    final tx = p.dx.toInt();
    final ty = p.dy.toInt();
    final w  = grid.w;

    // 少しずらした初期位置から各チャンネルを発射
    final n = boltCount.toInt();
    for (int k = 0; k < n; k++) {
      final angle  = 2 * pi * k / n;
      final ox     = (cos(angle) * 2).round();
      final oy     = (sin(angle) * 2).round();
      final sx     = (tx + ox).clamp(1, grid.w - 2);
      final sy     = (ty + oy).clamp(1, grid.h - 2);
      final si     = sy * w + sx;

      if (grid.mask[si] > 0) {
        _broken[si] = 1.0;
        // 初期方向：外向き（タッチ点から放射）
        final initDir = Offset(ox.toDouble(), oy.toDouble());
        _channels.add(_Channel(si, initDir));
      }
    }

    _solveLaplace(grid, 50); // 初回は精密に解く
  }

  @override
  void onTouchMove(Grid grid, Offset p) {
    _touchPos = p;
  }

  @override
  void onTouchEnd(Grid grid, Offset p) {
    _touchPos = null;
    _active   = false;
  }

  bool _isTouchCell(int x, int y) {
    if (_touchPos == null) return false;
    return (x - _touchPos!.dx.toInt()).abs() <= 1 &&
           (y - _touchPos!.dy.toInt()).abs() <= 1;
  }
}
