import 'dart:convert';

import 'package:artistic_qr/artistic_qr.dart';
import 'package:flutter/material.dart';

void main() => runApp(const GalleryApp());

const _url = 'https://pub.dev/packages/artistic_qr';

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'artistic_qr gallery',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4A148C), useMaterial3: true),
      home: const GalleryPage(),
    );
  }
}

class Demo {
  const Demo(this.title, this.child, {this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <Demo>[
      const Demo('Classic', ArtisticQrCode(data: _url)),
      Demo(
        'Dots + gradient',
        ArtisticQrCode(
          data: _url,
          style: QrStyle(
            moduleShape: ModuleShape.circle,
            moduleScale: 0.85,
            fill: QrFill.radialGradient(colors: const [Color(0xFF00838F), Color(0xFF1A237E)], radius: 0.9),
            eyeStyle: const QrEyeStyle(
              frame: EyeFrameShape.circle,
              pupil: EyePupilShape.circle,
              frameFill: QrFill.solid(Color(0xFF00838F)),
            ),
          ),
        ),
      ),
      Demo(
        'Fluid + linear gradient',
        ArtisticQrCode(
          data: _url,
          style: QrStyle(
            moduleShape: ModuleShape.fluid,
            fill: QrFill.linearGradient(colors: const [Color(0xFF1565C0), Color(0xFF6A1B9A)]),
            eyeStyle: const QrEyeStyle(frame: EyeFrameShape.rounded(), pupil: EyePupilShape.rounded()),
            // eyeStyleOverrides: {
            //   QrEyePosition.bottomLeft: const QrEyeStyle(
            //     frame: EyeFrameShape.circle,
            //     pupil: EyePupilShape.circle,
            //     frameFill: QrFill.solid(Color(0xFF1565C0)),
            //   ),
            // },
          ),
        ),
      ),
      const Demo(
        'Classy + leaf eyes',
        ArtisticQrCode(
          data: _url,
          style: QrStyle(
            moduleShape: ModuleShape.classy,
            fill: QrFill.solid(Color(0xFF1B5E20)),
            eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.leaf,
              pupil: EyePupilShape.leaf,
              frameFill: QrFill.solid(Color(0xFF2E7D32)),
            ),
          ),
        ),
      ),
      Demo(
        'Sweep gradient + stars',
        ArtisticQrCode(
          data: _url,
          style: QrStyle(
            moduleShape: const ModuleShape.star(),
            moduleScale: 0.95,
            fill: QrFill.sweepGradient(colors: const [Color(0xFFB71C1C), Color(0xFF4A148C), Color(0xFFB71C1C)]),
          ),
        ),
      ),
      const Demo(
        'Per-eye styles',
        ArtisticQrCode(
          data: _url,
          style: QrStyle(
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
          ),
        ),
      ),
      Demo(
        'Centered logo',
        subtitle: 'QrImageMode.logo — knockout + EC-aware sizing',
        ArtisticQrCode(
          data: _url,
          errorCorrection: QrErrorCorrection.high,
          style: const QrStyle(
            moduleShape: ModuleShape.rounded(),
            eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(),
              pupil: EyePupilShape.rounded(),
              frameFill: QrFill.solid(Color(0xFF1565C0)),
            ),
          ),
          image: QrImage(source: QrImageSource.asset('assets/logo.png'), mode: const QrImageMode.logo()),
        ),
      ),
      Demo(
        'Color blend',
        subtitle: "QrImageMode.blend — modules take the artwork's colors",
        ArtisticQrCode(
          data: _url,
          errorCorrection: QrErrorCorrection.high,
          style: const QrStyle(
            moduleShape: ModuleShape.circle,
            eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(),
              pupil: EyePupilShape.circle,
              frameFill: QrFill.solid(Color(0xFF7B1FA2)),
            ),
          ),
          image: QrImage(source: QrImageSource.asset('assets/portrait.png'), mode: const QrImageMode.blend()),
        ),
      ),
      Demo(
        'Halftone photo',
        subtitle: 'QrImageMode.halftone — the "face in the code" effect',
        ArtisticQrCode(
          data: _url,
          errorCorrection: QrErrorCorrection.high,
          image: QrImage(source: QrImageSource.asset('assets/portrait.png'), mode: const QrImageMode.halftone()),
        ),
      ),
      Demo(
        'Colored halftone',
        ArtisticQrCode(
          data: _url,
          errorCorrection: QrErrorCorrection.high,
          image: QrImage(
            source: QrImageSource.asset('assets/portrait.png'),
            mode: const QrImageMode.halftone(colored: true),
          ),
        ),
      ),

