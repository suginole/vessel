import 'package:flutter/material.dart';
import '../game/game_controller.dart';
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

enum PanelMode { closed, standard, full }

const _ruleOptions = ['wave', 'gravity', 'heat', 'gray-scott', 'bz', 'life', 'arc', 'electric', 'dipole'];

class ControlPanel extends StatefulWidget {
  final GameController controller;
  final VoidCallback onRebuild;
  final VoidCallback? onBack;

  const ControlPanel({
    super.key,
    required this.controller,
    required this.onRebuild,
    this.onBack,
  });

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  int _n = 6;
  PanelMode _mode = PanelMode.standard;

  FieldRule _buildRule(String name) {
    switch (name) {
      case 'wave': return WaveRule();
      case 'gravity': return GravityRule();
      case 'heat': return HeatRule();
      case 'gray-scott': return GrayScottRule();
      case 'bz': return BZRule();
      case 'life': return LifeRule();
      case 'arc': return ArcRule();
      case 'electric': return ElectricRule();
      case 'dipole': return DipoleRule();
      default: return WaveRule();
    }
  }

  void _restart([String? ruleName]) {
    final name = ruleName ?? _currentRuleName();
    final rule = _buildRule(name);
    widget.controller.restart(_n, rule);
    
    if (rule is GravityRule) {
      final newG = 0.00002 + (0.01 - 0.00002) * (_n - 3) / (16 - 3);
      widget.controller.setParam('G', newG);
    }
    
    widget.onRebuild();
  }

  String _currentRuleName() {
    final r = widget.controller.rule;
    if (r is WaveRule) return 'wave';
    if (r is GravityRule) return 'gravity';
    if (r is HeatRule) return 'heat';
    if (r is GrayScottRule) return 'gray-scott';
    if (r is BZRule) return 'bz';
    if (r is LifeRule) return 'life';
    if (r is ArcRule) return 'arc';
    if (r is ElectricRule) return 'electric';
    if (r is DipoleRule) return 'dipole';
    return 'wave';
  }

  void _cycleMode() {
    setState(() {
      if (_mode == PanelMode.closed) {
        _mode = PanelMode.standard;
      } else if (_mode == PanelMode.standard) {
        _mode = PanelMode.full;
      } else {
        _mode = PanelMode.closed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.controller.rule;
    final params = rule.params;
    final ruleName = _currentRuleName();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A12),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2A3A), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Row (Always Visible) ──
          Row(
            children: [
              if (widget.onBack != null) ...[
                _IconBtn(
                  icon: Icons.arrow_back,
                  onTap: widget.onBack!,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 32,
                ),
                const SizedBox(width: 12),
              ],
              _label('RULE'),
              const SizedBox(width: 8),
              _RuleDropdown(
                value: ruleName,
                options: _ruleOptions,
                onChanged: (v) => _restart(v),
              ),
              const Spacer(),
              _IconBtn(
                icon: Icons.restart_alt,
                onTap: () => _restart(),
                color: const Color(0xFFFF3D6B),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: _mode == PanelMode.closed 
                    ? Icons.expand_more 
                    : (_mode == PanelMode.standard ? Icons.expand_less : (widget.controller.grid.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen)),
                onTap: () {
                  if (_mode == PanelMode.full) {
                    widget.controller.toggleFullscreen();
                    widget.onRebuild();
                  } else {
                    _cycleMode();
                  }
                },
                color: const Color(0xFF00C8FF),
              ),
            ],
          ),

          if (_mode != PanelMode.closed) ...[
            const SizedBox(height: 8),
            // ── N Slider (Standard & Full) ──
            Row(
              children: [
                _label('N'),
                const SizedBox(width: 6),
                _nBadge(),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSlider(
                    value: _n.toDouble(),
                    min: 3, max: 16,
                    divisions: 13,
                    onChanged: (v) {
                      setState(() {
                        _n = v.toInt();
                        if (ruleName == 'gravity') {
                          final newG = 0.00002 + (0.01 - 0.00002) * (_n - 3) / (16 - 3);
                          widget.controller.setParam('G', newG);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ],

          if (_mode == PanelMode.full && params.isNotEmpty) ...[
            const SizedBox(height: 12),
            // ── Dynamic Params (Full Only) ──
            ...params.where((p) => !(ruleName == 'gravity' && p.key == 'G')).map((p) {
              final isChargeParam = ruleName == 'electric' && p.key == 'charge';
              final isDipoleView = ruleName == 'dipole' && p.key == 'view';
              
              final chargeValue = isChargeParam ? (p.getCurrentValue?.call() ?? p.defaultValue).toInt() : 0;
              final chargeLabel = isChargeParam
                  ? (chargeValue == 0 ? 'Monopole' : (chargeValue > 0 ? '+$chargeValue' : '$chargeValue'))
                  : '';
              
              final viewValue = isDipoleView ? (p.getCurrentValue?.call() ?? p.defaultValue).toInt() : 0;
              final viewLabel = isDipoleView ? FieldView.values[viewValue].name.toUpperCase() : '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 80, child: _label(p.label.toUpperCase())),
                        Expanded(
                          child: _buildSlider(
                            value: p.getCurrentValue?.call() ?? p.defaultValue,
                            min: p.min, max: p.max,
                            divisions: p.divisions,
                            activeColor: const Color(0xFF80C8FF),
                            onChanged: (v) {
                              widget.controller.setParam(p.key, v);
                              widget.onRebuild();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (isChargeParam) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _label('-5'),
                          _label('0'),
                          _label('+5'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chargeLabel,
                        style: TextStyle(
                          color: chargeValue == 0
                              ? Colors.white
                              : (chargeValue > 0 ? const Color(0xFFFF3D6B) : const Color(0xFF00C8FF)),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                    if (isDipoleView) ...[
                      const SizedBox(height: 4),
                      Text(
                        viewLabel,
                        style: const TextStyle(
                          color: Color(0xFF00FFB2),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
          
          if (_mode != PanelMode.closed && ruleName == 'gravity') ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _label('AUTO-SYNCED G: '),
                Text(
                  (widget.controller.rule is GravityRule 
                      ? (widget.controller.rule as GravityRule).g 
                      : 1.0).toStringAsFixed(5),
                  style: const TextStyle(
                    color: Color(0xFF00FFB2), 
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    Color activeColor = const Color(0xFF00C8FF),
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: activeColor,
        inactiveTrackColor: const Color(0xFF1A2A3A),
        thumbColor: activeColor,
        overlayColor: activeColor.withValues(alpha: 0.2),
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      child: Slider(
        value: value,
        min: min, max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      color: Color(0xFF4A6A8A),
      fontSize: 10,
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _nBadge() => Container(
    width: 28,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF00C8FF), width: 1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text('$_n', style: const TextStyle(color: Color(0xFF00C8FF), fontSize: 13, fontWeight: FontWeight.bold)),
  );
}

class _RuleDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _RuleDropdown({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1E3A5A)),
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFF0D1A2A),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF0D1A2A),
          style: const TextStyle(color: Color(0xFF80C8FF), fontSize: 12, letterSpacing: 1.5),
          isDense: true,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase()))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _IconBtn({required this.icon, required this.onTap, required this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.08),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
