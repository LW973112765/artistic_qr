import 'dart:typed_data';

/// What a module is *for*. Renderers use this to style the three finder eyes
/// independently, keep function patterns solid in halftone/blend image modes,
/// and know which modules can safely be recolored.
enum QrModuleRole {
  /// Not yet assigned (only during construction; never in a finished matrix).
  none,

  /// Part of one of the three 7×7 finder patterns (the "eyes").
  finder,

  /// The 1-module light separator ring around each finder pattern.
  separator,

  /// Part of a 5×5 alignment pattern.
  alignment,

  /// The alternating timing lines (row 6 / column 6).
  timing,

  /// Format information (EC level + mask id).
  format,

  /// Version information (versions ≥ 7 only).
  version,

  /// The single always-dark module next to the bottom-left finder.
  dark,

  /// Data or error-correction codeword bits — the artistic canvas.
  data,
}

/// Which of the three finder eyes a module belongs to.
enum QrEyePosition { topLeft, topRight, bottomLeft }

/// The final QR module grid plus per-module role metadata.
class QrMatrix {
  QrMatrix(this.size)
      : _dark = Uint8List(size * size),
        _roles = Uint8List(size * size);

  /// Modules per side (17 + 4·version).
  final int size;

  final Uint8List _dark;
  final Uint8List _roles;

  bool isDark(int row, int col) => _dark[row * size + col] != 0;

  QrModuleRole roleAt(int row, int col) =>
      QrModuleRole.values[_roles[row * size + col]];

  bool isFunction(int row, int col) {
    final role = roleAt(row, col);
    return role != QrModuleRole.data && role != QrModuleRole.none;
  }

  void set(int row, int col, {required bool dark, required QrModuleRole role}) {
    final i = row * size + col;
    _dark[i] = dark ? 1 : 0;
    _roles[i] = role.index;
  }

  void setDark(int row, int col, bool dark) {
    _dark[row * size + col] = dark ? 1 : 0;
  }

  bool isAssigned(int row, int col) =>
      _roles[row * size + col] != QrModuleRole.none.index;

  /// If (row, col) is inside a 7×7 finder pattern, returns which eye.
  QrEyePosition? eyeAt(int row, int col) {
    if (row < 7 && col < 7) return QrEyePosition.topLeft;
    if (row < 7 && col >= size - 7) return QrEyePosition.topRight;
    if (row >= size - 7 && col < 7) return QrEyePosition.bottomLeft;
    return null;
  }
}
