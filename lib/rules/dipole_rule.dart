import 'dart:math' as math;
import 'dart:typed_data';
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
  
  // 正負電荷の座標
  Offset get posPlus  => pos + Offset(math.cos(angle), math.sin(angle)) * (separation * 0.5);
  Offset get posMinus => pos - Offset(math.cos(angle), math.sin(angle)) * (separation * 0.5);

  void update(double dt, double damping) {
    pos += vel * dt;
    angle += angularVel * dt;
    vel *= damping;
    angularVel *= damping;
  }
}

class DipoleBinding {
  int idA, idB;
  double bondLength;
  DipoleBinding(this.idA, this.idB, this.bondLength);
}

class DipoleRule extends FieldRule {
  final List<ElectricDipole> dipoles = [];
  final List<DipoleBinding> bonds = [];
  
  double k = 100.0; // Coulomb constant
  double separation = 4.0;
  double initialAngularVel = 0.1;
  double damping = 0.98;
  double interactionStrength = 5.0; // 並進運動を強化
  double lightSpeed = 0.7; // クーラン条件(c*dt/dx <= 0.707)の限界近くまで上げる
  
  // Visualization mode: 0: Potential, 1: Electric Field, 2: Radiation
  int visualizationMode = 0;

  // プレビュー用
  ElectricDipole? _placing;
  Offset? _dragStart;
  Offset? _dragCurrent;
  
  ElectricDipole? get placing => _placing;
  Offset? get dragStart => _dragStart;
  Offset? get dragCurrent => _dragCurrent;

  List<List<Offset>>? _fieldLines;
  List<List<Offset>>? get fieldLines => _fieldLines;

  @override
  String get name => "Dipole";

  @override
  RenderConfig get renderConfig => RenderConfig.electric();

  @override
  List<RuleParam> get params => [
    RuleParam(key: 'k', label: 'Coulomb K', min: 10.0, max: 500.0, defaultValue: 100.0, getCurrentValue: () => k),
    RuleParam(key: 'separation', label: 'Separation', min: 1.0, max: 10.0, defaultValue: 4.0, getCurrentValue: () => separation),
    RuleParam(key: 'initialAngularVel', label: 'Initial Rot', min: 0.0, max: 1.0, defaultValue: 0.1, getCurrentValue: () => initialAngularVel),
    RuleParam(key: 'damping', label: 'Damping', min: 0.9, max: 1.0, defaultValue: 0.98, getCurrentValue: () => damping),
    RuleParam(key: 'visualizationMode', label: 'Mode (0:Pot, 1:E, 2:Rad)', min: 0, max: 2, defaultValue: 0, getCurrentValue: () => visualizationMode.toDouble(), divisions: 2),
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
    bonds.clear();
    _placing = null;
    _dragStart = null;
    _dragCurrent = null;
    grid.u.fillRange(0, grid.u.length, 0.0);
    grid.uPrev.fillRange(0, grid.uPrev.length, 0.0);
    _fieldLines = null;
  }

  // 対消滅パルスを一時保存するリスト
  final List<Offset> _pendingPulses = [];

  @override
  void step(Grid grid, double dt) {
    // 1. 物理演算と相互作用 (Annihilation & Binding)
    if (dipoles.isNotEmpty) {
      final List<Offset> forces = List.filled(dipoles.length, Offset.zero);
      final List<double> torques = List.filled(dipoles.length, 0.0);

      for (int i = 0; i < dipoles.length; i++) {
        final d = dipoles[i];
        final eField = _computeExternalEField(d.pos, i);
        final p = d.moment;
        torques[i] = (p.dx * eField.dy - p.dy * eField.dx);
        forces[i] = _computeForce(d, i);
      }

      for (int i = 0; i < dipoles.length; i++) {
        final d = dipoles[i];
        d.vel += forces[i] * interactionStrength * dt;
        d.angularVel += torques[i] * interactionStrength * dt;
        d.pPrev2 = d.pPrev;
        d.pPrev = d.moment;
        d.update(dt, damping);
        _reflectAtBoundary(d, grid);
      }
      _updateInteractions(grid, dt);
    }

    // 2. 視覚化
    if (visualizationMode == 2) {
      // Radiationモード: 波動方程式で更新
      _stepWave(grid, dt);
      _computeFieldLines(grid);
    } else {
      // Potential / E-Fieldモード: 静的に書き込み
      _writeToGrid(grid);
      _fieldLines = null;
    }
  }

