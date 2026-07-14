import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter/painting.dart';

/// Where the embedded image comes from. Wraps Flutter's [ImageProvider], so
/// assets, files, network URLs (with caching and headers), and raw bytes all
/// work the same way.
class QrImageSource {
  const QrImageSource(this.provider);

  /// An image bundled with the app: `QrImageSource.asset('assets/logo.png')`.
  QrImageSource.asset(String name, {AssetBundle? bundle, String? package})
      : provider = AssetImage(name, bundle: bundle, package: package);

  /// An image on disk.
  QrImageSource.file(File file) : provider = FileImage(file);

  /// An image fetched over HTTP(S).
  QrImageSource.network(String url, {Map<String, String>? headers})
      : provider = NetworkImage(url, headers: headers);

  /// Raw encoded bytes (PNG/JPEG/WebP/...).
  QrImageSource.memory(Uint8List bytes) : provider = MemoryImage(bytes);

  final ImageProvider provider;

  /// Resolves the provider to pixel data ready for sampling.
  Future<QrImagePixels> resolve(
      {ImageConfiguration configuration = ImageConfiguration.empty}) async {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(configuration);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final image = await completer.future;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('Could not read pixel data from image');
    }
    return QrImagePixels._(
        image, byteData.buffer.asUint8List(), image.width, image.height);
  }
}

/// A decoded image with CPU-side pixels for region sampling, plus the
/// original [ui.Image] for drawing.
class QrImagePixels {
  QrImagePixels._(this.image, this._rgba, this.width, this.height);

  final ui.Image image;
  final Uint8List _rgba;
  final int width;
  final int height;

  /// Average color over a normalized region ([0..1] in image space).
  /// Returns null when the region is (almost) fully transparent.
  Color? averageColor(Rect normRect, {double alphaThreshold = 0.08}) {
    final x0 = (normRect.left * width).floor().clamp(0, width - 1);
    final x1 = (normRect.right * width).ceil().clamp(x0 + 1, width);
    final y0 = (normRect.top * height).floor().clamp(0, height - 1);
    final y1 = (normRect.bottom * height).ceil().clamp(y0 + 1, height);

    var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
    var count = 0;
    for (var y = y0; y < y1; y++) {
      var i = (y * width + x0) * 4;
      for (var x = x0; x < x1; x++, i += 4) {
        final alpha = _rgba[i + 3] / 255.0;
        r += _rgba[i] * alpha;
        g += _rgba[i + 1] * alpha;
        b += _rgba[i + 2] * alpha;
        a += alpha;
        count++;
      }
    }
    if (count == 0 || a / count < alphaThreshold) return null;
    // Un-premultiply by total alpha so transparent pixels don't darken.
    return Color.fromARGB(
      255,
      (r / a).round().clamp(0, 255),
      (g / a).round().clamp(0, 255),
      (b / a).round().clamp(0, 255),
    );
  }

  /// Average relative luminance (0 = black, 1 = white) over a normalized
  /// region; null when transparent.
  double? averageLuminance(Rect normRect) {
    final color = averageColor(normRect);
    if (color == null) return null;
    return (0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
  }
}
