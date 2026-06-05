import '../game/grid.dart';
import 'dart:ui';
import 'dart:math';

// ─────────────────────────────────────────
// RuleParam
// ─────────────────────────────────────────
class RuleParam {
  final String key, label;
  final double min, max, defaultValue;
  final int?   divisions;
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

  // ヘルパー：Smoothstepによるアンチエイリアス
  static double _smoothstep(double edge0, double edge1, double x) {
    double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  // 水面（Wave用）：深青（谷）〜シアン（平坦）〜白（山）
  static RenderConfig water() => RenderConfig(pixel: (u, m, ch) {
    final v = (u / 3.0).clamp(-1.0, 1.0);
    int r, g, b;
    if (v >= 0) {
      r = (v * 255).toInt();
      g = (180 + v * 75).toInt();
      b = 255;
    } else {
      final t = -v;
      r = 0;
      g = (180 * (1.0 - t) + 20 * t).toInt();
      b = (255 * (1.0 - t) + 80 * t).toInt();
    }
    final rgb = [r, g, b];
    return (rgb[ch] * m).toInt().clamp(0, 255);
  });

  // BZ反応用：マゼンタ（高活性）〜紫〜黒（抑制）
  static RenderConfig bz() => RenderConfig(pixel: (u, m, ch) {
    final v = ((u + 1.0) / 3.0).clamp(0.0, 1.0);
    int r, g, b;
    r = (v * 255).toInt();
    g = (v * 50).toInt();
    b = (v * 200 + (1.0 - v) * 50).toInt();
    final rgb = [r, g, b];
    return (rgb[ch] * m).toInt().clamp(0, 255);
  });

  // 重力ポテンシャル等高線（滑らかに均す）
  static RenderConfig gravity() => RenderConfig(pixel: (u, m, ch) {
    final v = (-u).clamp(0.0, 1.0);
    const levels = 12.0;
    final val = v * levels;
    final frac = val - val.floor();
    
    // 境界をsmoothstepでぼかす
    final contourWeight = _smoothstep(0.12, 0.0, frac) + _smoothstep(0.88, 1.0, frac);
    final quantized = val.floor() / levels;
    
    // 等高線部分は明るく、それ以外は階調
    final bright = (contourWeight * 0.6 + quantized).clamp(0.0, 1.0);
    
    final rgb = [
      (bright * 0.4 * 255 * m).toInt(),
      (bright * 0.8 * 255 * m).toInt(),
      (bright * 0.5 * 255 * m).toInt(),
    ];
    return rgb[ch].clamp(0, 255);
  });

  // 電場用等高線（滑らかに均す）
  static RenderConfig electric() => RenderConfig(pixel: (u, m, ch) {
    final v = u;
    final absV = v.abs();
    final logV = log(1.0 + absV * 0.01);
    const levels = 8.0;
    final val = logV * levels;
    final frac = val - val.floor();
    
    // 滑らかな等高線ウェイト
    final contourWeight = _smoothstep(0.15, 0.0, frac) + _smoothstep(0.85, 1.0, frac);
    final isVisible = logV > 0.001;
    
    if (isVisible && contourWeight > 0.01) {
      final w = contourWeight * m;
      if (v > 0) {
        final rgb = [(w * 255).toInt(), (w * 0.3 * 255).toInt(), (w * 0.1 * 255).toInt()];
        return rgb[ch].clamp(0, 255);
      } else {
        final rgb = [(w * 0.1 * 255).toInt(), (w * 0.4 * 255).toInt(), (w * 255).toInt()];
        return rgb[ch].clamp(0, 255);
      }
    }
    
    // オーラ部分（ここも滑らかに）
    if (absV > 0.1) {
      final aura = (logV * 15 * m).toInt();
      if (v > 0) {
        final rgb = [aura, (aura * 0.2).toInt(), 0];
        return rgb[ch].clamp(0, 255);
      } else {
        final rgb = [0, (aura * 0.3).toInt(), aura];
        return rgb[ch].clamp(0, 255);
      }
    }
    return 0;
  });

  // Gray-Scott用
  static RenderConfig bio() => RenderConfig(pixel: (u, m, ch) {
    final v = (1.0 - u).clamp(0.0, 1.0);
    final rgb = [
      (v * 0.2 * 255 * m).toInt(),
      (v * 0.9 * 255 * m).toInt(),
      (v * 0.4 * 255 * m).toInt(),
    ];
    return rgb[ch].clamp(0, 255);
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

  // ライフゲーム用
  static RenderConfig life() => RenderConfig(pixel: (u, m, ch) {
    if (u < 0.5) return 0;
    return (255 * m).toInt();
  });

  // アーク放電用（ビット感を抑える）
  static RenderConfig arc() => RenderConfig(pixel: (u, m, ch) {
    final v = u.clamp(0.0, 2.0);
    int r, g, b;
    
    if (v < 0.15) {
      // オーラ：線形補間で滑らかに
      final t = v / 0.15;
      r = (t * 40).toInt();
      g = (t * 10).toInt();
      b = (t * 100).toInt();
    } else if (v < 1.0) {
      // グロー：smoothstepで境界を均す
      final t = _smoothstep(0.15, 1.0, v);
      r = (40 + t * 160).toInt();
      g = (10 + t * 200).toInt();
      b = 255;
    } else {
      // コア：白飛びを滑らかに
      final t = _smoothstep(1.0, 1.5, v);
      r = (200 + t * 55).toInt();
      g = (210 + t * 45).toInt();
      b = 255;
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

  void onPoint(Grid grid, Offset p)              => onTouchStart(grid, p);
  void onStroke(Grid grid, List<Offset> points)  {
    for (final p in points) onTouchMove(grid, p);
  }
}
