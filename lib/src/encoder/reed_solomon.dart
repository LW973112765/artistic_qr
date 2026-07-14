import 'dart:typed_data';

import 'galois_field.dart';

/// Reed-Solomon error-correction codeword generation over GF(256).
class ReedSolomon {
  ReedSolomon._();

  static final Map<int, Uint8List> _generatorCache = <int, Uint8List>{};

  /// Returns the generator polynomial coefficients for [degree] EC codewords:
  /// (x - α^0)(x - α^1)…(x - α^(degree-1)), highest-order term first, with
  /// the leading 1 omitted.
  static Uint8List _generator(int degree) {
    return _generatorCache.putIfAbsent(degree, () {
      final gf = GaloisField.instance;
      var poly = Uint8List.fromList([1]);
      for (var i = 0; i < degree; i++) {
        final next = Uint8List(poly.length + 1);
        final root = gf.exp(i);
        for (var j = 0; j < poly.length; j++) {
          next[j] ^= gf.multiply(poly[j], root);
          next[j + 1] ^= poly[j];
        }
        poly = next;
      }
      // Drop the leading coefficient (always 1) and reverse so index 0 is
      // the highest remaining order, matching the division loop below.
      final result = Uint8List(degree);
      for (var i = 0; i < degree; i++) {
        result[i] = poly[degree - 1 - i];
      }
      return result;
    });
  }

  /// Computes [degree] EC codewords for [data] (polynomial long division).
  static Uint8List encode(List<int> data, int degree) {
    final gf = GaloisField.instance;
    final generator = _generator(degree);
    final remainder = Uint8List(degree);
    for (final byte in data) {
      final factor = byte ^ remainder[0];
      // Shift left by one.
      remainder.setRange(0, degree - 1, remainder, 1);
      remainder[degree - 1] = 0;
      if (factor != 0) {
        final logFactor = gf.log(factor);
        for (var i = 0; i < degree; i++) {
          final g = generator[i];
          if (g != 0) {
            remainder[i] ^= gf.exp(gf.log(g) + logFactor);
          }
        }
      }
    }
    return remainder;
  }
}
