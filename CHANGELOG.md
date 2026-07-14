# Changelog

## 0.2.0

* **Payload builders** — `QrData.wifi / vCard / email / sms / phone /
  whatsapp / geo / event` with correct escaping, so WiFi-login and
  add-contact codes are one-liners.
* **Decorative frames** — `QrFrame`: rounded border + "SCAN ME" label
  banner (top or bottom), rendered by the widget, PNG, and SVG exports.
* **3D depth effects** — `QrEffect.extruded` (isometric blocks),
  `QrEffect.shadow` (floating sticker), and `QrEffect.emboss` (bevel
  lighting, raster-only). Extrusion on the finder eyes is automatically
  capped to keep detectors happy, and the scan guard flags risky
  depth/scale combinations.
* **Style presets** — `QrStylePresets` with 8 curated, decode-verified
  looks (`ocean`, `sunset`, `forest`, `candy`, `paper`, `blocks3d`,
  `neon`, `classic`).
* **JSON styles** — `QrStyle.toJson()/fromJson()` (plus fills, shapes,
  effects, frames) so designs can be saved, shared, and used as templates.
* **Animated QR widget** — `AnimatedArtisticQrCode` with `gradientSweep`,
  `reveal`, and `pulse` effects; resting states are always fully scannable.

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
