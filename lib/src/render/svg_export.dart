import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../encoder/matrix.dart';
import '../encoder/qr_encoder.dart';
import '../image/qr_image.dart';
import '../image/qr_image_renderer.dart';
import '../style/qr_fill.dart';
import '../style/qr_style.dart';
import 'qr_geometry.dart';
import 'svg_utils.dart';

/// Builds a standalone SVG document for the QR code — same geometry as the
/// canvas painter, infinitely scalable for print.
///
/// Notes:
///  * Sweep gradients have no SVG 1.1 equivalent and are exported as a
///    diagonal linear gradient with the same colors.
///  * A centered logo is embedded as a base64 PNG `<image>` element.
///  * Custom module shapes are exported as sampled polygon outlines.
Future<String> buildQrSvg({
  required QrCode code,
  QrStyle style = const QrStyle(),
  QrImageRenderData? imageData,
  ResolvedQrImage? resolvedImage,
  double size = 512,
}) async {
  final layout = QrLayout(code: code, style: style, size: Size.square(size));
  final defs = StringBuffer();
  var gradientId = 0;

  String fillAttr(QrFill fill) {
    switch (fill) {
      case QrSolidFill(:final color):
        final attr = 'fill="${svgColorHex(color)}"';
        return color.a < 1.0
            ? '$attr fill-opacity="${svgNum(color.a)}"'
            : attr;
      case QrGradientFill(:final gradient):
        final id = 'g${gradientId++}';
        defs.write(_gradientDef(gradient, id, layout.bounds));
        return 'fill="url(#$id)"';
    }
  }

  final body = StringBuffer();

  // Background.
  body.writeln('<rect width="${svgNum(size)}" height="${svgNum(size)}" '
      '${fillAttr(style.background)}/>');

  final halftone = imageData?.halftone;
  if (halftone != null) {
    _writeHalftone(body, layout, halftone, fillAttr(style.fill));
  } else {
    _writeModules(body, layout, imageData, fillAttr);
  }

  _writeEyes(body, layout, fillAttr);

  // Centered logo.
  final logoMode = resolvedImage?.mode;
  if (resolvedImage != null && logoMode is QrLogoMode) {
    final png = await resolvedImage.pixels.image
        .toByteData(format: ui.ImageByteFormat.png);
    if (png != null) {
      final symbolSide = layout.moduleSize * code.size;
      final half = logoMode.scale / 2;
      final dest = Rect.fromLTWH(
        layout.origin.dx + (0.5 - half) * symbolSide,
        layout.origin.dy + (0.5 - half) * symbolSide,
        logoMode.scale * symbolSide,
        logoMode.scale * symbolSide,
      );
      final b64 = base64Encode(png.buffer.asUint8List());
      body.writeln('<image x="${svgNum(dest.left)}" y="${svgNum(dest.top)}" '
          'width="${svgNum(dest.width)}" height="${svgNum(dest.height)}" '
          'preserveAspectRatio="xMidYMid meet" '
          'href="data:image/png;base64,$b64"/>');
    }
  }

  return '<svg xmlns="http://www.w3.org/2000/svg" '
      'viewBox="0 0 ${svgNum(size)} ${svgNum(size)}" '
      'width="${svgNum(size)}" height="${svgNum(size)}">\n'
      '${defs.isEmpty ? '' : '<defs>\n$defs</defs>\n'}'
      '$body</svg>\n';
}

void _writeModules(
  StringBuffer body,
  QrLayout layout,
  QrImageRenderData? imageData,
  String Function(QrFill) fillAttr,
) {
  final code = layout.code;
  final style = layout.style;
  final shared = StringBuffer();
  final recolored = <Color, StringBuffer>{};

  for (var row = 0; row < code.size; row++) {
    for (var col = 0; col < code.size; col++) {
      if (!layout.isModulePainted(row, col)) continue;
      if (imageData?.skipModule?.call(row, col) ?? false) continue;
      final rect = layout.scaledModuleRect(row, col);
      final neighbors = layout.neighborsOf(row, col);
      final override = imageData?.moduleColorResolver?.call(row, col);
      final target = override != null
          ? recolored.putIfAbsent(override, StringBuffer.new)
          : shared;
      target.write(style.moduleShape.svgPath(rect, neighbors));
    }
  }

  body.writeln('<path ${fillAttr(style.fill)} d="$shared"/>');
  for (final entry in recolored.entries) {
    body.writeln('<path fill="${svgColorHex(entry.key)}" d="${entry.value}"/>');
  }
}

