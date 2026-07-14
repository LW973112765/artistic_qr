import 'package:flutter/painting.dart';

import 'eye_shape.dart';
import 'module_shape.dart';
import 'qr_effect.dart';
import 'qr_fill.dart';
import 'qr_style.dart';

/// Curated ready-made styles. Use them directly or as a starting point:
///
/// ```dart
/// ArtisticQrCode(data: url, style: QrStylePresets.ocean)
/// ArtisticQrCode(data: url, style: QrStylePresets.sunset.copyWith(quietZone: 6))
/// ```
///
/// Every preset ships decode-verified in the test suite.
abstract final class QrStylePresets {
  /// Plain black squares — maximum compatibility.
  static const QrStyle classic = QrStyle();

  /// Fluid teal-to-blue gradient with rounded eyes.
  static final QrStyle ocean = QrStyle(
    moduleShape: ModuleShape.fluid,
    fill: QrFill.linearGradient(
      colors: const [Color(0xFF00838F), Color(0xFF1565C0)],
    ),
    eyeStyle: const QrEyeStyle(
      frame: EyeFrameShape.rounded(),
      pupil: EyePupilShape.rounded(),
      frameFill: QrFill.solid(Color(0xFF006064)),
    ),
  );

  /// Warm rounded dots fading from deep orange to magenta.
  static final QrStyle sunset = QrStyle(
    moduleShape: const ModuleShape.rounded(),
    moduleScale: 0.92,
    fill: QrFill.linearGradient(
      colors: const [Color(0xFFBF360C), Color(0xFF880E4F)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    eyeStyle: const QrEyeStyle(
      frame: EyeFrameShape.rounded(),
      pupil: EyePupilShape.circle,
      frameFill: QrFill.solid(Color(0xFFBF360C)),
      pupilFill: QrFill.solid(Color(0xFF880E4F)),
    ),
  );

  /// Classy green modules with leaf eyes.
  static const QrStyle forest = QrStyle(
    moduleShape: ModuleShape.classy,
    fill: QrFill.solid(Color(0xFF1B5E20)),
    eyeStyle: QrEyeStyle(
      frame: EyeFrameShape.leaf,
      pupil: EyePupilShape.leaf,
      frameFill: QrFill.solid(Color(0xFF2E7D32)),
    ),
  );

  /// Airy circle dots in a pink-violet radial glow.
  static final QrStyle candy = QrStyle(
    moduleShape: ModuleShape.circle,
    moduleScale: 0.85,
    fill: QrFill.radialGradient(
      colors: const [Color(0xFFAD1457), Color(0xFF4A148C)],
      radius: 0.9,
    ),
    eyeStyle: const QrEyeStyle(
      frame: EyeFrameShape.circle,
      pupil: EyePupilShape.circle,
      frameFill: QrFill.solid(Color(0xFFAD1457)),
    ),
  );

  /// Near-black indigo with a subtle drop shadow — the floating sticker.
  static const QrStyle paper = QrStyle(
    moduleShape: ModuleShape.rounded(),
    moduleScale: 0.9,
    fill: QrFill.solid(Color(0xFF1A237E)),
    effect: QrEffect.shadow(),
    eyeStyle: QrEyeStyle(
      frame: EyeFrameShape.rounded(),
      pupil: EyePupilShape.rounded(),
    ),
  );

  /// Isometric 3D blocks.
  static const QrStyle blocks3d = QrStyle(
    moduleShape: ModuleShape.square,
    moduleScale: 0.72,
    fill: QrFill.solid(Color(0xFF283593)),
    effect: QrEffect.extruded(depth: 0.4),
    eyeStyle: QrEyeStyle(
      frame: EyeFrameShape.rounded(),
      pupil: EyePupilShape.rounded(),
      frameFill: QrFill.solid(Color(0xFF283593)),
    ),
  );

  /// Cyan→violet sweep with star sparkle modules.
  static final QrStyle neon = QrStyle(
    moduleShape: const ModuleShape.star(inset: 0.55),
    moduleScale: 0.98,
    fill: QrFill.sweepGradient(
      colors: const [
        Color(0xFF006064),
        Color(0xFF4A148C),
        Color(0xFF006064),
      ],
    ),
    eyeStyle: const QrEyeStyle(
      frame: EyeFrameShape.circle,
      pupil: EyePupilShape.circle,
      frameFill: QrFill.solid(Color(0xFF4A148C)),
    ),
  );

  /// All presets by name (handy for building preset pickers).
  static final Map<String, QrStyle> all = {
    'classic': classic,
    'ocean': ocean,
    'sunset': sunset,
    'forest': forest,
    'candy': candy,
    'paper': paper,
    'blocks3d': blocks3d,
    'neon': neon,
  };
}
