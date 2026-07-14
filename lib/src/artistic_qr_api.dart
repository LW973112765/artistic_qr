import 'package:flutter/foundation.dart';

import 'encoder/qr_encoder.dart';
import 'encoder/tables.dart';
import 'image/qr_image.dart';
import 'image/qr_image_renderer.dart';
import 'render/qr_painter.dart';
import 'render/svg_export.dart';
import 'style/qr_style.dart';
import 'validate/scan_guard.dart';

/// Headless entry point: encode + style + (optionally) embed an image,
/// then export — no widget tree required.
///
/// ```dart
/// final qr = await ArtisticQr.create(
///   data: 'https://example.com',
///   errorCorrection: QrErrorCorrection.high,
///   style: QrStyle(moduleShape: ModuleShape.circle),
///   image: QrImage(
///     source: QrImageSource.asset('assets/logo.png'),
///     mode: QrImageMode.halftone(),
///   ),
/// );
/// final png = await qr.toPngBytes(pixelSize: 2048);
/// ```
class ArtisticQr {
  ArtisticQr._(this.code, this.style, this.imageData, this.resolvedImage);

  final QrCode code;
  final QrStyle style;
  final QrImageRenderData? imageData;
  final ResolvedQrImage? resolvedImage;

  /// Encodes [data] and resolves [image] (if any) ready for rendering.
  ///
  /// In debug builds, designs with common scannability problems (low
  /// contrast, oversized logo, art modes without EC-high…) print
  /// [QrScanWarning]s — see [validate].
  static Future<ArtisticQr> create({
    required String data,
    QrErrorCorrection errorCorrection = QrErrorCorrection.quartile,
    QrStyle style = const QrStyle(),
    QrImage? image,
    int minVersion = 1,
    int maxVersion = 40,
  }) async {
    final code = QrCode.encode(data,
        errorCorrection: errorCorrection,
        minVersion: minVersion,
        maxVersion: maxVersion);
    QrImageRenderData? imageData;
    ResolvedQrImage? resolved;
    if (image != null) {
      final pixels = await image.source.resolve();
      resolved = ResolvedQrImage(pixels: pixels, mode: image.mode);
      imageData = buildImageRenderData(code: code, style: style, image: resolved);
    }
    final qr = ArtisticQr._(code, style, imageData, resolved);
    assert(() {
      for (final warning in qr.validate()) {
        debugPrint('artistic_qr: $warning');
      }
      return true;
    }());
    return qr;
  }

  /// Heuristic scannability check; empty means no known problems.
  List<QrScanWarning> validate() => validateQrDesign(
      code: code, style: style, imageMode: resolvedImage?.mode);

  /// A ready-to-use painter for [CustomPaint].
  QrPainter get painter {
    final data = imageData;
    return data == null
        ? QrPainter(code: code, style: style)
        : QrPainter.withImage(code: code, style: style, imageData: data);
  }

  /// Renders to PNG at [pixelSize]×[pixelSize] pixels.
  Future<Uint8List> toPngBytes({int pixelSize = 1024}) async {
    final byteData = await painter.toPngByteData(pixelSize);
    return byteData!.buffer.asUint8List();
  }

  /// Exports a standalone SVG document (vector, print-ready).
  Future<String> toSvg({double size = 512}) => buildQrSvg(
        code: code,
        style: style,
        imageData: imageData,
        resolvedImage: resolvedImage,
        size: size,
      );
}
