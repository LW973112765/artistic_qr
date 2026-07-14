import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../render/svg_utils.dart';

/// Which adjacent modules are dark, for connected shapes like
/// [ModuleShape.fluid] and the bar shapes.
class ModuleNeighbors {
  const ModuleNeighbors({
    this.top = false,
    this.bottom = false,
    this.left = false,
    this.right = false,
  });

  static const none = ModuleNeighbors();

  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
}

/// Signature for fully custom module shapes.
typedef ModulePathBuilder = void Function(
    Path path, Rect rect, ModuleNeighbors neighbors);

/// The shape drawn for each dark module.
///
/// [rect] is the *full* module cell; shapes are expected to stay inside it.
/// Any scaling (dot gaps) is applied by the painter before calling
/// [addPath], so shapes always fill the rect they are given.
abstract class ModuleShape {
  const ModuleShape();

  /// Classic solid squares.
  static const ModuleShape square = _SquareShape();

  /// Independent circles ("dots"), the most common artistic style.
  static const ModuleShape circle = _CircleShape();

  /// Rounded squares. [radius] is a fraction of the module size (0–0.5).
  const factory ModuleShape.rounded({double radius}) = _RoundedShape;

  /// Squares rotated 45°.
  static const ModuleShape diamond = _DiamondShape();

  /// A four-pointed sparkle/star.
  const factory ModuleShape.star({int points, double inset}) = _StarShape;

  /// Rounded on the top-left and bottom-right corners only.
  static const ModuleShape classy = _ClassyShape();

  /// Rounded corners only where no dark neighbor touches, so adjacent
  /// modules melt together into a fluid blob (like most premium QR designs).
  static const ModuleShape fluid = _FluidShape();

  /// Vertical pill segments: caps appear where a run of modules starts/ends.
  static const ModuleShape verticalBars = _BarShape(horizontal: false);

  /// Horizontal pill segments.
  static const ModuleShape horizontalBars = _BarShape(horizontal: true);

  /// A fully custom shape drawn by [builder].
  const factory ModuleShape.custom(ModulePathBuilder builder) = _CustomShape;

  void addPath(Path path, Rect rect, ModuleNeighbors neighbors);

  /// SVG path data for this shape. Built-in shapes emit exact primitives;
  /// custom shapes fall back to sampling the canvas path.
  String svgPath(Rect rect, ModuleNeighbors neighbors) {
    final path = Path();
    addPath(path, rect, neighbors);
    return svgFromUiPath(path);
  }
}

class _SquareShape extends ModuleShape {
  const _SquareShape();

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    path.addRect(rect);
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) => svgRectPath(rect);
}

class _CircleShape extends ModuleShape {
  const _CircleShape();

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    path.addOval(rect);
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) => svgOvalPath(rect);
}

class _RoundedShape extends ModuleShape {
  const _RoundedShape({this.radius = 0.35});

  /// Corner radius as a fraction of the module size (0 = square, 0.5 = pill).
  final double radius;

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    path.addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.width * radius)));
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) {
    final r = Radius.circular(rect.width * radius);
    return svgRRectPath(rect,
        topLeft: r, topRight: r, bottomRight: r, bottomLeft: r);
  }
}

class _DiamondShape extends ModuleShape {
  const _DiamondShape();

  List<Offset> _points(Rect rect) => [
        Offset(rect.center.dx, rect.top),
        Offset(rect.right, rect.center.dy),
        Offset(rect.center.dx, rect.bottom),
        Offset(rect.left, rect.center.dy),
      ];

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    final points = _points(rect);
    path.moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) =>
      svgPolygonPath(_points(rect));
}

class _StarShape extends ModuleShape {
  const _StarShape({this.points = 4, this.inset = 0.5});

  final int points;

  /// Inner radius as a fraction of the outer radius (smaller = spikier).
  final double inset;

  List<Offset> _points(Rect rect) {
    final center = rect.center;
    final outer = rect.width / 2;
    final inner = outer * inset;
    final step = math.pi / points;
    return [
      for (var i = 0; i < points * 2; i++)
        Offset(
          center.dx + (i.isEven ? outer : inner) * math.cos(i * step - math.pi / 2),
          center.dy + (i.isEven ? outer : inner) * math.sin(i * step - math.pi / 2),
        ),
    ];
  }

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    final pts = _points(rect);
    path.moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) =>
      svgPolygonPath(_points(rect));
}

class _ClassyShape extends ModuleShape {
  const _ClassyShape();

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    final r = Radius.circular(rect.width * 0.5);
    path.addRRect(RRect.fromRectAndCorners(rect, topLeft: r, bottomRight: r));
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) {
    final r = Radius.circular(rect.width * 0.5);
    return svgRRectPath(rect, topLeft: r, bottomRight: r);
  }
}

class _FluidShape extends ModuleShape {
  const _FluidShape();

  (Radius, Radius, Radius, Radius) _corners(Rect rect, ModuleNeighbors n) {
    final r = Radius.circular(rect.width / 2);
    return (
      n.top || n.left ? Radius.zero : r,
      n.top || n.right ? Radius.zero : r,
      n.bottom || n.right ? Radius.zero : r,
      n.bottom || n.left ? Radius.zero : r,
    );
  }

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    final (tl, tr, br, bl) = _corners(rect, neighbors);
    path.addRRect(RRect.fromRectAndCorners(
      rect,
      topLeft: tl,
      topRight: tr,
      bottomRight: br,
      bottomLeft: bl,
    ));
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) {
    final (tl, tr, br, bl) = _corners(rect, neighbors);
    return svgRRectPath(rect,
        topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl);
  }
}

class _BarShape extends ModuleShape {
  const _BarShape({required this.horizontal});

  final bool horizontal;

  (Radius, Radius, Radius, Radius) _corners(Rect rect, ModuleNeighbors n) {
    final r = Radius.circular(rect.width / 2);
    if (horizontal) {
      final left = n.left ? Radius.zero : r;
      final right = n.right ? Radius.zero : r;
      return (left, right, right, left);
    }
    final top = n.top ? Radius.zero : r;
    final bottom = n.bottom ? Radius.zero : r;
    return (top, top, bottom, bottom);
  }

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    final (tl, tr, br, bl) = _corners(rect, neighbors);
    path.addRRect(RRect.fromRectAndCorners(
      rect,
      topLeft: tl,
      topRight: tr,
      bottomRight: br,
      bottomLeft: bl,
    ));
  }

  @override
  String svgPath(Rect rect, ModuleNeighbors neighbors) {
    final (tl, tr, br, bl) = _corners(rect, neighbors);
    return svgRRectPath(rect,
        topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl);
  }
}

class _CustomShape extends ModuleShape {
  const _CustomShape(this.builder);

  final ModulePathBuilder builder;

  @override
  void addPath(Path path, Rect rect, ModuleNeighbors neighbors) {
    builder(path, rect, neighbors);
  }
}
