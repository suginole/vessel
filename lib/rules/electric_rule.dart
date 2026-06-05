import 'dart:math';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class ElectricBody {
  Offset pos;
  Offset vel;
  double charge; // 正負両方の値を持つ
  ElectricBody({required this.pos, required this.vel, required this.charge});
}

class ElectricRule extends FieldRule {
  @override
  String get name => 'electric';

  @override
  RenderConfig get renderConfig => RenderConfig(pixel: (u, m, ch) {
    // 電位の可視化：正は赤、負は青
    final v = u;
    final absV = v.abs();
    
    // 対数スケールによる等高線
    final logV = log(1.0 + absV * 0.01);
    const levels = 8.0;
    final val = logV * levels;
    final frac = val - val.floor();
    
    final isContour = frac < 0.12 && logV > 0.001;
    
    if (isContour) {
      if (v > 0) {
        // 正電位：赤〜オレンジ（高輝度）
        final rgb = [(1.0 * 255 * m).toInt(), (0.3 * 255 * m).toInt(), (0.1 * 255 * m).toInt()];
        return rgb[ch].clamp(0, 255);
      } else {
        // 負電位：青〜シアン（高輝度）
        final rgb = [(0.1 * 255 * m).toInt(), (0.4 * 255 * m).toInt(), (1.0 * 255 * m).toInt()];
        return rgb[ch].clamp(0, 255);
      }
    }
    
    // 背景に微かな電場オーラ（ポテンシャルに応じた発光）を表示
    if (absV > 0.1) {
      final aura = (logV * 15 * m).toInt();
      if (v > 0) {
        final rgb = [aura, (aura * 0.2).toInt(), 0];
        return rgb[ch].clamp(0, 255);
      } else {
        final rgb = [0, (aura * 0.3).toInt(), aura];
        return rgb[ch].clamp(0, 255);
      }
    }
    
    return 0;
  });

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'K', label: 'Coulomb K', min: 0.00002, max: 0.01, defaultValue: 0.001, getCurrentValue: () => kConstant),
    RuleParam(key: 'charge', label: 'Charge', min: -5.0, max: 5.0, defaultValue: 1.0, getCurrentValue: () => currentCharge),
  ];

  double kConstant = 0.001;
  double currentCharge = 1.0;

  List<ElectricBody> bodies = [];
  List<Offset> trails = [];
  
  ElectricBody? placing;
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
    if (key == 'K') kConstant = value;
    if (key == 'charge') currentCharge = value;
  }

  @override
  void step(Grid grid, double dt) {
    const double timeScale = 0.1;
    final double scaledDt = dt * timeScale;
    const int subSteps = 8;
    final double dtSub = scaledDt / subSteps;

    for (int s = 0; s < subSteps; s++) {
      _stepYoshida(dtSub, grid.mask, grid.w, grid.h);
    }

    if (bodies.isNotEmpty) {
      for (var b in bodies) trails.add(b.pos);
      if (trails.length > 500) trails.removeRange(0, trails.length - 500);
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
      if (b.pos.dx < 0 || b.pos.dx >= w || b.pos.dy < 0 || b.pos.dy >= h || mask[b.pos.dy.toInt() * w + b.pos.dx.toInt()] == 0) {
        if (b.pos.dx < 0 || b.pos.dx >= w) b.vel = Offset(-b.vel.dx, b.vel.dy);
        if (b.pos.dy < 0 || b.pos.dy >= h) b.vel = Offset(b.vel.dx, -b.vel.dy);
        b.pos = Offset(b.pos.dx.clamp(0.1, w - 1.1), b.pos.dy.clamp(0.1, h - 1.1));
      }
    }

    _handleInteractions();

    if (dtD == 0) return;

    for (int i = 0; i < bodies.length; i++) {
      Offset acc = Offset.zero;
      for (int j = 0; j < bodies.length; j++) {
        if (i == j) continue;
        final r = bodies[j].pos - bodies[i].pos;
        final distSq = r.dx * r.dx + r.dy * r.dy;
        const double epsSq = 25.0;
        final invDistCube = 1.0 / pow(distSq + epsSq, 1.5);
        // クーロンの法則：F = k * q1 * q2 / r^2
        // 同符号は反発(accがrと逆方向)、異符号は吸引(accがr方向)
        // ここでは r = pos[j] - pos[i] なので、q1*q2 が負なら吸引、正なら反発
        acc -= r * (kConstant * bodies[i].charge * bodies[j].charge * 10000.0 * invDistCube);
      }
      bodies[i].vel += acc * dtD;
    }
  }

  void _handleInteractions() {
    if (bodies.length < 2) return;
    List<int> toRemove = [];
    for (int i = 0; i < bodies.length; i++) {
      if (toRemove.contains(i)) continue;
      for (int j = i + 1; j < bodies.length; j++) {
        if (toRemove.contains(j)) continue;
        final dist = (bodies[i].pos - bodies[j].pos).distance;
        final interactionDist = (bodies[i].charge.abs() + bodies[j].charge.abs()) * 2.0 + 4.0;
        
        if (dist < interactionDist) {
          final q1 = bodies[i].charge;
          final q2 = bodies[j].charge;
          
          if ((q1 > 0 && q2 < 0) || (q1 < 0 && q2 > 0)) {
            // 対消滅ロジック：正負が合わさると電荷が相殺
            final totalCharge = q1 + q2;
            if (totalCharge.abs() < 0.5) {
              // ほぼゼロなら両方消滅
              toRemove.add(i);
              toRemove.add(j);
              break;
            } else {
              // 残った電荷を持つ一つに統合
              bodies[i].charge = totalCharge;
              toRemove.add(j);
            }
          } else {
            // 同符号：合体して大きな電荷に
            bodies[i].charge = q1 + q2;
            toRemove.add(j);
          }
        }
      }
    }
    toRemove.sort((a, b) => b.compareTo(a));
    for (var idx in toRemove.toSet().toList()..sort((a, b) => b.compareTo(a))) {
      if (idx < bodies.length) bodies.removeAt(idx);
    }
  }

  void _updatePotential(Grid grid) {
    final u = grid.u;
    final mask = grid.mask;
    final w = grid.w;
    final h = grid.h;
    for (int i = 0; i < w * h; i++) {
      if (mask[i] == 0) { u[i] = 0; continue; }
      final x = i % w;
      final y = i ~/ w;
      double phi = 0;
      for (var b in bodies) {
        final dx = b.pos.dx - x;
        final dy = b.pos.dy - y;
        const double epsSq = 25.0;
        phi += (kConstant * b.charge * 50000.0) / sqrt(dx * dx + dy * dy + epsSq);
      }
      u[i] = phi;
    }
  }

  @override
  void onTouchStart(Grid grid, Offset p) {
    dragStart = p;
    placing = ElectricBody(pos: p, vel: Offset.zero, charge: currentCharge);
  }

  @override
  void onTouchMove(Grid grid, Offset p) {
    if (placing != null && dragStart != null) {
      placing!.vel = (p - dragStart!) * 0.004;
    }
  }

  @override
  void onTouchEnd(Grid grid, Offset p) {
    if (placing != null) {
      bodies.add(placing!);
      if (bodies.length > 10) bodies.removeAt(0);
      placing = null;
      dragStart = null;
    }
  }
}
