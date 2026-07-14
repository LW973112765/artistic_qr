import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../encoder/matrix.dart';
import '../encoder/qr_encoder.dart';
import '../render/qr_geometry.dart';
import '../style/qr_style.dart';
import 'qr_image.dart';

/// Per-subcell halftone pattern (3×3 subcells per module), precomputed once
/// per (code, image) pair and consumed by the painter and SVG exporter.
class HalftoneGrid {
  HalftoneGrid(this.moduleCount)
      : cells = Uint8List(moduleCount * moduleCount * 9);

  final int moduleCount;

  /// 1 = dark, indexed `(row*3+subRow) * moduleCount*3 + (col*3+subCol)`.
  final Uint8List cells;

  /// Optional per-subcell colors (colored halftone), same indexing.
  List<Color?>? colors;

  int get gridSize => moduleCount * 3;

  bool isDark(int r3, int c3) => cells[r3 * gridSize + c3] != 0;

  Color? colorAt(int r3, int c3) => colors?[r3 * gridSize + c3];
}

/// Painter-ready behavior derived from a [QrImage] + resolved pixels.
class QrImageRenderData {
  QrImageRenderData({
    this.moduleColorResolver,
    this.skipModule,
    this.foregroundPainter,
    this.halftone,
  });

  final Color? Function(int row, int col)? moduleColorResolver;
  final bool Function(int row, int col)? skipModule;
  final void Function(ui.Canvas canvas, QrLayout layout)? foregroundPainter;
  final HalftoneGrid? halftone;
}

QrImageRenderData buildImageRenderData({
  required QrCode code,
  required QrStyle style,
  required ResolvedQrImage image,
}) {
  switch (image.mode) {
    case final QrLogoMode mode:
      return _buildLogo(code, image, mode);
    case final QrBlendMode mode:
      return _buildBlend(code, style, image, mode);
    case final QrHalftoneMode mode:
      return QrImageRenderData(
          halftone: buildHalftoneGrid(code, image, mode));
  }
}

// --- Logo mode -------------------------------------------------------------

QrImageRenderData _buildLogo(
    QrCode code, ResolvedQrImage image, QrLogoMode mode) {
  final n = code.size;
  // Normalized (symbol-space) rect of the logo, centered.
  final half = mode.scale / 2;
  final logoRect = Rect.fromLTRB(0.5 - half, 0.5 - half, 0.5 + half, 0.5 + half);
  // Knockout area includes padding, measured in modules.
  final pad = mode.padding / n;
  final clearRect = logoRect.inflate(pad);

  Set<int>? knockedOut;
  if (mode.knockout) {
    knockedOut = <int>{};
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        if (code.matrix.roleAt(row, col) != QrModuleRole.data) continue;
        final center = Offset((col + 0.5) / n, (row + 0.5) / n);
        if (clearRect.contains(center)) knockedOut.add(row * n + col);
      }
    }
  }

  final knocked = knockedOut;
  return QrImageRenderData(
    skipModule: knocked == null
        ? null
        : (row, col) => knocked.contains(row * n + col),
    foregroundPainter: (canvas, layout) {
      final symbolSide = layout.moduleSize * n;
      final dest = Rect.fromLTWH(
        layout.origin.dx + logoRect.left * symbolSide,
        layout.origin.dy + logoRect.top * symbolSide,
        logoRect.width * symbolSide,
        logoRect.height * symbolSide,
      );
      paintImage(
        canvas: canvas,
        rect: dest,
        image: image.pixels.image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        isAntiAlias: true,
      );
    },
  );
}

// --- Blend mode ------------------------------------------------------------

QrImageRenderData _buildBlend(
    QrCode code, QrStyle style, ResolvedQrImage image, QrBlendMode mode) {
  final n = code.size;
  final baseColor = style.fill.representativeColor;
  // Colors are sampled once and cached: painting happens per frame.
  final cache = List<Color?>.filled(n * n, null);
  final cached = List<bool>.filled(n * n, false);

  Color? resolve(int row, int col) {
    final role = code.matrix.roleAt(row, col);
    final blendable = role == QrModuleRole.data ||
        (mode.includeFunctionPatterns &&
            role != QrModuleRole.finder &&
            role != QrModuleRole.separator);
    if (!blendable) return null;

    final index = row * n + col;
    if (cached[index]) return cache[index];
    cached[index] = true;

    final cell = Rect.fromLTRB(col / n, row / n, (col + 1) / n, (row + 1) / n);
    var color = image.pixels.averageColor(image.symbolToImage(cell));
    if (color == null) return null; // transparent → default fill

    final lum = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    if (lum >= mode.whiteThreshold) return null; // white background → fill

    if (mode.enforceContrast) {
      color = _clampLuminance(color, 0.55);
    }
    if (mode.opacity < 1.0) {
      color = Color.lerp(baseColor, color, mode.opacity)!;
    }
    cache[index] = color;
    return color;
  }

  return QrImageRenderData(moduleColorResolver: resolve);
}

