# Icon Generator Tool 🎨

This tool generates all app icons with the brand's gradient theme.

## Quick Start

```bash
# Run the icon generator
flutter run lib/tools/generate_icons.dart
```

## What Gets Generated

The script creates 5 icon files with the eco/leaf icon and purple gradient:

- ✅ `web/favicon.png` (48x48) - Browser tab icon
- ✅ `web/icons/Icon-192.png` (192x192) - PWA icon
- ✅ `web/icons/Icon-512.png` (512x512) - PWA icon  
- ✅ `web/icons/Icon-maskable-192.png` (192x192) - Android adaptive icon
- ✅ `web/icons/Icon-maskable-512.png` (512x512) - Android adaptive icon

## Design Specifications

**Colors:**
- Primary: `#27042E` (Deep Purple)
- Accent: `#B170CC` (Light Purple)
- Icon: White eco/leaf symbol

**Icon Style:**
- Gradient background (primary → accent, diagonal)
- White eco/leaf icon centered
- Rounded corners (15% radius) for regular icons
- Circular for maskable icons (adaptive safe zone)

## Customization

Edit `generate_icons.dart` to customize:
- Icon colors (`primaryColor`, `accentColor`)
- Icon symbol (`_drawEcoIcon` method)
- Border radius
- Icon padding/sizing

## Notes

- The icon generator uses Flutter's `dart:ui` rendering
- Output is pure PNG with no external dependencies
- All icons match the app's Material 3 gradient theme
- Maskable icons have extra padding for Android adaptive icons

## Next Steps

After generating icons:
1. ✅ Icons are already in correct locations
2. ✅ `manifest.json` updated with brand colors
3. ✅ `index.html` updated with app description
4. 🚀 Build for production: `flutter build web`

## For iOS/Android Native Icons

For native platform icons, use a tool like:
- [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)
- Or design in Figma/Sketch and export manually

The `generate_icons.dart` creates perfect reference icons you can use as a template!
