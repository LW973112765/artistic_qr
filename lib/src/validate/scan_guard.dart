import 'package:flutter/painting.dart';

import '../encoder/qr_encoder.dart';
import '../encoder/tables.dart';
import '../image/qr_image.dart';
import '../style/qr_fill.dart';
import '../style/qr_style.dart';

/// A single scannability concern found in a design.
class QrScanWarning {
  const QrScanWarning(this.code, this.message);

  /// Stable identifier (e.g. `low-contrast`, `logo-too-large`).
  final String code;
  final String message;

  @override
  String toString() => 'QrScanWarning($code): $message';
}

/// Checks a design for choices that commonly break real-world scanning.
///
/// This is heuristic — always test final designs with real phone cameras —
/// but it catches the classic mistakes: low contrast, oversized logos for
/// the EC level, missing quiet zone, and heavy art modes on low EC.
List<QrScanWarning> validateQrDesign({
  required QrCode code,
  QrStyle style = const QrStyle(),
  QrImageMode? imageMode,
}) {
  final warnings = <QrScanWarning>[];

  // 1. Contrast between fill and background.
  final backgroundLum = _luminance(style.background.representativeColor);
  for (final color in _fillColors(style.fill)) {
    final diff = (backgroundLum - _luminance(color)).abs();
    if (diff < 0.35) {
      warnings.add(QrScanWarning(
        'low-contrast',
        'Fill ${_hex(color)} vs background has luminance difference '
            '${diff.toStringAsFixed(2)} (< 0.35); many cameras will fail. '
            'Darken the fill or lighten the background.',
      ));
    }
  }

  // 2. Quiet zone.
  if (style.quietZone < 2) {
    warnings.add(const QrScanWarning(
      'quiet-zone',
      'Quiet zone below 2 modules: scanners need clear space around the '
          'symbol (the spec asks for 4).',
    ));
  }

  // 3. Tiny dots.
  if (style.moduleScale < 0.6) {
    warnings.add(QrScanWarning(
      'small-modules',
      'moduleScale ${style.moduleScale} leaves very small dots; below ~0.6 '
          'low-end cameras start missing modules.',
    ));
  }

  // 4. Image modes vs error correction.
  switch (imageMode) {
    case QrLogoMode(:final scale, :final knockout):
      final ec = ecBlocksFor(code.version, code.errorCorrection);
      // Codewords the logo area can destroy (worst case) vs what RS can fix.
      final totalCw = totalCodewords(code.version);
      final coveredFraction = scale * scale * (knockout ? 1.3 : 1.0);
      final destroyed = (coveredFraction * totalCw).ceil();
      final recoverable = ec.totalBlocks * (ec.ecCodewordsPerBlock ~/ 2);
      if (destroyed > recoverable * 0.65) {
        warnings.add(QrScanWarning(
          'logo-too-large',
          'Logo scale $scale can destroy ~$destroyed codewords but EC level '
              '${code.errorCorrection.letter} recovers at most $recoverable. '
              'Shrink the logo or raise the error-correction level.',
        ));
      }
    case QrBlendMode() || QrHalftoneMode():
      if (code.errorCorrection != QrErrorCorrection.high) {
        warnings.add(QrScanWarning(
          'art-mode-needs-ec-high',
          'Blend/halftone modes consume error-correction headroom; use '
              'QrErrorCorrection.high (currently '
              '${code.errorCorrection.letter}).',
        ));
      }
    case null:
      break;
  }

  return warnings;
}

List<Color> _fillColors(QrFill fill) => switch (fill) {
      QrSolidFill(:final color) => [color],
      QrGradientFill(:final gradient) => gradient.colors,
    };

double _luminance(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

String _hex(Color c) {
  String h(double v) =>
      (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}
