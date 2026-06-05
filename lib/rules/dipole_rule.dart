import 'dart:math' as math;
import 'dart:ui';
import 'field_rule.dart';
import '../game/grid.dart';
import '../game/boundary.dart';

enum FieldView { potential, electric, radiation, fieldLines }

class ElectricDipole {
  Offset pos;
  Offset vel;
  double angle;
  double angularVel;
  double charge;
  double separation;

  // For radiation calculation
  Offset pPrev = Offset.zero;
  Offset pPrev2 = Offset.zero;

  ElectricDipole({
    required this.pos,
    this.vel = Offset.zero,
    this.angle = 0,
    this.angularVel = 1.0,
    this.charge = 1.0,
    this.separation = 8.0,
  });

  Offset get moment => Offset(math.cos(angle), math.sin(angle)) * charge * separation;

  void update(double dt, double damping) {
    pos += vel * dt;
    angle += angularVel * dt;
    angularVel *= damping;

    pPrev2 = pPrev;
    pPrev = moment;
  }

  Offset get pDotDot => (moment - pPrev * 2 + pPrev2);
}

class DipoleRule extends FieldRule {
  final List<ElectricDipole> dipoles = [];
  FieldView view = FieldView.potential;
  
  double kConstant = 0.01;
  double separation = 8.0;
  double initialAngularVel = 1.0;
  double damping = 0.999;
  double lightSpeed = 2.0;
  double interactionStrength = 0.1;

  Offset? _dragStart;
  List<List<Offset>>? _fieldLines;
  
  List<List<Offset>>? get fieldLines => _fieldLines;

  @override
  String get name => "Dipole";

  @override
  List<RuleParam> get params => [
    RuleParam(
      key: 'k',
      label: 'K Constant',
      min: 0.001, max: 0.05,
      defaultValue: 0.01,
      getCurrentValue: () => kConstant,
    ),
    RuleParam(
      key: 'sep',
      label: 'Separation',
      min: 4.0, max: 20.0,
      defaultValue: 8.0,
      getCurrentValue: () => separation,
    ),
    RuleParam(
      key: 'w',
      label: 'Angular Vel',
      min: 0.0, max: 5.0,
      defaultValue: 1.0,
      getCurrentValue: () => initialAngularVel,
    ),
    RuleParam(
      key: 'interact',
      label: 'Interaction',
      min: 0.0, max: 1.0,
      defaultValue: 0.1,
      getCurrentValue: () => interactionStrength,
    ),
    RuleParam(
      key: 'view',
      label: 'Visualization',
      min: 0, max: 3,
      defaultValue: 0,
      divisions: 3,
      getCurrentValue: () => view.index.toDouble(),
    ),
  ];

