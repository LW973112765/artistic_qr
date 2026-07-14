import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../encoder/matrix.dart';
import '../encoder/qr_encoder.dart';
import '../image/qr_image_renderer.dart';
import '../style/qr_effect.dart';
import '../style/qr_fill.dart';
import '../style/qr_frame.dart';
import '../style/qr_style.dart';
import 'qr_geometry.dart';

/// Paints an encoded [QrCode] with a [QrStyle].
///
/// The optional hooks are used by the image-integration modes:
///  * [moduleColorResolver] recolors individual modules (blend mode),
///  * [skipModule] leaves modules unpainted (logo knockout),
///  * [foregroundPainter] draws on top (centered logo, halftone art).
class QrPainter extends CustomPainter {
  QrPainter({
    required this.code,
    this.style = const QrStyle(),
    this.frame,
    this.moduleColorResolver,
    this.skipModule,
    this.foregroundPainter,
    this.halftone,
    super.repaint,
  });

  /// Builds a painter with an embedded image (logo / blend / halftone mode)
  /// already wired up.
  factory QrPainter.withImage({
    required QrCode code,
    required QrImageRenderData imageData,
    QrStyle style = const QrStyle(),
    QrFrame? frame,
    Listenable? repaint,
  }) =>
      QrPainter(
        code: code,
        style: style,
        frame: frame,
        moduleColorResolver: imageData.moduleColorResolver,
        skipModule: imageData.skipModule,
        foregroundPainter: imageData.foregroundPainter,
        halftone: imageData.halftone,
        repaint: repaint,
      );

  final QrCode code;
  final QrStyle style;

  /// Optional decorative border + "SCAN ME" banner around the code.
  final QrFrame? frame;

  final Color? Function(int row, int col)? moduleColorResolver;
  final bool Function(int row, int col)? skipModule;
  final void Function(Canvas canvas, QrLayout layout)? foregroundPainter;

  /// When set, modules are rendered as 3×3 halftone subcells instead of
  /// module shapes (the finder eyes are still drawn as vector shapes).
  final HalftoneGrid? halftone;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final frame = this.frame;
    if (frame == null) {
      _paintCode(canvas, size, paint, paintBackground: true);
      return;
    }

    // Background across the whole canvas (the frame area included).
    style.background.apply(paint, Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final geometry = QrFrameGeometry.compute(frame, size);
    canvas.save();
    canvas.translate(geometry.qrRect.left, geometry.qrRect.top);
    _paintCode(canvas, geometry.qrRect.size, paint, paintBackground: false);
    canvas.restore();

    _paintFrame(canvas, paint, frame, geometry);
  }

  void _paintCode(Canvas canvas, Size size, Paint paint,
      {required bool paintBackground}) {
    final layout = QrLayout(code: code, style: style, size: size);

    if (paintBackground) {
      style.background.apply(paint, layout.bounds);
      canvas.drawRect(layout.bounds, paint);
    }

    if (halftone != null) {
      _paintHalftone(canvas, layout, paint, halftone!);
    } else {
      _paintModules(canvas, layout, paint);
    }
    _paintEyes(canvas, layout, paint);

    foregroundPainter?.call(canvas, layout);
  }