  void _stepWave(Grid grid, double dt) {
    final w = grid.w;
    final h = grid.h;
    final u = grid.u;
    final uPrev = grid.uPrev;
    final next = Float32List(u.length);
    final c2 = lightSpeed * lightSpeed;

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final lap = u[i+1] + u[i-1] + u[i+w] + u[i-w] - 4 * u[i];
        next[i] = (2 * u[i] - uPrev[i] + c2 * lap) * 0.98;
      }
    }
    
    // 双極子の加速度放射を注入
    for (final d in dipoles) {
      final pDotDot = (d.moment - d.pPrev * 2.0 + d.pPrev2);
      final idx = d.pos.dy.toInt() * w + d.pos.dx.toInt();
      if (idx >= 0 && idx < u.length) {
        next[idx] += pDotDot.distance * 15.0;
      }
    }

    // 対消滅パルスを注入
    for (final pos in _pendingPulses) {
      final idx = pos.dy.toInt() * w + pos.dx.toInt();
      if (idx >= 0 && idx < u.length) {
        next[idx] += 100.0; // 強力なパルス
      }
    }
    _pendingPulses.clear();

    uPrev.setAll(0, u);
    u.setAll(0, next);
  }

  void _updateInteractions(Grid grid, double dt) {
    final toRemove = <int>{};
    const annihilationRadius = 3.0;
    const annihilationEnergy = 50.0;

    // 1. 対消滅判定 (Annihilation)
    for (int i = 0; i < dipoles.length; i++) {
      for (int j = 0; j < dipoles.length; j++) {
        if (i == j) continue;
        
        // Aの正電荷とBの負電荷の接触
        final dist = (dipoles[i].posPlus - dipoles[j].posMinus).distance;
        if (dist < annihilationRadius) {
          toRemove.add(i);
          toRemove.add(j);
          
          // パルスをキューに追加
          _pendingPulses.add((dipoles[i].posPlus + dipoles[j].posMinus) * 0.5);
        }
      }
    }

    // 削除処理
    if (toRemove.isNotEmpty) {
      final sortedIndices = toRemove.toList()..sort((a, b) => b.compareTo(a));
      for (final idx in sortedIndices) {
        dipoles.removeAt(idx);
        // 関連する結合も削除
        bonds.removeWhere((b) => b.idA == idx || b.idB == idx);
        // 残った結合のインデックス調整
        for (final b in bonds) {
          if (b.idA > idx) b.idA--;
          if (b.idB > idx) b.idB--;
        }
      }
    }

    // 2. 結合ロジック (Binding)
    // 既存の結合の維持（バネ的な拘束）
    for (final b in bonds) {
      final dA = dipoles[b.idA];
      final dB = dipoles[b.idB];
      final rVec = dB.pos - dA.pos;
      final dist = rVec.distance;
      final diff = dist - b.bondLength;
      final force = rVec * (diff * 0.1);
      dA.vel += force;
      dB.vel -= force;
      
      // 角度を揃えるトルク
      final angleDiff = (dB.angle - dA.angle);
      dA.angularVel += angleDiff * 0.05;
      dB.angularVel -= angleDiff * 0.05;
    }

    // 新規結合の判定
    const bindRadius = 15.0;
    for (int i = 0; i < dipoles.length; i++) {
      for (int j = i + 1; j < dipoles.length; j++) {
        if (bonds.any((b) => (b.idA == i && b.idB == j) || (b.idA == j && b.idB == i))) continue;
        
        final dist = (dipoles[i].pos - dipoles[j].pos).distance;
        final angleDiff = (dipoles[i].angle - dipoles[j].angle).abs() % math.pi;
        final relVel = (dipoles[i].vel - dipoles[j].vel).distance;

        if (dist < bindRadius && angleDiff < 0.3 && relVel < 5.0) {
          bonds.add(DipoleBinding(i, j, dist));
        }
      }
    }
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
    // 軟化パラメータを小さくして近距離の力を強める (1.0 -> 0.1)
    final r2 = rVec.dx * rVec.dx + rVec.dy * rVec.dy + 0.1;
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
    const double h = 0.2; // 差分間隔を狭めて精度向上
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
               
    // 力をさらにスケーリング (2.0倍)
    return Offset(fx, fy) * 2.0;
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
    if (visualizationMode == 2) return; // Radiationモードでは波動方程式がgrid.uを管理する

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
    _dragCurrent = pos;
    _placing = ElectricDipole(
      pos: pos,
      vel: Offset.zero,
      angle: 0.0,
      angularVel: initialAngularVel,
      separation: separation,
    );
  }

  @override
  void onTouchMove(Grid grid, Offset pos) {
    _dragCurrent = pos;
    if (_placing != null && _dragStart != null) {
      final delta = pos - _dragStart!;
      // 速度スケールを GravityRule に合わせつつ、少し強めに (0.004 -> 0.1)
      _placing!.vel = delta * 0.1;
      // 角度をドラッグ方向に同期
      if (delta.distance > 0.1) {
        _placing!.angle = math.atan2(delta.dy, delta.dx);
      }
    }
  }

  @override
  void onTouchEnd(Grid grid, Offset pos) {
    if (_placing != null) {
      dipoles.add(_placing!);
      if (dipoles.length > 8) dipoles.removeAt(0); // 最大数を少し増やす
      _placing = null;
      _dragStart = null;
      _dragCurrent = null;
    }
  }
}
