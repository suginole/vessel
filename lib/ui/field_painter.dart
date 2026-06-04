import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/game_controller.dart';
import '../rules/field_rule.dart';
import '../rules/gravity_rule.dart';

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
        filterQuality: FilterQuality.low,
      );
    }

    // 境界線の描画
    final boundaryPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

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
        canvas.drawCircle(
          Offset(v.dx * sx, v.dy * sy),
          6.0,
          Paint()..color = Colors.white.withOpacity(0.5),
        );
      }
    }

    // ルール固有の描画
    if (controller.rule is GravityRule) {
      _drawGravity(canvas, size, controller.rule as GravityRule);
    }
  }

  void _drawGravity(Canvas canvas, Size size, GravityRule rule) {
    final sx = size.width / kW;
    final sy = size.height / kH;

    // 軌跡
    final trailPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
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
      // 質量に応じてサイズを大きくする（上限を緩和）
      final r = (b.mass * 4.0 + 4.0).clamp(4.0, 40.0);
      canvas.drawCircle(c, r + 2, Paint()..color = Colors.white.withOpacity(0.2));
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
      final tip = Offset(
        (p.pos.dx + p.vel.dx) * sx,
        (p.pos.dy + p.vel.dy) * sy,
      );
      canvas.drawCircle(c, 8, Paint()..color = Colors.white.withOpacity(0.6));
      canvas.drawLine(c, tip, Paint()..color = Colors.white..strokeWidth = 2);
      canvas.drawCircle(tip, 3, Paint()..color = Colors.white);
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
    if (m == 0.0) {
      pixels[i * 4 + 0] = 0;
      pixels[i * 4 + 1] = 0;
      pixels[i * 4 + 2] = 0;
      pixels[i * 4 + 3] = 0;
      continue;
    }

    pixels[i * 4 + 0] = config.pixel(u[i], m, 0);
    pixels[i * 4 + 1] = config.pixel(u[i], m, 1);
    pixels[i * 4 + 2] = config.pixel(u[i], m, 2);
    pixels[i * 4 + 3] = 255;
  }

  final comp = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, kW, kH, ui.PixelFormat.rgba8888, comp.complete);
  return comp.future;
}
