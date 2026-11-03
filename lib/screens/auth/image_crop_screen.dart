// lib/screens/auth/image_crop_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const ImageCropScreen({super.key, required this.imageBytes});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  static const _blue = Color(0xFF1877F2);

  ui.Image? _image;
  bool _loading = true;

  // Transform state
  double _scale     = 1.0;
  Offset _offset    = Offset.zero;

  // For gesture tracking
  double _startScale   = 1.0;
  Offset _startOffset  = Offset.zero;
  Offset _startFocal   = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _image   = frame.image;
        _loading = false;
      });
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startScale  = _scale;
    _startOffset = _offset;
    _startFocal  = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale  = (_startScale * d.scale).clamp(0.5, 8.0);
      // Translate: move with focal point delta + adjust for scale change
      final focalDelta = d.localFocalPoint - _startFocal;
      _offset = _startOffset + focalDelta;
    });
  }

  Future<Uint8List?> _cropImage(Size canvasSize, double cropSize) async {
    if (_image == null) return null;

    const outputSize = 512.0;

    // How the image is drawn on canvas
    final imgW    = _image!.width.toDouble();
    final imgH    = _image!.height.toDouble();
    final aspect  = imgW / imgH;

    double drawW, drawH;
    if (aspect > 1) {
      drawW = canvasSize.width;
      drawH = drawW / aspect;
    } else {
      drawH = canvasSize.height;
      drawW = drawH * aspect;
    }

    // Apply scale
    drawW *= _scale;
    drawH *= _scale;

    // Image top-left on canvas
    final imgLeft = (canvasSize.width  - drawW) / 2 + _offset.dx;
    final imgTop  = (canvasSize.height - drawH) / 2 + _offset.dy;

    // Crop circle center on canvas
    final cropCX = canvasSize.width  / 2;
    final cropCY = canvasSize.height / 2;

    // Crop rect on canvas
    final cropLeft   = cropCX - cropSize / 2;
    final cropTop    = cropCY - cropSize / 2;

    // Map crop rect to image source coordinates
    final scaleToImg = imgW / drawW;
    final srcLeft    = (cropLeft - imgLeft) * scaleToImg;
    final srcTop     = (cropTop  - imgTop)  * scaleToImg;
    final srcSize    = cropSize * scaleToImg;

    final srcRect = Rect.fromLTWH(srcLeft, srcTop, srcSize, srcSize);
    final dstRect = Rect.fromLTWH(0, 0, outputSize, outputSize);

    // Draw cropped image into circular output
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    // Clip to circle
    final circlePath = Path()
      ..addOval(Rect.fromLTWH(0, 0, outputSize, outputSize));
    canvas.clipPath(circlePath);

    canvas.drawImageRect(_image!, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);

    final picture = recorder.endRecording();
    final img     = await picture.toImage(outputSize.toInt(), outputSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Move and Scale'),
        actions: [
          TextButton(
            onPressed: _loading ? null : () async {
              final size     = MediaQuery.of(context).size;
              final cropSize = size.width * 0.80;
              final cropped  = await _cropImage(
                Size(size.width, size.height - kToolbarHeight - MediaQuery.of(context).padding.top),
                cropSize,
              );
              if (mounted) Navigator.of(context).pop(cropped);
            },
            child: const Text('Use Photo',
                style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : LayoutBuilder(builder: (context, constraints) {
        final cropSize = constraints.maxWidth * 0.80;
        final center   = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

        return GestureDetector(
          onScaleStart:  _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: SizedBox(
            width:  constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // ── Image layer ───────────────────────────────────
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _ImagePainter(
                    image:      _image!,
                    scale:      _scale,
                    offset:     _offset,
                    canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                ),

                // ── Dark overlay + circle cutout ──────────────────
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _OverlayPainter(cropSize: cropSize, center: center),
                  ),
                ),

                // ── Hint ──────────────────────────────────────────
                Positioned(
                  bottom: 32,
                  left: 0, right: 0,
                  child: Center(
                    child: Text(
                      'Pinch to zoom  •  Drag to reposition',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _ImagePainter extends CustomPainter {
  final ui.Image image;
  final double   scale;
  final Offset   offset;
  final Size     canvasSize;

  _ImagePainter({
    required this.image,
    required this.scale,
    required this.offset,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgW   = image.width.toDouble();
    final imgH   = image.height.toDouble();
    final aspect = imgW / imgH;

    double drawW, drawH;
    if (aspect > 1) {
      drawW = canvasSize.width;
      drawH = drawW / aspect;
    } else {
      drawH = canvasSize.height;
      drawW = drawH * aspect;
    }

    drawW *= scale;
    drawH *= scale;

    final dx = (canvasSize.width  - drawW) / 2 + offset.dx;
    final dy = (canvasSize.height - drawH) / 2 + offset.dy;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(dx, dy, drawW, drawH),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) =>
      old.scale != scale || old.offset != offset;
}

class _OverlayPainter extends CustomPainter {
  final double cropSize;
  final Offset center;

  _OverlayPainter({required this.cropSize, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay with circular cutout
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path    = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(center: center, width: cropSize, height: cropSize))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // White circle border
    canvas.drawCircle(
      center,
      cropSize / 2,
      Paint()
        ..color       = Colors.white
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => false;
}
