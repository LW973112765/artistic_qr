/// A growable buffer of bits, appended most-significant-bit first.
///
/// Used to assemble the QR data bit stream (mode indicators, character
/// counts, payload, padding) before it is split into codewords.
class BitBuffer {
  final List<bool> _bits = <bool>[];

  int get length => _bits.length;

  bool operator [](int index) => _bits[index];

  /// Appends the [length] least-significant bits of [value], MSB first.
  void appendBits(int value, int length) {
    assert(length >= 0 && length <= 32, 'bit length out of range: $length');
    assert(
      length == 32 || (value >> length) == 0,
      'value $value does not fit in $length bits',
    );
    for (var i = length - 1; i >= 0; i--) {
      _bits.add((value >> i) & 1 == 1);
    }
  }

  void appendBit(bool bit) => _bits.add(bit);

  /// Packs the bits into whole bytes, MSB first. The bit length must be a
  /// multiple of 8 (the encoder pads before calling this).
  List<int> toBytes() {
    assert(_bits.length % 8 == 0, 'bit stream not byte aligned');
    final bytes = List<int>.filled(_bits.length ~/ 8, 0);
    for (var i = 0; i < _bits.length; i++) {
      if (_bits[i]) {
        bytes[i ~/ 8] |= 0x80 >> (i % 8);
      }
    }
    return bytes;
  }
}
