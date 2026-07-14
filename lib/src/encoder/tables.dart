/// Constant tables from ISO/IEC 18004 for QR versions 1–40.
library;

/// Error-correction level, in increasing order of robustness.
///
/// Higher levels allow more of the symbol to be damaged (or covered by a
/// logo / consumed by halftone art) while remaining decodable.
enum QrErrorCorrection {
  /// Recovers ~7% of codewords.
  low(1, 'L'),

  /// Recovers ~15% of codewords.
  medium(0, 'M'),

  /// Recovers ~25% of codewords.
  quartile(3, 'Q'),

  /// Recovers ~30% of codewords. Required for heavy artistic styling.
  high(2, 'H');

  const QrErrorCorrection(this.formatBits, this.letter);

  /// The 2-bit indicator used in the format information string.
  final int formatBits;
  final String letter;
}

/// Error-correction block structure for one (version, level) combination.
class EcBlocks {
  const EcBlocks(
    this.ecCodewordsPerBlock,
    this.group1Blocks,
    this.group1DataCodewords, [
    this.group2Blocks = 0,
    this.group2DataCodewords = 0,
  ]);

  final int ecCodewordsPerBlock;
  final int group1Blocks;
  final int group1DataCodewords;
  final int group2Blocks;
  final int group2DataCodewords;

  int get totalBlocks => group1Blocks + group2Blocks;

  int get totalDataCodewords =>
      group1Blocks * group1DataCodewords + group2Blocks * group2DataCodewords;
}

