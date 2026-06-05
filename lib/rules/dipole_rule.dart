import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart' show Colors, Color;
import '../game/grid.dart';
import 'field_rule.dart';

enum FieldView { potential, electricField, radiation }

class ElectricDipole {
  Offset pos;
  Offset vel;
  double angle;
  double angularVel;
  double separation;
  
  // For radiation calculation (previous dipole moments)
  Offset pPrev = Offset.zero;
  Offset pPrev2 = Offset.zero;

  ElectricDipole({
    required this.pos,
    this.vel = Offset.zero,
    required this.angle,
    this.angularVel = 0.0,
    required this.separation,
  }) {
    pPrev = moment;
    pPrev2 = moment;
  }

  Offset get moment => Offset(math.cos(angle), math.sin(angle)) * separation;

  void update(double dt, double damping) {
    pos += vel * dt;
    angle += angularVel * dt;
    vel *= damping;
    angularVel *= damping;
  }
}

class DipoleRule extends FieldRule {
  final List<ElectricDipole> dipoles = [];
  
  double k = 100.0; // Coulomb constant
  double separation = 4.0;
  double initialAngularVel = 0.1;
  double damping = 0.98;
  double interactionStrength = 1.0;
  
  // Visualization mode: 0: Potential, 1: Electric Field, 2: Radiation
  int visualizationMode = 0;

  Offset? _dragStart;
  List<List<Offset>>? _fieldLines;
  List<List<Offset>>? get fieldLines => _fieldLines;

  @override
  String get name => "Dipole";

