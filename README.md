# Vessel

> 多角形の境界を操作し、内部で自然現象が走るインタラクティブフィールドシミュレーター  
> Google Play デプロイを想定した Flutter アプリ

---

## コンセプト

- **多角形（Boundary）** がプレイヤーの操作する「容器」
- **フィールド（Field）** が内部で走る自然現象の「世界」
- **タッチ操作** で初期条件を与える
- **フィールドルール** を差し替えることで全く異なる現象が走る

境界は反射壁・障壁として機能し、形を変えると内部現象のパターンが変わる。  
エージェントは存在しない。状態場の変化のみを扱う。

---

## 現在の実装状況

### ✅ 完成済み

#### Wave（波動伝播）
- 2次元波動方程式（有限差分法）
- クーラン条件を満たす固定 r=0.5 でサブステップ計算
- 固定端反射（Dirichlet境界）
- タッチでインパルス（5×5範囲、速度ゼロ初期条件）
- 赤－白－青カラースケール

#### Gravity（重力シミュレーション） ← 実装中・デバッグ中
- Yoshida 4次シンプレクティック積分
- 1〜3体の天体配置（タップ＋ドラッグで座標・初速決定）
- 重力ポテンシャルの等高線可視化
- 多角形境界での完全弾性反射
- 配置フェーズ → 最大数配置で自動シミュレーション開始

#### UI
- N角スライダー（3〜16）
- ルール選択ドロップダウン（wave / gravity）
- 正多角形化ボタン
- お掃除ボタン（フィールド初期化）
- 再起動ボタン
- 大理石テクスチャ背景（assets/images/white-marble1.jpg）
- 多角形外側は透明（背景が透ける）
- 境界線グロー＋頂点リングハンドル

---

## ディレクトリ構成

```
vessel/
├── assets/
│   └── images/
│       └── white-marble1.jpg
└── lib/
    ├── main.dart
    ├── game/
    │   ├── game_controller.dart   # ゲームループ・状態管理・タッチ振り分け
    │   ├── boundary.dart          # 多角形・mask生成・交差チェック
    │   └── grid.dart              # u, uPrev, mask 状態配列
    ├── rules/
    │   ├── field_rule.dart        # 抽象基底・RuleParam・RenderConfig
    │   ├── wave_rule.dart         # 波動方程式実装
    │   └── gravity_rule.dart      # 重力シミュレーション実装
    └── ui/
        ├── game_screen.dart       # メイン画面・Ticker・GestureDetector
        ├── field_painter.dart     # CustomPaint（ピクセル＋ベクタ）
        └── control_panel.dart     # スライダー・ドロップダウン・ボタン
```

---

## クラス設計

### GameController
```
restart(n, rule)      # 頂点数・ルール変更時のみ呼ぶ（Grid・Boundaryリセット）
clean()               # フィールドのみ初期化（ルール・境界保持）
update(dt)            # 毎フレーム：mask更新 + rule.step()
onTouchStart(gridPos) # 頂点近傍 → ドラッグ / それ以外 → rule委譲
onTouchMove(gridPos)  # 頂点ドラッグ or rule委譲（Wave系は距離間引き）
onTouchEnd()          # rule委譲・状態リセット
setParam(key, value)  # ルールパラメータ設定
```

### FieldRule（抽象基底）
```
name                  # ルール名
params                # List<RuleParam>（UIスライダー自動生成）
renderConfig          # RenderConfig（カラーマップ）
init(grid)            # 再起動時初期化
step(grid, dt)        # 毎フレーム更新
clean(grid)           # お掃除（デフォルト=init委譲）
setParam(key, value)  # パラメータ受け取り
onTouchStart/Move/End # タッチ委譲
```

### Boundary
```
vertices              # 頂点座標リスト（単純多角形、非交差）
moveVertex(i, pos)    # ドラッグ（交差チェック・グリッド範囲クランプ）
buildMask(w, h)       # float mask生成（区分線形補正）
regularize(cx,cy,r)   # 正多角形化
nearestVertex(p)      # 最近傍頂点インデックス
dirty                 # mask再計算フラグ
```

### Grid
```
u        # Float32List 現在の状態値
uPrev    # Float32List 前ステップの状態値（Wave用）
mask     # Float32List 0.0〜1.0（境界内外・区分線形）
```

---

## 物理・数値計算

### Wave
```
更新式: u_next = 2u - u_prev + r²(u[i+1]+u[i-1]+u[i+w]+u[i-w] - 4u[i])
r = 0.5（固定、クーラン条件 r ≤ 1/√2 を満たす）
波速: c = 45.0 [cell/s]
減衰: × 0.9999（ほぼ減衰なし・長持ち）
境界: next[i] *= mask[i]（固定端反射）
インパルス: 5×5範囲、amp=3.0、u=uPrev=amp（初速ゼロ）
サブステップ: dt/dtSub、最大8回/フレーム
```

