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

  // 電場用等高線（ポテンシャル0で白、離れると赤/青）
  static RenderConfig electric() => RenderConfig(pixel: (u, m, ch) {
    final v = u;
    final absV = v.abs();
    
    // 0付近を白く、離れると色を付ける
    // t = 0 で白、t が大きくなると各色へ
    final t = (absV * 0.2).clamp(0.0, 1.0);
    
    double r = 255, g = 255, b = 255;
    
    if (v > 0) {
      // 正電位：青と緑を減らして赤にする
      g = 255 - (t * 200);
      b = 255 - (t * 255);
    } else {
      // 負電位：赤と緑を減らして青にする
      r = 255 - (t * 255);
      g = 255 - (t * 180);
    }
    
    // 等高線の描画
    final logV = log(1.0 + absV * 0.1);
    const levels = 8.0;
    final val = logV * levels;
    final frac = val - val.floor();
    final contourWeight = _smoothstep(0.15, 0.0, frac) + _smoothstep(0.85, 1.0, frac);
    
    // 等高線部分は少し暗くしてエッジを立たせる（または明るくする）
    // ここでは白ベースなので、少し暗くして「溝」のように見せる
    final cw = contourWeight * 50;
    r -= cw; g -= cw; b -= cw;
    
    final rgb = [r.toInt(), g.toInt(), b.toInt()];
    return (rgb[ch] * m).toInt().clamp(0, 255);
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
    
    // 電場と同様に等高線を描画してビット感を抑える
    const levels = 6.0;
    final val = v * levels;
    final frac = val - val.floor();
    final contourWeight = _smoothstep(0.15, 0.0, frac) + _smoothstep(0.85, 1.0, frac);
    
    int r, g, b;
    if (v < 0.15) {
      final t = v / 0.15;
      r = (t * 40).toInt();
      g = (t * 10).toInt();
      b = (t * 100).toInt();
    } else if (v < 1.0) {
      final t = _smoothstep(0.15, 1.0, v);
      r = (40 + t * 160).toInt();
      g = (10 + t * 200).toInt();
      b = 255;
    } else {
      final t = _smoothstep(1.0, 1.5, v);
      r = (200 + t * 55).toInt();
      g = (210 + t * 45).toInt();
      b = 255;
    }
    
    // 等高線を加算（滑らかなハイライト）
    final cw = (contourWeight * 0.4 * 255 * m).toInt();
    r = (r + cw).clamp(0, 255);
    g = (g + cw).clamp(0, 255);
    b = (b + cw).clamp(0, 255);
    
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