/// EC block table indexed as `ecBlockTable[version - 1][level.index]` with
/// levels ordered [L, M, Q, H] (matching [QrErrorCorrection] declaration
/// order: low, medium, quartile, high).
const List<List<EcBlocks>> ecBlockTable = [
  // v1
  [EcBlocks(7, 1, 19), EcBlocks(10, 1, 16), EcBlocks(13, 1, 13), EcBlocks(17, 1, 9)],
  // v2
  [EcBlocks(10, 1, 34), EcBlocks(16, 1, 28), EcBlocks(22, 1, 22), EcBlocks(28, 1, 16)],
  // v3
  [EcBlocks(15, 1, 55), EcBlocks(26, 1, 44), EcBlocks(18, 2, 17), EcBlocks(22, 2, 13)],
  // v4
  [EcBlocks(20, 1, 80), EcBlocks(18, 2, 32), EcBlocks(26, 2, 24), EcBlocks(16, 4, 9)],
  // v5
  [EcBlocks(26, 1, 108), EcBlocks(24, 2, 43), EcBlocks(18, 2, 15, 2, 16), EcBlocks(22, 2, 11, 2, 12)],
  // v6
  [EcBlocks(18, 2, 68), EcBlocks(16, 4, 27), EcBlocks(24, 4, 19), EcBlocks(28, 4, 15)],
  // v7
  [EcBlocks(20, 2, 78), EcBlocks(18, 4, 31), EcBlocks(18, 2, 14, 4, 15), EcBlocks(26, 4, 13, 1, 14)],
  // v8
  [EcBlocks(24, 2, 97), EcBlocks(22, 2, 38, 2, 39), EcBlocks(22, 4, 18, 2, 19), EcBlocks(26, 4, 14, 2, 15)],
  // v9
  [EcBlocks(30, 2, 116), EcBlocks(22, 3, 36, 2, 37), EcBlocks(20, 4, 16, 4, 17), EcBlocks(24, 4, 12, 4, 13)],
  // v10
  [EcBlocks(18, 2, 68, 2, 69), EcBlocks(26, 4, 43, 1, 44), EcBlocks(24, 6, 19, 2, 20), EcBlocks(28, 6, 15, 2, 16)],
  // v11
  [EcBlocks(20, 4, 81), EcBlocks(30, 1, 50, 4, 51), EcBlocks(28, 4, 22, 4, 23), EcBlocks(24, 3, 12, 8, 13)],
  // v12
  [EcBlocks(24, 2, 92, 2, 93), EcBlocks(22, 6, 36, 2, 37), EcBlocks(26, 4, 20, 6, 21), EcBlocks(28, 7, 14, 4, 15)],
  // v13
  [EcBlocks(26, 4, 107), EcBlocks(22, 8, 37, 1, 38), EcBlocks(24, 8, 20, 4, 21), EcBlocks(22, 12, 11, 4, 12)],
  // v14
  [EcBlocks(30, 3, 115, 1, 116), EcBlocks(24, 4, 40, 5, 41), EcBlocks(20, 11, 16, 5, 17), EcBlocks(24, 11, 12, 5, 13)],
  // v15
  [EcBlocks(22, 5, 87, 1, 88), EcBlocks(24, 5, 41, 5, 42), EcBlocks(30, 5, 24, 7, 25), EcBlocks(24, 11, 12, 7, 13)],
  // v16
  [EcBlocks(24, 5, 98, 1, 99), EcBlocks(28, 7, 45, 3, 46), EcBlocks(24, 15, 19, 2, 20), EcBlocks(30, 3, 15, 13, 16)],
  // v17
  [EcBlocks(28, 1, 107, 5, 108), EcBlocks(28, 10, 46, 1, 47), EcBlocks(28, 1, 22, 15, 23), EcBlocks(28, 2, 14, 17, 15)],
  // v18
  [EcBlocks(30, 5, 120, 1, 121), EcBlocks(26, 9, 43, 4, 44), EcBlocks(28, 17, 22, 1, 23), EcBlocks(28, 2, 14, 19, 15)],
  // v19
  [EcBlocks(28, 3, 113, 4, 114), EcBlocks(26, 3, 44, 11, 45), EcBlocks(26, 17, 21, 4, 22), EcBlocks(26, 9, 13, 16, 14)],
  // v20
  [EcBlocks(28, 3, 107, 5, 108), EcBlocks(26, 3, 41, 13, 42), EcBlocks(30, 15, 24, 5, 25), EcBlocks(28, 15, 15, 10, 16)],
  // v21
  [EcBlocks(28, 4, 116, 4, 117), EcBlocks(26, 17, 42), EcBlocks(28, 17, 22, 6, 23), EcBlocks(30, 19, 16, 6, 17)],
  // v22
  [EcBlocks(28, 2, 111, 7, 112), EcBlocks(28, 17, 46), EcBlocks(30, 7, 24, 16, 25), EcBlocks(24, 34, 13)],
  // v23
  [EcBlocks(30, 4, 121, 5, 122), EcBlocks(28, 4, 47, 14, 48), EcBlocks(30, 11, 24, 14, 25), EcBlocks(30, 16, 15, 14, 16)],
  // v24
  [EcBlocks(30, 6, 117, 4, 118), EcBlocks(28, 6, 45, 14, 46), EcBlocks(30, 11, 24, 16, 25), EcBlocks(30, 30, 16, 2, 17)],
  // v25
  [EcBlocks(26, 8, 106, 4, 107), EcBlocks(28, 8, 47, 13, 48), EcBlocks(30, 7, 24, 22, 25), EcBlocks(30, 22, 15, 13, 16)],
  // v26
  [EcBlocks(28, 10, 114, 2, 115), EcBlocks(28, 19, 46, 4, 47), EcBlocks(28, 28, 22, 6, 23), EcBlocks(30, 33, 16, 4, 17)],
  // v27
  [EcBlocks(30, 8, 122, 4, 123), EcBlocks(28, 22, 45, 3, 46), EcBlocks(30, 8, 23, 26, 24), EcBlocks(30, 12, 15, 28, 16)],
  // v28
  [EcBlocks(30, 3, 117, 10, 118), EcBlocks(28, 3, 45, 23, 46), EcBlocks(30, 4, 24, 31, 25), EcBlocks(30, 11, 15, 31, 16)],
  // v29
  [EcBlocks(30, 7, 116, 7, 117), EcBlocks(28, 21, 45, 7, 46), EcBlocks(30, 1, 23, 37, 24), EcBlocks(30, 19, 15, 26, 16)],
  // v30
  [EcBlocks(30, 5, 115, 10, 116), EcBlocks(28, 19, 47, 10, 48), EcBlocks(30, 15, 24, 25, 25), EcBlocks(30, 23, 15, 25, 16)],
  // v31
  [EcBlocks(30, 13, 115, 3, 116), EcBlocks(28, 2, 46, 29, 47), EcBlocks(30, 42, 24, 1, 25), EcBlocks(30, 23, 15, 28, 16)],
  // v32
  [EcBlocks(30, 17, 115), EcBlocks(28, 10, 46, 23, 47), EcBlocks(30, 10, 24, 35, 25), EcBlocks(30, 19, 15, 35, 16)],
  // v33
  [EcBlocks(30, 17, 115, 1, 116), EcBlocks(28, 14, 46, 21, 47), EcBlocks(30, 29, 24, 19, 25), EcBlocks(30, 11, 15, 46, 16)],
  // v34
  [EcBlocks(30, 13, 115, 6, 116), EcBlocks(28, 14, 46, 23, 47), EcBlocks(30, 44, 24, 7, 25), EcBlocks(30, 59, 16, 1, 17)],
  // v35
  [EcBlocks(30, 12, 121, 7, 122), EcBlocks(28, 12, 47, 26, 48), EcBlocks(30, 39, 24, 14, 25), EcBlocks(30, 22, 15, 41, 16)],
  // v36
  [EcBlocks(30, 6, 121, 14, 122), EcBlocks(28, 6, 47, 34, 48), EcBlocks(30, 46, 24, 10, 25), EcBlocks(30, 2, 15, 64, 16)],
  // v37
  [EcBlocks(30, 17, 122, 4, 123), EcBlocks(28, 29, 46, 14, 47), EcBlocks(30, 49, 24, 10, 25), EcBlocks(30, 24, 15, 46, 16)],
  // v38
  [EcBlocks(30, 4, 122, 18, 123), EcBlocks(28, 13, 46, 32, 47), EcBlocks(30, 48, 24, 14, 25), EcBlocks(30, 42, 15, 32, 16)],
  // v39
  [EcBlocks(30, 20, 117, 4, 118), EcBlocks(28, 40, 47, 7, 48), EcBlocks(30, 43, 24, 22, 25), EcBlocks(30, 10, 15, 67, 16)],
  // v40
  [EcBlocks(30, 19, 118, 6, 119), EcBlocks(28, 18, 47, 31, 48), EcBlocks(30, 34, 24, 34, 25), EcBlocks(30, 20, 15, 61, 16)],
];

