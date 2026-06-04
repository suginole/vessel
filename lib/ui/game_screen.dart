import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game/game_controller.dart';
import 'field_painter.dart';
import 'control_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameController _ctrl;
  late Ticker _ticker;
  Duration _last = Duration.zero;
  ui.Image? _img;
  Size _canvasSize = const Size(256, 256);

  @override
  void initState() {
    super.initState();
    _ctrl = GameController();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) async {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _ctrl.update(dt);
    final img = await gridToImage(_ctrl);
    if (mounted) setState(() => _img = img);
  }

  Offset _toGrid(Offset local) => Offset(
    local.dx / _canvasSize.width  * kW,
    local.dy / _canvasSize.height * kH,
  );

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景画像
          Image.asset(
            'assets/images/white-marble1.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // コンテンツ全体（背景の上に重ねる）
          Positioned.fill(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: ControlPanel(
                    controller: _ctrl,
                    onRebuild: () => setState(() {}),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final side = constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;
                    _canvasSize = Size(side, side);

                    return Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: GestureDetector(
                          onPanStart:  (d) => _ctrl.onTouchStart(_toGrid(d.localPosition)),
                          onPanUpdate: (d) => _ctrl.onTouchMove(_toGrid(d.localPosition)),
                          onPanEnd: (_) => _ctrl.onTouchEnd(),
                          child: CustomPaint(
                            painter: FieldPainter(controller: _ctrl, gridImage: _img),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}