  @override
  void init(Grid grid) {
    dipoles.clear();
    grid.u.fillRange(0, grid.u.length, 0.0);
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0);
    _dragStart = null;
    _fieldLines = null;
  }

  @override
  void setParam(String key, double val) {
    if (key == 'k') kConstant = val;
    if (key == 'sep') separation = val;
    if (key == 'w') initialAngularVel = val;
    if (key == 'interact') interactionStrength = val;
    if (key == 'view') view = FieldView.values[val.toInt()];
  }

  @override
  void step(Grid grid, double dt) {
    // Compute electric field at each dipole
    final eFields = <Offset>[];
    for (int i = 0; i < dipoles.length; i++) {
      Offset eField = Offset.zero;
      for (int j = 0; j < dipoles.length; j++) {
        if (i == j) continue;
        eField += _computeEFieldAtDipole(dipoles[i].pos, dipoles[j]);
      }
      eFields.add(eField);
    }

    // Update each dipole with interactions and boundary reflection
    for (int i = 0; i < dipoles.length; i++) {
      final d = dipoles[i];
      
      // Interaction: Force and Torque
      final e = eFields[i];
      final pMoment = d.moment;
      
      // Translational force: F = ∇(p·E) ≈ (p·∇)E
      final f = Offset(
        (pMoment.dx * e.dx + pMoment.dy * e.dy) * interactionStrength * 0.01,
        (pMoment.dx * e.dy - pMoment.dy * e.dx) * interactionStrength * 0.01,
      );
      d.vel += f * dt;
      
      // Rotational torque: τ = p × E
      final torque = pMoment.dx * e.dy - pMoment.dy * e.dx;
      d.angularVel += torque * interactionStrength * 0.001;
      
      // Update position and angle
      d.update(dt, damping);
      
      // Boundary reflection with normal calculation
      _reflectAtBoundary(d, grid);
    }

    _computeFields(grid);
    _computeFieldLines(grid);
  }

  Offset _computeEFieldAtDipole(Offset pos, ElectricDipole dipole) {
    final r = pos - dipole.pos;
    final r2 = r.dx * r.dx + r.dy * r.dy + 1.0;
    final r3 = r2 * math.sqrt(r2);
    
    final p = dipole.moment;
    final pDotR = p.dx * r.dx + p.dy * r.dy;
    
    final rHat = r / math.sqrt(r2);
    final ex = kConstant * 1000.0 / r3 * (3 * pDotR * rHat.dx - p.dx);
    final ey = kConstant * 1000.0 / r3 * (3 * pDotR * rHat.dy - p.dy);
    
    return Offset(ex, ey);
  }

  void _reflectAtBoundary(ElectricDipole d, Grid grid) {
    final ix = d.pos.dx.toInt();
    final iy = d.pos.dy.toInt();
    
    if (ix < 0 || ix >= grid.w || iy < 0 || iy >= grid.h) {
      d.vel = Offset(-d.vel.dx, -d.vel.dy);
      d.pos = Offset(
        d.pos.dx.clamp(0.0, grid.w - 1.0),
        d.pos.dy.clamp(0.0, grid.h - 1.0),
      );
      return;
    }
    
    if (grid.mask[iy * grid.w + ix] == 0) {
      // Find normal by sampling neighbors
      final maskLeft = ix > 0 ? grid.mask[iy * grid.w + (ix - 1)] : 0;
      final maskRight = ix < grid.w - 1 ? grid.mask[iy * grid.w + (ix + 1)] : 0;
      final maskUp = iy > 0 ? grid.mask[(iy - 1) * grid.w + ix] : 0;
      final maskDown = iy < grid.h - 1 ? grid.mask[(iy + 1) * grid.w + ix] : 0;
      
      final nx = (maskRight - maskLeft) / 2.0;
      final ny = (maskDown - maskUp) / 2.0;
      final nLen = math.sqrt(nx * nx + ny * ny);
      
      if (nLen > 0.1) {
        final nxNorm = nx / nLen;
        final nyNorm = ny / nLen;
        
        // Reflect velocity
        final dot = d.vel.dx * nxNorm + d.vel.dy * nyNorm;
        d.vel = Offset(
          d.vel.dx - 2 * dot * nxNorm,
          d.vel.dy - 2 * dot * nyNorm,
        );
        
        // Increase angular velocity on sharp reflection
        d.angularVel += dot.abs() * 0.1;
      }
      
      // Push back into domain
      d.pos = Offset(
        d.pos.dx.clamp(0.5, grid.w - 1.5),
        d.pos.dy.clamp(0.5, grid.h - 1.5),
      );
    }
  }

  void _computeFields(Grid grid) {
    final w = grid.w;
    final h = grid.h;
    const eps = 1.0;

    for (int i = 0; i < w * h; i++) {
      if (grid.mask[i] == 0) {
        grid.u[i] = 0;
        continue;
      }

      final x = i % w;
      final y = i ~/ w;

      double phi = 0;
      double erad = 0;
      double ex = 0;
      double ey = 0;

      for (final d in dipoles) {
        final rx = x - d.pos.dx;
        final ry = y - d.pos.dy;
        final r2 = rx * rx + ry * ry + eps;
        final r = math.sqrt(r2);
        final r3 = r2 * r;

        final rHatX = rx / r;
        final rHatY = ry / r;

        final px = d.moment.dx;
        final py = d.moment.dy;

        final pDotR = px * rHatX + py * rHatY;
        phi += kConstant * pDotR * 100.0 / r2;

        final ex_i = kConstant * 1000.0 / r3 * (3 * pDotR * rHatX - px);
        final ey_i = kConstant * 1000.0 / r3 * (3 * pDotR * rHatY - py);
        ex += ex_i;
        ey += ey_i;

        final pddx = d.pDotDot.dx;
        final pddy = d.pDotDot.dy;
        final pdd_perp = pddx * (-rHatY) + pddy * rHatX;
        erad += kConstant * 500.0 / (lightSpeed * lightSpeed * r) * pdd_perp;
      }

      if (view == FieldView.potential) {
        grid.u[i] = phi;
      } else if (view == FieldView.electric) {
        grid.u[i] = math.sqrt(ex * ex + ey * ey);
      } else if (view == FieldView.radiation) {
        grid.u[i] = erad;
      } else if (view == FieldView.fieldLines) {
        grid.u[i] = math.sqrt(ex * ex + ey * ey);
      }
    }
  }

  void _computeFieldLines(Grid grid) {
    if (view != FieldView.fieldLines) return;
    
    _fieldLines = [];
    const numLines = 16;
    const stepSize = 0.5;
    const maxSteps = 200;
    
    for (final d in dipoles) {
      for (int lineIdx = 0; lineIdx < numLines; lineIdx++) {
        final angle = (lineIdx / numLines) * math.pi * 2;
        final line = <Offset>[];
        var pos = d.pos + Offset(math.cos(angle), math.sin(angle)) * 5.0;
        
        for (int step = 0; step < maxSteps; step++) {
          if (pos.dx < 0 || pos.dx >= grid.w || pos.dy < 0 || pos.dy >= grid.h) break;
          if (grid.mask[pos.dy.toInt() * grid.w + pos.dx.toInt()] == 0) break;
          
          line.add(pos);
          
          // Compute E field at current position
          var ex = 0.0, ey = 0.0;
          for (final dipole in dipoles) {
            final r = pos - dipole.pos;
            final r2 = r.dx * r.dx + r.dy * r.dy + 1.0;
            final r3 = r2 * math.sqrt(r2);
            final p = dipole.moment;
            final pDotR = p.dx * r.dx + p.dy * r.dy;
            final rHat = r / math.sqrt(r2);
            ex += kConstant * 1000.0 / r3 * (3 * pDotR * rHat.dx - p.dx);
            ey += kConstant * 1000.0 / r3 * (3 * pDotR * rHat.dy - p.dy);
          }
          
          final eMag = math.sqrt(ex * ex + ey * ey);
          if (eMag < 0.1) break;
          
          pos += Offset(ex / eMag, ey / eMag) * stepSize;
        }
        
        if (line.isNotEmpty) _fieldLines!.add(line);
      }
    }
  }

  @override
  RenderConfig get renderConfig {
    if (view == FieldView.potential) {
      return RenderConfig(pixel: (u, m, ch) {
        final v = (u * 0.5).clamp(-1.0, 1.0);
        final levels = 12;
        final logV = math.log(v.abs() * 9 + 1) / math.log(10) * v.sign;
        final frac = (logV * levels).abs() % 1.0;
        final isContour = frac < 0.08;
        
        int r, g, b;
        if (isContour) {
          r = g = b = 255;
        } else if (v > 0) {
          final t = v;
          r = 255; g = (255 * (1 - t)).toInt(); b = (255 * (1 - t)).toInt();
        } else {
          final t = -v;
          r = (255 * (1 - t)).toInt(); g = (255 * (1 - t)).toInt(); b = 255;
        }
        return ([r, g, b][ch] * m).toInt().clamp(0, 255);
      });
    } else if (view == FieldView.electric) {
      return RenderConfig(pixel: (u, m, ch) {
        final v = (u * 0.2).clamp(0.0, 1.0);
        final r = (v * 255 * m).toInt().clamp(0, 255);
        final g = (v * 200 * m).toInt().clamp(0, 255);
        final b = (v * 150 * m).toInt().clamp(0, 255);
        return [r, g, b][ch];
      });
    } else if (view == FieldView.radiation) {
      return RenderConfig(pixel: (u, m, ch) {
        final v = (u * 1.5).clamp(-1.0, 1.0);
        int r, g, b;
        if (v >= 0) {
          r = (255 * (1 - v)).toInt(); g = r; b = 255;
        } else {
          final t = -v;
          r = 255; g = (255 * (1 - t)).toInt(); b = g;
        }
        return ([r, g, b][ch] * m).toInt().clamp(0, 255);
      });
    } else {
      // Field lines view
      return RenderConfig(pixel: (u, m, ch) {
        final v = (u * 0.15).clamp(0.0, 1.0);
        int r, g, b;
        r = (50 * m).toInt();
        g = (50 * m).toInt();
        b = (100 + v * 155 * m).toInt();
        return [r, g, b][ch].clamp(0, 255);
      });
    }
  }

  @override
  void onTouchStart(Grid grid, Offset pos) {
    _dragStart = pos;
  }

  @override
  void onTouchMove(Grid grid, Offset pos) {}

  @override
  void onTouchEnd(Grid grid, Offset pos) {
    final delta = _dragStart != null ? pos - _dragStart! : Offset.zero;
    dipoles.add(ElectricDipole(
      pos: pos,
      vel: delta * 0.5,
      angle: math.atan2(delta.dy, delta.dx),
      angularVel: initialAngularVel,
      separation: separation,
    ));
    _dragStart = null;
  }
}
