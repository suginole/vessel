import 'dart:typed_data';

class Grid {
  final int w, h;
  late Float32List u;
  late Float32List uPrev;
  late Float32List polygonMask;
  late Float32List fullMask;
  bool isFullscreen = false;

  Float32List get mask => isFullscreen ? fullMask : polygonMask;

  // 2成分系エイリアス
  Float32List get a => u;
  Float32List get b => uPrev;

  Grid(this.w, this.h) {
    u           = Float32List(w * h);
    uPrev       = Float32List(w * h);
    polygonMask = Float32List(w * h);
    fullMask    = Float32List(w * h)..fillRange(0, w * h, 1.0);
  }

  void clear() {
    u.fillRange(0, u.length, 0.0);
    uPrev.fillRange(0, uPrev.length, 0.0);
  }

  int idx(int x, int y) => y * w + x;
}
