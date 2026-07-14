# artistic_qr

High-quality, fully customizable **artistic QR codes** for Flutter — custom
module & eye shapes, gradients, and three ways to weave an image into the
code itself: centered **logo**, color **blend**, and photo **halftone**
(the "face in the QR code" effect).

Ships with its **own ISO/IEC 18004 encoder** — zero runtime dependencies —
and every style is **decode-verified against zxing in the test suite**, so
pretty never means unscannable.

| Halftone photo | Color blend | Fluid gradient |
|---|---|---|
| ![halftone](doc/1_halftone_portrait.png) | ![blend](doc/3_blend_circles.png) | ![fluid](doc/4_gradient_fluid.png) |

> Images above are actual package output (see `example/` for the full
> gallery; images visible on the repository, not on pub.dev).

## Features

* 🎨 **Module shapes** — square, circle, rounded, diamond, star, classy,
  neighbor-connected *fluid*, vertical/horizontal bars, or bring your own
  `ModuleShape.custom(...)`.
* 👁 **Eye styling** — square / rounded / circle / leaf frames & pupils,
  separate fills, and per-eye overrides.
* 🌈 **Fills** — solid colors or linear / radial / sweep gradients that flow
  across the whole symbol; adjustable dot size (`moduleScale`) and quiet zone.
* 🖼 **Image embedding** from **asset, file, network, or memory**:
  * `QrImageMode.logo` — centered logo, optional knockout, EC-aware size guard,
  * `QrImageMode.blend` — modules take the colors of the artwork beneath them,
  * `QrImageMode.halftone` — the photo is woven into the dots while every
    module's data-carrying center subpixel stays intact (dithering, colored
    or monochrome).
* 📤 **Exports** — Flutter widget, high-resolution PNG bytes (headless, no
  widget tree needed), and standalone **SVG** (true vector paths, gradients
  as `<defs>`, logo embedded as base64).
* 🛡 **Scannability guard** — contrast / quiet-zone / logo-size heuristics
  with debug warnings, and a test suite that renders every style and decodes
  it with a real QR reader.
* 🚀 **Zero runtime dependencies** — the QR encoder (Reed–Solomon, masking,
  all versions 1–40, UTF-8 via ECI) is implemented in pure Dart and verified
  bit-for-bit against zxing's encoder.

## Quick start

```dart
import 'package:artistic_qr/artistic_qr.dart';

ArtisticQrCode(
  data: 'https://example.com',
  size: 280,
  style: QrStyle(
    moduleShape: ModuleShape.circle,
    fill: QrFill.linearGradient(
      colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
    ),
    eyeStyle: QrEyeStyle(
      frame: EyeFrameShape.rounded(),
      pupil: EyePupilShape.circle,
    ),
  ),
)
```

### Embed a logo

```dart
ArtisticQrCode(
  data: 'https://example.com',
  errorCorrection: QrErrorCorrection.high,
  image: QrImage(
    source: QrImageSource.asset('assets/logo.png'), // .file / .network / .memory
    mode: QrImageMode.logo(scale: 0.22, knockout: true),
  ),
)
```

### Halftone photo QR ("face in the code")

```dart
ArtisticQrCode(
  data: 'https://example.com',
  errorCorrection: QrErrorCorrection.high, // required headroom for art modes
  image: QrImage(
    source: QrImageSource.network('https://example.com/portrait.jpg'),
    mode: QrImageMode.halftone(dithering: true), // colored: true for color
  ),
)
```

### Color-blend artwork

```dart
ArtisticQrCode(
  data: 'https://example.com',
  errorCorrection: QrErrorCorrection.high,
  style: QrStyle(moduleShape: ModuleShape.circle),
  image: QrImage(
    source: QrImageSource.asset('assets/artwork.png'),
    mode: QrImageMode.blend(), // modules take the artwork's colors
  ),
)
```

### Headless export (PNG / SVG)

```dart
final qr = await ArtisticQr.create(
  data: 'https://example.com',
  style: QrStyle(moduleShape: ModuleShape.fluid),
);

final Uint8List png = await qr.toPngBytes(pixelSize: 4096); // print-ready
final String svg = await qr.toSvg(size: 512);               // vector

// Design linting (also printed automatically in debug builds):
final warnings = qr.validate(); // e.g. low-contrast, logo-too-large…
```

## Scannability

Artistic styling always trades error-correction headroom for looks. The
package keeps you safe by default:

* Function patterns (finder eyes, timing, alignment) are never consumed by
  image modes; in halftone mode every module's **center subpixel** always
  carries the real data bit.
* `qr.validate()` flags low contrast, missing quiet zones, tiny dots, and
  logos too large for the chosen error-correction level — and prints these
  as warnings in debug builds.
* Use `QrErrorCorrection.high` with blend/halftone modes, and always test
  final printed designs with a couple of real phones.

## API overview

| Type | What it does |
|---|---|
| `ArtisticQrCode` | The widget: `data`, `style`, `image`, `errorBuilder` |
| `ArtisticQr` | Headless: `create` → `toPngBytes` / `toSvg` / `validate` |
| `QrStyle` | `moduleShape`, `moduleScale`, `fill`, `eyeStyle(+Overrides)`, `background`, `quietZone` |
| `ModuleShape` | `square·circle·rounded·diamond·star·classy·fluid·bars·custom` |
| `EyeFrameShape` / `EyePupilShape` | `square·rounded·circle·leaf` |
| `QrFill` | `solid`, `linearGradient`, `radialGradient`, `sweepGradient` |
| `QrImageSource` | `asset`, `file`, `network`, `memory` |
| `QrImageMode` | `logo`, `blend`, `halftone` |
| `QrCode` | Low-level encoder access (role-tagged module matrix) |

## Example

The `example/` app is a gallery of ready-made styles — including
recreations of popular commercial QR-designer looks — plus all three image
modes and the headless exporters.

```sh
cd example && flutter run
```

## License

MIT
