import '../game/grid.dart';
import 'dart:ui';

// ─────────────────────────────────────────
// RuleParam
// ─────────────────────────────────────────
class RuleParam {
  final String key, label;
  final double min, max, defaultValue;
  final int?   divisions;
  
  // 現在の値を取得するためのコールバックを追加
  final double Function()? getCurrentValue;

  const RuleParam({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.divisions,
    this.getCurrentValue,
  });
}

// ─────────────────────────────────────────
// RenderConfig
// ─────────────────────────────────────────
class RenderConfig {
  final int Function(double u, double mask, int channel) pixel;
  const RenderConfig({required this.pixel});

  // 赤-白-青（Wave用）
  static RenderConfig blueRed() => RenderConfig(pixel: (u, m, ch) {
    final v = (u / 3.0).clamp(-1.0, 1.0);
    int r, g, b;
    if (v >= 0) {
      r = (255 * (1.0 - v)).toInt().clamp(0, 255);
      g = (255 * (1.0 - v)).toInt().clamp(0, 255);
      b = 255;
    } else {
      final t = -v;
      r = 255;
      g = (255 * (1.0 - t)).toInt().clamp(0, 255);
      b = (255 * (1.0 - t)).toInt().clamp(0, 255);
    }
    final rgb = [r, g, b];
    return (rgb[ch] * m).toInt().clamp(0, 255);
  });

  // 重力ポテンシャル等高線
  static RenderConfig gravity() => RenderConfig(pixel: (u, m, ch) {
    final v = (-u).clamp(0.0, 1.0);
    const levels = 12;
    final frac      = (v * levels) - (v * levels).floor();
    final isContour = frac < 0.08;
    final quantized = (v * levels).floor() / levels;
    final bright    = isContour ? 1.0 : quantized.toDouble();
    final rgb = [
      (bright * 0.4 * 255 * m).toInt().clamp(0, 255),
      (bright * 0.8 * 255 * m).toInt().clamp(0, 255),
      (bright * 0.5 * 255 * m).toInt().clamp(0, 255),
    ];
    return rgb[ch];
  });

  // Gray-Scott用
  static RenderConfig bio() => RenderConfig(pixel: (u, m, ch) {
    // u: U成分, uPrev: V成分 (今回は u のみ渡される想定なので工夫が必要)
    // FieldRule側で u に V-U などの情報を込めて渡すか、RenderConfigを拡張する
    // ここでは簡易的に u を V成分と見なし、0.5を閾値にする
    final v = u.clamp(0.0, 1.0);
    int r, g, b;
    if (v > 0.5) {
      // 反応済み：黄緑
      r = 150; g = 255; b = 50;
    } else if (v > 0.4) {
      // 境界：白
      r = 255; g = 255; b = 255;
    } else {
      // 未反応：青
      r = 30; g = 50; b = 150;
    }
    final rgb = [r, g, b];
    return (rgb[ch] * m).toInt().clamp(0, 255);
  });

  // 熱分布カラーマップ
  static RenderConfig heatmap() => RenderConfig(pixel: (u, m, ch) {
    final v = u.clamp(0.0, 1.0);
    int r, g, b;
    if (v < 0.33) {
      r = (v / 0.33 * 255).toInt(); g = 0; b = 0;
    } else if (v < 0.66) {
      r = 255; g = ((v - 0.33) / 0.33 * 255).toInt(); b = 0;
    } else {
      r = 255; g = 255; b = ((v - 0.66) / 0.34 * 255).toInt();
    }
    final rgb = [r, g, b];
    return (rgb[ch] * m).toInt().clamp(0, 255);
  });
}

// ─────────────────────────────────────────
// FieldRule 抽象基底
// ─────────────────────────────────────────
abstract class FieldRule {
  String get name;
  List<RuleParam> get params => [];
  RenderConfig get renderConfig;

  void init(Grid grid);
  void step(Grid grid, double dt);
  void clean(Grid grid) => init(grid);
  void setParam(String key, double value) {}

  void onTouchStart(Grid grid, Offset p) {}
  void onTouchMove(Grid grid, Offset p)  {}
  void onTouchEnd(Grid grid, Offset p)   {}

  // Wave互換（旧インターフェース）
  void onPoint(Grid grid, Offset p)              => onTouchStart(grid, p);
  void onStroke(Grid grid, List<Offset> points)  {
    for (final p in points) onTouchMove(grid, p);
  }
}