  void _paintFrame(
      Canvas canvas, Paint paint, QrFrame frame, QrFrameGeometry geometry) {
    // Border.
    paint
      ..shader = null
      ..maskFilter = null
      ..color = frame.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.strokeWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          geometry.outerRect, Radius.circular(geometry.cornerRadius)),
      paint,
    );
    paint.style = PaintingStyle.fill;

    if (!geometry.hasBanner) return;

    // Banner with the outer corners rounded to match the border.
    final r = Radius.circular(geometry.cornerRadius);
    final bottom = frame.labelPosition == QrFrameLabelPosition.bottom;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        geometry.bannerRect,
        bottomLeft: bottom ? r : Radius.zero,
        bottomRight: bottom ? r : Radius.zero,
        topLeft: bottom ? Radius.zero : r,
        topRight: bottom ? Radius.zero : r,
      ),
      paint,
    );

    // Label, shrunk if needed to fit the banner width.
    var fontSize = geometry.fontSize;
    final maxWidth = geometry.bannerRect.width * 0.85;
    TextPainter textPainter;
    do {
      textPainter = TextPainter(
        text: TextSpan(
          text: frame.text,
          style: TextStyle(
            color: frame.textColor,
            fontSize: fontSize,
            fontWeight: frame.fontWeight,
            fontFamily: frame.fontFamily,
            letterSpacing: frame.letterSpacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (textPainter.width <= maxWidth || fontSize < 4) break;
      fontSize *= 0.9;
    } while (true);
    textPainter.paint(
      canvas,
      geometry.bannerRect.center -
          Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _paintModules(Canvas canvas, QrLayout layout, Paint paint) {
    // Modules with the shared fill are collected into one path so gradients
    // flow across the whole symbol; recolored modules get their own path.
    final sharedPath = Path();
    final recolored = <Color, Path>{};

    for (var row = 0; row < code.size; row++) {
      for (var col = 0; col < code.size; col++) {
        if (!layout.isModulePainted(row, col)) continue;
        if (skipModule?.call(row, col) ?? false) continue;

        final rect = layout.scaledModuleRect(row, col);
        final neighbors = layout.neighborsOf(row, col);
        final override = moduleColorResolver?.call(row, col);
        if (override != null) {
          final path = recolored.putIfAbsent(override, Path.new);
          style.moduleShape.addPath(path, rect, neighbors);
        } else {
          style.moduleShape.addPath(sharedPath, rect, neighbors);
        }
      }
    }

    // Depth effects go under all module paths.
    final allModules = Path()..addPath(sharedPath, Offset.zero);
    for (final path in recolored.values) {
      allModules.addPath(path, Offset.zero);
    }
    _paintEffectUnder(canvas, layout, paint, allModules, style.fill);

    style.fill.apply(paint, layout.bounds);
    canvas.drawPath(sharedPath, paint);

    if (recolored.isNotEmpty) {
      paint.shader = null;
      for (final entry in recolored.entries) {
        paint.color = entry.key;
        canvas.drawPath(entry.value, paint);
      }
    }

    _paintEmbossOver(canvas, layout, paint, allModules);
  }

  /// The finder eyes carry the detector's module-size estimate; extruding
  /// them too far breaks the 1:1:3:1:1 ratio, so their depth is capped.
  static const double _maxEyeExtrusion = 0.25;

  /// Draws extrusion sides or a drop shadow beneath [path].
  void _paintEffectUnder(Canvas canvas, QrLayout layout, Paint paint,
      Path path, QrFill fill,
      {double maxDepth = double.infinity}) {
    switch (style.effect) {
      case QrNoEffect() || QrEmbossEffect():
        return;
      case QrExtrudedEffect(depth: final rawDepth, :final color):
        final depth = rawDepth > maxDepth ? maxDepth : rawDepth;
        paint
          ..shader = null
          ..color = color ?? _darken(fill.representativeColor, 0.45);
        final d = depth * layout.moduleSize;
        const steps = 4;
        for (var i = steps; i >= 1; i--) {
          final offset = d * i / steps;
          canvas.save();
          canvas.translate(offset, offset);
          canvas.drawPath(path, paint);
          canvas.restore();
        }
      case QrShadowEffect(:final blur, :final offset, :final color):
        paint
          ..shader = null
          ..color = color
          ..maskFilter = blur > 0
              ? MaskFilter.blur(BlurStyle.normal, blur * layout.moduleSize)
              : null;
        canvas.save();
        canvas.translate(
            offset.dx * layout.moduleSize, offset.dy * layout.moduleSize);
        canvas.drawPath(path, paint);
        canvas.restore();
        paint.maskFilter = null;
    }
  }

  /// Draws the bevel highlight/shade crescents on top of [path].
  void _paintEmbossOver(
      Canvas canvas, QrLayout layout, Paint paint, Path path) {
    final effect = style.effect;
    if (effect is! QrEmbossEffect) return;
    final d = layout.moduleSize * 0.18;
    final highlight =
        Path.combine(PathOperation.difference, path, path.shift(Offset(d, d)));
    final shade = Path.combine(
        PathOperation.difference, path, path.shift(Offset(-d, -d)));
    paint.shader = null;
    paint.color = Color.fromRGBO(255, 255, 255, 0.55 * effect.strength);
    canvas.drawPath(highlight, paint);
    paint.color = Color.fromRGBO(0, 0, 0, 0.35 * effect.strength);
    canvas.drawPath(shade, paint);
  }

  static Color _darken(Color color, double amount) => Color.from(
        alpha: color.a,
        red: color.r * (1 - amount),
        green: color.g * (1 - amount),
        blue: color.b * (1 - amount),
      );

  void _paintHalftone(
      Canvas canvas, QrLayout layout, Paint paint, HalftoneGrid grid) {
    final g = grid.gridSize;
    final sub = layout.moduleSize / 3;
    final sharedPath = Path();
    final recolored = <Color, Path>{};

    for (var r3 = 0; r3 < g; r3++) {
      for (var c3 = 0; c3 < g; c3++) {
        if (!grid.isDark(r3, c3)) continue;
        final rect = Rect.fromLTWH(
          layout.origin.dx + c3 * sub,
          layout.origin.dy + r3 * sub,
          // Overdraw a hair to avoid antialiasing seams between subcells.
          sub + 0.05,
          sub + 0.05,
        );
        final color = grid.colorAt(r3, c3);
        if (color != null) {
          recolored.putIfAbsent(color, Path.new).addRect(rect);
        } else {
          sharedPath.addRect(rect);
        }
      }
    }

    style.fill.apply(paint, layout.bounds);
    canvas.drawPath(sharedPath, paint);
    if (recolored.isNotEmpty) {
      paint.shader = null;
      for (final entry in recolored.entries) {
        paint.color = entry.key;
        canvas.drawPath(entry.value, paint);
      }
    }
  }

  void _paintEyes(Canvas canvas, QrLayout layout, Paint paint) {
    for (final eye in QrEyePosition.values) {
      final eyeStyle = style.eyeStyleFor(eye);
      final outer = layout.eyeRect(eye);

      final framePath = Path();
      eyeStyle.frame.addPath(framePath, outer, layout.moduleSize);
      final pupilRect = outer.deflate(layout.moduleSize * 2);
      final pupilPath = Path();
      eyeStyle.pupil.addPath(pupilPath, pupilRect, layout.moduleSize);

      final frameFill = eyeStyle.frameFill ?? style.fill;
      _paintEffectUnder(canvas, layout, paint, framePath, frameFill,
          maxDepth: _maxEyeExtrusion);
      frameFill.apply(paint, layout.bounds);
      canvas.drawPath(framePath, paint);

      final pupilFill = eyeStyle.pupilFill ?? eyeStyle.frameFill ?? style.fill;
      _paintEffectUnder(canvas, layout, paint, pupilPath, pupilFill,
          maxDepth: _maxEyeExtrusion);
      pupilFill.apply(paint, layout.bounds);
      canvas.drawPath(pupilPath, paint);

      // Even-odd keeps the frame ring's hole open in the combined path.
      final eyePaths = Path()
        ..fillType = PathFillType.evenOdd
        ..addPath(framePath, Offset.zero)
        ..addPath(pupilPath, Offset.zero);
      _paintEmbossOver(canvas, layout, paint, eyePaths);
    }
  }

  /// Renders this painter to PNG bytes at [pixelSize]×[pixelSize], without
  /// needing a widget tree. Suitable for saving/sharing/printing.
  Future<ui.Image> toImage(int pixelSize) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, Size.square(pixelSize.toDouble()));
    return recorder.endRecording().toImage(pixelSize, pixelSize);
  }

  Future<ByteData?> toPngByteData(int pixelSize) async {
    final image = await toImage(pixelSize);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  }

  @override
  bool shouldRepaint(QrPainter oldDelegate) =>
      oldDelegate.code != code ||
      oldDelegate.style != style ||
      oldDelegate.frame != frame ||
      oldDelegate.moduleColorResolver != moduleColorResolver ||
      oldDelegate.skipModule != skipModule ||
      oldDelegate.foregroundPainter != foregroundPainter ||
      oldDelegate.halftone != halftone;
}
