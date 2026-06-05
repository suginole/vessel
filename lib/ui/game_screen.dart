import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game/game_controller.dart';
import '../rules/field_rule.dart';
import 'field_painter.dart';
import 'control_panel.dart';

class GameScreen extends StatefulWidget {
  final FieldRule? initialRule;
  const GameScreen({super.key, this.initialRule});

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
    if (widget.initialRule != null) {
      _ctrl.restart(6, widget.initialRule!);
    }
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
          // Background Marble
          Positioned.fill(
            child: Image.asset(
              'assets/images/white-marble1.jpg',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.15),
            ),
          ),
          
          // Content
          Positioned.fill(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: ControlPanel(
                    controller: _ctrl,
                    onRebuild: () => setState(() {}),
                    onBack: () => Navigator.of(context).pop(),
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
          
          // Floating Home Button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF1A1A2A),
              foregroundColor: Colors.white70,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(Icons.home_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
