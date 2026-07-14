import 'dart:convert';
import 'dart:typed_data';

import 'bit_buffer.dart';
import 'matrix.dart';
import 'reed_solomon.dart';
import 'tables.dart';

/// Thrown when the payload cannot fit in the allowed version range at the
/// requested error-correction level.
class QrDataTooLongException implements Exception {
  QrDataTooLongException(this.message);
  final String message;

  @override
  String toString() => 'QrDataTooLongException: $message';
}

const String _alphanumericCharset =
    r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:';

class _Mode {
  static const int numeric = 0x1;
  static const int alphanumeric = 0x2;
  static const int byte = 0x4;
  static const int eci = 0x7;
}

/// An encoded QR symbol: the module matrix plus the parameters that
/// produced it.
class QrCode {
  QrCode._({
    required this.version,
    required this.errorCorrection,
    required this.mask,
    required this.matrix,
  }) : size = matrix.size;

  final int version;
  final int size;
  final QrErrorCorrection errorCorrection;

  /// The mask pattern (0–7) that was applied.
  final int mask;

  final QrMatrix matrix;

  /// Encodes [text], picking the densest mode that can represent it
  /// (numeric → alphanumeric → byte; UTF-8 with an ECI header when the text
  /// is not Latin-1).
  ///
  /// The smallest version within [minVersion]..[maxVersion] that fits is
  /// used. [mask] forces a specific mask pattern (0–7); by default all eight
  /// are scored and the best is chosen.
  static QrCode encode(
    String text, {
    QrErrorCorrection errorCorrection = QrErrorCorrection.quartile,
    int minVersion = 1,
    int maxVersion = 40,
    int? mask,
  }) {
    assert(minVersion >= 1 && maxVersion <= 40 && minVersion <= maxVersion);
    assert(mask == null || (mask >= 0 && mask <= 7));
    final segment = _Segment.fromText(text);
    return _encodeSegment(segment, errorCorrection, minVersion, maxVersion, mask);
  }

  /// Encodes raw [bytes] in byte mode.
  static QrCode encodeBytes(
    List<int> bytes, {
    QrErrorCorrection errorCorrection = QrErrorCorrection.quartile,
    int minVersion = 1,
    int maxVersion = 40,
    int? mask,
  }) {
    final segment = _Segment.fromBytes(bytes);
    return _encodeSegment(segment, errorCorrection, minVersion, maxVersion, mask);
  }

  static QrCode _encodeSegment(
    _Segment segment,
    QrErrorCorrection level,
    int minVersion,
    int maxVersion,
    int? forcedMask,
  ) {
    // Pick the smallest version whose data capacity fits the segment.
    int? version;
    for (var v = minVersion; v <= maxVersion; v++) {
      final capacityBits = ecBlocksFor(v, level).totalDataCodewords * 8;
      if (segment.totalBits(v) <= capacityBits) {
        version = v;
        break;
      }
    }
    if (version == null) {
      throw QrDataTooLongException(
        'Data length ${segment.charCount} does not fit in version '
        '$maxVersion at level ${level.letter}',
      );
    }

    final ec = ecBlocksFor(version, level);
    final bits = BitBuffer();
    segment.writeTo(bits, version);

    // Terminator and padding.
    final capacityBits = ec.totalDataCodewords * 8;
    final terminator = capacityBits - bits.length;
    bits.appendBits(0, terminator < 4 ? terminator : 4);
    if (bits.length % 8 != 0) {
      bits.appendBits(0, 8 - bits.length % 8);
    }
    var padByte = 0xEC;
    while (bits.length < capacityBits) {
      bits.appendBits(padByte, 8);
      padByte = padByte == 0xEC ? 0x11 : 0xEC;
    }

    final codewords = _interleave(bits.toBytes(), ec);
    final builder = _MatrixBuilder(version, level);
    builder.placeCodewords(codewords);
    final mask = builder.selectMask(forcedMask);

    return QrCode._(
      version: version,
      errorCorrection: level,
      mask: mask,
      matrix: builder.matrix,
    );
  }

  /// Splits data codewords into RS blocks, appends EC codewords, and
  /// interleaves per the spec.
  static Uint8List _interleave(List<int> data, EcBlocks ec) {
    final blocks = <List<int>>[];
    final ecBlocks = <Uint8List>[];
    var offset = 0;
    for (var b = 0; b < ec.totalBlocks; b++) {
      final blockLen = b < ec.group1Blocks
          ? ec.group1DataCodewords
          : ec.group2DataCodewords;
      final block = data.sublist(offset, offset + blockLen);
      offset += blockLen;
      blocks.add(block);
      ecBlocks.add(ReedSolomon.encode(block, ec.ecCodewordsPerBlock));
    }
    assert(offset == data.length);

    final maxLen = ec.group2Blocks > 0
        ? ec.group2DataCodewords
        : ec.group1DataCodewords;
    final result = BytesBuilder(copy: false);
    for (var i = 0; i < maxLen; i++) {
      for (final block in blocks) {
        if (i < block.length) result.addByte(block[i]);
      }
    }
    for (var i = 0; i < ec.ecCodewordsPerBlock; i++) {
      for (final block in ecBlocks) {
        result.addByte(block[i]);
      }
    }
    return result.toBytes();
  }
}

