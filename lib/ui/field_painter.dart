import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/game_controller.dart';
import '../rules/gravity_rule.dart';
import '../rules/electric_rule.dart';

class FieldPainter extends CustomPainter {
  final GameController controller;
  final ui.Image? gridImage;

  FieldPainter({required this.controller, this.gridImage});

  @override
  void paint(Canvas canvas, Size size) {
    if (gridImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: gridImage!,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium, // アンチエイリアスを効かせる
      );
    }

    // 境界線の描画（ジャギーを隠すために少し太めで滑らかな線を重ねる）
    final boundaryPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 // 少し太く
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.5); // わずかにぼかして馴染ませる

    final path = Path();
    final vertices = controller.boundary.vertices;
    if (vertices.isNotEmpty) {
      final sx = size.width / kW;
      final sy = size.height / kH;
      path.moveTo(vertices[0].dx * sx, vertices[0].dy * sy);
      for (int i = 1; i < vertices.length; i++) {
        path.lineTo(vertices[i].dx * sx, vertices[i].dy * sy);
      }
      path.close();
      canvas.drawPath(path, boundaryPaint);

      // 頂点ハンドル
      for (var v in vertices) {
        final pos = Offset(v.dx * sx, v.dy * sy);
        // 外光
        canvas.drawCircle(
          pos,
          8.0,
          Paint()..color = Colors.white.withValues(alpha: 0.1),
        );
        // 中心
        canvas.drawCircle(
          pos,
          5.0,
          Paint()..color = Colors.white.withValues(alpha: 0.6),
        );
      }
    }

    // ルール固有の描画
    if (controller.rule is GravityRule) {
      _drawGravity(canvas, size, controller.rule as GravityRule);
    } else if (controller.rule is ElectricRule) {
      _drawElectric(canvas, size, controller.rule as ElectricRule);
    }
  }

  void _drawElectric(Canvas canvas, Size size, ElectricRule rule) {
    final sx = size.width / kW;
    final sy = size.height / kH;
    final paint = Paint();

    for (final b in rule.bodies) {
      final pos = Offset(b.pos.dx * sx, b.pos.dy * sy);
      final radius = (b.charge.abs() * 2.0 + 4.0).clamp(4.0, 20.0);
      final color = b.charge > 0 ? const Color(0xFFFF3D6B) : const Color(0xFF00C8FF);
      
      // Outer Glow
      canvas.drawCircle(pos, radius + 2, paint..color = color.withValues(alpha: 0.3));
      // Main Body
      canvas.drawCircle(pos, radius, paint..color = color);
      // Core
      canvas.drawCircle(pos, radius * 0.4, paint..color = Colors.white);
    }
  }

  void _drawGravity(Canvas canvas, Size size, GravityRule rule) {
    final sx = size.width / kW;
    final sy = size.height / kH;

    // 軌跡
    final trailPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < rule.trails.length; i++) {
      final t = rule.trails[i];
      canvas.drawCircle(Offset(t.dx * sx, t.dy * sy), 0.8, trailPaint);
    }

    // 天体
    for (int i = 0; i < rule.bodies.length; i++) {
      final b = rule.bodies[i];
      final c = Offset(b.pos.dx * sx, b.pos.dy * sy);
      final r = (b.mass * 4.0 + 4.0).clamp(4.0, 40.0);
      canvas.drawCircle(c, r + 2, Paint()..color = Colors.white.withValues(alpha: 0.2));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = [
            Colors.orangeAccent,
            Colors.cyanAccent,
            Colors.pinkAccent,
          ][i % 3],
      );
    }

    // 配置中の天体＋初速矢印
    if (rule.placing != null && rule.dragStart != null) {
      final p = rule.placing!;
      final c = Offset(p.pos.dx * sx, p.pos.dy * sy);
      const arrowScale = 50.0; 
      final tip = Offset(
        (p.pos.dx + p.vel.dx * arrowScale) * sx,
        (p.pos.dy + p.vel.dy * arrowScale) * sy,
      );
      
      canvas.drawCircle(c, 8, Paint()..color = Colors.white.withValues(alpha: 0.6));
      canvas.drawLine(c, tip, Paint()..color = Colors.white.withValues(alpha: 0.8)..strokeWidth = 2.0);
      canvas.drawCircle(tip, 3, Paint()..color = Colors.white);
      canvas.drawLine(
        tip,
        Offset((p.pos.dx + p.vel.dx * arrowScale * 2) * sx, (p.pos.dy + p.vel.dy * arrowScale * 2) * sy),
        Paint()..color = Colors.white.withValues(alpha: 0.2)..strokeWidth = 1.0..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FieldPainter oldDelegate) => true;
}

Future<ui.Image> gridToImage(GameController c) async {
  final pixels = Uint8List(kW * kH * 4);
  final u = c.grid.u;
  final mask = c.grid.mask;
  final config = c.rule.renderConfig;

  for (int i = 0; i < kW * kH; i++) {
    final m = mask[i];
    
    // 境界の滑らかさ向上のため、maskの値(0.0~1.0)をアルファ値として利用
    // ただし、完全な外側(0.0)はスキップ
    if (m <= 0.0) {
      pixels[i * 4 + 3] = 0;
      continue;
    }

    pixels[i * 4 + 0] = config.pixel(u[i], m, 0);
    pixels[i * 4 + 1] = config.pixel(u[i], m, 1);
    pixels[i * 4 + 2] = config.pixel(u[i], m, 2);
    // maskの値をそのままアルファ値(0~255)にマッピングしてアンチエイリアス効果を出す
    pixels[i * 4 + 3] = (m * 255).toInt();
  }

  final comp = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, kW, kH, ui.PixelFormat.rgba8888, comp.complete);
  return comp.future;
}
