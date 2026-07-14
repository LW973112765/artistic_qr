# Changelog

## 0.1.0

Initial release.

* From-scratch ISO/IEC 18004 QR encoder (versions 1–40, EC levels L/M/Q/H,
  numeric/alphanumeric/byte modes, UTF-8 via ECI) — zero runtime dependencies.
* Role-tagged module matrix (finder/alignment/timing/format/data) enabling
  safe artistic styling.
* Module shapes: square, circle, rounded, diamond, star, classy, fluid
  (neighbor-connected), vertical/horizontal bars, and fully custom builders.
* Eye styling: square/rounded/circle/leaf frames and pupils, independent
  fills, per-eye overrides.
* Fills: solid colors and linear/radial/sweep gradients flowing across the
  whole symbol; module scale (dot gaps); configurable quiet zone.
* Image embedding from asset/file/network/memory:
  * `QrImageMode.logo` — centered logo with knockout and EC-aware sizing,
  * `QrImageMode.blend` — modules take the artwork's colors,
  * `QrImageMode.halftone` — photo woven into the code (3×3 subpixel
    halftone with Floyd–Steinberg dithering, monochrome or colored).
* `ArtisticQrCode` widget, headless `ArtisticQr` API, high-resolution PNG
  export, and standalone SVG export (exact vector paths, gradients as defs,
  logos embedded as base64).
* Scannability guard: contrast, quiet-zone, module-size, and logo-size
  checks with debug warnings; every style and image mode is decode-verified
  against zxing in CI.
