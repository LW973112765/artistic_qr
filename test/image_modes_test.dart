import 'dart:typed_data';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart' as zxing;

/// A synthetic "photo": diagonal luminance gradient with colored quadrants,
/// plus a transparent 10% border to exercise the alpha fallback paths.
Uint8List makeTestPhoto({int size = 240}) {
  final photo = img.Image(width: size, height: size, numChannels: 4);
  final border = size ~/ 10;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (x < border || y < border || x >= size - border || y >= size - border) {
        photo.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      final t = (x + y) / (2.0 * size);
      final base = (40 + 190 * t).round();
      final left = x < size ~/ 2;
      final top = y < size ~/ 2;
      photo.setPixelRgba(
        x,
        y,
        left ? base : base ~/ 2,
        top ? base ~/ 2 : base,
        left == top ? base : 60,
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(photo));
}

Future<String> renderAndDecode(QrPainter painter, {int pixelSize = 660}) async {
  final byteData = await painter.toPngByteData(pixelSize);
  final decoded = img.decodePng(byteData!.buffer.asUint8List())!;
  final pixels = Int32List(decoded.width * decoded.height);
  var i = 0;
  for (final pixel in decoded) {
    pixels[i++] = (0xFF << 24) |
        (pixel.r.toInt() << 16) |
        (pixel.g.toInt() << 8) |
        pixel.b.toInt();
  }
  final source =
      zxing.RGBLuminanceSource(decoded.width, decoded.height, pixels);
  final bitmap = zxing.BinaryBitmap(zxing.HybridBinarizer(source));
  return zxing.QRCodeReader().decode(bitmap).text;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const data = 'https://example.com/image-mode-test';
  late Uint8List photoBytes;

  setUpAll(() {
    photoBytes = makeTestPhoto();
  });

  Future<ArtisticQr> createQr(QrImageMode mode,
      {QrStyle style = const QrStyle()}) {
    return ArtisticQr.create(
      data: data,
      errorCorrection: QrErrorCorrection.high,
      style: style,
      image: QrImage(
        source: QrImageSource.memory(photoBytes),
        mode: mode,
      ),
    );
  }

  group('image sampling', () {
    test('averageColor and transparency handling', () async {
      final pixels = await QrImageSource.memory(photoBytes).resolve();
      // Transparent border → null.
      expect(
          pixels.averageColor(const Rect.fromLTRB(0, 0, 0.05, 0.05)), isNull);
      // Opaque center → a color.
      final center =
          pixels.averageColor(const Rect.fromLTRB(0.45, 0.45, 0.55, 0.55));
      expect(center, isNotNull);
      expect(center!.a, 1.0);
      final lum =
          pixels.averageLuminance(const Rect.fromLTRB(0.45, 0.45, 0.55, 0.55));
      expect(lum, isNotNull);
      expect(lum, inInclusiveRange(0.0, 1.0));
    });
  });

  group('logo mode', () {
    test('renders and decodes with knockout', () async {
      final qr = await createQr(const QrImageMode.logo());
      expect(qr.imageData!.skipModule, isNotNull);
      // Some data modules must actually be knocked out.
      var skipped = 0;
      for (var r = 0; r < qr.code.size; r++) {
        for (var c = 0; c < qr.code.size; c++) {
          if (qr.imageData!.skipModule!(r, c)) skipped++;
        }
      }
      expect(skipped, greaterThan(10));
      expect(await renderAndDecode(qr.painter), data);
    });

    test('renders and decodes without knockout', () async {
      final qr = await createQr(const QrImageMode.logo(knockout: false));
      expect(qr.imageData!.skipModule, isNull);
      expect(await renderAndDecode(qr.painter), data);
    });

    test('works at every error-correction level (size per guidance)', () async {
      // Low EC levels can only recover a few codewords, so the logo must
      // stay small there — this mirrors the documented guidance.
      const scaleFor = {
        QrErrorCorrection.low: 0.10,
        QrErrorCorrection.medium: 0.14,
        QrErrorCorrection.quartile: 0.18,
        QrErrorCorrection.high: 0.25,
      };
      for (final level in QrErrorCorrection.values) {
        final qr = await ArtisticQr.create(
          data: data,
          errorCorrection: level,
          image: QrImage(
            source: QrImageSource.memory(photoBytes),
            mode: QrImageMode.logo(scale: scaleFor[level]!),
          ),
        );
        expect(await renderAndDecode(qr.painter), data,
            reason: 'logo failed at $level');
      }
    });
  });

  group('blend mode', () {
    test('modules take image colors and stay scannable', () async {
      final qr = await createQr(const QrImageMode.blend(),
          style: const QrStyle(moduleShape: ModuleShape.circle));
      final resolver = qr.imageData!.moduleColorResolver!;
      // Modules under the opaque image area get recolored…
      var recolored = 0;
      for (var r = 0; r < qr.code.size; r++) {
        for (var c = 0; c < qr.code.size; c++) {
          if (resolver(r, c) != null) recolored++;
        }
      }
      expect(recolored, greaterThan(50));
      // …and finder modules never are.
      expect(resolver(0, 0), isNull);
      expect(await renderAndDecode(qr.painter), data);
    });

    test('enforceContrast darkens light colors', () async {
      // Light but below the white threshold, so it gets clamped (not
      // treated as background).
      final white = img.Image(width: 32, height: 32);
      img.fill(white, color: img.ColorRgb8(235, 210, 190));
      final source =
          QrImageSource.memory(Uint8List.fromList(img.encodePng(white)));
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(source: source, mode: const QrImageMode.blend()),
      );
      final resolver = qr.imageData!.moduleColorResolver!;
      Color? sample;
      for (var r = 0; r < qr.code.size && sample == null; r++) {
        for (var c = 0; c < qr.code.size && sample == null; c++) {
          sample = resolver(r, c);
        }
      }
      expect(sample, isNotNull);
      final lum = 0.299 * sample!.r + 0.587 * sample.g + 0.114 * sample.b;
      expect(lum, lessThanOrEqualTo(0.56),
          reason: 'light image colors must be darkened for contrast');
      expect(await renderAndDecode(qr.painter), data);
    });

    test('near-white areas fall back to the style fill', () async {
      final white = img.Image(width: 32, height: 32);
      img.fill(white, color: img.ColorRgb8(252, 252, 252));
      final source =
          QrImageSource.memory(Uint8List.fromList(img.encodePng(white)));
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(source: source, mode: const QrImageMode.blend()),
      );
      final resolver = qr.imageData!.moduleColorResolver!;
      for (var r = 0; r < qr.code.size; r++) {
        for (var c = 0; c < qr.code.size; c++) {
          expect(resolver(r, c), isNull,
              reason: 'white background must not recolor modules');
        }
      }
    });
  });

  group('halftone mode', () {
    test('center subpixels always carry the data bit', () async {
      final qr = await createQr(const QrImageMode.halftone());
      final grid = qr.imageData!.halftone!;
      for (var r = 0; r < qr.code.size; r++) {
        for (var c = 0; c < qr.code.size; c++) {
          if (qr.code.matrix.roleAt(r, c) != QrModuleRole.data) continue;
          expect(grid.isDark(r * 3 + 1, c * 3 + 1),
              qr.code.matrix.isDark(r, c),
              reason: 'module ($r,$c) center subpixel lost its data bit');
        }
      }
    });

    test('monochrome halftone decodes', () async {
      final qr = await createQr(const QrImageMode.halftone());
      expect(await renderAndDecode(qr.painter, pixelSize: 900), data);
    });

    test('halftone without dithering decodes', () async {
      final qr = await createQr(const QrImageMode.halftone(dithering: false));
      expect(await renderAndDecode(qr.painter, pixelSize: 900), data);
    });

    test('colored halftone decodes', () async {
      final qr = await createQr(const QrImageMode.halftone(colored: true));
      expect(await renderAndDecode(qr.painter, pixelSize: 900), data);
    });

    test('brightness shifts the dark pixel count', () async {
      final dark = await createQr(const QrImageMode.halftone(
          brightness: -0.8, dithering: false));
      final light = await createQr(const QrImageMode.halftone(
          brightness: 0.8, dithering: false));
      int countDark(HalftoneGrid grid) {
        var count = 0;
        for (var i = 0; i < grid.cells.length; i++) {
          count += grid.cells[i];
        }
        return count;
      }

      expect(countDark(dark.imageData!.halftone!),
          greaterThan(countDark(light.imageData!.halftone!)));
      expect(await renderAndDecode(light.painter, pixelSize: 900), data);
    });
  });

  group('widget with image', () {
    testWidgets('resolves image and repaints', (tester) async {
      await tester.pumpWidget(
        Center(
          child: ArtisticQrCode(
            data: data,
            size: 240,
            errorCorrection: QrErrorCorrection.high,
            image: QrImage(
              source: QrImageSource.memory(photoBytes),
              mode: const QrImageMode.blend(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArtisticQrCode), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
