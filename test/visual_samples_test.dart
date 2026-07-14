@Tags(['samples'])
library;

// One-off visual sample generator: renders showcase PNGs so a human can
// eyeball the artistic quality. Run with:
//   flutter test test/visual_samples_test.dart --tags samples
import 'dart:io';
import 'dart:typed_data';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory('build/visual_samples');

  setUpAll(() => outDir.createSync(recursive: true));

  Future<void> save(String name, ArtisticQr qr, {int px = 900}) async {
    final bytes = await qr.toPngBytes(pixelSize: px);
    File('${outDir.path}/$name.png').writeAsBytesSync(bytes);
  }

  test('generate showcase samples', () async {
    // Crop the portrait out of the reference sheet for the halftone demo.
    final reference =
        img.decodeImage(File('atatchments/adaptive-icon.jpg').readAsBytesSync())!;
    final portrait = img.copyCrop(
      reference,
      x: (reference.width * 0.55).round(),
      y: (reference.height * 0.25).round(),
      width: (reference.width * 0.38).round(),
      height: (reference.height * 0.70).round(),
    );
    final portraitBytes = Uint8List.fromList(img.encodePng(portrait));

    const url = 'https://pub.dev/packages/artistic_qr';

    await save(
      '1_halftone_portrait',
      await ArtisticQr.create(
        data: url,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(
          source: QrImageSource.memory(portraitBytes),
          mode: const QrImageMode.halftone(),
        ),
      ),
    );

    await save(
      '2_halftone_colored',
      await ArtisticQr.create(
        data: url,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(
          source: QrImageSource.memory(portraitBytes),
          mode: const QrImageMode.halftone(colored: true),
        ),
      ),
    );

    await save(
      '3_blend_circles',
      await ArtisticQr.create(
        data: url,
        errorCorrection: QrErrorCorrection.high,
        style: const QrStyle(
          moduleShape: ModuleShape.circle,
          eyeStyle: QrEyeStyle(
            frame: EyeFrameShape.rounded(),
            pupil: EyePupilShape.circle,
            frameFill: QrFill.solid(Color(0xFF7B1FA2)),
            pupilFill: QrFill.solid(Color(0xFF7B1FA2)),
          ),
        ),
        image: QrImage(
          source: QrImageSource.memory(portraitBytes),
          mode: const QrImageMode.blend(),
        ),
      ),
    );

    await save(
      '4_gradient_fluid',
      await ArtisticQr.create(
        data: url,
        errorCorrection: QrErrorCorrection.quartile,
        style: QrStyle(
          moduleShape: ModuleShape.fluid,
          fill: QrFill.linearGradient(
            colors: const [Color(0xFF1565C0), Color(0xFF6A1B9A)],
          ),
          eyeStyle: const QrEyeStyle(
            frame: EyeFrameShape.rounded(),
            pupil: EyePupilShape.rounded(),
          ),
        ),
      ),
    );

    await save(
      '5_dots_gradient_circle_eyes',
      await ArtisticQr.create(
        data: url,
        errorCorrection: QrErrorCorrection.quartile,
        style: QrStyle(
          moduleShape: ModuleShape.circle,
          moduleScale: 0.85,
          fill: QrFill.radialGradient(
            colors: const [Color(0xFF00838F), Color(0xFF1A237E)],
            radius: 0.9,
          ),
          eyeStyle: const QrEyeStyle(
            frame: EyeFrameShape.circle,
            pupil: EyePupilShape.circle,
            frameFill: QrFill.solid(Color(0xFF00838F)),
          ),
        ),
      ),
    );
  }, tags: ['samples'], timeout: const Timeout(Duration(minutes: 3)));
}
