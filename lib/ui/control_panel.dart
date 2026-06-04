import 'package:flutter/material.dart';
import '../game/game_controller.dart';
import '../rules/field_rule.dart';
import '../rules/wave_rule.dart';
import '../rules/gravity_rule.dart';

// 利用可能なルール一覧
const _ruleOptions = ['wave', 'gravity']; // 後で拡張

class ControlPanel extends StatefulWidget {
  final GameController controller;
  final VoidCallback onRebuild;

  const ControlPanel({
    super.key,
    required this.controller,
    required this.onRebuild,
  });

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  int    _n         = 6;
  String _selected  = 'wave';

  FieldRule _buildRule() {
    switch (_selected) {
      case 'wave':    return WaveRule();
      case 'gravity': return GravityRule();
      default:        return WaveRule();
    }
  }

  void _restart() {
    widget.controller.restart(_n, _buildRule());
    widget.onRebuild();
  }

  void _clean() {
    widget.controller.clean();
    widget.onRebuild();
  }

  void _regularize() {
    widget.controller.boundary.regularize(kW / 2, kH / 2, kW * 0.38);
    widget.controller.boundary.dirty = true;
    widget.onRebuild();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A12),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2A3A), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: スライダー ──
          Row(
            children: [
              _label('N'),
              const SizedBox(width: 6),
              _nBadge(),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor:   const Color(0xFF00C8FF),
                    inactiveTrackColor: const Color(0xFF1A2A3A),
                    thumbColor:         const Color(0xFF00C8FF),
                    overlayColor:       const Color(0x2200C8FF),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _n.toDouble(),
                    min: 3, max: 16,
                    divisions: 13,
                    onChanged: (v) => setState(() => _n = v.toInt()),
                  ),
                ),
              ),
            ],
          ),

          // ── Row 2: ルール選択 + ボタン群 ──
          Row(
            children: [
              // ルール選択ドロップダウン
              _label('RULE'),
              const SizedBox(width: 8),
              _RuleDropdown(
                value:    _selected,
                options:  _ruleOptions,
                onChanged: (v) => setState(() => _selected = v),
              ),
              const SizedBox(width: 10),
              const Spacer(),

              // 正多角形化
              _IconBtn(
                icon:    Icons.change_history,
                tooltip: '正多角形化',
                onTap:   _regularize,
                color:   const Color(0xFF00FFB2),
              ),
              const SizedBox(width: 6),

              // お掃除
              _IconBtn(
                icon:    Icons.cleaning_services,
                tooltip: 'フィールド初期化',
                onTap:   _clean,
                color:   const Color(0xFFFFD600),
              ),
              const SizedBox(width: 6),

              // 再起動
              _IconBtn(
                icon:    Icons.restart_alt,
                tooltip: '再起動',
                onTap:   _restart,
                color:   const Color(0xFFFF3D6B),
              ),
            ],
          ),
        ],
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
    child: Text(
      '$_n',
      style: const TextStyle(
        color: Color(0xFF00C8FF),
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// ── ドロップダウン ──────────────────────────────
class _RuleDropdown extends StatelessWidget {
  final String         value;
  final List<String>   options;
  final ValueChanged<String> onChanged;

  const _RuleDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

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
          style: const TextStyle(
            color: Color(0xFF80C8FF),
            fontSize: 12,
            letterSpacing: 1.5,
          ),
          isDense: true,
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o.toUpperCase()),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ── アイコンボタン ──────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;
  final Color    color;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(8),
            color: color.withOpacity(0.08),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}