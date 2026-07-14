import 'package:flutter/painting.dart';

import '../encoder/matrix.dart';
import '../encoder/qr_encoder.dart';
import '../style/module_shape.dart';
import '../style/qr_style.dart';

/// Shared layout math for all renderers (canvas, PNG, SVG), so every export
/// of the same code/style pair is geometrically identical.
class QrLayout {
  QrLayout({required this.code, required this.style, required Size size})
      : moduleSize = size.shortestSide / (code.size + 2 * style.quietZone),
        origin = Offset(
          (size.width - size.shortestSide) / 2 +
              style.quietZone *
                  (size.shortestSide / (code.size + 2 * style.quietZone)),
          (size.height - size.shortestSide) / 2 +
              style.quietZone *
                  (size.shortestSide / (code.size + 2 * style.quietZone)),
        ),
        bounds = Offset.zero & size;

  final QrCode code;
  final QrStyle style;

  /// Side length of one module in output units.
  final double moduleSize;

  /// Top-left corner of module (0, 0).
  final Offset origin;

  /// The full output rect (including quiet zone).
  final Rect bounds;

  QrMatrix get matrix => code.matrix;

  /// Full cell rect of a module.
  Rect moduleRect(int row, int col) => Rect.fromLTWH(
        origin.dx + col * moduleSize,
        origin.dy + row * moduleSize,
        moduleSize,
        moduleSize,
      );

  /// Cell rect shrunk by the style's moduleScale, centered in the cell.
  Rect scaledModuleRect(int row, int col) {
    final rect = moduleRect(row, col);
    return style.moduleScale == 1.0
        ? rect
        : Rect.fromCenter(
            center: rect.center,
            width: rect.width * style.moduleScale,
            height: rect.height * style.moduleScale,
          );
  }

  /// The 7×7-module rect of a finder eye.
  Rect eyeRect(QrEyePosition eye) {
    final n = code.size;
    switch (eye) {
      case QrEyePosition.topLeft:
        return moduleRect(0, 0).expandToInclude(moduleRect(6, 6));
      case QrEyePosition.topRight:
        return moduleRect(0, n - 7).expandToInclude(moduleRect(6, n - 1));
      case QrEyePosition.bottomLeft:
        return moduleRect(n - 7, 0).expandToInclude(moduleRect(n - 1, 6));
    }
  }

  /// Whether this module is drawn by the module-shape pass. The finder eyes
  /// (and their separators) are drawn as whole vector shapes instead.
  bool isModulePainted(int row, int col) {
    if (!matrix.isDark(row, col)) return false;
    final role = matrix.roleAt(row, col);
    return role != QrModuleRole.finder && role != QrModuleRole.separator;
  }

  ModuleNeighbors neighborsOf(int row, int col) {
    bool painted(int r, int c) =>
        r >= 0 &&
        r < code.size &&
        c >= 0 &&
        c < code.size &&
        isModulePainted(r, c);
    return ModuleNeighbors(
      top: painted(row - 1, col),
      bottom: painted(row + 1, col),
      left: painted(row, col - 1),
      right: painted(row, col + 1),
    );
  }
}