  @override
  RenderConfig get renderConfig => RenderConfig.electric();

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'k', label: 'Coulomb K', min: 10.0, max: 500.0, defaultValue: 100.0),
    RuleParam(key: 'separation', label: 'Separation', min: 1.0, max: 10.0, defaultValue: 4.0),
    RuleParam(key: 'initialAngularVel', label: 'Initial Rot', min: 0.0, max: 1.0, defaultValue: 0.1),
    RuleParam(key: 'damping', label: 'Damping', min: 0.9, max: 1.0, defaultValue: 0.98),
    RuleParam(key: 'visualizationMode', label: 'Mode (0:Pot, 1:E, 2:Rad)', min: 0, max: 2, defaultValue: 0),
  ];

  @override
  void setParam(String key, double value) {
    if (key == 'k') k = value;
    if (key == 'separation') separation = value;
    if (key == 'initialAngularVel') initialAngularVel = value;
    if (key == 'damping') damping = value;
    if (key == 'visualizationMode') visualizationMode = value.toInt();
  }

  @override
  void init(Grid grid) {
    dipoles.clear();
    grid.u.fillRange(0, grid.u.length, 0.0);
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0);
    _fieldLines = null;
  }

  @override
  void step(Grid grid, double dt) {
    if (dipoles.isEmpty) return;

    // 1. Physics: Compute interactions
    final List<Offset> forces = List.filled(dipoles.length, Offset.zero);
    final List<double> torques = List.filled(dipoles.length, 0.0);

    for (int i = 0; i < dipoles.length; i++) {
      final d = dipoles[i];
      final eField = _computeExternalEField(d.pos, i);
      
      // Torque: tau = p x E
      final p = d.moment;
      torques[i] = (p.dx * eField.dy - p.dy * eField.dx);
      
      // Force: F = grad(p . E) using finite difference
      forces[i] = _computeForce(d, i);
    }

    // 2. Physics: Update states
    for (int i = 0; i < dipoles.length; i++) {
      final d = dipoles[i];
      d.vel += forces[i] * interactionStrength * dt;
      d.angularVel += torques[i] * interactionStrength * dt;
      
      d.pPrev2 = d.pPrev;
      d.pPrev = d.moment;
      
      d.update(dt, damping);
      _reflectAtBoundary(d, grid);
    }

    // 3. Visualization: Write to grid
    _writeToGrid(grid);
    
    // 4. Visualization: Compute field lines (can be skipped or throttled)
    _computeFieldLines(grid);
  }

  Offset _computeExternalEField(Offset pos, int skipIndex) {
    Offset e = Offset.zero;
    for (int j = 0; j < dipoles.length; j++) {
      if (j == skipIndex) continue;
      e += _eFieldOf(dipoles[j], pos);
    }
    return e;
  }

  Offset _eFieldOf(ElectricDipole d, Offset target) {
    final rVec = target - d.pos;
    final r2 = rVec.dx * rVec.dx + rVec.dy * rVec.dy + 1.0;
    final r = math.sqrt(r2);
    final r3 = r2 * r;
    final r5 = r3 * r2;
    
    final p = d.moment;
    final pDotR = p.dx * rVec.dx + p.dy * rVec.dy;
    
    // E = k * [ 3(p.r)r/r^5 - p/r^3 ]
    return Offset(
      k * (3 * pDotR * rVec.dx / r5 - p.dx / r3),
      k * (3 * pDotR * rVec.dy / r5 - p.dy / r3)
    );
  }

  Offset _computeForce(ElectricDipole d, int index) {
    const double h = 0.5;
    final p = d.moment;
    
    final exPlus = _computeExternalEField(d.pos + const Offset(h, 0), index);
    final exMinus = _computeExternalEField(d.pos - const Offset(h, 0), index);
    final eyPlus = _computeExternalEField(d.pos + const Offset(0, h), index);
    final eyMinus = _computeExternalEField(d.pos - const Offset(0, h), index);
    
    // Fx = p . (dE/dx)
    final fx = p.dx * (exPlus.dx - exMinus.dx) / (2 * h) + 
               p.dy * (exPlus.dy - exMinus.dy) / (2 * h);
    // Fy = p . (dE/dy)
    final fy = p.dx * (eyPlus.dx - eyMinus.dx) / (2 * h) + 
               p.dy * (eyPlus.dy - eyMinus.dy) / (2 * h);
               
    return Offset(fx, fy);
  }

  void _reflectAtBoundary(ElectricDipole d, Grid grid) {
    final x = d.pos.dx.toInt();
    final y = d.pos.dy.toInt();
    
    bool hit = false;
    Offset normal = Offset.zero;
    
    if (x <= 1) { hit = true; normal += const Offset(1, 0); }
    else if (x >= grid.w - 2) { hit = true; normal += const Offset(-1, 0); }
    if (y <= 1) { hit = true; normal += const Offset(0, 1); }
    else if (y >= grid.h - 2) { hit = true; normal += const Offset(0, -1); }
    
    // Polygon boundary check
    if (!hit && x >= 0 && x < grid.w && y >= 0 && y < grid.h) {
      if (grid.mask[y * grid.w + x] == 0) {
        hit = true;
        // Estimate normal from mask gradient
        for (int i = -1; i <= 1; i++) {
          for (int j = -1; j <= 1; j++) {
            int nx = x + j;
            int ny = y + i;
            if (nx >= 0 && nx < grid.w && ny >= 0 && ny < grid.h) {
              if (grid.mask[ny * grid.w + nx] > 0) {
                normal += Offset(j.toDouble(), i.toDouble());
              }
            }
          }
        }
      }
    }

    if (hit && normal != Offset.zero) {
      normal = normal / (normal.distance + 0.001);
      final dot = d.vel.dx * normal.dx + d.vel.dy * normal.dy;
      if (dot < 0) {
        d.vel = d.vel - normal * (2.0 * dot);
        // Add angular velocity from collision
        d.angularVel += d.vel.distance * 0.1;
      }
      // Push out
      d.pos += normal * 2.0;
    }
  }

  void _writeToGrid(Grid grid) {
    for (int y = 0; y < grid.h; y++) {
      for (int x = 0; x < grid.w; x++) {
        final pos = Offset(x.toDouble(), y.toDouble());
        double val = 0.0;
        
        if (visualizationMode == 0) { // Potential
          for (final d in dipoles) {
            final rVec = pos - d.pos;
            final r2 = rVec.dx * rVec.dx + rVec.dy * rVec.dy + 1.0;
            final p = d.moment;
            val += k * (p.dx * rVec.dx + p.dy * rVec.dy) / (r2 * math.sqrt(r2));
          }
        } else if (visualizationMode == 1) { // Electric Field Magnitude
          final e = _computeExternalEField(pos, -1);
          val = e.distance * 0.1;
        } else { // Radiation
          for (final d in dipoles) {
            final rVec = pos - d.pos;
            final r = rVec.distance + 1.0;
            // Simplified delayed potential effect using p, pPrev, pPrev2
            final pAccel = (d.moment - d.pPrev * 2.0 + d.pPrev2);
            val += k * (pAccel.dx * rVec.dy - pAccel.dy * rVec.dx) / (r * r);
          }
        }
        grid.u[y * grid.w + x] = val;
      }
    }
  }

  void _computeFieldLines(Grid grid) {
    _fieldLines = [];
    for (final d in dipoles) {
      // Start lines from positive charge area
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final startPos = d.pos + Offset(math.cos(angle), math.sin(angle)) * d.separation;
        _fieldLines!.add(_traceFieldLine(startPos, 30));
      }
    }
  }

  List<Offset> _traceFieldLine(Offset start, int steps) {
    List<Offset> line = [start];
    Offset curr = start;
    for (int i = 0; i < steps; i++) {
      final e = _computeExternalEField(curr, -1);
      if (e.distance < 0.1) break;
      curr += (e / e.distance) * 4.0;
      line.add(curr);
      if (curr.dx < 0 || curr.dx > 256 || curr.dy < 0 || curr.dy > 256) break;
    }
    return line;
  }

  @override
  void onTouchStart(Grid grid, Offset pos) {
    _dragStart = pos;
  }

  @override
  void onTouchMove(Grid grid, Offset pos) {}

  @override
  void onTouchEnd(Grid grid, Offset pos) {
    if (_dragStart == null) return;
    final delta = pos - _dragStart!;
    
    dipoles.add(ElectricDipole(
      pos: pos,
      vel: delta * 0.05,
      angle: math.atan2(delta.dy, delta.dx),
      angularVel: initialAngularVel,
      separation: separation,
    ));
    _dragStart = null;
  }
}
