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

  /// Serializes this fill. Gradients support linear/radial/sweep with
  /// [Alignment] geometry; anything else throws [UnsupportedError].
  Map<String, dynamic> toJson();

  static QrFill fromJson(Map<String, dynamic> json) {
    List<Color> colors() =>
        [for (final v in json['colors'] as List) Color(v as int)];
    List<double>? stops() => json['stops'] == null
        ? null
        : [for (final v in json['stops'] as List) (v as num).toDouble()];
    Alignment point(String key) {
      final list = json[key] as List;
      return Alignment(
          (list[0] as num).toDouble(), (list[1] as num).toDouble());
    }

    switch (json['type']) {
      case 'solid':
        return QrSolidFill(Color(json['color'] as int));
      case 'linear':
        return QrGradientFill(LinearGradient(
            colors: colors(),
            stops: stops(),
            begin: point('begin'),
            end: point('end')));
      case 'radial':
        return QrGradientFill(RadialGradient(
            colors: colors(),
            stops: stops(),
            center: point('center'),
            radius: (json['radius'] as num).toDouble()));
      case 'sweep':
        return QrGradientFill(SweepGradient(
            colors: colors(), stops: stops(), center: point('center')));
      default:
        throw FormatException('Unknown fill type: ${json['type']}');
    }
  }
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
  Map<String, dynamic> toJson() =>
      {'type': 'solid', 'color': color.toARGB32()};

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
  Map<String, dynamic> toJson() {
    List<int> colors() => [for (final c in gradient.colors) c.toARGB32()];
    List<double> point(AlignmentGeometry alignment) {
      if (alignment is! Alignment) {
        throw UnsupportedError(
            'Only Alignment geometry can be serialized (got $alignment)');
      }
      return [alignment.x, alignment.y];
    }

    switch (gradient) {
      case LinearGradient(:final begin, :final end):
        return {
          'type': 'linear',
          'colors': colors(),
          'stops': gradient.stops,
          'begin': point(begin),
          'end': point(end),
        };
      case RadialGradient(:final center, :final radius):
        return {
          'type': 'radial',
          'colors': colors(),
          'stops': gradient.stops,
          'center': point(center),
          'radius': radius,
        };
      case SweepGradient(:final center):
        return {
          'type': 'sweep',
          'colors': colors(),
          'stops': gradient.stops,
          'center': point(center),
        };
      default:
        throw UnsupportedError(
            '${gradient.runtimeType} cannot be serialized to JSON');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is QrGradientFill && other.gradient == gradient;

  @override
  int get hashCode => gradient.hashCode;
}