/// Darkens [color] proportionally until its relative luminance is at most
/// [maxLuminance], preserving hue.
Color _clampLuminance(Color color, double maxLuminance) {
  final lum = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
  if (lum <= maxLuminance) return color;
  final k = maxLuminance / lum;
  return Color.from(
      alpha: color.a, red: color.r * k, green: color.g * k, blue: color.b * k);
}

// --- Halftone mode ----------------------------------------------------------

HalftoneGrid buildHalftoneGrid(
    QrCode code, ResolvedQrImage image, QrHalftoneMode mode) {
  final n = code.size;
  final g = n * 3;
  final grid = HalftoneGrid(n);

  // 1. Sample luminance for every subcell (NaN = image transparent there).
  final lum = Float32List(g * g);
  for (var r3 = 0; r3 < g; r3++) {
    for (var c3 = 0; c3 < g; c3++) {
      final cell =
          Rect.fromLTRB(c3 / g, r3 / g, (c3 + 1) / g, (r3 + 1) / g);
      lum[r3 * g + c3] =
          image.pixels.averageLuminance(image.symbolToImage(cell))
                  ?.toDouble() ??
              double.nan;
    }
  }

  // 2. Threshold (with optional Floyd–Steinberg error diffusion).
  // Positive brightness → lower threshold → fewer dark subcells (lighter).
  final threshold = 0.5 - mode.brightness * 0.4;
  final dark = Uint8List(g * g);
  if (mode.dithering) {
    for (var r3 = 0; r3 < g; r3++) {
      for (var c3 = 0; c3 < g; c3++) {
        final i = r3 * g + c3;
        final v = lum[i];
        if (v.isNaN) continue;
        final isDark = v < threshold;
        dark[i] = isDark ? 1 : 0;
        final error = v - (isDark ? 0.0 : 1.0);
        void diffuse(int r, int c, double factor) {
          if (r < 0 || r >= g || c < 0 || c >= g) return;
          final j = r * g + c;
          if (!lum[j].isNaN) lum[j] += error * factor;
        }

        diffuse(r3, c3 + 1, 7 / 16);
        diffuse(r3 + 1, c3 - 1, 3 / 16);
        diffuse(r3 + 1, c3, 5 / 16);
        diffuse(r3 + 1, c3 + 1, 1 / 16);
      }
    }
  } else {
    for (var i = 0; i < g * g; i++) {
      if (!lum[i].isNaN) dark[i] = lum[i] < threshold ? 1 : 0;
    }
  }

  // 3. Force the QR constraints on top of the halftoned photo:
  //    - function patterns are fully solid (their module value),
  //    - each data module's center subcell carries the data bit,
  //    - areas the image doesn't cover render as normal solid modules.
  final colors = mode.colored ? List<Color?>.filled(g * g, null) : null;
  for (var row = 0; row < n; row++) {
    for (var col = 0; col < n; col++) {
      final role = code.matrix.roleAt(row, col);
      final moduleDark = code.matrix.isDark(row, col);
      for (var sr = 0; sr < 3; sr++) {
        for (var sc = 0; sc < 3; sc++) {
          final r3 = row * 3 + sr;
          final c3 = col * 3 + sc;
          final i = r3 * g + c3;
          final bool value;
          if (role == QrModuleRole.finder || role == QrModuleRole.separator) {
            value = false; // eyes are drawn as vector shapes instead
          } else if (role != QrModuleRole.data) {
            value = moduleDark;
          } else if (sr == 1 && sc == 1) {
            value = moduleDark; // the data-carrying center subpixel
          } else if (lum[i].isNaN) {
            value = moduleDark; // outside the image: solid module
          } else {
            value = dark[i] != 0;
          }
          grid.cells[i] = value ? 1 : 0;
          if (value && colors != null) {
            final cell =
                Rect.fromLTRB(c3 / g, r3 / g, (c3 + 1) / g, (r3 + 1) / g);
            final sampled =
                image.pixels.averageColor(image.symbolToImage(cell));
            if (sampled != null) {
              colors[i] = _clampLuminance(sampled, 0.4);
            }
          }
        }
      }
    }
  }
  grid.colors = colors;
  return grid;
}
