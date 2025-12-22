import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Icon Generator for Fruit Quality Detector
///
/// This script generates all required icon files with the app's branding:
/// - Eco/leaf icon with gradient purple background
/// - Sizes: 192x192, 512x512, favicon
///
/// Run: flutter run -d windows (or any device) to generate icons

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🎨 Generating Fruit Quality Detector Icons...\n');

  final iconGenerator = IconGenerator();

  // Generate all required sizes
  await iconGenerator.generateIcon(192, 'web/icons/Icon-192.png');
  await iconGenerator.generateIcon(512, 'web/icons/Icon-512.png');
  await iconGenerator.generateIcon(
    192,
    'web/icons/Icon-maskable-192.png',
    maskable: true,
  );
  await iconGenerator.generateIcon(
    512,
    'web/icons/Icon-maskable-512.png',
    maskable: true,
  );
  await iconGenerator.generateIcon(48, 'web/favicon.png');

  print('\n✅ All icons generated successfully!');
  print('📍 Location: web/icons/ and web/favicon.png');
  print('\n🎉 Your app now has modern gradient icons!');

  // Exit after generation
  exit(0);
}

class IconGenerator {
  // App colors
  static const primaryColor = Color(0xFF27042E);
  static const accentColor = Color(0xFFB170CC);

  Future<void> generateIcon(
    int size,
    String outputPath, {
    bool maskable = false,
  }) async {
    print('Generating ${size}x$size icon${maskable ? " (maskable)" : ""}...');

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Calculate sizes
    final iconSize = maskable
        ? size * 0.6
        : size * 0.7; // Smaller for maskable to fit safe zone
    final iconPadding = (size - iconSize) / 2;

    // Draw gradient background
    final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final gradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(size.toDouble(), size.toDouble()),
      [primaryColor, accentColor],
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    // Draw rounded rectangle (or circle for maskable)
    if (maskable) {
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
    } else {
      final radius = size * 0.15; // 15% border radius
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, paint);
    }

    // Draw eco icon (leaf shape)
    _drawEcoIcon(canvas, iconPadding, iconPadding, iconSize);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Save to file
    final file = File(outputPath);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);

    print('✓ Saved: $outputPath');
  }

  void _drawEcoIcon(Canvas canvas, double x, double y, double size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = size * 0.03;

    // Scale factor for the icon
    final scale = size / 24; // Material icon size is 24

    canvas.save();
    canvas.translate(x + size / 2, y + size / 2);
    canvas.scale(scale);

    // Draw eco/leaf icon path (simplified Material eco icon)
    final path = Path();

    // Main leaf shape
    path.moveTo(-8, 4);
    path.cubicTo(-8, -6, -2, -10, 4, -10);
    path.cubicTo(10, -10, 14, -6, 14, 2);
    path.cubicTo(14, 8, 10, 12, 4, 12);
    path.cubicTo(-4, 12, -8, 8, -8, 4);

    // Center vein
    path.moveTo(4, -10);
    path.lineTo(4, 12);

    canvas.drawPath(path, paint);

    // Draw small circle (berry/fruit element)
    canvas.drawCircle(Offset(-6, -4), 2.5, paint);

    canvas.restore();
  }
}