      Demo(
        'Colored halftone',
        ArtisticQrCode(
          data: _url,
          errorCorrection: QrErrorCorrection.high,
          style: QrStyle(
            eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(),
              pupil: EyePupilShape.rounded(),
              frameFill: QrFill.solid(Color(0xFF1565C0)),
              pupilFill: QrFill.solid(Color(0xFF6A1B9A)),
            ),
            eyeStyleOverrides: {
              QrEyePosition.bottomLeft: QrEyeStyle(
                frame: EyeFrameShape.leaf,
                pupil: EyePupilShape.leaf,

                frameFill: QrFill.solid(Color(0xFF1565C0)),
                pupilFill: QrFill.solid(Color(0xFF6A1B9A)),
              ),
            },
          ),
          image: QrImage(
            source: QrImageSource.network(
              'https://www.celebrity-cutouts.co.uk/wp-content/uploads/2024/01/cristiano-ronaldo-young.jpg',
            ),
            mode: const QrImageMode.halftone(colored: true),
          ),
        ),
      ),

      Demo(
        'Colored halftone',
        ArtisticQrCode(
          data: _url,

          errorCorrection: QrErrorCorrection.high,
          style: QrStyle(
            eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(),
              pupil: EyePupilShape.rounded(),
              frameFill: QrFill.solid(Color(0xFF1565C0)),
              pupilFill: QrFill.solid(Color(0xFF6A1B9A)),
            ),
            eyeStyleOverrides: {
              QrEyePosition.bottomLeft: QrEyeStyle(
                frame: EyeFrameShape.leaf,
                pupil: EyePupilShape.leaf,

                frameFill: QrFill.solid(Color(0xFF1565C0)),
                pupilFill: QrFill.solid(Color(0xFF6A1B9A)),
              ),
              QrEyePosition.topRight: QrEyeStyle(
                frame: EyeFrameShape.leaf,
                pupil: EyePupilShape.leaf,

                frameFill: QrFill.solid(Color(0xFF1565C0)),
                pupilFill: QrFill.solid(Color(0xFF6A1B9A)),
              ),
            },
          ),
          image: QrImage(source: QrImageSource.asset('assets/cr7.png'), mode: const QrImageMode.blend()),
        ),
      ),

      // ---- v0.2 features ----
      Demo(
        'WiFi payload',
        subtitle: 'QrData.wifi — scanning joins the network',
        ArtisticQrCode(
          data: QrData.wifi(ssid: 'CoffeeShop', password: 'espresso42'),
          style: QrStylePresets.ocean,
        ),
      ),
      const Demo(
        '"Scan me" frame',
        subtitle: 'QrFrame — border + label banner',
        ArtisticQrCode(
          data: _url,
          frame: QrFrame(color: Color(0xFF006064)),
          style: QrStyle(
            moduleShape: ModuleShape.fluid,
            fill: QrFill.solid(Color(0xFF006064)),
            eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(),
              pupil: EyePupilShape.rounded(),
            ),
          ),
        ),
      ),
      Demo(
        '3D blocks',
        subtitle: 'QrEffect.extruded — isometric look',
        ArtisticQrCode(data: _url, style: QrStylePresets.blocks3d),
      ),
      Demo(
        'Floating sticker',
        subtitle: 'QrEffect.shadow',
        ArtisticQrCode(data: _url, style: QrStylePresets.paper),
      ),
      const Demo(
        'Embossed buttons',
        subtitle: 'QrEffect.emboss — raster only',
        ArtisticQrCode(
          data: _url,
          style: QrStyle(
            moduleShape: ModuleShape.rounded(),
            moduleScale: 0.92,
            fill: QrFill.solid(Color(0xFF37474F)),
            effect: QrEffect.emboss(),
            eyeStyle: QrEyeStyle(
              frame: EyeFrameShape.rounded(),
              pupil: EyePupilShape.rounded(),
            ),
          ),
        ),
      ),
      Demo(
        'Preset: sunset',
        subtitle: 'QrStylePresets — 8 ready-made styles',
        ArtisticQrCode(data: _url, style: QrStylePresets.sunset),
      ),
      Demo(
        'Animated gradient sweep',
        subtitle: 'AnimatedArtisticQrCode',
        AnimatedArtisticQrCode(
          data: _url,
          effect: QrAnimationEffect.gradientSweep,
          style: QrStylePresets.candy,
        ),
      ),
      const Demo(
        'Animated reveal',
        AnimatedArtisticQrCode(
          data: _url,
          effect: QrAnimationEffect.reveal,
          duration: Duration(seconds: 2),
          repeat: true,
        ),
      ),
      Demo(
        'Animated pulse',
        AnimatedArtisticQrCode(
          data: _url,
          effect: QrAnimationEffect.pulse,
          style: QrStylePresets.neon,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('artistic_qr'),
        actions: [
          IconButton(
            tooltip: 'Export sample PNG + SVG',
            icon: const Icon(Icons.download),
            onPressed: () => _showExports(context),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
        itemCount: demos.length,
        itemBuilder: (context, index) {
          final demo = demos[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: Colors.white,
                      child: Center(child: demo.child),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(demo.title, style: Theme.of(context).textTheme.titleSmall),
                  if (demo.subtitle != null)
                    Text(demo.subtitle!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showExports(BuildContext context) async {
    final qr = await ArtisticQr.create(
      data: _url,
      errorCorrection: QrErrorCorrection.quartile,
      style: QrStyle(
        moduleShape: ModuleShape.fluid,
        fill: QrFill.linearGradient(colors: const [Color(0xFF1565C0), Color(0xFF6A1B9A)]),
        eyeStyle: const QrEyeStyle(frame: EyeFrameShape.rounded(), pupil: EyePupilShape.rounded()),
      ),
    );
    final png = await qr.toPngBytes(pixelSize: 2048);
    final svg = await qr.toSvg(size: 512);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Headless export'),
        content: SingleChildScrollView(
          child: Text(
            'toPngBytes → ${png.length ~/ 1024} KB PNG at 2048×2048\n'
            'toSvg → ${svg.length ~/ 1024} KB vector SVG\n\n'
            'SVG preview (first 300 chars):\n'
            '${svg.substring(0, 300)}…\n\n'
            'PNG base64 head: ${base64Encode(png).substring(0, 48)}…',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}
