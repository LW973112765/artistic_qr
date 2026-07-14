import 'dart:convert';
import 'dart:typed_data';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zxing2/qrcode.dart' as zxing;
// Low-level pieces for detector-free decoding: zxing2's image detector fails
// on some perfectly valid symbols (even its own encoder's v25/v31 output),
// so structural tests feed the module matrix straight to the decoder.
import 'package:zxing2/src/common/bit_matrix.dart' as zxing;
import 'package:zxing2/src/qrcode/decoder/decoder.dart' as zxing;

/// Decodes an encoded [QrCode] with zxing2 by rasterizing each module to
/// [scale]×[scale] pixels with a quiet zone.
zxing.Result zxingResult(QrCode code, {int scale = 4, int quietZone = 4}) {
  final size = (code.size + quietZone * 2) * scale;
  final pixels = Int32List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final row = y ~/ scale - quietZone;
      final col = x ~/ scale - quietZone;
      final dark = row >= 0 &&
          row < code.size &&
          col >= 0 &&
          col < code.size &&
          code.matrix.isDark(row, col);
      pixels[y * size + x] = dark ? 0xFF000000 : 0xFFFFFFFF;
    }
  }
  final source = zxing.RGBLuminanceSource(size, size, pixels);
  final bitmap = zxing.BinaryBitmap(zxing.HybridBinarizer(source));
  return zxing.QRCodeReader().decode(bitmap);
}

String decodeWithZxing(QrCode code, {int scale = 4, int quietZone = 4}) =>
    zxingResult(code, scale: scale, quietZone: quietZone).text;

/// Decodes the module matrix directly, without zxing2's image detector.
String decodeMatrixWithZxing(QrCode code) {
  final bits = zxing.BitMatrix(code.size);
  for (var r = 0; r < code.size; r++) {
    for (var c = 0; c < code.size; c++) {
      if (code.matrix.isDark(r, c)) bits.set(c, r);
    }
  }
  final result = zxing.Decoder().decode(bits, hints: zxing.DecodeHints());
  return result.text;
}

/// Decoded byte-mode payload. zxing2's `Result.text` mangles bytes > 0x7F
/// (it feeds signed Int8List values into Utf8Codec), so byte-fidelity tests
/// read the raw byte segments instead.
List<int> decodeBytesWithZxing(QrCode code, {int scale = 4}) {
  final result = zxingResult(code, scale: scale);
  final segments =
      result.resultMetadata[zxing.ResultMetadataType.byteSegments]!
          as List<Int8List>;
  return [
    for (final segment in segments)
      for (final b in segment) b & 0xFF,
  ];
}