/// One encoded data segment (this encoder always uses a single segment with
/// the best mode for the whole input, which is optimal for all-numeric,
/// all-alphanumeric, or general text).
class _Segment {
  _Segment._(this.modeIndicator, this.charCount, this.payload, this.useEci);

  final int modeIndicator;

  /// Characters for numeric/alphanumeric; bytes for byte mode.
  final int charCount;
  final BitBuffer payload;

  /// Whether a UTF-8 ECI header must precede the segment.
  final bool useEci;

  factory _Segment.fromText(String text) {
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
      return _Segment._(_Mode.numeric, text.length, _numericBits(text), false);
    }
    if (text.split('').every(_alphanumericCharset.contains) &&
        text.isNotEmpty) {
      return _Segment._(
          _Mode.alphanumeric, text.length, _alphanumericBits(text), false);
    }
    // Byte mode. Pure ASCII needs no charset marker; anything else is
    // encoded as UTF-8 with an ECI designator, which is what modern
    // scanners (iOS, Android, zxing) expect.
    final isAscii = text.codeUnits.every((c) => c <= 0x7F);
    final bytes = isAscii ? ascii.encode(text) : utf8.encode(text);
    final payload = BitBuffer();
    for (final b in bytes) {
      payload.appendBits(b, 8);
    }
    return _Segment._(_Mode.byte, bytes.length, payload, !isAscii);
  }

  factory _Segment.fromBytes(List<int> bytes) {
    final payload = BitBuffer();
    for (final b in bytes) {
      payload.appendBits(b, 8);
    }
    return _Segment._(_Mode.byte, bytes.length, payload, false);
  }

  int totalBits(int version) {
    var bits = 4 + characterCountBits(modeIndicator, version) + payload.length;
    if (useEci) bits += 4 + 8; // ECI mode + assignment number 26 (UTF-8)
    return bits;
  }

  void writeTo(BitBuffer bits, int version) {
    if (useEci) {
      bits.appendBits(_Mode.eci, 4);
      bits.appendBits(26, 8); // ECI assignment 26 = UTF-8
    }
    bits.appendBits(modeIndicator, 4);
    final countBits = characterCountBits(modeIndicator, version);
    if (charCount >= (1 << countBits)) {
      throw QrDataTooLongException(
          'Character count $charCount does not fit in $countBits bits');
    }
    bits.appendBits(charCount, countBits);
    for (var i = 0; i < payload.length; i++) {
      bits.appendBit(payload[i]);
    }
  }

  static BitBuffer _numericBits(String text) {
    final bits = BitBuffer();
    for (var i = 0; i < text.length; i += 3) {
      final group = text.substring(i, i + 3 > text.length ? text.length : i + 3);
      bits.appendBits(int.parse(group), group.length * 3 + 1);
    }
    return bits;
  }

  static BitBuffer _alphanumericBits(String text) {
    final bits = BitBuffer();
    for (var i = 0; i + 1 < text.length; i += 2) {
      bits.appendBits(
        _alphanumericCharset.indexOf(text[i]) * 45 +
            _alphanumericCharset.indexOf(text[i + 1]),
        11,
      );
    }
    if (text.length.isOdd) {
      bits.appendBits(_alphanumericCharset.indexOf(text[text.length - 1]), 6);
    }
    return bits;
  }
}

/// Builds the module matrix: function patterns, codeword placement, masking,
/// and format/version information.
class _MatrixBuilder {
  _MatrixBuilder(this.version, this.level)
      : matrix = QrMatrix(version * 4 + 17) {
    _drawFunctionPatterns();
  }

  final int version;
  final QrErrorCorrection level;
  final QrMatrix matrix;

  int get size => matrix.size;

