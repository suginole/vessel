import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart'; // Webビルドエラー回避のため一時コメントアウト
import '../rules/field_rule.dart';
import '../rules/wave_rule.dart';
import '../rules/gravity_rule.dart';
import '../rules/heat_rule.dart';
import '../rules/gray_scott_rule.dart';
import '../rules/bz_rule.dart';
import '../rules/life_rule.dart';
import '../rules/arc_rule.dart';
import '../rules/electric_rule.dart';
import 'game_screen.dart';

// Global Audio Player for persistent BGM
// final AudioPlayer _bgmPlayer = AudioPlayer();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // _startBgm();
  }

  // Future<void> _startBgm() async {
  //   await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  //   await _bgmPlayer.play(AssetSource('audio/piano_loop.mp3'));
  //   await _bgmPlayer.setVolume(0.4);
  // }

  void _launch(BuildContext context, FieldRule rule) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (c) => GameScreen(initialRule: rule)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              const Color(0xFF101020),
              const Color(0xFF05050A),
            ],
          ),
        ),
        child: CustomScrollView(
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
                      'MULTIMODAL PHYSICS SIMULATOR',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _section('CLASSICAL PHYSICS', [
              _item(context, 'WAVE', 'Wave propagation & interference', const Color(0xFF00C8FF), WaveRule(), Icons.waves_rounded),
              _item(context, 'GRAVITY', 'Orbital mechanics & N-body', const Color(0xFFFF3D6B), GravityRule(), Icons.public_rounded),
              _item(context, 'ELECTRIC', 'Coulomb force & Annihilation', const Color(0xFF80C8FF), ElectricRule(), Icons.flash_on_rounded),
              _item(context, 'HEAT', 'Thermal diffusion & Entropy', const Color(0xFFFF8A00), HeatRule(), Icons.thermostat_rounded),
            ]),
            _section('CHEMICAL & BIOLOGICAL', [
              _item(context, 'GRAY-SCOTT', 'Reaction-diffusion patterns', const Color(0xFF00FFB2), GrayScottRule(), Icons.biotech_rounded),
              _item(context, 'BZ REACTION', 'Oscillatory wave patterns', const Color(0xFFFF00F5), BZRule(), Icons.opacity_rounded),
            ]),
            _section('DISCRETE SYSTEMS', [
              _item(context, 'LIFE', "Conway's Game of Life", const Color(0xFFFFFFFF), LifeRule(), Icons.grid_view_rounded),
              _item(context, 'ARC', 'Dielectric breakdown model', const Color(0xFF7000FF), ArcRule(), Icons.electric_bolt_rounded),
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
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
