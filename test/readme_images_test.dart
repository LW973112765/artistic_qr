@Tags(['samples'])
library;

// Generates the README style-catalog cells. Run with:
//   flutter test test/readme_images_test.dart --tags samples
// then compose the grid sheets with:
//   dart run tool/make_readme_images.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const url = 'https://pub.dev/packages/artistic_qr';
  final outDir = Directory('build/readme_raw');

  late Uint8List alkarama;
  late Uint8List cr7;

  setUpAll(() async {
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    alkarama = File('example/assets/alkarama.png').readAsBytesSync();
    cr7 = File('example/assets/cr7.png').readAsBytesSync();

    // The test environment has no fonts (labels would render as boxes);
    // load Roboto from the Flutter SDK cache so frame labels look real.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final roboto = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/roboto-bold.ttf');
    if (roboto.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(
            roboto.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  Future<void> cell(String sheet, int order, String label, ArtisticQr qr,
      {int px = 460}) async {
    final bytes = await qr.toPngBytes(pixelSize: px);
    final name = '${sheet}__${order.toString().padLeft(2, '0')}__$label.png';
    File('${outDir.path}/$name').writeAsBytesSync(bytes);
  }

  QrImage blend(Uint8List bytes) => QrImage(
      source: QrImageSource.memory(bytes), mode: const QrImageMode.blend());

  test('generate README catalog cells', () async {
    // ---- Sheet 1: module shapes (each with a fitting eye style) ----
    final shapes = <(String, QrStyle)>[
      ('Square', const QrStyle()),
      (
        'Circle dots',
        const QrStyle(
          moduleShape: ModuleShape.circle,
          moduleScale: 0.88,
          fill: QrFill.solid(Color(0xFF1565C0)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.circle, pupil: EyePupilShape.circle),
        )
      ),
      (
        'Rounded',
        const QrStyle(
          moduleShape: ModuleShape.rounded(),
          fill: QrFill.solid(Color(0xFF00695C)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(), pupil: EyePupilShape.rounded()),
        )
      ),
      (
        'Diamond',
        const QrStyle(
          moduleShape: ModuleShape.diamond,
          fill: QrFill.solid(Color(0xFF4527A0)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(), pupil: EyePupilShape.circle),
        )
      ),
      (
        'Star',
        QrStyle(
          moduleShape: const ModuleShape.star(),
          moduleScale: 0.95,
          fill: const QrFill.solid(Color(0xFFAD1457)),
          eyeStyle: const QrEyeStyle(
              frame: EyeFrameShape.circle, pupil: EyePupilShape.circle),
        )
      ),
      (
        'Classy',
        const QrStyle(
          moduleShape: ModuleShape.classy,
          fill: QrFill.solid(Color(0xFF1B5E20)),
          eyeStyle:
              QrEyeStyle(frame: EyeFrameShape.leaf, pupil: EyePupilShape.leaf),
        )
      ),
      (
        'Fluid',
        const QrStyle(
          moduleShape: ModuleShape.fluid,
          fill: QrFill.solid(Color(0xFFBF360C)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(), pupil: EyePupilShape.rounded()),
        )
      ),
      (
        'Vertical bars',
        const QrStyle(
          moduleShape: ModuleShape.verticalBars,
          fill: QrFill.solid(Color(0xFF01579B)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(), pupil: EyePupilShape.rounded()),
        )
      ),
      (
        'Horizontal bars',
        const QrStyle(
          moduleShape: ModuleShape.horizontalBars,
          fill: QrFill.solid(Color(0xFF33691E)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(), pupil: EyePupilShape.rounded()),
        )
      ),
    ];
    for (var i = 0; i < shapes.length; i++) {
      await cell('shapes', i, shapes[i].$1,
          await ArtisticQr.create(data: url, style: shapes[i].$2));
    }

    // ---- Sheet 2: colors & eyes ----
    final colors = <(String, QrStyle)>[
      (
        'Linear gradient',
        QrStyle(
          moduleShape: ModuleShape.fluid,
          fill: QrFill.linearGradient(
              colors: const [Color(0xFF1565C0), Color(0xFF6A1B9A)]),
          eyeStyle: const QrEyeStyle(
              frame: EyeFrameShape.rounded(), pupil: EyePupilShape.rounded()),
        )
      ),
      (
        'Radial gradient',
        QrStyle(
          moduleShape: ModuleShape.circle,
          moduleScale: 0.85,
          fill: QrFill.radialGradient(
              colors: const [Color(0xFF00838F), Color(0xFF1A237E)],
              radius: 0.9),
          eyeStyle: const QrEyeStyle(
              frame: EyeFrameShape.circle,
              pupil: EyePupilShape.circle,
              frameFill: QrFill.solid(Color(0xFF00838F))),
        )
      ),
      (
        'Sweep gradient',
        QrStyle(
          fill: QrFill.sweepGradient(colors: const [
            Color(0xFFB71C1C),
            Color(0xFF4A148C),
            Color(0xFFB71C1C),
          ]),
        )
      ),
      (
        'Per-eye styles',
        const QrStyle(
          moduleShape: ModuleShape.circle,
          fill: QrFill.solid(Color(0xFF212121)),
          eyeStyle: QrEyeStyle(
            frame: EyeFrameShape.rounded(),
            pupil: EyePupilShape.circle,
            frameFill: QrFill.solid(Color(0xFFB71C1C)),
            pupilFill: QrFill.solid(Color(0xFFE65100)),
          ),
          eyeStyleOverrides: {
            QrEyePosition.bottomLeft: QrEyeStyle(
              frame: EyeFrameShape.circle,
              pupil: EyePupilShape.circle,
              frameFill: QrFill.solid(Color(0xFF1B5E20)),
              pupilFill: QrFill.solid(Color(0xFF1B5E20)),
            ),
          },
        )
      ),
      (
        'Leaf eyes',
        const QrStyle(
          moduleShape: ModuleShape.rounded(),
          fill: QrFill.solid(Color(0xFF33691E)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.leaf,
              pupil: EyePupilShape.leaf,
              frameFill: QrFill.solid(Color(0xFF827717))),
        )
      ),
      (
        'Airy dots',
        const QrStyle(
          moduleShape: ModuleShape.circle,
          moduleScale: 0.7,
          fill: QrFill.solid(Color(0xFF37474F)),
          eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.circle, pupil: EyePupilShape.circle),
        )
      ),
    ];
    for (var i = 0; i < colors.length; i++) {
      await cell('colors', i, colors[i].$1,
          await ArtisticQr.create(data: url, style: colors[i].$2));
    }

    // ---- Sheet 3: image modes (Al-Karamah crest + CR7 portrait) ----
    await cell(
        'images',
        0,
        'Center logo',
        await ArtisticQr.create(
          data: url,
          errorCorrection: QrErrorCorrection.high,
          style: const QrStyle(
            moduleShape: ModuleShape.rounded(),
            fill: QrFill.solid(Color(0xFF1A237E)),
            eyeStyle: QrEyeStyle(
                frame: EyeFrameShape.rounded(),
                pupil: EyePupilShape.rounded(),
                frameFill: QrFill.solid(Color(0xFFE65100))),
          ),
          image: QrImage(
              source: QrImageSource.memory(alkarama),
              mode: const QrImageMode.logo(scale: 0.24)),
        ));
    await cell(
        'images',
        1,
        'Crest blend',
        await ArtisticQr.create(
          data: url,
          errorCorrection: QrErrorCorrection.high,
          style: const QrStyle(
            moduleShape: ModuleShape.circle,
            fill: QrFill.solid(Color(0xFF1A237E)),
            eyeStyle: QrEyeStyle(
                frame: EyeFrameShape.rounded(),
                pupil: EyePupilShape.circle,
                frameFill: QrFill.solid(Color(0xFFE65100)),
                pupilFill: QrFill.solid(Color(0xFF1A237E))),
          ),
          image: QrImage(
              source: QrImageSource.memory(alkarama),
              mode: const QrImageMode.blend()),
        ));
    await cell(
        'images',
        2,
        'Photo blend',
        await ArtisticQr.create(
          data: url,
          errorCorrection: QrErrorCorrection.high,
          style: const QrStyle(
            moduleShape: ModuleShape.circle,
            eyeStyle: QrEyeStyle(
                frame: EyeFrameShape.rounded(),
                pupil: EyePupilShape.circle,
                frameFill: QrFill.solid(Color(0xFF7B1FA2))),
          ),
          image: blend(cr7),
        ));
    await cell(
        'images',
        3,
        'Halftone photo',
        await ArtisticQr.create(
          data: url,
          errorCorrection: QrErrorCorrection.high,
          image: QrImage(
              source: QrImageSource.memory(cr7),
              mode: const QrImageMode.halftone()),
        ));
    await cell(
        'images',
        4,
        'Colored halftone',
        await ArtisticQr.create(
          data: url,
          errorCorrection: QrErrorCorrection.high,
          image: QrImage(
              source: QrImageSource.memory(cr7),
              mode: const QrImageMode.halftone(colored: true)),
        ));
    await cell(
        'images',
        5,
        'Halftone light',
        await ArtisticQr.create(
          data: url,
          errorCorrection: QrErrorCorrection.high,
          image: QrImage(
              source: QrImageSource.memory(cr7),
              mode: const QrImageMode.halftone(brightness: 0.25)),
        ));

    // ---- Sheet 4: effects & frames ----
    await cell('effects', 0, '3D extruded',
        await ArtisticQr.create(data: url, style: QrStylePresets.blocks3d));
    await cell('effects', 1, 'Drop shadow',
        await ArtisticQr.create(data: url, style: QrStylePresets.paper));
    await cell(
        'effects',
        2,
        'Emboss',
        await ArtisticQr.create(
          data: url,
          style: const QrStyle(
            moduleShape: ModuleShape.rounded(),
            moduleScale: 0.92,
            fill: QrFill.solid(Color(0xFF37474F)),
            effect: QrEffect.emboss(),
            eyeStyle: QrEyeStyle(
                frame: EyeFrameShape.rounded(),
                pupil: EyePupilShape.rounded()),
          ),
        ));
    await cell(
        'effects',
        3,
        'Scan-me frame',
        await ArtisticQr.create(
          data: url,
          style: QrStylePresets.ocean,
          frame: const QrFrame(color: Color(0xFF006064), fontFamily: 'Roboto'),
        ));
    await cell(
        'effects',
        4,
        'Top label frame',
        await ArtisticQr.create(
          data: url,
          style: const QrStyle(
            moduleShape: ModuleShape.fluid,
            fill: QrFill.solid(Color(0xFF880E4F)),
            eyeStyle: QrEyeStyle(
                frame: EyeFrameShape.rounded(),
                pupil: EyePupilShape.rounded()),
          ),
          frame: const QrFrame(
            text: 'FOLLOW US',
            labelPosition: QrFrameLabelPosition.top,
            color: Color(0xFF880E4F),
            fontFamily: 'Roboto',
          ),
        ));
    await cell(
        'effects',
        5,
        'Logo in frame',
        await ArtisticQr.create(
          data: url,
          errorCorrection: QrErrorCorrection.high,
          style: const QrStyle(
            moduleShape: ModuleShape.rounded(),
            fill: QrFill.solid(Color(0xFF1A237E)),
            eyeStyle: QrEyeStyle(
                frame: EyeFrameShape.rounded(),
                pupil: EyePupilShape.rounded(),
                frameFill: QrFill.solid(Color(0xFFE65100))),
          ),
          frame: const QrFrame(color: Color(0xFF1A237E), fontFamily: 'Roboto'),
          image: QrImage(
              source: QrImageSource.memory(alkarama),
              mode: const QrImageMode.logo(scale: 0.22)),
        ));

    // ---- Sheet 5: presets ----
    var i = 0;
    for (final entry in QrStylePresets.all.entries) {
      await cell('presets', i++, entry.key,
          await ArtisticQr.create(data: url, style: entry.value));
    }
  }, tags: ['samples'], timeout: const Timeout(Duration(minutes: 5)));
}
