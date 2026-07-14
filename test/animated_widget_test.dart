import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render_test.dart' show renderAndDecode;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const data = 'https://example.com/animated-test';

  group('AnimatedArtisticQrCode', () {
    for (final effect in QrAnimationEffect.values) {
      testWidgets('$effect pumps frames without exceptions', (tester) async {
        await tester.pumpWidget(
          Center(
            child: AnimatedArtisticQrCode(
              data: data,
              size: 220,
              effect: effect,
              duration: const Duration(milliseconds: 400),
              style: QrStylePresets.ocean,
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull,
              reason: '$effect threw during frame $i');
        }
      });
    }

    testWidgets('reveal completes and stops', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: AnimatedArtisticQrCode(
            data: data,
            size: 220,
            effect: QrAnimationEffect.reveal,
            duration: Duration(milliseconds: 300),
          ),
        ),
      );
      // Reveal does not repeat, so the tree settles.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching effects restarts cleanly', (tester) async {
      Widget build(QrAnimationEffect effect) => Center(
            child: AnimatedArtisticQrCode(
              data: data,
              size: 220,
              effect: effect,
              duration: const Duration(milliseconds: 300),
            ),
          );
      await tester.pumpWidget(build(QrAnimationEffect.pulse));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(build(QrAnimationEffect.reveal));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('animation resting states stay scannable', () {
    test('reveal at t=1 equals the full code and decodes', () async {
      // The reveal skip predicate lets everything through at t=1, so the
      // resting painter must decode like a plain one.
      final code =
          QrCode.encode(data, errorCorrection: QrErrorCorrection.high);
      final painter = QrPainter(code: code, style: QrStylePresets.candy);
      expect(await renderAndDecode(painter), data);
    });

    test('pulse minimum size (85% of moduleScale) decodes', () async {
      final code =
          QrCode.encode(data, errorCorrection: QrErrorCorrection.high);
      final painter = QrPainter(
        code: code,
        style: QrStylePresets.candy
            .copyWith(moduleScale: QrStylePresets.candy.moduleScale * 0.85),
      );
      expect(await renderAndDecode(painter), data);
    });
  });
}
