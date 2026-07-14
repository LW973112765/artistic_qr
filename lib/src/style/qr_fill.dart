import 'package:flutter/painting.dart';

/// How an element of the QR code (modules, eye frame, eye pupil,
/// background) is filled: a solid color or any Flutter [Gradient]
/// (linear, radial, or sweep).
///
/// Gradients are evaluated over the *whole symbol's* bounds, so colors flow
/// smoothly across all modules rather than restarting inside each dot.
sealed class QrFill {
  const QrFill();

  const factory QrFill.solid(Color color) = QrSolidFill;

  const factory QrFill.gradient(Gradient gradient) = QrGradientFill;

  /// Linear gradient convenience, defaulting to a top-left → bottom-right
  /// sweep like most branded QR designs.
  factory QrFill.linearGradient({
    required List<Color> colors,
    List<double>? stops,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      QrGradientFill(
        LinearGradient(colors: colors, stops: stops, begin: begin, end: end),
      );

  factory QrFill.radialGradient({
    required List<Color> colors,
    List<double>? stops,
    AlignmentGeometry center = Alignment.center,
    double radius = 0.7,
  }) =>
      QrGradientFill(
        RadialGradient(colors: colors, stops: stops, center: center, radius: radius),
      );

  factory QrFill.sweepGradient({
    required List<Color> colors,
    List<double>? stops,
    AlignmentGeometry center = Alignment.center,
  }) =>
      QrGradientFill(SweepGradient(colors: colors, stops: stops, center: center));

  /// Configures [paint] to draw this fill inside [bounds].
  void apply(Paint paint, Rect bounds);

  /// A representative color (used for contrast checks and SVG fallbacks).
  Color get representativeColor;
}

class QrSolidFill extends QrFill {
  const QrSolidFill(this.color);

  final Color color;

  @override
  void apply(Paint paint, Rect bounds) {
    paint
      ..shader = null
      ..color = color;
  }

  @override
  Color get representativeColor => color;

  @override
  bool operator ==(Object other) => other is QrSolidFill && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

class QrGradientFill extends QrFill {
  const QrGradientFill(this.gradient);

  final Gradient gradient;

  @override
  void apply(Paint paint, Rect bounds) {
    paint.shader = gradient.createShader(bounds);
  }

  @override
  Color get representativeColor => gradient.colors.first;

  @override
  bool operator ==(Object other) =>
      other is QrGradientFill && other.gradient == gradient;

  @override
  int get hashCode => gradient.hashCode;
}