void main() {
  group('module matrix structure', () {
    test('v1 has size 21 and correct function patterns', () {
      final code = QrCode.encode('HELLO WORLD',
          errorCorrection: QrErrorCorrection.quartile);
      expect(code.version, 1);
      expect(code.size, 21);
      // Finder corners are dark.
      expect(code.matrix.isDark(0, 0), isTrue);
      expect(code.matrix.isDark(0, 20), isTrue);
      expect(code.matrix.isDark(20, 0), isTrue);
      // Separator is light.
      expect(code.matrix.isDark(7, 7), isFalse);
      expect(code.matrix.roleAt(7, 7), QrModuleRole.separator);
      // Timing pattern alternates.
      expect(code.matrix.isDark(6, 8), isTrue);
      expect(code.matrix.isDark(6, 9), isFalse);
      expect(code.matrix.roleAt(6, 8), QrModuleRole.timing);
      // Dark module.
      expect(code.matrix.isDark(code.size - 8, 8), isTrue);
      expect(code.matrix.roleAt(code.size - 8, 8), QrModuleRole.dark);
    });

    test('every module has a role assigned', () {
      final code = QrCode.encode('https://example.com/some/path?q=1');
      for (var r = 0; r < code.size; r++) {
        for (var c = 0; c < code.size; c++) {
          expect(code.matrix.roleAt(r, c), isNot(QrModuleRole.none),
              reason: 'module ($r,$c) has no role');
        }
      }
    });

    test('eyeAt identifies the three finder regions', () {
      final code = QrCode.encode('EYE TEST');
      expect(code.matrix.eyeAt(0, 0), QrEyePosition.topLeft);
      expect(code.matrix.eyeAt(3, code.size - 1), QrEyePosition.topRight);
      expect(code.matrix.eyeAt(code.size - 1, 3), QrEyePosition.bottomLeft);
      expect(code.matrix.eyeAt(10, 10), isNull);
    });

    test('version info present for v7+', () {
      // 200 alphanumeric chars at EC-H needs at least version 12.
      final code = QrCode.encode('A' * 200,
          errorCorrection: QrErrorCorrection.high);
      expect(code.version, greaterThanOrEqualTo(7));
      expect(code.matrix.roleAt(0, code.size - 9), QrModuleRole.version);
      expect(code.matrix.roleAt(code.size - 9, 0), QrModuleRole.version);
    });
  });

  group('round-trip decoding (zxing2)', () {
    test('numeric mode', () {
      final code = QrCode.encode('0123456789012345');
      expect(decodeWithZxing(code), '0123456789012345');
    });

    test('alphanumeric mode', () {
      final code = QrCode.encode(r'HELLO WORLD $%*+-./:');
      expect(decodeWithZxing(code), r'HELLO WORLD $%*+-./:');
    });

    test('byte mode (ASCII with mixed symbols)', () {
      const text = 'https://example.com/path?a=1&b=2#frag_~';
      final code = QrCode.encode(text);
      expect(decodeWithZxing(code), text);
    });

    test('byte mode (UTF-8 with ECI)', () {
      // Compare byte segments directly: zxing2's Result.text corrupts
      // non-ASCII bytes regardless of what the encoder does.
      const text = 'Ünïcödé مرحبا 你好世界 🎨';
      final code = QrCode.encode(text);
      expect(utf8.decode(decodeBytesWithZxing(code)), text);
    });

    test('raw bytes survive round trip exactly', () {
      final bytes = List<int>.generate(64, (i) => (i * 37) & 0xFF);
      final code = QrCode.encodeBytes(bytes);
      expect(decodeBytesWithZxing(code), bytes);
    });

    test('all error-correction levels', () {
      for (final level in QrErrorCorrection.values) {
        final code =
            QrCode.encode('https://pub.dev/packages/artistic_qr?ec=$level',
                errorCorrection: level);
        expect(decodeWithZxing(code),
            'https://pub.dev/packages/artistic_qr?ec=$level',
            reason: 'failed at level $level');
      }
    });

    test('all 8 forced masks decode', () {
      for (var mask = 0; mask < 8; mask++) {
        final code = QrCode.encode('MASK TEST $mask', mask: mask);
        expect(code.mask, mask);
        expect(decodeWithZxing(code), 'MASK TEST $mask',
            reason: 'failed at mask $mask');
      }
    });

    test('every version 1–40 decodes', () {
      // zxing2's image detector cannot locate v25/v31 symbols at all (it
      // fails on its own encoder's output too), so those two are decoded
      // matrix-directly; everything else goes through the full image path.
      const detectorBlindVersions = {25, 31};
      for (var v = 1; v <= 40; v++) {
        final code = QrCode.encode(
          'VERSION $v TEST',
          errorCorrection: QrErrorCorrection.medium,
          minVersion: v,
          maxVersion: v,
        );
        expect(code.version, v);
        final decoded = detectorBlindVersions.contains(v)
            ? decodeMatrixWithZxing(code)
            : decodeWithZxing(code, scale: 8);
        expect(decoded, 'VERSION $v TEST', reason: 'failed at version $v');
      }
    });

    test('matches zxing2 encoder bit-for-bit, all versions and levels', () {
      final levels = {
        QrErrorCorrection.low: zxing.ErrorCorrectionLevel.l,
        QrErrorCorrection.medium: zxing.ErrorCorrectionLevel.m,
        QrErrorCorrection.quartile: zxing.ErrorCorrectionLevel.q,
        QrErrorCorrection.high: zxing.ErrorCorrectionLevel.h,
      };
      for (var v = 1; v <= 40; v++) {
        for (final entry in levels.entries) {
          final hints = zxing.EncodeHints()
            ..put<int>(zxing.EncodeHintType.qrVersion, v);
          final reference = zxing.Encoder.encode(
              'BITWISE $v', entry.value, hints: hints);
          final matrix = reference.matrix!;
          final mine = QrCode.encode('BITWISE $v',
              errorCorrection: entry.key,
              minVersion: v,
              maxVersion: v,
              mask: reference.maskPattern);
          var diffs = 0;
          for (var r = 0; r < mine.size; r++) {
            for (var c = 0; c < mine.size; c++) {
              if ((matrix.get(c, r) == 1) != mine.matrix.isDark(r, c)) {
                diffs++;
              }
            }
          }
          expect(diffs, 0,
              reason: 'v$v ${entry.key}: $diffs modules differ from zxing2');
        }
      }
    });

    test('large payload picks a high version and decodes', () {
      final text = List.generate(40, (i) => 'segment-$i-of-payload').join('/');
      final code =
          QrCode.encode(text, errorCorrection: QrErrorCorrection.high);
      expect(code.version, greaterThan(10));
      expect(decodeWithZxing(code, scale: 3), text);
    });
  });

  group('limits', () {
    test('too much data throws', () {
      expect(
        () => QrCode.encode('9' * 8000,
            errorCorrection: QrErrorCorrection.high),
        throwsA(isA<QrDataTooLongException>()),
      );
    });

    test('version constraint respected', () {
      final code = QrCode.encode('FIT', minVersion: 5);
      expect(code.version, 5);
    });
  });
}
