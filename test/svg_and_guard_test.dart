import 'dart:typed_data';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

Uint8List solidPng(int r, int g, int b, {int size = 32}) {
  final im = img.Image(width: size, height: size);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const data = 'https://example.com/svg-test';

  group('SVG export', () {
    test('plain styled code produces well-formed SVG', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: QrStyle(
          moduleShape: ModuleShape.fluid,
          fill: QrFill.linearGradient(
            colors: const [Color(0xFF0D47A1), Color(0xFF4A148C)],
          ),
          eyeStyle: const QrEyeStyle(
            frame: EyeFrameShape.rounded(),
            pupil: EyePupilShape.circle,
          ),
        ),
      );
      final svg = await qr.toSvg();
      final doc = XmlDocument.parse(svg); // throws if malformed
      final root = doc.rootElement;
      expect(root.name.local, 'svg');
      expect(root.getAttribute('viewBox'), '0 0 512 512');
      expect(svg, contains('<linearGradient'));
      expect(svg, contains('fill-rule="evenodd"'));
      expect(svg, contains('url(#g'));
      // One background rect + module path + 3 eye frames + 3 pupils.
      expect(root.findAllElements('path').length, greaterThanOrEqualTo(7));
    });

    test('every module shape exports exact (non-sampled) paths', () async {
      final shapes = <ModuleShape>[
        ModuleShape.square,
        ModuleShape.circle,
        const ModuleShape.rounded(),
        ModuleShape.diamond,
        const ModuleShape.star(),
        ModuleShape.classy,
        ModuleShape.fluid,
        ModuleShape.verticalBars,
        ModuleShape.horizontalBars,
      ];
      for (final shape in shapes) {
        final qr = await ArtisticQr.create(
            data: data, style: QrStyle(moduleShape: shape));
        final svg = await qr.toSvg();
        XmlDocument.parse(svg);
        expect(svg, isNot(contains('NaN')), reason: '$shape emitted NaN');
      }
    });

    test('custom shapes fall back to sampled outlines', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: QrStyle(
          moduleShape: ModuleShape.custom(
              (path, rect, _) => path.addOval(rect.deflate(0.5))),
        ),
      );
      final svg = await qr.toSvg();
      XmlDocument.parse(svg);
      expect(svg, contains('<path'));
    });

    test('logo mode embeds a base64 PNG image', () async {
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(
          source: QrImageSource.memory(solidPng(200, 30, 30)),
          mode: const QrImageMode.logo(),
        ),
      );
      final svg = await qr.toSvg();
      XmlDocument.parse(svg);
      expect(svg, contains('data:image/png;base64,'));
    });

    test('halftone mode exports subcell rects', () async {
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(
          source: QrImageSource.memory(solidPng(90, 90, 90, size: 64)),
          mode: const QrImageMode.halftone(),
        ),
      );
      final svg = await qr.toSvg();
      final doc = XmlDocument.parse(svg);
      // Halftone body is a big multi-rect path.
      final paths = doc.rootElement.findAllElements('path');
      final longest = paths
          .map((p) => p.getAttribute('d')?.length ?? 0)
          .reduce((a, b) => a > b ? a : b);
      expect(longest, greaterThan(5000));
    });

    test('blend mode exports per-color module paths', () async {
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(
          source: QrImageSource.memory(solidPng(20, 60, 160)),
          mode: const QrImageMode.blend(),
        ),
      );
      final svg = await qr.toSvg();
      XmlDocument.parse(svg);
      expect(svg, contains('fill="#'));
    });
  });

  group('scan guard', () {
    test('clean default design has no warnings', () async {
      final qr = await ArtisticQr.create(data: data);
      expect(qr.validate(), isEmpty);
    });

    test('low contrast is flagged', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: const QrStyle(
          fill: QrFill.solid(Color(0xFFDDDDDD)),
        ),
      );
      expect(qr.validate().map((w) => w.code), contains('low-contrast'));
    });

    test('missing quiet zone is flagged', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: const QrStyle(quietZone: 0),
      );
      expect(qr.validate().map((w) => w.code), contains('quiet-zone'));
    });

    test('tiny modules are flagged', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: const QrStyle(moduleScale: 0.4),
      );
      expect(qr.validate().map((w) => w.code), contains('small-modules'));
    });

    test('oversized logo at low EC is flagged', () async {
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.low,
        image: QrImage(
          source: QrImageSource.memory(solidPng(10, 10, 10)),
          mode: const QrImageMode.logo(scale: 0.3),
        ),
      );
      expect(qr.validate().map((w) => w.code), contains('logo-too-large'));
    });

    test('reasonable logo at high EC is not flagged', () async {
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.high,
        image: QrImage(
          source: QrImageSource.memory(solidPng(10, 10, 10)),
          mode: const QrImageMode.logo(scale: 0.2),
        ),
      );
      expect(qr.validate(), isEmpty);
    });

    test('blend without EC-high is flagged', () async {
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.quartile,
        image: QrImage(
          source: QrImageSource.memory(solidPng(10, 10, 10)),
          mode: const QrImageMode.blend(),
        ),
      );
      expect(
          qr.validate().map((w) => w.code), contains('art-mode-needs-ec-high'));
    });
  });
}
