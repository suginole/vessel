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

  // 水面（Wave用）：深青（谷）〜シアン（平坦）〜白（山）
  static RenderConfig water() => RenderConfig(pixel: (u, m, ch) {
    final v = (u / 3.0).clamp(-1.0, 1.0);
    int r, g, b;
    
    if (v >= 0) {
      // 山（正の変位）：シアンから白へ
      // v=0: (0, 180, 255) -> v=1: (255, 255, 255)
      r = (v * 255).toInt();
      g = (180 + v * 75).toInt();
      b = 255;
    } else {
      // 谷（負の変位）：シアンから深青へ
      // v=0: (0, 180, 255) -> v=-1: (0, 20, 80)
      final t = -v;
      r = 0;
      g = (180 * (1.0 - t) + 20 * t).toInt();
      b = (255 * (1.0 - t) + 80 * t).toInt();
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

  // Gray-Scott用 (U成分単体で可視化: 低いほど反応済み)
  static RenderConfig bio() => RenderConfig(pixel: (u, m, ch) {
    final v = (1.0 - u).clamp(0.0, 1.0); // U低い=V高い=パターン
    final rgb = [
      (v * 0.2 * 255 * m).toInt().clamp(0, 255), // R 暗め
      (v * 0.9 * 255 * m).toInt().clamp(0, 255), // G 明るく
      (v * 0.4 * 255 * m).toInt().clamp(0, 255), // B 中程度
    ];
    return rgb[ch];
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

  // ライフゲーム用 (生セル=白, 死セル=透明)
  static RenderConfig life() => RenderConfig(pixel: (u, m, ch) {
    if (u < 0.5) return 0; // 死セル
    return (255 * m).toInt(); // 生セル
  });

  // アーク放電用 (u: 0.0=背景, 0.1=電位場オーラ, 1.0=コア, 2.0=フラッシュ)
  static RenderConfig arc() => RenderConfig(pixel: (u, m, ch) {
    final v = u.clamp(0.0, 2.0);
    int r, g, b;
    
    if (v < 0.15) {
      // 1. 電位場のオーラ (青紫のぼんやりした光)
      final t = v / 0.15;
      r = (t * 40).toInt();
      g = (t * 10).toInt();
      b = (t * 100).toInt();
    } else if (v < 1.0) {
      // 2. チャンネルのグロー (青→白へのグラデーション)
      final t = (v - 0.15) / 0.85;
      r = (40 + t * 160).toInt();
      g = (10 + t * 200).toInt();
      b = 255;
    } else {
      // 3. コア・フラッシュ (純白)
      final t = (v - 1.0).clamp(0.0, 1.0);
      r = (200 + t * 55).toInt();
      g = (210 + t * 45).toInt();
      b = 255;
    }
    
    // 最終出力 (RGBチャンネル選択)
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
