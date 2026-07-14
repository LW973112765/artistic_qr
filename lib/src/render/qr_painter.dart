import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../encoder/matrix.dart';
import '../encoder/qr_encoder.dart';
import '../image/qr_image_renderer.dart';
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
    Listenable? repaint,
  }) =>
      QrPainter(
        code: code,
        style: style,
        moduleColorResolver: imageData.moduleColorResolver,
        skipModule: imageData.skipModule,
        foregroundPainter: imageData.foregroundPainter,
        halftone: imageData.halftone,
        repaint: repaint,
      );

  final QrCode code;
  final QrStyle style;
  final Color? Function(int row, int col)? moduleColorResolver;
  final bool Function(int row, int col)? skipModule;
  final void Function(Canvas canvas, QrLayout layout)? foregroundPainter;

  /// When set, modules are rendered as 3×3 halftone subcells instead of
  /// module shapes (the finder eyes are still drawn as vector shapes).
  final HalftoneGrid? halftone;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = QrLayout(code: code, style: style, size: size);
    final paint = Paint()..isAntiAlias = true;

    // Background.
    style.background.apply(paint, layout.bounds);
    canvas.drawRect(layout.bounds, paint);

    if (halftone != null) {
      _paintHalftone(canvas, layout, paint, halftone!);
    } else {
      _paintModules(canvas, layout, paint);
    }
    _paintEyes(canvas, layout, paint);

    foregroundPainter?.call(canvas, layout);
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
      (eyeStyle.frameFill ?? style.fill).apply(paint, layout.bounds);
      canvas.drawPath(framePath, paint);

      final pupilRect = outer.deflate(layout.moduleSize * 2);
      final pupilPath = Path();
      eyeStyle.pupil.addPath(pupilPath, pupilRect, layout.moduleSize);
      (eyeStyle.pupilFill ?? eyeStyle.frameFill ?? style.fill)
          .apply(paint, layout.bounds);
      canvas.drawPath(pupilPath, paint);
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
      oldDelegate.moduleColorResolver != moduleColorResolver ||
      oldDelegate.skipModule != skipModule ||
      oldDelegate.foregroundPainter != foregroundPainter ||
      oldDelegate.halftone != halftone;
}
