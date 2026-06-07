import 'package:flutter/material.dart';
import '../rules/field_rule.dart';
import '../rules/wave_rule.dart';
import '../rules/gravity_rule.dart';
import '../rules/heat_rule.dart';
import '../rules/gray_scott_rule.dart';
import '../rules/bz_rule.dart';
import '../rules/life_rule.dart';
import '../rules/arc_rule.dart';
import '../rules/electric_rule.dart';
import '../rules/dipole_rule.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class Ripple {
  final Offset position;
  final DateTime startTime;
  Ripple(this.position, this.startTime);
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final List<Ripple> _ripples = [];
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final now = DateTime.now();
      setState(() {
        _ripples.removeWhere((r) => now.difference(r.startTime).inMilliseconds > 1000);
      });
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _addRipple(Offset position) {
    setState(() {
      _ripples.add(Ripple(position, DateTime.now()));
    });
  }

  void _launch(BuildContext context, FieldRule rule) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (c) => GameScreen(initialRule: rule)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';

    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: GestureDetector(
        onTapDown: (details) => _addRipple(details.localPosition),
        behavior: HitTestBehavior.translucent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                Color(0xFF101020),
                Color(0xFF05050A),
              ],
            ),
          ),
          child: Stack(
            children: [
              CustomPaint(
                painter: RipplePainter(_ripples),
                size: Size.infinite,
              ),
              CustomScrollView(
                slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VESSEL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(color: Colors.cyanAccent.withValues(alpha: 0.5), blurRadius: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isJa ? '多様な物理シミュレーター' : 'MULTIMODAL PHYSICS SIMULATOR',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        letterSpacing: isJa ? 2 : 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _section(isJa ? '古典物理' : 'CLASSICAL PHYSICS', [
              _item(context, 'WAVE', isJa ? '波の伝播と干渉' : 'Wave propagation & interference', const Color(0xFF00C8FF), WaveRule(), Icons.waves_rounded),
              _item(context, 'GRAVITY', isJa ? '軌道力学・多体問題' : 'Orbital mechanics & N-body', const Color(0xFFFF3D6B), GravityRule(), Icons.public_rounded),
              _item(context, 'ELECTRIC', isJa ? 'クーロン力と対消滅' : 'Coulomb force & Annihilation', const Color(0xFF80C8FF), ElectricRule(), Icons.flash_on_rounded),
              _item(context, 'DIPOLE', isJa ? '電気双極子と電磁場' : 'Dipole & Electromagnetic Field', const Color(0xFF00FFB2), DipoleRule(), Icons.settings_input_component_rounded),
              _item(context, 'HEAT', isJa ? '熱拡散とエントロピー' : 'Thermal diffusion & Entropy', const Color(0xFFFF8A00), HeatRule(), Icons.thermostat_rounded),
            ]),
            _section(isJa ? '化学・生物' : 'CHEMICAL & BIOLOGICAL', [
              _item(context, 'GRAY-SCOTT', isJa ? '反応拡散パターン' : 'Reaction-diffusion patterns', const Color(0xFF00FFB2), GrayScottRule(), Icons.biotech_rounded),
              _item(context, 'BZ REACTION', isJa ? '振動波パターン' : 'Oscillatory wave patterns', const Color(0xFFFF00F5), BZRule(), Icons.opacity_rounded),
            ]),
            _section(isJa ? '離散系' : 'DISCRETE SYSTEMS', [
              _item(context, 'LIFE', isJa ? 'コンウェイのライフゲーム' : "Conway's Game of Life", const Color(0xFFFFFFFF), LifeRule(), Icons.grid_view_rounded),
              _item(context, 'ARC', isJa ? '絶縁破壊モデル' : 'Dielectric breakdown model', const Color(0xFF7000FF), ArcRule(), Icons.electric_bolt_rounded),
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> items) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: items,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String name, String desc, Color color, FieldRule rule, IconData icon) {
    return GestureDetector(
      onTap: () => _launch(context, rule),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 160,
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final List<Ripple> ripples;
  RipplePainter(this.ripples);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final ripple in ripples) {
      final elapsed = now.difference(ripple.startTime).inMilliseconds;
      final t = (elapsed / 1000).clamp(0.0, 1.0);
      
      final radius = t * 150.0;
      final opacity = 1.0 - t;
      
      paint.color = Colors.white.withValues(alpha: opacity * 0.3);
      canvas.drawCircle(ripple.position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}
