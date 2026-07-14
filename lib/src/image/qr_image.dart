import 'package:flutter/painting.dart';

import 'qr_image_source.dart';

/// An image embedded in the QR code, in one of three modes:
///
///  * [QrImageMode.logo] — the image sits on top at the center, optionally
///    clearing the modules underneath ("knockout").
///  * [QrImageMode.blend] — the modules themselves take the colors of the
///    image beneath them, weaving artwork into the code.
///  * [QrImageMode.halftone] — each module becomes a 3×3 halftone cell:
///    the center subpixel carries the QR data and the rest reproduce the
///    photo, like the classic "face in the QR code" effect.
///
/// Blend and halftone consume error-correction headroom; use
/// [QrErrorCorrection.high] with them (the renderer asserts this in debug).
class QrImage {
  const QrImage({required this.source, this.mode = const QrLogoMode()});

  final QrImageSource source;
  final QrImageMode mode;
}

sealed class QrImageMode {
  const QrImageMode();

  const factory QrImageMode.logo({
    double scale,
    bool knockout,
    double padding,
  }) = QrLogoMode;

  const factory QrImageMode.blend({
    double opacity,
    bool enforceContrast,
    bool includeFunctionPatterns,
    double whiteThreshold,
  }) = QrBlendMode;

  const factory QrImageMode.halftone({
    double brightness,
    bool dithering,
    bool colored,
  }) = QrHalftoneMode;
}

class QrLogoMode extends QrImageMode {
  const QrLogoMode({
    this.scale = 0.22,
    this.knockout = true,
    this.padding = 0.5,
  }) : assert(scale > 0 && scale <= 0.3,
            'logo scale above 0.3 destroys too many codewords');

  /// Logo side length as a fraction of the symbol size (excluding quiet
  /// zone). 0.22 is safe at any EC level; stay ≤ 0.3 even at EC-H.
  final double scale;

  /// Clear the modules behind the logo so it sits on clean background.
  final bool knockout;

  /// Extra cleared margin around the logo, in modules.
  final double padding;
}

class QrBlendMode extends QrImageMode {
  const QrBlendMode({
    this.opacity = 1.0,
    this.enforceContrast = true,
    this.includeFunctionPatterns = false,
    this.whiteThreshold = 0.92,
  });

  /// Blend strength between the style fill (0) and the image color (1).
  final double opacity;

  /// Darkens sampled colors that are too light to scan against the
  /// background. Turn off only for controlled designs you test yourself.
  final bool enforceContrast;

  /// Also recolor timing/alignment/format modules (bolder look, slightly
  /// riskier for scanners).
  final bool includeFunctionPatterns;

  /// Image areas lighter than this luminance (e.g. a logo's white
  /// background) are treated like transparency: the module keeps the
  /// style's fill instead of turning gray. Set to 1.0 to disable.
  final double whiteThreshold;
}

class QrHalftoneMode extends QrImageMode {
  const QrHalftoneMode({
    this.brightness = 0.0,
    this.dithering = true,
    this.colored = false,
  }) : assert(brightness >= -1 && brightness <= 1);

  /// Shifts the halftone threshold: positive values render the photo
  /// lighter (more background), negative darker.
  final double brightness;

  /// Floyd–Steinberg error diffusion for smoother midtones.
  final bool dithering;

  /// Paint halftone dots with the image's (darkened) colors instead of the
  /// module fill.
  final bool colored;
}

/// Where the image is drawn / sampled, produced by the resolver.
class ResolvedQrImage {
  const ResolvedQrImage({required this.pixels, required this.mode});

  final QrImagePixels pixels;
  final QrImageMode mode;

  /// Maps a normalized symbol-space rect (0..1 across the module area) to
  /// normalized image space using a BoxFit.cover mapping, so the image
  /// fills the symbol without distortion.
  Rect symbolToImage(Rect symbolRect) {
    final iw = pixels.width.toDouble();
    final ih = pixels.height.toDouble();
    // cover: scale so the smaller relative dimension fills, crop the other.
    final scale = iw < ih ? iw : ih;
    final dx = (iw - scale) / 2 / iw;
    final dy = (ih - scale) / 2 / ih;
    final sx = scale / iw;
    final sy = scale / ih;
    return Rect.fromLTRB(
      dx + symbolRect.left * sx,
      dy + symbolRect.top * sy,
      dx + symbolRect.right * sx,
      dy + symbolRect.bottom * sy,
    );
  }
}
