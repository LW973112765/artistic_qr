import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../encoder/matrix.dart';
import '../encoder/qr_encoder.dart';
import '../image/qr_image.dart';
import '../image/qr_image_renderer.dart';
import '../style/qr_effect.dart';
import '../style/qr_fill.dart';
import '../style/qr_frame.dart';
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
  QrFrame? frame,
  QrImageRenderData? imageData,
  ResolvedQrImage? resolvedImage,
  double size = 512,
}) async {
  final frameGeometry = frame == null
      ? null
      : QrFrameGeometry.compute(frame, Size.square(size));
  final qrSize = frameGeometry?.qrRect.size ?? Size.square(size);
  final layout = QrLayout(code: code, style: style, size: qrSize);
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

  final qrBody = StringBuffer();

  final halftone = imageData?.halftone;
  if (halftone != null) {
    _writeHalftone(qrBody, layout, halftone, fillAttr(style.fill));
    _writeEyes(qrBody, layout, fillAttr);
  } else {
    // Depth effects reference the combined dark geometry via <use>, so the
    // path data is collected first (effects go beneath the real layers).
    final modules = _collectModulePaths(layout, imageData);
    final eyes = _collectEyePaths(layout);
    _writeEffect(qrBody, defs, layout, modules, eyes);
    _writeModules(qrBody, layout, modules, fillAttr);
    _writeEyes(qrBody, layout, fillAttr, collected: eyes);
  }

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
      qrBody.writeln('<image x="${svgNum(dest.left)}" y="${svgNum(dest.top)}" '
          'width="${svgNum(dest.width)}" height="${svgNum(dest.height)}" '
          'preserveAspectRatio="xMidYMid meet" '
          'href="data:image/png;base64,$b64"/>');
    }
  }

  final body = StringBuffer()
    ..writeln('<rect width="${svgNum(size)}" height="${svgNum(size)}" '
        '${fillAttr(style.background)}/>');
  if (frameGeometry == null) {
    body.write(qrBody);
  } else {
    body
      ..writeln('<g transform="translate('
          '${svgNum(frameGeometry.qrRect.left)} '
          '${svgNum(frameGeometry.qrRect.top)})">')
      ..write(qrBody)
      ..writeln('</g>');
    _writeFrame(body, frame!, frameGeometry);
  }

  return '<svg xmlns="http://www.w3.org/2000/svg" '
      'viewBox="0 0 ${svgNum(size)} ${svgNum(size)}" '
      'width="${svgNum(size)}" height="${svgNum(size)}">\n'
      '${defs.isEmpty ? '' : '<defs>\n$defs</defs>\n'}'
      '$body</svg>\n';
}

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

void _writeFrame(StringBuffer body, QrFrame frame, QrFrameGeometry g) {
  body.writeln('<rect x="${svgNum(g.outerRect.left)}" '
      'y="${svgNum(g.outerRect.top)}" '
      'width="${svgNum(g.outerRect.width)}" '
      'height="${svgNum(g.outerRect.height)}" '
      'rx="${svgNum(g.cornerRadius)}" fill="none" '
      'stroke="${svgColorHex(frame.color)}" '
      'stroke-width="${svgNum(g.strokeWidth)}"/>');

  if (!g.hasBanner) return;

  final r = Radius.circular(g.cornerRadius);
  final bottom = frame.labelPosition == QrFrameLabelPosition.bottom;
  final bannerPath = svgRRectPath(
    g.bannerRect,
    bottomLeft: bottom ? r : Radius.zero,
    bottomRight: bottom ? r : Radius.zero,
    topLeft: bottom ? Radius.zero : r,
    topRight: bottom ? Radius.zero : r,
  );
  body.writeln('<path fill="${svgColorHex(frame.color)}" d="$bannerPath"/>');

  final weight = frame.fontWeight.value;
  final family = frame.fontFamily == null
      ? 'Helvetica, Arial, sans-serif'
      : '${frame.fontFamily}, Helvetica, Arial, sans-serif';
  body.writeln('<text x="${svgNum(g.bannerRect.center.dx)}" '
      'y="${svgNum(g.bannerRect.center.dy)}" '
      'text-anchor="middle" dominant-baseline="central" '
      'font-family="$family" font-size="${svgNum(g.fontSize)}" '
      'font-weight="$weight" '
      'letter-spacing="${svgNum(frame.letterSpacing)}" '
      'fill="${svgColorHex(frame.textColor)}">'
      '${_escapeXml(frame.text)}</text>');
}

class _ModulePaths {
  final shared = StringBuffer();
  final recolored = <Color, StringBuffer>{};

  String get allPathData =>
      shared.toString() + recolored.values.join();
}

class _EyePaths {
  const _EyePaths(this.eye, this.frameData, this.pupilData);

  final QrEyePosition eye;
  final String frameData;
  final String pupilData;
}

