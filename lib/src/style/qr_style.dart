import 'package:flutter/painting.dart';

import '../encoder/matrix.dart';
import 'eye_shape.dart';
import 'module_shape.dart';
import 'qr_fill.dart';

/// Styling for the three finder "eyes".
class QrEyeStyle {
  const QrEyeStyle({
    this.frame = EyeFrameShape.square,
    this.pupil = EyePupilShape.square,
    this.frameFill,
    this.pupilFill,
  });

  final EyeFrameShape frame;
  final EyePupilShape pupil;

  /// Defaults to the module fill when null.
  final QrFill? frameFill;

  /// Defaults to [frameFill] (or the module fill) when null.
  final QrFill? pupilFill;

  QrEyeStyle copyWith({
    EyeFrameShape? frame,
    EyePupilShape? pupil,
    QrFill? frameFill,
    QrFill? pupilFill,
  }) =>
      QrEyeStyle(
        frame: frame ?? this.frame,
        pupil: pupil ?? this.pupil,
        frameFill: frameFill ?? this.frameFill,
        pupilFill: pupilFill ?? this.pupilFill,
      );
}

/// The complete visual configuration of a QR code.
///
/// Everything is optional: the default renders a classic black-on-white
/// square QR. See the example gallery for configurations matching common
/// artistic styles.
class QrStyle {
  const QrStyle({
    this.moduleShape = ModuleShape.square,
    this.moduleScale = 1.0,
    this.fill = const QrFill.solid(Color(0xFF000000)),
    this.eyeStyle = const QrEyeStyle(),
    this.eyeStyleOverrides = const {},
    this.background = const QrFill.solid(Color(0xFFFFFFFF)),
    this.quietZone = 4,
  })  : assert(moduleScale > 0 && moduleScale <= 1),
        assert(quietZone >= 0);

  /// Shape of each dark module.
  final ModuleShape moduleShape;

  /// Fraction of the module cell each dot occupies (1.0 = touching).
  /// Values around 0.8–0.9 give the airy "dotted" look; going below ~0.6
  /// risks scannability on low-end cameras.
  final double moduleScale;

  /// Fill for the dark modules (and non-eye function patterns).
  final QrFill fill;

  /// Style applied to all three eyes.
  final QrEyeStyle eyeStyle;

  /// Per-eye overrides, e.g. `{QrEyePosition.topRight: QrEyeStyle(...)}`.
  final Map<QrEyePosition, QrEyeStyle> eyeStyleOverrides;

  /// Background fill. Use a transparent solid color for no background.
  final QrFill background;

  /// Light border around the symbol, in modules. The spec requires 4;
  /// don't go below 2 if you want reliable scanning.
  final int quietZone;

  QrEyeStyle eyeStyleFor(QrEyePosition position) =>
      eyeStyleOverrides[position] ?? eyeStyle;

  QrStyle copyWith({
    ModuleShape? moduleShape,
    double? moduleScale,
    QrFill? fill,
    QrEyeStyle? eyeStyle,
    Map<QrEyePosition, QrEyeStyle>? eyeStyleOverrides,
    QrFill? background,
    int? quietZone,
  }) =>
      QrStyle(
        moduleShape: moduleShape ?? this.moduleShape,
        moduleScale: moduleScale ?? this.moduleScale,
        fill: fill ?? this.fill,
        eyeStyle: eyeStyle ?? this.eyeStyle,
        eyeStyleOverrides: eyeStyleOverrides ?? this.eyeStyleOverrides,
        background: background ?? this.background,
        quietZone: quietZone ?? this.quietZone,
      );
}
