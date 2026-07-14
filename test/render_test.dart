import 'dart:typed_data';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart' as zxing;

/// Renders [painter] to a PNG and decodes it with zxing2, exactly as a
/// phone camera pipeline would see it.
Future<String> renderAndDecode(QrPainter painter, {int pixelSize = 480}) async {
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

  const data = 'https://example.com/artistic-qr-style-test';

  final presets = <String, QrStyle>{
    'default (squares)': const QrStyle(),
    'circle dots': const QrStyle(
      moduleShape: ModuleShape.circle,
      eyeStyle: QrEyeStyle(
        frame: EyeFrameShape.circle,
        pupil: EyePupilShape.circle,
      ),
    ),
    'rounded + scaled': const QrStyle(
      moduleShape: ModuleShape.rounded(),
      moduleScale: 0.85,
      eyeStyle: QrEyeStyle(
        frame: EyeFrameShape.rounded(),
        pupil: EyePupilShape.rounded(),
      ),
    ),
    'fluid': const QrStyle(moduleShape: ModuleShape.fluid),
    'diamond': const QrStyle(moduleShape: ModuleShape.diamond),
    'star': QrStyle(moduleShape: const ModuleShape.star(), moduleScale: 0.95),
    'classy + leaf eyes': const QrStyle(
      moduleShape: ModuleShape.classy,
      eyeStyle: QrEyeStyle(
        frame: EyeFrameShape.leaf,
        pupil: EyePupilShape.leaf,
      ),
    ),
    'vertical bars': const QrStyle(moduleShape: ModuleShape.verticalBars),
    'horizontal bars': const QrStyle(moduleShape: ModuleShape.horizontalBars),
    'linear gradient': QrStyle(
      moduleShape: ModuleShape.circle,
      fill: QrFill.linearGradient(
        colors: const [Color(0xFF1A237E), Color(0xFF4A148C)],
      ),
      eyeStyle: const QrEyeStyle(
        frame: EyeFrameShape.rounded(),
        pupil: EyePupilShape.circle,
        frameFill: QrFill.solid(Color(0xFF1A237E)),
      ),
    ),
    'radial gradient': QrStyle(
      moduleShape: const ModuleShape.rounded(),
      fill: QrFill.radialGradient(
        colors: const [Color(0xFF004D40), Color(0xFF1B5E20)],
      ),
    ),
    'sweep gradient': QrStyle(
      fill: QrFill.sweepGradient(
        colors: const [
          Color(0xFF0D47A1),
          Color(0xFF4A148C),
          Color(0xFF0D47A1),
        ],
      ),
    ),
    'per-eye overrides': const QrStyle(
      moduleShape: ModuleShape.circle,
      fill: QrFill.solid(Color(0xFF212121)),
      eyeStyle: QrEyeStyle(
        frame: EyeFrameShape.rounded(),
        pupil: EyePupilShape.circle,
        frameFill: QrFill.solid(Color(0xFFB71C1C)),
        pupilFill: QrFill.solid(Color(0xFFE65100)),
      ),
      eyeStyleOverrides: {
        QrEyePosition.bottomLeft: QrEyeStyle(
          frame: EyeFrameShape.circle,
          pupil: EyePupilShape.circle,
          frameFill: QrFill.solid(Color(0xFF1B5E20)),
        ),
      },
    ),
    'custom module shape': QrStyle(
      moduleShape: ModuleShape.custom((path, rect, neighbors) {
        path.addOval(rect.deflate(rect.width * 0.05));
      }),
    ),
  };

  group('styled QR codes decode from rendered PNGs', () {
    for (final entry in presets.entries) {
      test(entry.key, () async {
        final code = QrCode.encode(data,
            errorCorrection: QrErrorCorrection.high);
        final painter = QrPainter(code: code, style: entry.value);
        expect(await renderAndDecode(painter), data,
            reason: 'style "${entry.key}" broke scannability');
      });
    }
  });

  group('painter hooks', () {
    test('module color overrides keep the code scannable', () async {
      final code =
          QrCode.encode(data, errorCorrection: QrErrorCorrection.high);
      final painter = QrPainter(
        code: code,
        moduleColorResolver: (row, col) =>
            (row + col).isEven ? const Color(0xFF1A237E) : null,
      );
      expect(await renderAndDecode(painter), data);
    });

    test('foreground painter is invoked', () async {
      var called = false;
      final code = QrCode.encode(data);
      final painter = QrPainter(
        code: code,
        foregroundPainter: (canvas, layout) => called = true,
      );
      await painter.toPngByteData(120);
      expect(called, isTrue);
    });
  });

  group('widget', () {
    testWidgets('builds and paints', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: ArtisticQrCode(data: 'https://example.com', size: 200),
        ),
      );
      expect(find.byType(ArtisticQrCode), findsOneWidget);
    });

    testWidgets('errorBuilder used when data too long', (tester) async {
      await tester.pumpWidget(
        Center(
          child: ArtisticQrCode(
            data: '9' * 8000,
            size: 200,
            errorBuilder: (context, error) => const SizedBox(key: Key('err')),
          ),
        ),
      );
      expect(find.byKey(const Key('err')), findsOneWidget);
    });
  });
}
