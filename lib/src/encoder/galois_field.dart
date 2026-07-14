/// GF(256) arithmetic with the QR code polynomial x^8 + x^4 + x^3 + x^2 + 1
/// (0x11D), generator α = 2.
library;

import 'dart:typed_data';

class GaloisField {
  GaloisField._() {
    var x = 1;
    for (var i = 0; i < 255; i++) {
      _exp[i] = x;
      _log[x] = i;
      x <<= 1;
      if (x >= 0x100) x ^= 0x11D;
    }
    // Duplicate the exp table so exp(a + b) never needs an explicit mod.
    for (var i = 255; i < 512; i++) {
      _exp[i] = _exp[i - 255];
    }
  }

  static final GaloisField instance = GaloisField._();

  final Uint8List _exp = Uint8List(512);
  final Uint16List _log = Uint16List(256);

  int exp(int power) => _exp[power];

  int log(int value) {
    assert(value != 0, 'log(0) is undefined in GF(256)');
    return _log[value];
  }

  int multiply(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _exp[_log[a] + _log[b]];
  }
}
