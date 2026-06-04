import 'dart:typed_data';

class Grid {
  final int w, h;
  late Float32List u;
  late Float32List uPrev;
  late Float32List mask;

  Grid(this.w, this.h) {
    u     = Float32List(w * h);
    uPrev = Float32List(w * h);
    mask  = Float32List(w * h);
  }

  void clear() {
    u.fillRange(0, u.length, 0.0);
    uPrev.fillRange(0, uPrev.length, 0.0);
  }

  int idx(int x, int y) => y * w + x;
}