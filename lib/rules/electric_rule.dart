import 'dart:math';
import 'dart:ui';
import '../game/grid.dart';
import 'field_rule.dart';

class ElectricBody {
  Offset pos;
  Offset vel;
  double charge; // 正負両方の値を持つ
  bool isMonopole;
  
  ElectricBody({
    required this.pos, 
    required this.vel, 
    required this.charge,
    this.isMonopole = false,
  });
}

class Photon {
  Offset pos;
  Offset vel;
  Photon({required this.pos, required this.vel});
}

class ElectricRule extends FieldRule {
  @override
  String get name => 'electric';

  @override
  RenderConfig get renderConfig => RenderConfig(pixel: (u, m, ch) {
    final v = u;
    final absV = v.abs();
    final logV = log(1.0 + absV * 0.01);
    const levels = 8.0;
    final val = logV * levels;
    final frac = val - val.floor();
    
    final isContour = frac < 0.12 && logV > 0.001;
    
    if (isContour) {
      if (v > 0) {
        final rgb = [(1.0 * 255 * m).toInt(), (0.3 * 255 * m).toInt(), (0.1 * 255 * m).toInt()];
        return rgb[ch].clamp(0, 255);
      } else {
        final rgb = [(0.1 * 255 * m).toInt(), (0.4 * 255 * m).toInt(), (1.0 * 255 * m).toInt()];
        return rgb[ch].clamp(0, 255);
      }
    }
    
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
    RuleParam(key: 'charge', label: 'Charge', min: -5.0, max: 5.0, defaultValue: 1.0, divisions: 10, getCurrentValue: () => currentCharge),
  ];

  double kConstant = 0.001;
  double currentCharge = 1.0;
  static const double lightSpeed = 120.0; // Photonの固定速度

  List<ElectricBody> bodies = [];
  List<Photon> photons = [];
  List<Offset> trails = [];
  
  ElectricBody? placing;
  Offset? dragStart;

  @override
  void init(Grid grid) {
    bodies = [];
    photons = [];
    trails = [];
    placing = null;
    dragStart = null;
    grid.u.fillRange(0, grid.u.length, 0.0);
  }

  @override
  void setParam(String key, double value) {
    if (key == 'K') kConstant = value;
    if (key == 'charge') currentCharge = value.roundToDouble();
  }

  @override
  void step(Grid grid, double dt) {
    const double timeScale = 0.1;
    final double scaledDt = dt * timeScale;
    const int subSteps = 8;
    final double dtSub = scaledDt / subSteps;

    for (int s = 0; s < subSteps; s++) {
      _stepYoshida(dtSub, grid.mask, grid.w, grid.h);
      _stepPhotons(dtSub, grid.mask, grid.w, grid.h);
    }

    if (bodies.isNotEmpty) {
      for (var b in bodies) trails.add(b.pos);
      if (trails.length > 500) trails.removeRange(0, trails.length - 500);
    }

    _updatePotential(grid);
  }

  void _stepPhotons(double dt, List<double> mask, int w, int h) {
    List<Photon> toRemove = [];
    List<ElectricBody> newPairs = [];

    for (var p in photons) {
      final oldPos = p.pos;
      p.pos += p.vel * dt;
      
      final ix = p.pos.dx.toInt();
      final iy = p.pos.dy.toInt();
      
      // 境界反射
      if (ix < 0 || ix >= w || iy < 0 || iy >= h || mask[iy * w + ix] == 0) {
        _handlePhotonReflection(p, oldPos, mask, w, h);
      }

      // モノポールとの接触判定（対生成）
      for (var b in bodies) {
        if (b.isMonopole) {
          if ((p.pos - b.pos).distance < 6.0) {
            toRemove.add(p);
            // 対生成：正負のペアを射出
            final angle = Random().nextDouble() * 2 * pi;
            const spawnSpeed = 15.0;
            newPairs.add(ElectricBody(
              pos: b.pos,
              vel: Offset(cos(angle), sin(angle)) * spawnSpeed,
              charge: 1.0,
            ));
            newPairs.add(ElectricBody(
              pos: b.pos,
              vel: Offset(cos(angle + pi), sin(angle + pi)) * spawnSpeed,
              charge: -1.0,
            ));
            break;
          }
        }
      }
    }

    photons.removeWhere((p) => toRemove.contains(p));
    bodies.addAll(newPairs);
    if (photons.length > 50) photons.removeRange(0, photons.length - 50);
  }

  void _handlePhotonReflection(Photon p, Offset oldPos, List<double> mask, int w, int h) {
    double nx = 0, ny = 0;
    final ix = oldPos.dx.toInt();
    final iy = oldPos.dy.toInt();
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final tx = ix + dx, ty = iy + dy;
        if (tx < 0 || tx >= w || ty < 0 || ty >= h) continue;
        if (mask[ty * w + tx] == 0) { nx -= dx; ny -= dy; }
      }
    }
    double len = sqrt(nx * nx + ny * ny);
    if (len > 0) {
      nx /= len; ny /= len;
      final dot = p.vel.dx * nx + p.vel.dy * ny;
      if (dot > 0) {
        p.vel = Offset(p.vel.dx - 2 * dot * nx, p.vel.dy - 2 * dot * ny);
      }
    } else {
      p.vel = Offset(-p.vel.dx, -p.vel.dy);
    }
    p.pos = Offset(oldPos.dx.clamp(0.1, w - 1.1), oldPos.dy.clamp(0.1, h - 1.1));
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
      final oldPos = b.pos;
      b.pos += b.vel * dtC;
      final ix = b.pos.dx.toInt(), iy = b.pos.dy.toInt();
      if (ix < 0 || ix >= w || iy < 0 || iy >= h || mask[iy * w + ix] == 0) {
        _handleReflection(b, oldPos, mask, w, h);
        const maxVel = 50.0;
        if (b.vel.distance > maxVel) b.vel = (b.vel / b.vel.distance) * (maxVel * 0.8);
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
        final q1 = bodies[i].isMonopole ? 1.0 : bodies[i].charge;
        final q2 = bodies[j].isMonopole ? 1.0 : bodies[j].charge;
        acc -= r * (kConstant * q1 * q2 * 10000.0 * invDistCube);
      }
      bodies[i].vel += acc * dtD;
    }
  }

  void _handleReflection(ElectricBody b, Offset oldPos, List<double> mask, int w, int h) {
    double nx = 0, ny = 0;
    final ix = oldPos.dx.toInt(), iy = oldPos.dy.toInt();
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final tx = ix + dx, ty = iy + dy;
        if (tx < 0 || tx >= w || ty < 0 || ty >= h) continue;
        if (mask[ty * w + tx] == 0) { nx -= dx; ny -= dy; }
      }
    }
    double len = sqrt(nx * nx + ny * ny);
    if (len > 0) {
      nx /= len; ny /= len;
      final dot = b.vel.dx * nx + b.vel.dy * ny;
      if (dot > 0) {
        b.vel = Offset(b.vel.dx - 2 * dot * nx, b.vel.dy - 2 * dot * ny);
      }
    } else {
      b.vel = Offset(-b.vel.dx, -b.vel.dy);
    }
    b.pos = Offset(oldPos.dx.clamp(0.1, w - 1.1), oldPos.dy.clamp(0.1, h - 1.1));
  }

  void _handleInteractions() {
    if (bodies.length < 2) return;
    List<int> toRemove = [];
    List<Photon> newPhotons = [];

    for (int i = 0; i < bodies.length; i++) {
      if (toRemove.contains(i)) continue;
      for (int j = i + 1; j < bodies.length; j++) {
        if (toRemove.contains(j)) continue;
        final dist = (bodies[i].pos - bodies[j].pos).distance;
        final interactionDist = (bodies[i].charge.abs() + bodies[j].charge.abs()) * 2.0 + 4.0;
        
        if (dist < interactionDist) {
          // モノポール接触：消滅のみ（Photon放出なし）
          if (bodies[i].isMonopole || bodies[j].isMonopole) {
            toRemove.add(i); toRemove.add(j);
            break;
          }

          final q1 = bodies[i].charge;
          final q2 = bodies[j].charge;
          
          if ((q1 > 0 && q2 < 0) || (q1 < 0 && q2 > 0)) {
            // 対消滅：Photon放出
            final totalCharge = q1 + q2;
            if (totalCharge.abs() < 0.5) {
              final center = (bodies[i].pos + bodies[j].pos) / 2.0;
              final angle = Random().nextDouble() * 2 * pi;
              newPhotons.add(Photon(pos: center, vel: Offset(cos(angle), sin(angle)) * lightSpeed));
              newPhotons.add(Photon(pos: center, vel: Offset(cos(angle + pi), sin(angle + pi)) * lightSpeed));
              toRemove.add(i); toRemove.add(j);
              break;
            } else {
              bodies[i].charge = totalCharge;
              toRemove.add(j);
            }
          } else {
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
    photons.addAll(newPhotons);
  }

  void _updatePotential(Grid grid) {
    final u = grid.u;
    final mask = grid.mask;
    final w = grid.w;
    final h = grid.h;
    for (int i = 0; i < w * h; i++) {
      if (mask[i] == 0) { u[i] = 0; continue; }
      final x = i % w, y = i ~/ w;
      double phi = 0;
      for (var b in bodies) {
        final dx = b.pos.dx - x, dy = b.pos.dy - y;
        const double epsSq = 25.0;
        final q = b.isMonopole ? 1.0 : b.charge;
        phi += (kConstant * q * 50000.0) / sqrt(dx * dx + dy * dy + epsSq);
      }
      u[i] = phi;
    }
  }

  @override
  void onTouchStart(Grid grid, Offset p) {
    dragStart = p;
    final isZero = currentCharge == 0;
    placing = ElectricBody(
      pos: p, vel: Offset.zero, 
      charge: isZero ? 1.0 : currentCharge,
      isMonopole: isZero,
    );
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
