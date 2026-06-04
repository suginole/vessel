import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart'; // ← PathFillType はここに含まれる
import '../game/game_controller.dart';
import '../game/boundary.dart';
import '../rules/gravity_rule.dart';
import '../rules/field_rule.dart';


class FieldPainter extends CustomPainter {
  final GameController controller;
  final ui.Image? fieldImage;

  FieldPainter(this.controller, this.fieldImage);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width  / kW;
    final sy = size.height / kH;

    // 1. フィールド画像
    if (fieldImage != null) {
      final src = Rect.fromLTWH(0, 0, kW.toDouble(), kH.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(fieldImage!, src, dst, Paint());
    }

    // 2. 多角形外側を暗転オーバーレイ
    final vs = controller.boundary.vertices;
    final path = Path()..moveTo(vs[0].dx * sx, vs[0].dy * sy);
    for (int i = 1; i < vs.length; i++) {
      path.lineTo(vs[i].dx * sx, vs[i].dy * sy);
    }
    path.close();


    // 3. 多角形の辺（グロー風）
    for (int w = 3; w >= 1; w--) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Color(0xFF00C8FF).withOpacity(0.08 * (4 - w))
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 2.0,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00C8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 4. 頂点ハンドル
    final inner = Paint()..color = const Color(0xFF050810);
    final outer = Paint()..color = const Color(0xFF00C8FF);
    for (final v in vs) {
      final c = Offset(v.dx * sx, v.dy * sy);
      canvas.drawCircle(c, 7, outer);
      canvas.drawCircle(c, 4, inner);
    }

    if (controller.rule is GravityRule) {
      _drawGravity(canvas, size, controller.rule as GravityRule);
    }
  }

  // paint()の末尾に追加
  void _drawGravity(Canvas canvas, Size size, GravityRule rule) {
    final sx = size.width  / kW;
    final sy = size.height / kH;

    // 軌跡
    final trailPaint = Paint()
      ..color      = Colors.greenAccent.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke;
    for (int i = 0; i < rule.trails.length; i++) {
      final t = rule.trails[i];
      canvas.drawCircle(Offset(t.dx*sx, t.dy*sy), 0.8, trailPaint);
    }

    // 天体
    for (int i = 0; i < rule.bodies.length; i++) {
      final b = rule.bodies[i];
      final c = Offset(b.pos.dx*sx, b.pos.dy*sy);
      final r = (b.mass * 6).clamp(4.0, 16.0);
      canvas.drawCircle(c, r + 2,
          Paint()..color = Colors.white.withOpacity(0.2));
      canvas.drawCircle(c, r,
          Paint()..color = [Colors.orangeAccent,
              Colors.cyanAccent, Colors.pinkAccent][i % 3]);
    }

    // 配置中の天体＋初速矢印
    if (rule.placing != null && rule.dragStart != null) {
      final p  = rule.placing!;
      final c  = Offset(p.pos.dx*sx, p.pos.dy*sy);
      final tip = Offset(
        (p.pos.dx + p.vel.dx)*sx,
        (p.pos.dy + p.vel.dy)*sy,
      );
      canvas.drawCircle(c, 8,
          Paint()..color = Colors.white.withOpacity(0.6));
      canvas.drawLine(c, tip,
          Paint()..color = Colors.white..strokeWidth = 2);
      // 矢印先端
      canvas.drawCircle(tip, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(FieldPainter old) => true;
}

Future<ui.Image> gridToImage(GameController c) async {
  final pixels = Uint8List(kW * kH * 4);
  final u    = c.grid.u;
  final mask = c.grid.mask;

  for (int i = 0; i < kW * kH; i++) {
    final m = mask[i];
    if (m == 0.0) {
      // 境界外：完全透明
      pixels[i*4+0] = 0;
      pixels[i*4+1] = 0;
      pixels[i*4+2] = 0;
      pixels[i*4+3] = 0;  // ← alpha=0
      continue;
    }

    final v = u[i].clamp(-1.0, 1.0);

    int r, g, b;
    if (v >= 0) {
      // 0→+1 : 白→青
      final t = v;
      r = (255 * (1.0 - t)).toInt().clamp(0, 255);
      g = (255 * (1.0 - t)).toInt().clamp(0, 255);
      b = 255;
    } else {
      // 0→-1 : 白→赤
      final t = -v;
      r = 255;
      g = (255 * (1.0 - t)).toInt().clamp(0, 255);
      b = (255 * (1.0 - t)).toInt().clamp(0, 255);
    }

    // 境界近傍はmaskで輝度を落とす
    pixels[i*4+0] = (r * m).toInt();
    pixels[i*4+1] = (g * m).toInt();
    pixels[i*4+2] = (b * m).toInt();
    pixels[i*4+3] = 255;
  }

  final comp = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, kW, kH, ui.PixelFormat.rgba8888, comp.complete);
  return comp.future;


  
}