### Gravity
```
積分法: Yoshida 4次シンプレクティック積分
係数: w1=1.3512..., w0=-1.7024...
サブステップ: 8回/フレーム
加速度: a_i = G Σ_j m_j(r_j - r_i) / (|r_ij|² + ε²)^(3/2)
ソフトニング: ε = 3.0（ゼロ除算防止）
境界反射: mask==0 で速度反転
ポテンシャル: Φ(x,y) = -G Σ m_i / sqrt(r_i² + ε²)
等高線描画: 12段階量子化、frac < 0.08 で輝線
パラメータ: G(100-2000), mass(0.1-5.0), 天体数(1-3)
```

### Boundary mask（区分線形補正）
```
内部: mask = 1.0
境界ピクセル: mask = min(最近傍辺距離, 1.0)（0.0〜1.0）
外部: mask = 0.0
用途: next[i] *= mask[i] で境界付近を滑らかに減衰
```

---

## ライフサイクル

```
操作                再起動  Grid    Mask    Rule
────────────────────────────────────────────────
頂点数変更          ✅      リセット 再生成  差替
ルール変更          ✅      リセット 再生成  差替
頂点ドラッグ        ❌      継続    再生成   継続
タッチ描画          ❌      注入    継続    継続
お掃除              ❌      リセット 継続    継続（パラメータ保持）
```

---

## 既知のバグ・TODO

### デバッグ中
- [ ] `gravity_rule.dart` の import パス問題（`../game/grid.dart` が必要）
- [ ] `game_controller.dart` で `GravityRule()` が未定義になる問題
  - 原因：`gravity_rule.dart` 内に誤った import（`grid.dart`、`boundary.dart` をルートから参照）が混入していた
- [ ] `onTouchEnd` のシグネチャ不一致（引数あり/なし）

### 次に実装するルール
- [ ] **HeatRule**（熱拡散）  
  `∂T/∂t = α∇²T`、タップで熱点/冷点、カラーマップ=heatmap
- [ ] **ReactionDiffRule**（Gray-Scott反応拡散）  
  斑点・縞・珊瑚・迷路、Feed/Kill/Du/Dv パラメータ
- [ ] **FluidRule**（Stam法流体）  
  多角形内に障害物多角形1つ、横方向煙の流れ
- [ ] GravityRule: 配置フェーズのバナーUI（天体数・質量をゲーム開始前に設定）

### UI改善
- [ ] ルール固有パラメータスライダーの動的生成（`RuleParam` リストから自動生成）
- [ ] Gravity配置フェーズ中の初速矢印描画（`_drawGravity` in field_painter）
- [ ] 軌跡描画の最適化

---

## 将来構想

```
追加したいフィールドルール
  ・Ising模型（磁区・相転移）
  ・森林火災CA（3状態セルオートマトン）
  ・砂崩れBTW模型（自己組織臨界）
  ・浸透クラスター
  ・BZ反応（螺旋波）

多角形の拡張
  ・内部障害物多角形（Fluid用）
  ・複数多角形

パフォーマンス
  ・compute() / Isolate でステップ計算をUIスレッドから分離
  ・グリッドサイズ選択（128/256/512）
```

---

## 技術スタック

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter（Dart） |
| ターゲット | Android（Google Play）、macOS/Chrome でデバッグ |
| 描画 | CustomPaint + ui.Image（ピクセル操作） |
| アニメーション | Ticker（毎フレーム） |
| 数値計算 | Dart単体（Float32List） |
| グリッドサイズ | 256×256（kW=kH=256） |

---

## 開発メモ

### import パスルール
```
rules/ から game/ を参照 → ../game/grid.dart
ui/   から game/ を参照 → ../game/game_controller.dart
ui/   から rules/ を参照 → ../rules/wave_rule.dart
```

### 新しいルールを追加する手順
1. `rules/new_rule.dart` を作成（`FieldRule` を継承）
2. `name`・`renderConfig`・`params` を実装
3. `game_controller.dart` の `ruleRegistry` に追加
4. `control_panel.dart` の `_buildRule()` に case 追加
5. `control_panel.dart` の `_ruleOptions` に追加
6. ルール固有描画があれば `field_painter.dart` の `paint()` に追加

### RenderConfig の追加
`field_rule.dart` の `RenderConfig` クラスに static factory を追加するだけ。
`gridToImage()` は `controller.rule.renderConfig` を自動参照する。
