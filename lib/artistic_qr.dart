/// High-quality, fully customizable artistic QR codes for Flutter.
///
/// Includes its own ISO/IEC 18004 encoder (zero runtime dependencies),
/// custom module & eye shapes, gradient fills, and logo / color-blend /
/// halftone photo image modes.
library;

export 'src/artistic_qr_api.dart' show ArtisticQr;
export 'src/encoder/matrix.dart' show QrMatrix, QrModuleRole, QrEyePosition;
export 'src/encoder/qr_encoder.dart' show QrCode, QrDataTooLongException;
export 'src/encoder/tables.dart' show QrErrorCorrection;
export 'src/image/qr_image.dart'
    show
        QrImage,
        QrImageMode,
        QrLogoMode,
        QrBlendMode,
        QrHalftoneMode,
        ResolvedQrImage;
export 'src/image/qr_image_renderer.dart'
    show QrImageRenderData, HalftoneGrid, buildImageRenderData;
export 'src/image/qr_image_source.dart' show QrImageSource, QrImagePixels;
export 'src/render/qr_geometry.dart' show QrLayout;
export 'src/render/qr_painter.dart' show QrPainter;
export 'src/render/qr_widget.dart' show ArtisticQrCode;
export 'src/render/svg_export.dart' show buildQrSvg;
export 'src/validate/scan_guard.dart' show QrScanWarning, validateQrDesign;
export 'src/style/eye_shape.dart' show EyeFrameShape, EyePupilShape;
export 'src/style/module_shape.dart'
    show ModuleShape, ModuleNeighbors, ModulePathBuilder;
export 'src/style/qr_fill.dart' show QrFill, QrSolidFill, QrGradientFill;
export 'src/style/qr_style.dart' show QrStyle, QrEyeStyle;
