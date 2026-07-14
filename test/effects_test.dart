import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'render_test.dart' show renderAndDecode;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const data = 'https://example.com/3d-effect-test';

  // Deep extrusion needs smaller dots so the sides stay inside the module
  // gaps (the scan guard warns about the risky combination).
  final effects = <String, (QrEffect, double)>{
    'extruded': (const QrEffect.extruded(), 0.9),
    'extruded deep + colored': (
      const QrEffect.extruded(depth: 0.45, color: Color(0xFF4527A0)),
      0.72,
    ),
    'shadow': (const QrEffect.shadow(), 0.9),
    'shadow hard (no blur)': (const QrEffect.shadow(blur: 0), 0.9),
    'emboss': (const QrEffect.emboss(), 0.9),
    'emboss strong': (const QrEffect.emboss(strength: 1.0), 0.9),
  };

  group('3D effects stay scannable', () {
    for (final entry in effects.entries) {
      test(entry.key, () async {
        final code =
            QrCode.encode(data, errorCorrection: QrErrorCorrection.high);
        final painter = QrPainter(
          code: code,
          style: QrStyle(
            moduleShape: const ModuleShape.rounded(),
            moduleScale: entry.value.$2,
            effect: entry.value.$1,
            eyeStyle: const QrEyeStyle(
              frame: EyeFrameShape.rounded(),
              pupil: EyePupilShape.rounded(),
            ),
          ),
        );
        expect(await renderAndDecode(painter, pixelSize: 640), data,
            reason: 'effect "${entry.key}" broke scannability');
      });
    }

    test('extruded + gradient + circles decodes', () async {
      final code =
          QrCode.encode(data, errorCorrection: QrErrorCorrection.high);
      final painter = QrPainter(
        code: code,
        style: QrStyle(
          moduleShape: ModuleShape.circle,
          moduleScale: 0.85,
          effect: const QrEffect.extruded(),
          fill: QrFill.linearGradient(
            colors: const [Color(0xFF1565C0), Color(0xFF6A1B9A)],
          ),
        ),
      );
      expect(await renderAndDecode(painter, pixelSize: 640), data);
    });
  });

  group('3D effects in SVG', () {
    test('extruded emits <use> layers', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: const QrStyle(effect: QrEffect.extruded()),
      );
      final svg = await qr.toSvg();
      XmlDocument.parse(svg);
      expect(svg, contains('id="qr-dark"'));
      expect('use href="#qr-dark"'.allMatches(svg).length, greaterThanOrEqualTo(4));
    });

    test('shadow emits a blur filter', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: const QrStyle(effect: QrEffect.shadow()),
      );
      final svg = await qr.toSvg();
      XmlDocument.parse(svg);
      expect(svg, contains('feGaussianBlur'));
      expect(svg, contains('filter="url(#qr-blur)"'));
    });

    test('emboss is skipped in SVG (raster-only)', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: const QrStyle(effect: QrEffect.emboss()),
      );
      final svg = await qr.toSvg();
      XmlDocument.parse(svg);
      expect(svg, isNot(contains('qr-dark')));
    });
  });
}