  void _drawFunctionPatterns() {
    // Finder patterns with separators (Chebyshev rings around the centers).
    _drawFinder(3, 3);
    _drawFinder(size - 4, 3);
    _drawFinder(3, size - 4);

    // Alignment patterns (skip the three finder corners).
    final positions = alignmentPositions[version - 1];
    for (var i = 0; i < positions.length; i++) {
      for (var j = 0; j < positions.length; j++) {
        final isCorner = (i == 0 && j == 0) ||
            (i == 0 && j == positions.length - 1) ||
            (i == positions.length - 1 && j == 0);
        if (isCorner) continue;
        _drawAlignment(positions[i], positions[j]);
      }
    }

    // Timing patterns on row 6 and column 6 (only cells not already used).
    for (var i = 0; i < size; i++) {
      if (!matrix.isAssigned(6, i)) {
        matrix.set(6, i, dark: i.isEven, role: QrModuleRole.timing);
      }
      if (!matrix.isAssigned(i, 6)) {
        matrix.set(i, 6, dark: i.isEven, role: QrModuleRole.timing);
      }
    }

    // Reserve format info areas (values written after mask selection).
    _drawFormatBits(0, reserveOnly: true);

    if (version >= 7) _drawVersionInfo();
  }

  void _drawFinder(int centerRow, int centerCol) {
    for (var dr = -4; dr <= 4; dr++) {
      for (var dc = -4; dc <= 4; dc++) {
        final r = centerRow + dr;
        final c = centerCol + dc;
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        final dist = dr.abs() > dc.abs() ? dr.abs() : dc.abs();
        matrix.set(
          r,
          c,
          dark: dist != 2 && dist != 4,
          role: dist <= 3 ? QrModuleRole.finder : QrModuleRole.separator,
        );
      }
    }
  }

  void _drawAlignment(int centerRow, int centerCol) {
    for (var dr = -2; dr <= 2; dr++) {
      for (var dc = -2; dc <= 2; dc++) {
        final dist = dr.abs() > dc.abs() ? dr.abs() : dc.abs();
        matrix.set(
          centerRow + dr,
          centerCol + dc,
          dark: dist != 1,
          role: QrModuleRole.alignment,
        );
      }
    }
  }

  void _drawVersionInfo() {
    // 18-bit version info: 6 data bits + 12 BCH remainder (generator 0x1F25).
    var rem = version;
    for (var i = 0; i < 12; i++) {
      rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
    }
    final bits = (version << 12) | rem;
    for (var i = 0; i < 18; i++) {
      final bit = (bits >> i) & 1 == 1;
      final a = size - 11 + i % 3;
      final b = i ~/ 3;
      matrix.set(a, b, dark: bit, role: QrModuleRole.version);
      matrix.set(b, a, dark: bit, role: QrModuleRole.version);
    }
  }

  /// Writes the 15-bit format information (both copies) for [mask].
  /// With [reserveOnly], just claims the cells so data placement skips them.
  void _drawFormatBits(int mask, {bool reserveOnly = false}) {
    final data = (level.formatBits << 3) | mask;
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    }
    final bits = ((data << 10) | rem) ^ 0x5412;

    void put(int row, int col, int bitIndex) {
      matrix.set(
        row,
        col,
        dark: !reserveOnly && ((bits >> bitIndex) & 1 == 1),
        role: QrModuleRole.format,
      );
    }

    // First copy, around the top-left finder: bits 0–7 run down column 8,
    // bits 8–14 run leftward along row 8.
    for (var i = 0; i <= 5; i++) {
      put(i, 8, i);
    }
    put(7, 8, 6);
    put(8, 8, 7);
    put(8, 7, 8);
    for (var i = 9; i < 15; i++) {
      put(8, 14 - i, i);
    }

    // Second copy: bits 0–7 along row 8 at the top-right, bits 8–14 down
    // column 8 at the bottom-left.
    for (var i = 0; i < 8; i++) {
      put(8, size - 1 - i, i);
    }
    for (var i = 8; i < 15; i++) {
      put(size - 15 + i, 8, i);
    }