void _writeHalftone(
    StringBuffer body, QrLayout layout, HalftoneGrid grid, String fill) {
  final g = grid.gridSize;
  final sub = layout.moduleSize / 3;
  final shared = StringBuffer();
  final recolored = <Color, StringBuffer>{};

  for (var r3 = 0; r3 < g; r3++) {
    for (var c3 = 0; c3 < g; c3++) {
      if (!grid.isDark(r3, c3)) continue;
      final rect = Rect.fromLTWH(
        layout.origin.dx + c3 * sub,
        layout.origin.dy + r3 * sub,
        sub + 0.05,
        sub + 0.05,
      );
      final color = grid.colorAt(r3, c3);
      final target = color != null
          ? recolored.putIfAbsent(color, StringBuffer.new)
          : shared;
      target.write(svgRectPath(rect));
    }
  }

  body.writeln('<path $fill d="$shared"/>');
  for (final entry in recolored.entries) {
    body.writeln('<path fill="${svgColorHex(entry.key)}" d="${entry.value}"/>');
  }
}

void _writeEyes(
    StringBuffer body, QrLayout layout, String Function(QrFill) fillAttr) {
  final style = layout.style;
  for (final eye in QrEyePosition.values) {
    final eyeStyle = style.eyeStyleFor(eye);
    final outer = layout.eyeRect(eye);
    final frame = eyeStyle.frame.svgPath(outer, layout.moduleSize);
    body.writeln('<path fill-rule="evenodd" '
        '${fillAttr(eyeStyle.frameFill ?? style.fill)} d="$frame"/>');
    final pupilRect = outer.deflate(layout.moduleSize * 2);
    final pupil = eyeStyle.pupil.svgPath(pupilRect, layout.moduleSize);
    body.writeln(
        '<path ${fillAttr(eyeStyle.pupilFill ?? eyeStyle.frameFill ?? style.fill)} '
        'd="$pupil"/>');
  }
}

String _gradientDef(Gradient gradient, String id, Rect bounds) {
  final colors = gradient.colors;
  final stops = gradient.stops ??
      [
        for (var i = 0; i < colors.length; i++)
          colors.length == 1 ? 0.0 : i / (colors.length - 1),
      ];
  final stopsXml = StringBuffer();
  for (var i = 0; i < colors.length; i++) {
    stopsXml.write('<stop offset="${svgNum(stops[i])}" '
        'stop-color="${svgColorHex(colors[i])}"');
    if (colors[i].a < 1.0) {
      stopsXml.write(' stop-opacity="${svgNum(colors[i].a)}"');
    }
    stopsXml.write('/>');
  }

  Offset resolvePoint(AlignmentGeometry alignment) {
    final a = alignment.resolve(TextDirection.ltr);
    return Offset(
      bounds.center.dx + a.x * bounds.width / 2,
      bounds.center.dy + a.y * bounds.height / 2,
    );
  }

  switch (gradient) {
    case LinearGradient(:final begin, :final end):
      final p1 = resolvePoint(begin);
      final p2 = resolvePoint(end);
      return '<linearGradient id="$id" gradientUnits="userSpaceOnUse" '
          'x1="${svgNum(p1.dx)}" y1="${svgNum(p1.dy)}" '
          'x2="${svgNum(p2.dx)}" y2="${svgNum(p2.dy)}">$stopsXml'
          '</linearGradient>\n';
    case RadialGradient(:final center, :final radius):
      final c = resolvePoint(center);
      return '<radialGradient id="$id" gradientUnits="userSpaceOnUse" '
          'cx="${svgNum(c.dx)}" cy="${svgNum(c.dy)}" '
          'r="${svgNum(radius * bounds.width)}">$stopsXml'
          '</radialGradient>\n';
    default:
      // Sweep (or unknown) gradients: diagonal linear fallback.
      return '<linearGradient id="$id" gradientUnits="userSpaceOnUse" '
          'x1="${svgNum(bounds.left)}" y1="${svgNum(bounds.top)}" '
          'x2="${svgNum(bounds.right)}" y2="${svgNum(bounds.bottom)}">'
          '$stopsXml</linearGradient>\n';
  }
}
