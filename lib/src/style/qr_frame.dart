import 'package:flutter/painting.dart';

/// Where the frame's label banner sits.
enum QrFrameLabelPosition { top, bottom }

/// A decorative frame around the QR code: a rounded border plus a solid
/// banner with a call-to-action label ("SCAN ME") — the classic marketing
/// frame. Rendered by the painter, PNG export, and SVG export alike.
///
/// The QR keeps its own quiet zone inside the frame, so scannability is
/// unaffected.
class QrFrame {
  const QrFrame({
    this.text = 'SCAN ME',
    this.labelPosition = QrFrameLabelPosition.bottom,
    this.color = const Color(0xFF000000),
    this.textColor = const Color(0xFFFFFFFF),
    this.borderWidth = 0.025,
    this.cornerRadius = 0.07,
    this.labelHeight = 0.15,
    this.fontFamily,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = 1.5,
  })  : assert(borderWidth >= 0 && borderWidth <= 0.1),
        assert(cornerRadius >= 0 && cornerRadius <= 0.25),
        assert(labelHeight > 0.05 && labelHeight <= 0.3);

  /// The call-to-action label. An empty string hides the banner and keeps
  /// just the border.
  final String text;

  final QrFrameLabelPosition labelPosition;

  /// Border + banner color.
  final Color color;

  final Color textColor;

  /// Stroke width as a fraction of the total side.
  final double borderWidth;

  /// Corner radius as a fraction of the total side.
  final double cornerRadius;

  /// Banner height as a fraction of the total side.
  final double labelHeight;

  /// Custom font family for the label (defaults to the platform font; the
  /// SVG export uses a generic sans-serif stack).
  final String? fontFamily;

  final FontWeight fontWeight;
  final double letterSpacing;

  Map<String, dynamic> toJson() => {
        'text': text,
        'labelPosition': labelPosition.name,
        'color': color.toARGB32(),
        'textColor': textColor.toARGB32(),
        'borderWidth': borderWidth,
        'cornerRadius': cornerRadius,
        'labelHeight': labelHeight,
        'fontFamily': fontFamily,
        'fontWeight': fontWeight.index,
        'letterSpacing': letterSpacing,
      };

  factory QrFrame.fromJson(Map<String, dynamic> json) => QrFrame(
        text: json['text'] as String,
        labelPosition:
            QrFrameLabelPosition.values.byName(json['labelPosition'] as String),
        color: Color(json['color'] as int),
        textColor: Color(json['textColor'] as int),
        borderWidth: (json['borderWidth'] as num).toDouble(),
        cornerRadius: (json['cornerRadius'] as num).toDouble(),
        labelHeight: (json['labelHeight'] as num).toDouble(),
        fontFamily: json['fontFamily'] as String?,
        fontWeight: FontWeight.values[json['fontWeight'] as int],
        letterSpacing: (json['letterSpacing'] as num).toDouble(),
      );

  QrFrame copyWith({
    String? text,
    QrFrameLabelPosition? labelPosition,
    Color? color,
    Color? textColor,
    double? borderWidth,
    double? cornerRadius,
    double? labelHeight,
    String? fontFamily,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) =>
      QrFrame(
        text: text ?? this.text,
        labelPosition: labelPosition ?? this.labelPosition,
        color: color ?? this.color,
        textColor: textColor ?? this.textColor,
        borderWidth: borderWidth ?? this.borderWidth,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        labelHeight: labelHeight ?? this.labelHeight,
        fontFamily: fontFamily ?? this.fontFamily,
        fontWeight: fontWeight ?? this.fontWeight,
        letterSpacing: letterSpacing ?? this.letterSpacing,
      );
}

/// Shared frame geometry so canvas and SVG renderers agree exactly.
class QrFrameGeometry {
  QrFrameGeometry._({
    required this.outerRect,
    required this.bannerRect,
    required this.qrRect,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.fontSize,
    required this.hasBanner,
  });

  factory QrFrameGeometry.compute(QrFrame frame, Size size) {
    final side = size.shortestSide;
    final square = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final strokeWidth = frame.borderWidth * side;
    final radius = frame.cornerRadius * side;
    final hasBanner = frame.text.isNotEmpty;
    final bannerH = hasBanner ? frame.labelHeight * side : 0.0;

    final outerRect = square.deflate(strokeWidth / 2);

    final Rect bannerRect;
    final Rect contentRect;
    final pad = strokeWidth * 1.5;
    if (frame.labelPosition == QrFrameLabelPosition.bottom) {
      bannerRect =
          Rect.fromLTRB(square.left, square.bottom - bannerH, square.right, square.bottom);
      contentRect = Rect.fromLTRB(square.left + pad, square.top + pad,
          square.right - pad, bannerRect.top - strokeWidth / 2);
    } else {
      bannerRect =
          Rect.fromLTRB(square.left, square.top, square.right, square.top + bannerH);
      contentRect = Rect.fromLTRB(square.left + pad,
          bannerRect.bottom + strokeWidth / 2, square.right - pad, square.bottom - pad);
    }

    final qrSide = contentRect.shortestSide;
    final qrRect = Rect.fromCenter(
        center: contentRect.center, width: qrSide, height: qrSide);

    return QrFrameGeometry._(
      outerRect: outerRect,
      bannerRect: bannerRect,
      qrRect: qrRect,
      strokeWidth: strokeWidth,
      cornerRadius: radius,
      fontSize: bannerH * 0.45,
      hasBanner: hasBanner,
    );
  }

  /// The border rect (stroke centered on it).
  final Rect outerRect;

  /// The solid label banner (zero-height when the text is empty).
  final Rect bannerRect;

  /// Where the QR symbol itself is painted.
  final Rect qrRect;

  final double strokeWidth;
  final double cornerRadius;
  final double fontSize;
  final bool hasBanner;
}
