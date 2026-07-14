// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

/// Generates the example app's demo assets:
///  * portrait.png — cropped from the reference sheet, for halftone demos
///  * logo.png — a simple generated round logo, for logo/blend demos
void main() {
  final reference = img.decodeImage(
      File('atatchments/adaptive-icon.jpg').readAsBytesSync())!;
  final portrait = img.copyCrop(
    reference,
    x: (reference.width * 0.55).round(),
    y: (reference.height * 0.25).round(),
    width: (reference.width * 0.38).round(),
    height: (reference.height * 0.70).round(),
  );
  File('example/assets/portrait.png')
      .writeAsBytesSync(img.encodePng(img.copyResize(portrait, width: 480)));

  // A bold two-tone round logo.
  const size = 256;
  final logo = img.Image(width: size, height: size, numChannels: 4);
  const cx = size / 2, cy = size / 2;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - cx, dy = y - cy;
      final d = dx * dx + dy * dy;
      if (d < (size * 0.48) * (size * 0.48)) {
        final inner = d < (size * 0.30) * (size * 0.30);
        logo.setPixelRgba(
            x, y, inner ? 255 : 21, inner ? 111 : 101, inner ? 0 : 192, 255);
      } else {
        logo.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  File('example/assets/logo.png').writeAsBytesSync(img.encodePng(logo));
  print('wrote example/assets/portrait.png and example/assets/logo.png');
}
