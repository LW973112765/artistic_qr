import 'package:flutter/painting.dart';

import '../render/svg_utils.dart';

/// The outer ring of a finder "eye" (7×7 modules, 1 module thick).
///
/// [outer] is the full 7×7-module rect. Implementations add a ring path
/// (outer outline + inner hole) using the even-odd fill rule, which the
/// painter and SVG exporter both honor.
abstract class EyeFrameShape {
  const EyeFrameShape();

  /// Classic sharp square frame.
  static const EyeFrameShape square = _SquareFrame();

  /// Rounded-square frame, the most common artistic style.
  /// [radius] is a fraction of the 7-module width (0–0.5).
  const factory EyeFrameShape.rounded({double radius}) = _RoundedFrame;

  /// Full circle frame.
  static const EyeFrameShape circle = _CircleFrame();

  /// A leaf: rounded except the top-left and bottom-right corners.
  static const EyeFrameShape leaf = _LeafFrame();

  void addPath(Path path, Rect outer, double moduleSize);

  /// SVG path data (two subpaths; render with `fill-rule="evenodd"`).
  String svgPath(Rect outer, double moduleSize) {
    final path = Path();
    addPath(path, outer, moduleSize);
    return svgFromUiPath(path);
  }
}

/// The 3×3-module pupil at the center of a finder eye.
abstract class EyePupilShape {
  const EyePupilShape();

  static const EyePupilShape square = _SquarePupil();

  /// [radius] is a fraction of the 3-module width (0–0.5).
  const factory EyePupilShape.rounded({double radius}) = _RoundedPupil;

  static const EyePupilShape circle = _CirclePupil();

  static const EyePupilShape leaf = _LeafPupil();

  void addPath(Path path, Rect rect, double moduleSize);

  String svgPath(Rect rect, double moduleSize) {
    final path = Path();
    addPath(path, rect, moduleSize);
    return svgFromUiPath(path);
  }
}

Rect _innerHole(Rect outer, double moduleSize) =>
    outer.deflate(moduleSize);

class _SquareFrame extends EyeFrameShape {
  const _SquareFrame();

  @override
  void addPath(Path path, Rect outer, double moduleSize) {
    path
      ..fillType = PathFillType.evenOdd
      ..addRect(outer)
      ..addRect(_innerHole(outer, moduleSize));
  }

  @override
  String svgPath(Rect outer, double moduleSize) =>
      svgRectPath(outer) + svgRectPath(_innerHole(outer, moduleSize));
}

class _RoundedFrame extends EyeFrameShape {
  const _RoundedFrame({this.radius = 0.30});

  final double radius;

  @override
  void addPath(Path path, Rect outer, double moduleSize) {
    final outerRadius = Radius.circular(outer.width * radius);
    final inner = _innerHole(outer, moduleSize);
    // Keep the ring thickness visually constant around the corner.
    final innerRadius =
        Radius.circular((outer.width * radius - moduleSize).clamp(0, 1e9));
    path
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndRadius(outer, outerRadius))
      ..addRRect(RRect.fromRectAndRadius(inner, innerRadius));
  }

  @override
  String svgPath(Rect outer, double moduleSize) {
    final ro = Radius.circular(outer.width * radius);
    final inner = _innerHole(outer, moduleSize);
    final ri = Radius.circular((outer.width * radius - moduleSize).clamp(0, 1e9));
    return svgRRectPath(outer,
            topLeft: ro, topRight: ro, bottomRight: ro, bottomLeft: ro) +
        svgRRectPath(inner,
            topLeft: ri, topRight: ri, bottomRight: ri, bottomLeft: ri);
  }
}

class _CircleFrame extends EyeFrameShape {
  const _CircleFrame();

  @override
  void addPath(Path path, Rect outer, double moduleSize) {
    path
      ..fillType = PathFillType.evenOdd
      ..addOval(outer)
      ..addOval(_innerHole(outer, moduleSize));
  }

  @override
  String svgPath(Rect outer, double moduleSize) =>
      svgOvalPath(outer) + svgOvalPath(_innerHole(outer, moduleSize));
}

class _LeafFrame extends EyeFrameShape {
  const _LeafFrame();

  @override
  void addPath(Path path, Rect outer, double moduleSize) {
    final r = Radius.circular(outer.width * 0.5);
    final inner = _innerHole(outer, moduleSize);
    final ri = Radius.circular(inner.width * 0.5);
    path
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndCorners(outer,
          topRight: r, bottomLeft: r))
      ..addRRect(RRect.fromRectAndCorners(inner,
          topRight: ri, bottomLeft: ri));
  }

  @override
  String svgPath(Rect outer, double moduleSize) {
    final r = Radius.circular(outer.width * 0.5);
    final inner = _innerHole(outer, moduleSize);
    final ri = Radius.circular(inner.width * 0.5);
    return svgRRectPath(outer, topRight: r, bottomLeft: r) +
        svgRRectPath(inner, topRight: ri, bottomLeft: ri);
  }
}

class _SquarePupil extends EyePupilShape {
  const _SquarePupil();

  @override
  void addPath(Path path, Rect rect, double moduleSize) {
    path.addRect(rect);
  }

  @override
  String svgPath(Rect rect, double moduleSize) => svgRectPath(rect);
}

class _RoundedPupil extends EyePupilShape {
  const _RoundedPupil({this.radius = 0.30});

  final double radius;

  @override
  void addPath(Path path, Rect rect, double moduleSize) {
    path.addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.width * radius)));
  }

  @override
  String svgPath(Rect rect, double moduleSize) {
    final r = Radius.circular(rect.width * radius);
    return svgRRectPath(rect,
        topLeft: r, topRight: r, bottomRight: r, bottomLeft: r);
  }
}

class _CirclePupil extends EyePupilShape {
  const _CirclePupil();

  @override
  void addPath(Path path, Rect rect, double moduleSize) {
    path.addOval(rect);
  }

  @override
  String svgPath(Rect rect, double moduleSize) => svgOvalPath(rect);
}

class _LeafPupil extends EyePupilShape {
  const _LeafPupil();

  @override
  void addPath(Path path, Rect rect, double moduleSize) {
    final r = Radius.circular(rect.width * 0.5);
    path.addRRect(RRect.fromRectAndCorners(rect, topRight: r, bottomLeft: r));
  }

  @override
  String svgPath(Rect rect, double moduleSize) {
    final r = Radius.circular(rect.width * 0.5);
    return svgRRectPath(rect, topRight: r, bottomLeft: r);
  }
}