_ModulePaths _collectModulePaths(
    QrLayout layout, QrImageRenderData? imageData) {
  final code = layout.code;
  final style = layout.style;
  final paths = _ModulePaths();

  for (var row = 0; row < code.size; row++) {
    for (var col = 0; col < code.size; col++) {
      if (!layout.isModulePainted(row, col)) continue;
      if (imageData?.skipModule?.call(row, col) ?? false) continue;
      final rect = layout.scaledModuleRect(row, col);
      final neighbors = layout.neighborsOf(row, col);
      final override = imageData?.moduleColorResolver?.call(row, col);
      final target = override != null
          ? paths.recolored.putIfAbsent(override, StringBuffer.new)
          : paths.shared;
      target.write(style.moduleShape.svgPath(rect, neighbors));
    }
  }
  return paths;
}

List<_EyePaths> _collectEyePaths(QrLayout layout) {
  final style = layout.style;
  return [
    for (final eye in QrEyePosition.values)
      _EyePaths(
        eye,
        style.eyeStyleFor(eye).frame.svgPath(
            layout.eyeRect(eye), layout.moduleSize),
        style.eyeStyleFor(eye).pupil.svgPath(
            layout.eyeRect(eye).deflate(layout.moduleSize * 2),
            layout.moduleSize),
      ),
  ];
}

/// The finder eyes carry the detector's module-size estimate; extrusion on
/// them is capped (matching the canvas painter).
const double _maxEyeExtrusion = 0.25;

/// Emits extruded sides or a drop shadow beneath the dark geometry.
/// Emboss is a raster-only effect and is skipped in SVG.
void _writeEffect(StringBuffer body, StringBuffer defs, QrLayout layout,
    _ModulePaths modules, List<_EyePaths> eyes) {
  final effect = layout.style.effect;
  if (effect is QrNoEffect || effect is QrEmbossEffect) return;

  final eyeData = StringBuffer();
  for (final eye in eyes) {
    eyeData
      ..write(eye.frameData)
      ..write(eye.pupilData);
  }
  defs
    ..writeln('<path id="qr-dark" d="${modules.allPathData}"/>')
    ..writeln('<path id="qr-dark-eyes" fill-rule="evenodd" d="$eyeData"/>');

  void emitUses(String id, double depthModules, Color side) {
    final d = depthModules * layout.moduleSize;
    const steps = 4;
    for (var i = steps; i >= 1; i--) {
      final o = svgNum(d * i / steps);
      body.writeln('<use href="#$id" fill="${svgColorHex(side)}" '
          'transform="translate($o $o)"/>');
    }
  }

  switch (effect) {
    case QrExtrudedEffect(:final depth, :final color):
      final side = color ??
          _darkenColor(layout.style.fill.representativeColor, 0.45);
      emitUses('qr-dark', depth, side);
      emitUses('qr-dark-eyes',
          depth > _maxEyeExtrusion ? _maxEyeExtrusion : depth, side);
    case QrShadowEffect(:final blur, :final offset, :final color):
      if (blur > 0) {
        final dev = svgNum(blur * layout.moduleSize / 2);
        defs.writeln('<filter id="qr-blur" x="-30%" y="-30%" '
            'width="160%" height="160%">'
            '<feGaussianBlur stdDeviation="$dev"/></filter>');
      }
      final dx = svgNum(offset.dx * layout.moduleSize);
      final dy = svgNum(offset.dy * layout.moduleSize);
      final filter = blur > 0 ? 'filter="url(#qr-blur)" ' : '';
      for (final id in ['qr-dark', 'qr-dark-eyes']) {
        body.writeln('<use href="#$id" fill="${svgColorHex(color)}" '
            'fill-opacity="${svgNum(color.a)}" $filter'
            'transform="translate($dx $dy)"/>');
      }
    case QrNoEffect() || QrEmbossEffect():
      break;
  }
}

Color _darkenColor(Color color, double amount) => Color.from(
      alpha: color.a,
      red: color.r * (1 - amount),
      green: color.g * (1 - amount),
      blue: color.b * (1 - amount),
    );

void _writeModules(
  StringBuffer body,
  QrLayout layout,
  _ModulePaths paths,
  String Function(QrFill) fillAttr,
) {
  body.writeln('<path ${fillAttr(layout.style.fill)} d="${paths.shared}"/>');
  for (final entry in paths.recolored.entries) {
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
    StringBuffer body, QrLayout layout, String Function(QrFill) fillAttr,
    {List<_EyePaths>? collected}) {
  final style = layout.style;
  final eyes = collected ?? _collectEyePaths(layout);
  for (final paths in eyes) {
    final eyeStyle = style.eyeStyleFor(paths.eye);
    body.writeln('<path fill-rule="evenodd" '
        '${fillAttr(eyeStyle.frameFill ?? style.fill)} d="${paths.frameData}"/>');
    body.writeln(
        '<path ${fillAttr(eyeStyle.pupilFill ?? eyeStyle.frameFill ?? style.fill)} '
        'd="${paths.pupilData}"/>');
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
