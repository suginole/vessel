import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../game/game_controller.dart';
import '../game/grid.dart';
import '../game/boundary.dart';
import '../rules/field_rule.dart';
import '../rules/gravity_rule.dart';
import '../rules/electric_rule.dart';
import '../rules/dipole_rule.dart';
import 'dart:math' as math;

// グリッドデータを画像に変換するユーティリティ関数
Future<ui.Image> gridToImage(GameController ctrl) async {
  final grid = ctrl.grid;
  final config = ctrl.rule.renderConfig;
  
  final pixels = Uint8List(grid.w * grid.h * 4);
  for (int i = 0; i < grid.w * grid.h; i++) {
    final m = grid.mask[i];
    final u = grid.u[i];
    
    if (m == 0) {
      pixels[i * 4 + 0] = 0;
      pixels[i * 4 + 1] = 0;
      pixels[i * 4 + 2] = 0;
      pixels[i * 4 + 3] = 0;
    } else {
      pixels[i * 4 + 0] = config.pixel(u, m, 0);
      pixels[i * 4 + 1] = config.pixel(u, m, 1);
      pixels[i * 4 + 2] = config.pixel(u, m, 2);
      pixels[i * 4 + 3] = 255;
    }
  }
  
  final descriptor = ui.ImageDescriptor.raw(
    await ui.ImmutableBuffer.fromUint8List(pixels),
    width: grid.w,
    height: grid.h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}

class FieldPainter extends CustomPainter {
  final GameController controller;
  final ui.Image? gridImage;

  FieldPainter({required this.controller, this.gridImage});

  @override
  void paint(Canvas canvas, Size size) {
    // 0. クリップパスの設定
    final sx = size.width / kW;
    final sy = size.height / kH;
    final clipPath = Path();
    final vertices = controller.boundary.vertices;
    if (vertices.isNotEmpty) {
      clipPath.moveTo(vertices[0].dx * sx, vertices[0].dy * sy);
      for (int i = 1; i < vertices.length; i++) {
        clipPath.lineTo(vertices[i].dx * sx, vertices[i].dy * sy);
      }
      clipPath.close();
      canvas.clipPath(clipPath);
    }

    // 1. グリッド背景の描画
    if (gridImage != null) {
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2);
      canvas.drawImageRect(
        gridImage!,
        Rect.fromLTWH(0, 0, gridImage!.width.toDouble(), gridImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }

    // 2. ルール固有のオーバーレイ描画
    if (controller.rule is GravityRule) {
      _drawGravity(canvas, size, controller.rule as GravityRule);
    } else if (controller.rule is ElectricRule) {
      _drawElectric(canvas, size, controller.rule as ElectricRule);
    } else if (controller.rule is DipoleRule) {
      _drawDipole(canvas, size, controller.rule as DipoleRule);
    }

    // 3. 多角形境界の描画
    _drawBoundary(canvas, size, controller.boundary.vertices);
  }

  void _drawDipole(Canvas canvas, Size size, DipoleRule rule) {
    final sx = size.width / kW;
    final sy = size.height / kH;
    final paint = Paint();

    for (var d in rule.dipoles) {
      final pos = Offset(d.pos.dx * sx, d.pos.dy * sy);
      final moment = d.moment;
      final angle = d.angle;
      final sep = d.separation * sx;

      // Draw the dipole body (line connecting charges)
      final p1 = pos + Offset(math.cos(angle), math.sin(angle)) * sep / 2;
      final p2 = pos - Offset(math.cos(angle), math.sin(angle)) * sep / 2;
      
      canvas.drawLine(p1, p2, paint..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 2);
      
      // Positive charge
      canvas.drawCircle(p1, 4, paint..color = const Color(0xFFFF3D6B));
      // Negative charge
      canvas.drawCircle(p2, 4, paint..color = const Color(0xFF00C8FF));
      
      // Moment vector arrow
      final arrowEnd = pos + moment * 2.0 * sx;
      canvas.drawLine(pos, arrowEnd, paint..color = Colors.yellowAccent..strokeWidth = 1);
    }
  }

  void _drawElectric(Canvas canvas, Size size, ElectricRule rule) {
    final sx = size.width / kW;
    final sy = size.height / kH;
    final paint = Paint();
    for (var b in rule.bodies) {
      final pos = Offset(b.pos.dx * sx, b.pos.dy * sy);
      final r = (b.isMonopole ? 2.0 : b.charge.abs()) * 2.0 + 2.0;
      if (b.isMonopole) {
        canvas.drawCircle(pos, r + 2, paint..color = Colors.white.withValues(alpha: 0.3));
        canvas.drawCircle(pos, r, paint..color = Colors.white);
      } else {
        final color = b.charge > 0 ? const Color(0xFFFF3D6B) : const Color(0xFF00C8FF);
        canvas.drawCircle(pos, r + 4, paint..color = color.withValues(alpha: 0.2));
        canvas.drawCircle(pos, r, paint..color = color);
      }
    }
  }

  void _drawGravity(Canvas canvas, Size size, GravityRule rule) {
    final sx = size.width / kW;
    final sy = size.height / kH;
    final paint = Paint();
    for (final b in rule.bodies) {
      final pos = Offset(b.pos.dx * sx, b.pos.dy * sy);
      final r = b.mass * 2.0 + 1.0;
      canvas.drawCircle(pos, r + 4, paint..color = Colors.greenAccent.withValues(alpha: 0.1));
      canvas.drawCircle(pos, r, paint..color = Colors.greenAccent);
      for (int i = 0; i < b.trail.length - 1; i++) {
        final p1 = b.trail[i];
        final p2 = b.trail[i+1];
        canvas.drawLine(
          Offset(p1.dx * sx, p1.dy * sy),
          Offset(p2.dx * sx, p2.dy * sy),
          paint..color = Colors.greenAccent.withValues(alpha: 0.3 * (i / b.trail.length))..strokeWidth = 1.0,
        );
      }
    }
  }

  void _drawDipole(Canvas canvas, Size size, DipoleRule rule) {
    final sx = size.width / kW;
    final sy = size.height / kH;
    final paint = Paint();
    
    // Draw field lines if available
    if (rule.fieldLines != null) {
      for (final line in rule.fieldLines!) {
        for (int i = 0; i < line.length - 1; i++) {
          final p1 = line[i];
          final p2 = line[i + 1];
          canvas.drawLine(
            Offset(p1.dx * sx, p1.dy * sy),
            Offset(p2.dx * sx, p2.dy * sy),
            paint..color = Colors.cyan.withValues(alpha: 0.4)..strokeWidth = 0.5,
          );
        }
      }
    }
    
    // Draw dipoles
    for (final d in rule.dipoles) {
      final pos = Offset(d.pos.dx * sx, d.pos.dy * sy);
      final momentDir = Offset(math.cos(d.angle), math.sin(d.angle));
      final momentEnd = pos + momentDir * (d.separation * sx);
      
      // Draw dipole moment vector
      canvas.drawLine(
        pos,
        momentEnd,
        paint..color = Colors.yellow.withValues(alpha: 0.6)..strokeWidth = 2.0,
      );
      
      // Draw positive charge
      canvas.drawCircle(
        momentEnd,
        3.0,
        paint..color = const Color(0xFFFF3D6B),
      );
      
      // Draw negative charge
      final negEnd = pos - momentDir * (d.separation * sx);
      canvas.drawCircle(
        negEnd,
        3.0,
        paint..color = const Color(0xFF00C8FF),
      );
      
      // Draw center
      canvas.drawCircle(
        pos,
        2.0,
        paint..color = Colors.white,
      );
    }
  }

  void _drawBoundary(Canvas canvas, Size size, List<Offset> vertices) {
    final sx = size.width / kW;
    final sy = size.height / kH;
    final path = Path();
    if (vertices.isNotEmpty) {
      path.moveTo(vertices[0].dx * sx, vertices[0].dy * sy);
      for (int i = 1; i < vertices.length; i++) {
        path.lineTo(vertices[i].dx * sx, vertices[i].dy * sy);
      }
      path.close();
    }
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = 2.0..style = PaintingStyle.stroke);
    for (final v in vertices) {
      canvas.drawCircle(Offset(v.dx * sx, v.dy * sy), 5.0, Paint()..color = Colors.cyanAccent.withValues(alpha: 0.5));
    }
  }

  void _drawDipoleRuleOverlay(Canvas canvas, Size size, DipoleRule rule) {
    if (controller.rule is DipoleRule) {
      _drawDipole(canvas, size, rule);
    }
  }

  @override
  bool shouldRepaint(covariant FieldPainter oldDelegate) => true;
}
