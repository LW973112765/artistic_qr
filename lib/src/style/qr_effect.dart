import 'package:flutter/painting.dart';

/// Pseudo-3D depth effects applied to the modules and eyes.
///
/// All effects keep the module centers untouched, so scannability is
/// preserved (the decode test suite covers each one), but stick to
/// generous quiet zones and strong contrast when combining them.
sealed class QrEffect {
  const QrEffect();

  /// Flat rendering (default).
  static const QrEffect none = QrNoEffect();

  /// Extrudes every module into a 3D block: a solid "side" is drawn
  /// down-right beneath each shape, like isometric pixel art.
  const factory QrEffect.extruded({double depth, Color? color}) =
      QrExtrudedEffect;

  /// A soft drop shadow under the modules and eyes — the "floating
  /// sticker" look.
  const factory QrEffect.shadow({double blur, Offset offset, Color color}) =
      QrShadowEffect;

  /// Bevel lighting: a light top-left edge and dark bottom-right edge
  /// inside each module, like embossed buttons. Canvas/PNG only (ignored
  /// in SVG export).
  const factory QrEffect.emboss({double strength}) = QrEmbossEffect;

  Map<String, dynamic> toJson() => switch (this) {
        QrNoEffect() => {'type': 'none'},
        QrExtrudedEffect(:final depth, :final color) => {
            'type': 'extruded',
            'depth': depth,
            'color': color?.toARGB32(),
          },
        QrShadowEffect(:final blur, :final offset, :final color) => {
            'type': 'shadow',
            'blur': blur,
            'offset': [offset.dx, offset.dy],
            'color': color.toARGB32(),
          },
        QrEmbossEffect(:final strength) => {
            'type': 'emboss',
            'strength': strength,
          },
      };

  static QrEffect fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'none':
        return none;
      case 'extruded':
        return QrExtrudedEffect(
          depth: (json['depth'] as num).toDouble(),
          color: json['color'] == null ? null : Color(json['color'] as int),
        );
      case 'shadow':
        final offset = json['offset'] as List;
        return QrShadowEffect(
          blur: (json['blur'] as num).toDouble(),
          offset: Offset((offset[0] as num).toDouble(),
              (offset[1] as num).toDouble()),
          color: Color(json['color'] as int),
        );
      case 'emboss':
        return QrEmbossEffect(strength: (json['strength'] as num).toDouble());
      default:
        throw FormatException('Unknown effect type: ${json['type']}');
    }
  }
}

class QrNoEffect extends QrEffect {
  const QrNoEffect();
}

class QrExtrudedEffect extends QrEffect {
  const QrExtrudedEffect({this.depth = 0.28, this.color})
      : assert(depth > 0 && depth <= 0.6,
            'extrusion beyond 0.6 modules fills the gaps between modules');

  /// Extrusion length in module units (0.28 ≈ a subtle block look).
  final double depth;

  /// Side color; defaults to a darkened version of the module fill.
  final Color? color;
}

class QrShadowEffect extends QrEffect {
  const QrShadowEffect({
    this.blur = 0.35,
    this.offset = const Offset(0.22, 0.28),
    this.color = const Color(0x59000000),
  }) : assert(blur >= 0);

  /// Blur radius in module units.
  final double blur;

  /// Shadow offset in module units.
  final Offset offset;

  final Color color;
}

class QrEmbossEffect extends QrEffect {
  const QrEmbossEffect({this.strength = 0.6})
      : assert(strength > 0 && strength <= 1);

  /// Opacity of the highlight/shade edges (0–1).
  final double strength;
}
