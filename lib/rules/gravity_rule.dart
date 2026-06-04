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
    const RuleParam(key: 'G', label: 'Gravity', min: 0.1, max: 10.0, defaultValue: 1.0),
    const RuleParam(key: 'mass', label: 'Mass', min: 0.1, max: 5.0, defaultValue: 1.0),
  ];

  double g = 1.0;
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
    for (var b in bodies) {
      b.pos += b.vel * dtC;
      
      final ix = b.pos.dx.toInt();
      final iy = b.pos.dy.toInt();
      if (ix < 0 || ix >= w || iy < 0 || iy >= h || mask[iy * w + ix] == 0) {
        if (b.pos.dx < 0 || b.pos.dx >= w) b.vel = Offset(-b.vel.dx, b.vel.dy);
        if (b.pos.dy < 0 || b.pos.dy >= h) b.vel = Offset(b.vel.dx, -b.vel.dy);
        
        // 境界外に出た場合の押し戻し
        b.pos = Offset(
          b.pos.dx.clamp(0.1, w - 1.1),
          b.pos.dy.clamp(0.1, h - 1.1),
        );
      }
    }

    if (dtD == 0) return;

    for (int i = 0; i < bodies.length; i++) {
      Offset acc = Offset.zero;
      for (int j = 0; j < bodies.length; j++) {
        if (i == j) continue;
        final r = bodies[j].pos - bodies[i].pos;
        final distSq = r.dx * r.dx + r.dy * r.dy;
        const double epsSq = 25.0; // softening
        final invDistCube = 1.0 / pow(distSq + epsSq, 1.5);
        acc += r * (g * bodies[j].mass * 100.0 * invDistCube); // Gのスケール調整
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
          const double epsSq = 25.0;
          phi += (g * b.mass * 10.0) / sqrt(dx * dx + dy * dy + epsSq);
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
      // 初速度を 0.1 倍にして調整（スピーディすぎるのを防ぐ）
      placing!.vel = (p - dragStart!) * 0.1;
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
