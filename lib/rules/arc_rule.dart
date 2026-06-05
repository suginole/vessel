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
    RuleParam(key: 'eta',   label: 'Eta',    min: 1.0, max: 8.0,  defaultValue: 4.0, getCurrentValue: () => eta),
    RuleParam(key: 'gamma', label: 'Direct', min: 0.0, max: 8.0,  defaultValue: 3.0, getCurrentValue: () => gamma),
    RuleParam(key: 'bolt',  label: 'Bolts',  min: 1.0, max: 8.0,  defaultValue: 3.0, getCurrentValue: () => boltCount, divisions: 7),
    RuleParam(key: 'decay', label: 'Decay',  min: 0.5, max: 0.99, defaultValue: 0.7, getCurrentValue: () => decay),
  ];

  double eta       = 4.0;
  double gamma     = 3.0;
  double boltCount = 3.0;
  double decay     = 0.7;

  Offset?      _touchPos;
  double       _flashAlpha = 0.0;
  final Random _rng        = Random();

  late Float32List _phi;
  late Float32List _channel;  // 現在の放電経路（輝度）
  bool _initialized = false;

  @override
  void init(Grid grid) {
    _phi     = Float32List(grid.w * grid.h);
    _channel = Float32List(grid.w * grid.h);
    grid.u.fillRange(0, grid.u.length, 0.0);
    _touchPos   = null;
    _flashAlpha = 0.0;
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
    final mask = grid.mask;

    // ── 1. 電位場を解く ────────────────────────
    _solveLaplace(grid, 20);

    if (_touchPos != null) {
      // ── 2. 経路を毎フレーム再生成 ──────────────
      // 前フレームの経路を減衰（残像）
      for (int i = 0; i < _channel.length; i++) {
        _channel[i] *= 0.3;  // さらに素早く消してジッターを際立たせる
      }

      // フリッカー (ちらつき)
      final flicker = 0.8 + _rng.nextDouble() * 0.4;

      // boltCount本の経路を独立に生成
      final n = boltCount.toInt();
      bool anyReached = false;

      for (int b = 0; b < n; b++) {
        final reached = _traceBolt(grid, flicker);
        if (reached) anyReached = true;
      }

      if (anyReached) {
        _flashAlpha = (_flashAlpha + 0.2).clamp(0.0, 1.0);
      }
    } else {
      // タッチなし → 経路を減衰
      for (int i = 0; i < _channel.length; i++) {
        _channel[i] *= decay;
      }
      _flashAlpha *= 0.8;
    }

    // ── 3. 可視化 ─────────────────────────────
    for (int i = 0; i < grid.u.length; i++) {
      if (mask[i] == 0.0) { grid.u[i] = 0.0; continue; }
      final ch = _channel[i];
      if (ch > 0.05) {
        grid.u[i] = (ch + _flashAlpha * 0.3).clamp(0.0, 2.0);
      } else {
        // 電位場を淡く
        grid.u[i] = ((_phi[i] + 1.0) / 2.0) * 0.15;
      }
    }
  }

  // 1本の経路をタッチ点から壁まで一気にトレース
  // 1フレームで完結 → 常につながって見える
  bool _traceBolt(Grid grid, double flicker) {
    final w    = grid.w;
    final h    = grid.h;
    final mask = grid.mask;

    final tx = _touchPos!.dx.toInt().clamp(1, w - 2);
    final ty = _touchPos!.dy.toInt().clamp(1, h - 2);

    int    curIdx = ty * w + tx;
    
    // 初期方向：タッチ点周囲の電位勾配から決定
    final dPhiX0 = _phi[curIdx + 1] - _phi[curIdx - 1];
    final dPhiY0 = _phi[curIdx + w] - _phi[curIdx - w];
    double gradX = dPhiX0;
    double gradY = dPhiY0;
    
    if (gradX.abs() < 1e-6 && gradY.abs() < 1e-6) {
      gradX = _rng.nextDouble() - 0.5;
      gradY = _rng.nextDouble() - 0.5;
    } else {
      gradX += (_rng.nextDouble() - 0.5) * 0.4; // 揺らぎを少し強める
      gradY += (_rng.nextDouble() - 0.5) * 0.4;
    }
    
    final len0 = sqrt(gradX * gradX + gradY * gradY) + 1e-6;
    Offset curDir = Offset(gradX / len0, gradY / len0);

    const maxSteps = 512;
    final path = <int>[curIdx];

    for (int step = 0; step < maxSteps; step++) {
      final cx = curIdx % w;
      final cy = curIdx ~/ w;

      // 8近傍
      const ndx  = [ 1, -1,  0,  0,  1,  1, -1, -1];
      const ndy  = [ 0,  0,  1, -1,  1, -1,  1, -1];
      const dist = [1.0, 1.0, 1.0, 1.0, 1.414, 1.414, 1.414, 1.414];

      final candidates = <int>[];
      final probs      = <double>[];
      double sumP      = 0.0;

      for (int d = 0; d < 8; d++) {
        final nx = cx + ndx[d];
        final ny = cy + ndy[d];
        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
        final ni = ny * w + nx;

        // 壁到達
        if (mask[ni] == 0.0) {
          // テーパリング（根元から先端に向かってわずかに細く・暗く）
          for (int i = 0; i < path.length; i++) {
            final t = 1.0 - (i / path.length) * 0.3;
            _channel[path[i]] = (1.0 * t * flicker).clamp(0.0, 1.5);
          }
          return true;
        }

        final dPhiFwd = (_phi[ni] - _phi[curIdx]).abs();
        final dPhiX   = _phi[(ny*w+(nx+1).clamp(0,w-1))] - _phi[(ny*w+(nx-1).clamp(0,w-1))];
        final dPhiY   = _phi[((ny+1).clamp(0,h-1)*w+nx)] - _phi[((ny-1).clamp(0,h-1)*w+nx)];
        
        // ジッター（経路の微細な揺れ）を確率計算に含める
        final jitter = 1.0 + (_rng.nextDouble() - 0.5) * 0.3;
        final grad    = (dPhiFwd * 3.0 + sqrt(dPhiX*dPhiX + dPhiY*dPhiY)) / dist[d] * jitter + 1e-6;

        final unitDx = ndx[d] / dist[d];
        final unitDy = ndy[d] / dist[d];
        final dot    = (curDir.dx * unitDx + curDir.dy * unitDy).clamp(-1.0, 1.0);
        final dirB   = pow((dot + 1.0) / 2.0 + 0.05, gamma);

        final p = pow(grad, eta) * dirB;
        candidates.add(ni);
        probs.add(p.toDouble());
        sumP += p;
      }

      if (candidates.isEmpty) break;

      // 確率的選択
      double r = _rng.nextDouble() * sumP;
      double cur = 0.0;
      for (int k = 0; k < candidates.length; k++) {
        cur += probs[k];
        if (r <= cur) {
          final ni = candidates[k];
          final nx = ni % w, ny = ni ~/ w;
          final ddx = (nx - cx).toDouble();
          final ddy = (ny - cy).toDouble();
          final dl  = sqrt(ddx*ddx + ddy*ddy) + 1e-6;
          curDir = Offset(ddx/dl, ddy/dl);
          curIdx = ni;
          path.add(curIdx);
          break;
        }
      }
    }

    // 壁未到達でも途中経路を薄く表示
    for (int i = 0; i < path.length; i++) {
      final t = 1.0 - (i / path.length) * 0.5;
      _channel[path[i]] = (_channel[path[i]] + 0.4 * t * flicker).clamp(0.0, 1.0);
    }
    return false;
  }

  // Laplace ガウスザイデル
  void _solveLaplace(Grid grid, int iter) {
    final w    = grid.w;
    final h    = grid.h;
    final mask = grid.mask;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = y * w + x;
        if (mask[i] == 0.0) { _phi[i] =  1.0; continue; }
        if (_isTouchCell(x, y)) { _phi[i] = -1.0; }
      }
    }

    for (int r = 0; r < iter; r++) {
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final i = y * w + x;
          if (mask[i] == 0.0)     continue;
          if (_isTouchCell(x, y)) continue;
          _phi[i] = (_phi[i+1] + _phi[i-1] +
                     _phi[i+w] + _phi[i-w]) * 0.25;
        }
      }
    }
  }

  @override
  void onTouchStart(Grid grid, Offset p) {
    _touchPos = p;
    _solveLaplace(grid, 60); // 初回精密計算
  }

  @override
  void onTouchMove(Grid grid, Offset p) {
    _touchPos = p; // 毎フレームstepで再計算されるので追従する
  }

  @override
  void onTouchEnd(Grid grid, Offset p) {
    _touchPos = null;
  }

  bool _isTouchCell(int x, int y) {
    if (_touchPos == null) return false;
    return (x - _touchPos!.dx.toInt()).abs() <= 2 &&
           (y - _touchPos!.dy.toInt()).abs() <= 2;
  }
}
