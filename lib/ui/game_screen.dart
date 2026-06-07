import 'dart:ui' as ui;
import 'dart:math' as math;
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

  Offset _toGrid(Offset local) {
    final isFull = _ctrl.grid.isFullscreen;
    if (!isFull) {
      return Offset(
        local.dx / _canvasSize.width  * kW,
        local.dy / _canvasSize.height * kH,
      );
    } else {
      final side = math.min(_canvasSize.width, _canvasSize.height);
      final dx = (_canvasSize.width - side) / 2;
      final dy = (_canvasSize.height - side) / 2;
      return Offset(
        (local.dx - dx) / side * kW,
        (local.dy - dy) / side * kH,
      );
    }
  }

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
            child: LayoutBuilder(builder: (ctx, constraints) {
              final isFull = _ctrl.grid.isFullscreen;
              final side = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              
              _canvasSize = isFull 
                  ? Size(constraints.maxWidth, constraints.maxHeight)
                  : Size(side, side);

              return Column(
                children: [
                  if (!isFull)
                    SafeArea(
                      bottom: false,
                      child: ControlPanel(
                        controller: _ctrl,
                        onRebuild: () => setState(() {}),
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: _canvasSize.width,
                        height: _canvasSize.height,
                        child: GestureDetector(
                          onPanStart:  (d) => _ctrl.onTouchStart(_toGrid(d.localPosition)),
                          onPanUpdate: (d) => _ctrl.onTouchMove(_toGrid(d.localPosition)),
                          onPanEnd: (_) => _ctrl.onTouchEnd(),
                          child: CustomPaint(
                            painter: FieldPainter(controller: _ctrl, gridImage: _img),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          
          // Floating Mode Toggle for Fullscreen
          if (_ctrl.grid.isFullscreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: FloatingActionButton.small(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white70,
                onPressed: () {
                  setState(() {
                    _ctrl.grid.isFullscreen = false;
                  });
                },
                child: const Icon(Icons.fullscreen_exit),
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
