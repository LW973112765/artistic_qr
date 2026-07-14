import 'package:artistic_qr/artistic_qr.dart';
import 'package:artistic_qr_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery renders all demos without exceptions', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GalleryApp());
    // pumpAndSettle would never settle: the animated demos loop forever.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: 'exception at frame $i');
    }

    expect(find.byType(ArtisticQrCode), findsWidgets);
    expect(find.byType(AnimatedArtisticQrCode), findsWidgets);
  });
}
