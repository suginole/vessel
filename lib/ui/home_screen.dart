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
import 'game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Stack(
        children: [
          // 背景装飾（大理石風のテクスチャがあればここに追加）
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'VESSEL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'NATURAL PHENOMENA SIMULATOR',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _RuleCard(
                        title: 'WAVE',
                        desc: 'Fluid ripple simulation',
                        icon: Icons.waves,
                        color: const Color(0xFF00C8FF),
                        onTap: () => _launch(context, WaveRule()),
                      ),
                      _RuleCard(
                        title: 'GRAVITY',
                        desc: 'Celestial mechanics & merging',
                        icon: Icons.blur_on,
                        color: const Color(0xFF00FFB2),
                        onTap: () => _launch(context, GravityRule()),
                      ),
                      _RuleCard(
                        title: 'HEAT',
                        desc: 'Thermal diffusion',
                        icon: Icons.whatshot,
                        color: const Color(0xFFFF3D6B),
                        onTap: () => _launch(context, HeatRule()),
                      ),
                      _RuleCard(
                        title: 'GRAY-SCOTT',
                        desc: 'Reaction-diffusion patterns',
                        icon: Icons.grain,
                        color: const Color(0xFF80FF00),
                        onTap: () => _launch(context, GrayScottRule()),
                      ),
                      _RuleCard(
                        title: 'BZ REACTION',
                        desc: 'Oscillating chemical waves',
                        icon: Icons.cyclone,
                        color: const Color(0xFFFFD600),
                        onTap: () => _launch(context, BZRule()),
                      ),
                      _RuleCard(
                        title: 'LIFE',
                        desc: "Conway's Game of Life",
                        icon: Icons.grid_view,
                        color: Colors.white,
                        onTap: () => _launch(context, LifeRule()),
                      ),
                      _RuleCard(
                        title: 'ARC',
                        desc: 'Dielectric breakdown',
                        icon: Icons.bolt,
                        color: const Color(0xFF7B61FF),
                        onTap: () => _launch(context, ArcRule()),
                      ),
                      _RuleCard(
                        title: 'ELECTRIC',
                        desc: 'Coulomb interactions',
                        icon: Icons.electrical_services,
                        color: const Color(0xFFFFAA00),
                        onTap: () => _launch(context, ElectricRule()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launch(BuildContext context, FieldRule rule) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(initialRule: rule)),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RuleCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
