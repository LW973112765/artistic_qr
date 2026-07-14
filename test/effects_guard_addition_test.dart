import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep extrusion with large modules is flagged', () async {
    final qr = await ArtisticQr.create(
      data: 'x',
      style: const QrStyle(
        effect: QrEffect.extruded(depth: 0.45),
        moduleScale: 0.9,
      ),
    );
    expect(qr.validate().map((w) => w.code), contains('extrusion-overlap'));
  });

  test('deep extrusion with small modules is fine', () async {
    final qr = await ArtisticQr.create(
      data: 'x',
      style: const QrStyle(
        effect: QrEffect.extruded(depth: 0.45),
        moduleScale: 0.72,
      ),
    );
    expect(qr.validate(), isEmpty);
  });
}
