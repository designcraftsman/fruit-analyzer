import 'dart:io';
import 'dart:math' as math;

/// Simple SVG-based icon generator
/// Run: dart lib/tools/generate_svg_icons.dart

void main() {
  print('🎨 Generating Fruit Quality Detector Icons (SVG)...\n');

  // Create SVG icons
  generateSvgIcon('web/icon.svg', 512);

  print('\n✅ SVG icon generated!');
  print('📍 Location: web/icon.svg');
  print('\n📝 Next steps:');
  print('   1. Open icon.svg in browser to preview');
  print('   2. Use online tools to convert SVG → PNG:');
  print('      - https://svgtopng.com');
  print('      - https://cloudconvert.com/svg-to-png');
  print('   3. Generate these sizes:');
  print('      • 48x48 → web/favicon.png');
  print('      • 192x192 → web/icons/Icon-192.png');
  print('      • 512x512 → web/icons/Icon-512.png');
  print('      • 192x192 → web/icons/Icon-maskable-192.png (circular crop)');
  print('      • 512x512 → web/icons/Icon-maskable-512.png (circular crop)');
}

void generateSvgIcon(String path, int size) {
  final svg =
      '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="$size" height="$size" viewBox="0 0 $size $size" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#27042E;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#B170CC;stop-opacity:1" />
    </linearGradient>
  </defs>
  
  <!-- Background with rounded corners -->
  <rect width="$size" height="$size" rx="${size * 0.15}" ry="${size * 0.15}" fill="url(#bgGradient)"/>
  
  <!-- Eco/Leaf Icon Group -->
  <g transform="translate(${size / 2}, ${size / 2})">
    <!-- Main leaf shape -->
    <g transform="scale(${size / 30})">
      <!-- Large leaf -->
      <path d="M -8 4 Q -8 -6 -2 -10 Q 4 -12 10 -10 Q 14 -8 14 2 Q 14 8 10 12 Q 4 14 -2 12 Q -8 10 -8 4 Z" 
            fill="white" opacity="0.95"/>
      
      <!-- Center vein -->
      <path d="M 4 -10 L 4 12" stroke="white" stroke-width="1.5" stroke-linecap="round" opacity="0.7"/>
      
      <!-- Side veins -->
      <path d="M 4 -5 Q 7 -3 8 0" stroke="white" stroke-width="0.8" stroke-linecap="round" opacity="0.5" fill="none"/>
      <path d="M 4 0 Q 7 2 8 5" stroke="white" stroke-width="0.8" stroke-linecap="round" opacity="0.5" fill="none"/>
      <path d="M 4 -5 Q 1 -3 0 0" stroke="white" stroke-width="0.8" stroke-linecap="round" opacity="0.5" fill="none"/>
      <path d="M 4 0 Q 1 2 0 5" stroke="white" stroke-width="0.8" stroke-linecap="round" opacity="0.5" fill="none"/>
      
      <!-- Small berry/fruit circle -->
      <circle cx="-6" cy="-4" r="2.5" fill="white" opacity="0.9"/>
    </g>
  </g>
</svg>''';

  final file = File(path);
  file.writeAsStringSync(svg);
  print('✓ Generated: $path');
}
