// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final files = Directory('example/assets')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.webp'))
      .toList();
  if (files.isEmpty) {
    print('no webp found');
    return;
  }
  final decoded = img.decodeImage(files.first.readAsBytesSync());
  if (decoded == null) {
    print('could not decode ${files.first.path}');
    return;
  }
  final resized =
      decoded.width > 512 ? img.copyResize(decoded, width: 512) : decoded;
  File('example/assets/alkarama.png')
      .writeAsBytesSync(img.encodePng(resized));
  print('wrote example/assets/alkarama.png '
      '(${resized.width}x${resized.height}, '
      'hasAlpha: ${resized.hasAlpha})');
}