    // The always-dark module above the bottom-left format strip.
    matrix.set(size - 8, 8, dark: !reserveOnly, role: QrModuleRole.dark);
  }

  /// Places interleaved codewords in the zigzag order defined by the spec.
  /// Leftover remainder bits stay light (0).
  void placeCodewords(Uint8List codewords) {
    var bitIndex = 0;
    final totalBits = codewords.length * 8;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final col = right - j;
          final upward = ((right + 1) & 2) == 0;
          final row = upward ? size - 1 - vert : vert;
          if (!matrix.isAssigned(row, col)) {
            var dark = false;
            if (bitIndex < totalBits) {
              dark = (codewords[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1 == 1;
              bitIndex++;
            }
            matrix.set(row, col, dark: dark, role: QrModuleRole.data);
          }
        }
      }
    }
    assert(bitIndex == totalBits, 'placed $bitIndex of $totalBits bits');
  }

  /// XORs the mask pattern over data modules. Applying twice undoes it.
  void _applyMask(int mask) {
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (matrix.roleAt(row, col) != QrModuleRole.data) continue;
        final bool invert;
        switch (mask) {
          case 0:
            invert = (col + row) % 2 == 0;
          case 1:
            invert = row % 2 == 0;
          case 2:
            invert = col % 3 == 0;
          case 3:
            invert = (col + row) % 3 == 0;
          case 4:
            invert = (col ~/ 3 + row ~/ 2) % 2 == 0;
          case 5:
            invert = col * row % 2 + col * row % 3 == 0;
          case 6:
            invert = (col * row % 2 + col * row % 3) % 2 == 0;
          case 7:
            invert = ((col + row) % 2 + col * row % 3) % 2 == 0;
          default:
            throw ArgumentError('mask out of range: $mask');
        }
        if (invert) {
          matrix.setDark(row, col, !matrix.isDark(row, col));
        }
      }
    }
  }

  /// Applies [forced] or the lowest-penalty mask, writes the matching format
  /// bits, and returns the chosen mask id.
  int selectMask(int? forced) {
    var best = forced;
    if (best == null) {
      var minPenalty = 0x7FFFFFFF; // safe on web (no 1 << 32)
      for (var m = 0; m < 8; m++) {
        _applyMask(m);
        _drawFormatBits(m);
        final penalty = _penaltyScore();
        if (penalty < minPenalty) {
          minPenalty = penalty;
          best = m;
        }
        _applyMask(m); // undo
      }
    }
    _applyMask(best!);
    _drawFormatBits(best);
    return best;
  }

  // Penalty scoring (ISO 18004 §8.8.2, ported from Nayuki's reference
  // implementation including the finder-like pattern run history).

  static const int _n1 = 3, _n2 = 3, _n3 = 40, _n4 = 10;

  int _penaltyScore() {
    var result = 0;

    // Rows: runs of same color and finder-like patterns.
    for (var row = 0; row < size; row++) {
      var runColor = false;
      var runLength = 0;
      final history = List<int>.filled(7, 0);
      for (var col = 0; col < size; col++) {
        if (matrix.isDark(row, col) == runColor) {
          runLength++;
          if (runLength == 5) {
            result += _n1;
          } else if (runLength > 5) {
            result++;
          }
        } else {
          _addRunToHistory(runLength, history);
          if (!runColor) {
            result += _countFinderPatterns(history) * _n3;
          }
          runColor = matrix.isDark(row, col);
          runLength = 1;
        }
      }
      result += _terminateAndCount(runColor, runLength, history) * _n3;
    }

    // Columns: same rules.
    for (var col = 0; col < size; col++) {
      var runColor = false;
      var runLength = 0;
      final history = List<int>.filled(7, 0);
      for (var row = 0; row < size; row++) {
        if (matrix.isDark(row, col) == runColor) {
          runLength++;
          if (runLength == 5) {
            result += _n1;
          } else if (runLength > 5) {
            result++;
          }
        } else {
          _addRunToHistory(runLength, history);
          if (!runColor) {
            result += _countFinderPatterns(history) * _n3;
          }
          runColor = matrix.isDark(row, col);
          runLength = 1;
        }
      }
      result += _terminateAndCount(runColor, runLength, history) * _n3;
    }

    // 2×2 blocks of the same color.
    for (var row = 0; row < size - 1; row++) {
      for (var col = 0; col < size - 1; col++) {
        final c = matrix.isDark(row, col);
        if (c == matrix.isDark(row, col + 1) &&
            c == matrix.isDark(row + 1, col) &&
            c == matrix.isDark(row + 1, col + 1)) {
          result += _n2;
        }
      }
    }

    // Dark/light balance.
    var dark = 0;
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (matrix.isDark(row, col)) dark++;
      }
    }
    final total = size * size;
    final k = ((dark * 20 - total * 10).abs() + total - 1) ~/ total - 1;
    result += k * _n4;
    return result;
  }

  int _countFinderPatterns(List<int> history) {
    final n = history[1];
    final core = n > 0 &&
        history[2] == n &&
        history[3] == n * 3 &&
        history[4] == n &&
        history[5] == n;
    return (core && history[0] >= n * 4 && history[6] >= n ? 1 : 0) +
        (core && history[6] >= n * 4 && history[0] >= n ? 1 : 0);
  }

  int _terminateAndCount(bool runColor, int runLength, List<int> history) {
    if (runColor) {
      _addRunToHistory(runLength, history);
      runLength = 0;
    }
    runLength += size; // treat the border as light
    _addRunToHistory(runLength, history);
    return _countFinderPatterns(history);
  }

  void _addRunToHistory(int runLength, List<int> history) {
    if (history[0] == 0) runLength += size; // initial light border
    for (var i = 6; i >= 1; i--) {
      history[i] = history[i - 1];
    }
    history[0] = runLength;
  }
}
