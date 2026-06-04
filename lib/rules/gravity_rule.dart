import 'dart:math';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class GravityBody {
  Offset pos;
  Offset vel;
  double mass;
  GravityBody({required this.pos, required this.vel, required this.mass});
}

class GravityRule extends FieldRule {
  @override
  String get name => 'gravity';

  @override
  RenderConfig get renderConfig => RenderConfig(pixel: (u, m, ch) {
    // 重力モードのフィールドカラーは黒ベース
    // 等高線の輝線のみを描画
    final v = u.abs(); // ポテンシャルの絶対値を使用
    const levels = 15;
    final val = v * levels;
    final frac = val - val.floor();
    
    // 等高線の幅を細くして「線」として表現
    final isContour = frac < 0.15 && v > 0.01;
    
    if (isContour) {
      // 輝線：緑〜青系の色
      final rgb = [
        (0.2 * 255 * m).toInt(), // R
        (0.8 * 255 * m).toInt(), // G
        (1.0 * 255 * m).toInt(), // B
      ];
      return rgb[ch].clamp(0, 255);
    } else {
      // 背景は黒
      return 0;
    }
  });

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'G', label: 'Gravity', min: 0.00002, max: 0.01, defaultValue: 0.001, getCurrentValue: () => g),
    RuleParam(key: 'mass', label: 'Mass', min: 0.1, max: 5.0, defaultValue: 1.0, getCurrentValue: () => currentMass),
  ];

  double _g = 1.0;
  double get g => _g;
  double currentMass = 1.0;

  List<GravityBody> bodies = [];
  List<Offset> trails = [];
  
  GravityBody? placing;
  Offset? dragStart;

  @override
  void init(Grid grid) {
    bodies = [];
    trails = [];
    placing = null;
    dragStart = null;
    grid.u.fillRange(0, grid.u.length, 0.0);
  }

  @override
  void setParam(String key, double value) {
    if (key == 'G') {
      _g = value;
    }
    if (key == 'mass') currentMass = value;
  }

  @override
  void step(Grid grid, double dt) {
    // ★ 時間の刻み幅（dt）の調整：ここを小さくするとゆっくり進みます（例: dt * 0.1）
    const double timeScale = 0.1;
    final double scaledDt = dt * timeScale;

    const int subSteps = 8;
    final double dtSub = scaledDt / subSteps;

    for (int s = 0; s < subSteps; s++) {
      _stepYoshida(dtSub, grid.mask, grid.w, grid.h);
    }

    if (bodies.isNotEmpty) {
      for (var b in bodies) {
        trails.add(b.pos);
      }
      if (trails.length > 500) {
        trails.removeRange(0, trails.length - 500);
      }
    }

    _updatePotential(grid);
  }

  void _stepYoshida(double dt, List<double> mask, int w, int h) {
    const double w1 = 1.351207191959657;
    const double w0 = -1.702414383919315;
    const double c1 = w1 / 2.0;
    const double c2 = (w1 + w0) / 2.0;
    const double d1 = w1;
    const double d2 = w0;

    _integrate(c1, d1, mask, w, h);
    _integrate(c2, d2, mask, w, h);
    _integrate(c2, d1, mask, w, h);
    _integrate(c1, 0, mask, w, h);
  }

  void _integrate(double dtC, double dtD, List<double> mask, int w, int h) {
    // 1. 位置更新と境界反射
    for (var b in bodies) {
      b.pos += b.vel * dtC;
      
      final ix = b.pos.dx.toInt();
      final iy = b.pos.dy.toInt();
      if (ix < 0 || ix >= w || iy < 0 || iy >= h || mask[iy * w + ix] == 0) {
        if (b.pos.dx < 0 || b.pos.dx >= w) b.vel = Offset(-b.vel.dx, b.vel.dy);
        if (b.pos.dy < 0 || b.pos.dy >= h) b.vel = Offset(b.vel.dx, -b.vel.dy);
        
        b.pos = Offset(
          b.pos.dx.clamp(0.1, w - 1.1),
          b.pos.dy.clamp(0.1, h - 1.1),
        );
      }
    }

    // 2. 合体判定（距離が極小の場合）
    _handleMergers();

    if (dtD == 0) return;

    // 3. 速度更新（加速度）
    for (int i = 0; i < bodies.length; i++) {
      Offset acc = Offset.zero;
      for (int j = 0; j < bodies.length; j++) {
        if (i == j) continue;
        final r = bodies[j].pos - bodies[i].pos;
        final distSq = r.dx * r.dx + r.dy * r.dy;
        const double epsSq = 25.0; 
        final invDistCube = 1.0 / pow(distSq + epsSq, 1.5);
        acc += r * (_g * bodies[j].mass * 100.0 * invDistCube);
      }
      bodies[i].vel += acc * dtD;
    }
  }

  void _handleMergers() {
    if (bodies.length < 2) return;
    
    List<int> toRemove = [];
    for (int i = 0; i < bodies.length; i++) {
      if (toRemove.contains(i)) continue;
      for (int j = i + 1; j < bodies.length; j++) {
        if (toRemove.contains(j)) continue;
        
        final dist = (bodies[i].pos - bodies[j].pos).distance;
        // ★ 合体半径の調整：この mergeDist を小さくすると、より近づかないと合体しなくなります
        final mergeDist = (bodies[i].mass + bodies[j].mass) * 2.0 + 2.0;
        
        if (dist < mergeDist) {
          final m1 = bodies[i].mass;
          final m2 = bodies[j].mass;
          final v1 = bodies[i].vel;
          final v2 = bodies[j].vel;
          
          final newMass = m1 + m2;
          final newVel = Offset(
            (m1 * v1.dx + m2 * v2.dx) / newMass,
            (m1 * v1.dy + m2 * v2.dy) / newMass,
          );
          final newPos = Offset(
            (m1 * bodies[i].pos.dx + m2 * bodies[j].pos.dx) / newMass,
            (m1 * bodies[i].pos.dy + m2 * bodies[j].pos.dy) / newMass,
          );
          
          bodies[i].mass = newMass;
          bodies[i].vel = newVel;
          bodies[i].pos = newPos;
          toRemove.add(j);
        }
      }
    }
    
    toRemove.sort((a, b) => b.compareTo(a));
    for (var idx in toRemove) {
      bodies.removeAt(idx);
    }
  }

  void _updatePotential(Grid grid) {
    final u = grid.u;
    final mask = grid.mask;
    final w = grid.w;
    final h = grid.h;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = y * w + x;
        if (mask[i] == 0) {
          u[i] = 0;
          continue;
        }

        double phi = 0;
        for (var b in bodies) {
          final dx = b.pos.dx - x;
          final dy = b.pos.dy - y;
          const double epsSq = 25.0;
          // Gが極小(0.00002~0.01)なので、可視化のために1000倍以上にブースト
          phi += (_g * b.mass * 50000.0) / sqrt(dx * dx + dy * dy + epsSq);
        }
        u[i] = phi; 
      }
    }
  }

  @override
  void onTouchStart(Grid grid, Offset p) {
    dragStart = p;
    placing = GravityBody(pos: p, vel: Offset.zero, mass: currentMass);
  }

  @override
  void onTouchMove(Grid grid, Offset p) {
    if (placing != null && dragStart != null) {
      // さらに5分の1に抑制 (0.02 / 5 = 0.004)
      const double velocityScale = 0.004;
      placing!.vel = (p - dragStart!) * velocityScale;
    }
  }

  @override
  void onTouchEnd(Grid grid, Offset p) {
    if (placing != null) {
      bodies.add(placing!);
      if (bodies.length > 3) bodies.removeAt(0);
      placing = null;
      dragStart = null;
    }
  }
}
