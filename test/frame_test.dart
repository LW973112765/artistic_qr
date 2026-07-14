import 'dart:typed_data';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

import 'render_test.dart' show renderAndDecode;

Uint8List _dot() {
  final im = img.Image(width: 24, height: 24);
  img.fill(im, color: img.ColorRgb8(180, 40, 40));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const data = 'https://example.com/frame-test';

  group('QrFrame rendering', () {
    test('framed code still decodes (bottom label)', () async {
      final qr = await ArtisticQr.create(
        data: data,
        frame: const QrFrame(),
      );
      expect(await renderAndDecode(qr.painter, pixelSize: 640), data);
    });

    test('framed code still decodes (top label + styles)', () async {
      final qr = await ArtisticQr.create(
        data: data,
        style: const QrStyle(moduleShape: ModuleShape.circle),
        frame: const QrFrame(
          text: 'SCAN FOR MENU',
          labelPosition: QrFrameLabelPosition.top,
          color: Color(0xFF1565C0),
        ),
      );
      expect(await renderAndDecode(qr.painter, pixelSize: 640), data);
    });

    test('empty text keeps the border only and decodes', () async {
      final qr = await ArtisticQr.create(
        data: data,
        frame: const QrFrame(text: ''),
      );
      expect(await renderAndDecode(qr.painter, pixelSize: 640), data);
    });

    test('frame combines with logo image mode', () async {
      final qr = await ArtisticQr.create(
        data: data,
        errorCorrection: QrErrorCorrection.high,
        frame: const QrFrame(color: Color(0xFF6A1B9A)),
        image: QrImage(
          source: QrImageSource.memory(_dot()),
          mode: const QrImageMode.logo(scale: 0.18),
        ),
      );
      expect(await renderAndDecode(qr.painter, pixelSize: 640), data);
    });

    test('geometry: QR square sits inside the banner-free area', () {
      const frame = QrFrame();
      final g = QrFrameGeometry.compute(frame, const Size.square(400));
      expect(g.qrRect.bottom, lessThanOrEqualTo(g.bannerRect.top));
      expect(g.qrRect.width, g.qrRect.height);
      expect(g.hasBanner, isTrue);
    });
  });

  group('QrFrame in SVG', () {
    test('emits border, banner and escaped label text', () async {
      final qr = await ArtisticQr.create(
        data: data,
        frame: const QrFrame(text: 'SCAN & GO'),
      );
      final svg = await qr.toSvg();
      final doc = XmlDocument.parse(svg);
      expect(svg, contains('stroke-width'));
      expect(svg, contains('SCAN &amp; GO'));
      expect(doc.rootElement.findAllElements('text').length, 1);
      expect(doc.rootElement.findAllElements('g').length, 1);
    });

    test('borderless label-free frame emits only the border rect', () async {
      final qr = await ArtisticQr.create(
        data: data,
        frame: const QrFrame(text: ''),
      );
      final svg = await qr.toSvg();
      final doc = XmlDocument.parse(svg);
      expect(doc.rootElement.findAllElements('text'), isEmpty);
    });
  });

  group('QrFrame widget', () {
    testWidgets('renders framed QR without exceptions', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: ArtisticQrCode(
            data: data,
            size: 240,
            frame: QrFrame(text: 'SCAN ME'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
