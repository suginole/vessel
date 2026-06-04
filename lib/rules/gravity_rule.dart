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
  RenderConfig get renderConfig => RenderConfig.gravity();

  @override
  List<RuleParam> get params => [
    const RuleParam(key: 'G', label: 'Gravity', min: 100, max: 2000, defaultValue: 1000),
    const RuleParam(key: 'mass', label: 'Mass', min: 0.1, max: 5.0, defaultValue: 1.0),
  ];

  double g = 1000.0;
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
    if (key == 'G') g = value;
    if (key == 'mass') currentMass = value;
  }

  @override
  void step(Grid grid, double dt) {
    const int subSteps = 8;
    final double dtSub = dt / subSteps;

    for (int s = 0; s < subSteps; s++) {
      _stepYoshida(dtSub, grid.mask, grid.w, grid.h);
    }

    // 軌跡の更新（間引き）
    if (bodies.isNotEmpty) {
      for (var b in bodies) {
        trails.add(b.pos);
      }
      if (trails.length > 500) {
        trails.removeRange(0, trails.length - 500);
      }
    }

    // ポテンシャル場の計算（グリッド）
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
    // 位置更新
    for (var b in bodies) {
      b.pos += b.vel * dtC;
      
      // 境界反射
      final ix = b.pos.dx.toInt();
      final iy = b.pos.dy.toInt();
      if (ix < 0 || ix >= w || iy < 0 || iy >= h || mask[iy * w + ix] == 0) {
        // 簡易反射：中心方向へ戻す
        final center = Offset(w / 2, h / 2);
        final toCenter = (center - b.pos);
        b.vel = Offset(-b.vel.dx, -b.vel.dy); // 反転
        b.pos += b.vel * dtC; // 戻す
      }
    }

    if (dtD == 0) return;

    // 速度更新（加速度）
    for (int i = 0; i < bodies.length; i++) {
      Offset acc = Offset.zero;
      for (int j = 0; j < bodies.length; j++) {
        if (i == j) continue;
        final r = bodies[j].pos - bodies[i].pos;
        final distSq = r.dx * r.dx + r.dy * r.dy;
        const double epsSq = 9.0; // epsilon = 3.0
        final invDistCube = 1.0 / pow(distSq + epsSq, 1.5);
        acc += r * (g * bodies[j].mass * invDistCube);
      }
      bodies[i].vel += acc * dtD;
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
          const double epsSq = 9.0;
          phi -= (g * b.mass) / sqrt(dx * dx + dy * dy + epsSq);
        }
        // スケーリング（RenderConfigに合わせて調整）
        u[i] = phi / 5000.0; 
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
      // 初速 = ドラッグ開始点からのベクトル
      placing!.vel = p - dragStart!;
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