EcBlocks ecBlocksFor(int version, QrErrorCorrection level) {
  // Table columns are stored [L, M, Q, H]; enum declaration order matches.
  return ecBlockTable[version - 1][level.index];
}

/// Alignment pattern center coordinates per version (empty for v1).
const List<List<int>> alignmentPositions = [
  [], // v1
  [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], // v2–6
  [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50], [6, 30, 54], // v7–11
  [6, 32, 58], [6, 34, 62], // v12–13
  [6, 26, 46, 66], [6, 26, 48, 70], [6, 26, 50, 74], [6, 30, 54, 78], // v14–17
  [6, 30, 56, 82], [6, 30, 58, 86], [6, 34, 62, 90], // v18–20
  [6, 28, 50, 72, 94], [6, 26, 50, 74, 98], [6, 30, 54, 78, 102], // v21–23
  [6, 28, 54, 80, 106], [6, 32, 58, 84, 110], [6, 30, 58, 86, 114], // v24–26
  [6, 34, 62, 90, 118], // v27
  [6, 26, 50, 74, 98, 122], [6, 30, 54, 78, 102, 126], // v28–29
  [6, 26, 52, 78, 104, 130], [6, 30, 56, 82, 108, 134], // v30–31
  [6, 34, 60, 86, 112, 138], [6, 30, 58, 86, 114, 142], // v32–33
  [6, 34, 62, 90, 118, 146], // v34
  [6, 30, 54, 78, 102, 126, 150], [6, 24, 50, 76, 102, 128, 154], // v35–36
  [6, 28, 54, 80, 106, 132, 158], [6, 32, 58, 84, 110, 136, 162], // v37–38
  [6, 26, 54, 82, 110, 138, 166], [6, 30, 58, 86, 114, 142, 170], // v39–40
];

/// Number of bits in the character-count field for a mode at a version.
int characterCountBits(int modeIndicator, int version) {
  final group = version <= 9 ? 0 : (version <= 26 ? 1 : 2);
  switch (modeIndicator) {
    case 0x1: // numeric
      return const [10, 12, 14][group];
    case 0x2: // alphanumeric
      return const [9, 11, 13][group];
    case 0x4: // byte
      return const [8, 16, 16][group];
    case 0x8: // kanji
      return const [8, 10, 12][group];
    default:
      throw ArgumentError('Unknown mode indicator: $modeIndicator');
  }
}

/// Number of data-carrying modules in a version's symbol (everything except
/// function patterns, format info, and version info).
int rawDataModules(int version) {
  var bits = (16 * version + 128) * version + 64;
  if (version >= 2) {
    final numAlign = version ~/ 7 + 2;
    bits -= (25 * numAlign - 10) * numAlign - 55;
    if (version >= 7) bits -= 36;
  }
  return bits;
}

/// Total codewords (data + EC) that fit in a version's symbol. The 0–7 bits
/// left over are remainder bits, always set to 0 during placement.
int totalCodewords(int version) => rawDataModules(version) ~/ 8;
