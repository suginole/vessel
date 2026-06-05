import 'dart:math' as math;
import 'dart:ui';
import 'field_rule.dart';
import '../game/grid.dart';

enum FieldView { potential, electric, radiation }

class ElectricDipole {
  Offset pos;
  Offset vel;
  double angle;
  double angularVel;
  double charge;
  double separation;

  // For radiation calculation (p_dot_dot)
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

    // Update moment history for acceleration calculation
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
      key: 'view',
      label: 'Visualization',
      min: 0, max: 2,
      defaultValue: 0,
      divisions: 2,
      getCurrentValue: () => view.index.toDouble(),
    ),
  ];

  @override
  void setParam(String key, double val) {
    if (key == 'k') kConstant = val;
    if (key == 'sep') separation = val;
    if (key == 'w') initialAngularVel = val;
    if (key == 'view') view = FieldView.values[val.toInt()];
  }

  @override
  void update(Grid grid, double dt) {
    for (var d in dipoles) {
      d.update(dt, damping);
      
      // Boundary check
      if (d.pos.dx < 0 || d.pos.dx >= grid.w || d.pos.dy < 0 || d.pos.dy >= grid.h) {
        // Simple bounce
        if (d.pos.dx < 0 || d.pos.dx >= grid.w) d.vel = Offset(-d.vel.dx, d.vel.dy);
        if (d.pos.dy < 0 || d.pos.dy >= grid.h) d.vel = Offset(d.vel.dx, -d.vel.dy);
      }
    }

    _computeFields(grid);
  }

  void _computeFields(Grid grid) {
    final w = grid.w;
    final h = grid.h;
    const eps = 1.0;

    for (int i = 0; i < w * h; i++) {
      if (grid.mask[i] == 0) {
        grid.u[i] = 0;
        grid.uPrev[i] = 0;
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

        // 1. Potential phi = k * (p·r_hat) / r^2
        final pDotR = px * rHatX + py * rHatY;
        phi += kConstant * pDotR * 100.0 / r2;

        // 2. Electric Field E = k/r^3 * (3(p·r_hat)r_hat - p)
        // We store magnitude in u for 'electric' view, but we need direction for painter
        final ex_i = kConstant * 1000.0 / r3 * (3 * pDotR * rHatX - px);
        final ey_i = kConstant * 1000.0 / r3 * (3 * pDotR * rHatY - py);
        ex += ex_i;
        ey += ey_i;

        // 3. Radiation Field E_rad
        final pddx = d.pDotDot.dx;
        final pddy = d.pDotDot.dy;
        final pdd_perp = pddx * (-rHatY) + pddy * rHatX;
        erad += kConstant * 500.0 / (lightSpeed * lightSpeed * r) * pdd_perp;
      }

      if (view == FieldView.potential) {
        grid.u[i] = phi;
      } else if (view == FieldView.electric) {
        grid.u[i] = math.sqrt(ex * ex + ey * ey);
        // We could store angle in uPrev if needed, but let's keep uPrev for radiation
      } else if (view == FieldView.radiation) {
        grid.u[i] = erad;
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
    } else {
      // Radiation: Blue-White-Red wave
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
    }
  }

  @override
  void onTouch(Offset pos, Offset delta, bool isEnd) {
    if (isEnd) {
      dipoles.add(ElectricDipole(
        pos: pos,
        vel: delta * 0.5,
        angle: math.atan2(delta.dy, delta.dx),
        angularVel: initialAngularVel,
        separation: separation,
      ));
    }
  }
}
