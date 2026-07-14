import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../encoder/qr_encoder.dart';
import '../encoder/tables.dart';
import '../image/qr_image.dart';
import '../image/qr_image_renderer.dart';
import '../style/qr_fill.dart';
import '../style/qr_frame.dart';
import '../style/qr_style.dart';
import 'qr_painter.dart';

/// Display animations for [AnimatedArtisticQrCode].
///
/// Animations are purely visual: the resting state of every effect is the
/// normal, fully scannable code (and the code is scannable during most of
/// the animation too — but always let it settle for reliable scanning).
enum QrAnimationEffect {
  /// Rotates the fill gradient around the symbol. No-op for solid fills.
  gradientSweep,

  /// Modules pop in one by one in a stable pseudo-random order.
  /// Plays once (unless [AnimatedArtisticQrCode.repeat] is true).
  reveal,

  /// Dots gently breathe between 85% and 100% of their size.
  pulse,
}

/// An [ArtisticQrCode] with a built-in animation.
///
/// ```dart
/// AnimatedArtisticQrCode(
///   data: 'https://example.com',
///   size: 280,
///   effect: QrAnimationEffect.gradientSweep,
///   style: QrStylePresets.ocean,
/// )
/// ```
class AnimatedArtisticQrCode extends StatefulWidget {
  const AnimatedArtisticQrCode({
    super.key,
    required this.data,
    this.effect = QrAnimationEffect.gradientSweep,
    this.duration = const Duration(seconds: 3),
    this.curve = Curves.linear,
    this.repeat,
    this.size,
    this.errorCorrection = QrErrorCorrection.quartile,
    this.style = const QrStyle(),
    this.frame,
    this.image,
    this.errorBuilder,
    this.semanticsLabel,
  });

  final String data;
  final QrAnimationEffect effect;
  final Duration duration;
  final Curve curve;

  /// Whether the animation loops. Defaults to true for [gradientSweep] and
  /// [pulse], false for [reveal].
  final bool? repeat;

  final double? size;
  final QrErrorCorrection errorCorrection;
  final QrStyle style;
  final QrFrame? frame;
  final QrImage? image;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final String? semanticsLabel;

  @override
  State<AnimatedArtisticQrCode> createState() => _AnimatedArtisticQrCodeState();
}

class _AnimatedArtisticQrCodeState extends State<AnimatedArtisticQrCode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  QrCode? _code;
  Object? _error;
  QrImageRenderData? _imageData;
  int _imageRequest = 0;

  bool get _repeats =>
      widget.repeat ?? widget.effect != QrAnimationEffect.reveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _startAnimation();
    _encode();
    _resolveImage();
  }

  void _startAnimation() {
    if (_repeats) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(AnimatedArtisticQrCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.effect != widget.effect ||
        oldWidget.repeat != widget.repeat) {
      _controller.stop();
      _startAnimation();
    }
    final reencode = oldWidget.data != widget.data ||
        oldWidget.errorCorrection != widget.errorCorrection;
    if (reencode) _encode();
    if (reencode || oldWidget.image != widget.image) _resolveImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _encode() {
    try {
      _code = QrCode.encode(widget.data,
          errorCorrection: widget.errorCorrection);
      _error = null;
    } catch (e) {
      _code = null;
      _error = e;
    }
  }

  Future<void> _resolveImage() async {
    final request = ++_imageRequest;
    final image = widget.image;
    final code = _code;
    _imageData = null;
    if (image == null || code == null) return;
    try {
      final pixels = await image.source.resolve(
          configuration: createLocalImageConfiguration(context));
      final data = buildImageRenderData(
        code: code,
        style: widget.style,
        image: ResolvedQrImage(pixels: pixels, mode: image.mode),
      );
      if (mounted && request == _imageRequest) {
        setState(() => _imageData = data);
      }
    } catch (_) {
      // Image failed to load: keep showing the plain animated code.
    }
  }

  /// Stable per-module pseudo-random value in [0, 1).
  static double _hash01(int index) {
    final v = math.sin(index * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  QrPainter _painterAt(double t) {
    final code = _code!;
    final imageData = _imageData;
    var style = widget.style;
    bool Function(int, int)? skip = imageData?.skipModule;

    switch (widget.effect) {
      case QrAnimationEffect.gradientSweep:
        final fill = style.fill;
        if (fill is QrGradientFill) {
          style = style.copyWith(
            fill: QrFill.gradient(
                _withRotation(fill.gradient, t * 2 * math.pi)),
          );
        }
      case QrAnimationEffect.reveal:
        final baseSkip = skip;
        final n = code.size;
        skip = (row, col) =>
            (baseSkip?.call(row, col) ?? false) ||
            _hash01(row * n + col) > t;
      case QrAnimationEffect.pulse:
        style = style.copyWith(
          moduleScale:
              style.moduleScale * (0.85 + 0.15 * (0.5 + 0.5 * math.sin(t * 2 * math.pi))),
        );
    }

    return QrPainter(
      code: code,
      style: style,
      frame: widget.frame,
      moduleColorResolver: imageData?.moduleColorResolver,
      skipModule: skip,
      foregroundPainter: imageData?.foregroundPainter,
      halftone: imageData?.halftone,
    );
  }

  static Gradient _withRotation(Gradient gradient, double angle) {
    final transform = GradientRotation(angle);
    return switch (gradient) {
      LinearGradient() => LinearGradient(
          colors: gradient.colors,
          stops: gradient.stops,
          begin: gradient.begin,
          end: gradient.end,
          tileMode: gradient.tileMode,
          transform: transform,
        ),
      RadialGradient() => RadialGradient(
          colors: gradient.colors,
          stops: gradient.stops,
          center: gradient.center,
          radius: gradient.radius,
          tileMode: gradient.tileMode,
          transform: transform,
        ),
      SweepGradient() => SweepGradient(
          colors: gradient.colors,
          stops: gradient.stops,
          center: gradient.center,
          startAngle: gradient.startAngle,
          endAngle: gradient.endAngle,
          tileMode: gradient.tileMode,
          transform: transform,
        ),
      _ => gradient,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final builder = widget.errorBuilder;
      if (builder != null) return builder(context, _error!);
      return SizedBox.square(dimension: widget.size);
    }
    return Semantics(
      label: widget.semanticsLabel ?? 'QR code',
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      image: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: widget.size != null
              ? Size.square(widget.size!)
              : Size.infinite,
          painter: _painterAt(widget.curve.transform(_controller.value)),
        ),
      ),
    );
  }
}
