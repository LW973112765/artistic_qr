import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Compact number formatting for SVG path data.
String svgNum(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  var s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

String svgRectPath(Rect r) =>
    'M${svgNum(r.left)} ${svgNum(r.top)}h${svgNum(r.width)}'
    'v${svgNum(r.height)}h${svgNum(-r.width)}Z';

String svgOvalPath(Rect r) {
  final rx = svgNum(r.width / 2);
  final ry = svgNum(r.height / 2);
  final cx = svgNum(r.center.dx);
  return 'M$cx ${svgNum(r.top)}'
      'A$rx $ry 0 1 1 $cx ${svgNum(r.bottom)}'
      'A$rx $ry 0 1 1 $cx ${svgNum(r.top)}Z';
}

/// Rounded rect with independent corner radii (clamped like Canvas does).
String svgRRectPath(Rect r,
    {Radius topLeft = Radius.zero,
    Radius topRight = Radius.zero,
    Radius bottomRight = Radius.zero,
    Radius bottomLeft = Radius.zero}) {
  double clampR(double v) => math.min(v, math.min(r.width, r.height) / 2);
  final tl = clampR(topLeft.x);
  final tr = clampR(topRight.x);
  final br = clampR(bottomRight.x);
  final bl = clampR(bottomLeft.x);
  final b = StringBuffer()
    ..write('M${svgNum(r.left + tl)} ${svgNum(r.top)}')
    ..write('H${svgNum(r.right - tr)}');
  if (tr > 0) {
    b.write('A${svgNum(tr)} ${svgNum(tr)} 0 0 1 '
        '${svgNum(r.right)} ${svgNum(r.top + tr)}');
  }
  b.write('V${svgNum(r.bottom - br)}');
  if (br > 0) {
    b.write('A${svgNum(br)} ${svgNum(br)} 0 0 1 '
        '${svgNum(r.right - br)} ${svgNum(r.bottom)}');
  }
  b.write('H${svgNum(r.left + bl)}');
  if (bl > 0) {
    b.write('A${svgNum(bl)} ${svgNum(bl)} 0 0 1 '
        '${svgNum(r.left)} ${svgNum(r.bottom - bl)}');
  }
  b.write('V${svgNum(r.top + tl)}');
  if (tl > 0) {
    b.write('A${svgNum(tl)} ${svgNum(tl)} 0 0 1 '
        '${svgNum(r.left + tl)} ${svgNum(r.top)}');
  }
  b.write('Z');
  return b.toString();
}

String svgPolygonPath(List<Offset> points) {
  final b = StringBuffer('M${svgNum(points.first.dx)} ${svgNum(points.first.dy)}');
  for (final p in points.skip(1)) {
    b.write('L${svgNum(p.dx)} ${svgNum(p.dy)}');
  }
  b.write('Z');
  return b.toString();
}

/// Generic fallback: samples a [ui.Path]'s contours into polygons. Used for
/// custom shapes that don't provide their own exact SVG path.
String svgFromUiPath(ui.Path path, {double step = 0.75}) {
  final b = StringBuffer();
  for (final metric in path.computeMetrics()) {
    final samples = math.max(8, (metric.length / step).ceil());
    for (var i = 0; i < samples; i++) {
      final pos =
          metric.getTangentForOffset(metric.length * i / samples)?.position;
      if (pos == null) continue;
      b.write(i == 0
          ? 'M${svgNum(pos.dx)} ${svgNum(pos.dy)}'
          : 'L${svgNum(pos.dx)} ${svgNum(pos.dy)}');
    }
    b.write('Z');
  }
  return b.toString();
}

/// `#rrggbb` (SVG fill); alpha is emitted separately as fill-opacity.
String svgColorHex(Color color) {
  String h(double channel) =>
      (channel * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${h(color.r)}${h(color.g)}${h(color.b)}';
}
