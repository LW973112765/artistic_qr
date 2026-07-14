import 'dart:convert';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render_test.dart' show renderAndDecode;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const data = 'https://example.com/presets-test';

  group('presets', () {
    test('all presets decode from rendered PNGs', () async {
      for (final entry in QrStylePresets.all.entries) {
        final code =
            QrCode.encode(data, errorCorrection: QrErrorCorrection.high);
        final painter = QrPainter(code: code, style: entry.value);
        expect(await renderAndDecode(painter, pixelSize: 640), data,
            reason: 'preset "${entry.key}" broke scannability');
      }
    });

    test('no preset triggers scan-guard warnings', () async {
      for (final entry in QrStylePresets.all.entries) {
        final qr = await ArtisticQr.create(data: data, style: entry.value);
        expect(qr.validate(), isEmpty,
            reason: 'preset "${entry.key}" has warnings');
      }
    });
  });

  group('style JSON serialization', () {
    test('every preset survives a JSON round trip', () {
      for (final entry in QrStylePresets.all.entries) {
        final json = jsonEncode(entry.value.toJson());
        final restored =
            QrStyle.fromJson(jsonDecode(json) as Map<String, dynamic>);
        expect(jsonEncode(restored.toJson()), json,
            reason: 'preset "${entry.key}" not stable through JSON');
      }
    });

    test('complex style with overrides round-trips', () {
      final style = QrStyle(
        moduleShape: const ModuleShape.star(points: 5, inset: 0.4),
        moduleScale: 0.8,
        fill: QrFill.linearGradient(
          colors: const [Color(0xFF112233), Color(0xFF445566)],
          stops: const [0.2, 0.9],
        ),
        eyeStyle: const QrEyeStyle(
          frame: EyeFrameShape.rounded(radius: 0.4),
          pupil: EyePupilShape.leaf,
          frameFill: QrFill.solid(Color(0xFFAA0000)),
        ),
        eyeStyleOverrides: const {
          QrEyePosition.bottomLeft: QrEyeStyle(
            frame: EyeFrameShape.circle,
            pupil: EyePupilShape.circle,
          ),
        },
        background: const QrFill.solid(Color(0xFFFFFFF0)),
        quietZone: 6,
        effect: const QrEffect.extruded(depth: 0.3, color: Color(0xFF000033)),
      );
      final restored = QrStyle.fromJson(
          jsonDecode(jsonEncode(style.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(restored.toJson()), jsonEncode(style.toJson()));
      expect(restored.eyeStyleOverrides.keys, [QrEyePosition.bottomLeft]);
      expect(restored.quietZone, 6);
    });

    test('all effect variants round-trip', () {
      const effects = [
        QrEffect.none,
        QrEffect.extruded(depth: 0.4),
        QrEffect.shadow(blur: 0.5, offset: Offset(0.3, 0.1)),
        QrEffect.emboss(strength: 0.9),
      ];
      for (final effect in effects) {
        final restored = QrEffect.fromJson(
            jsonDecode(jsonEncode(effect.toJson())) as Map<String, dynamic>);
        expect(jsonEncode(restored.toJson()), jsonEncode(effect.toJson()));
      }
    });

    test('QrFrame round-trips', () {
      const frame = QrFrame(
        text: 'SCAN & GO',
        labelPosition: QrFrameLabelPosition.top,
        color: Color(0xFF123456),
        fontFamily: 'Inter',
      );
      final restored = QrFrame.fromJson(
          jsonDecode(jsonEncode(frame.toJson())) as Map<String, dynamic>);
      expect(restored.text, frame.text);
      expect(restored.labelPosition, frame.labelPosition);
      expect(restored.color, frame.color);
      expect(restored.fontFamily, 'Inter');
    });

    test('custom module shapes refuse to serialize', () {
      final style =
          QrStyle(moduleShape: ModuleShape.custom((path, rect, _) {}));
      expect(style.toJson, throwsUnsupportedError);
    });
  });
}
