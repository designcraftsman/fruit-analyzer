@echo off
echo 🎨 Generating Fruit Quality Detector Icons...
echo.

where magick >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✓ ImageMagick found
    echo.
    
    if not exist "web\icons" mkdir "web\icons"
    
    echo Generating favicon...
    magick convert -background none -density 1200 web/icon.svg -resize 48x48 web/favicon.png
    
    echo Generating Icon-192.png...
    magick convert -background none -density 1200 web/icon.svg -resize 192x192 web/icons/Icon-192.png
    
    echo Generating Icon-512.png...
    magick convert -background none -density 1200 web/icon.svg -resize 512x512 web/icons/Icon-512.png
    
    echo Generating Icon-maskable-192.png...
    magick convert -background none -density 1200 web/icon.svg -resize 192x192 web/icons/Icon-maskable-192.png
    
    echo Generating Icon-maskable-512.png...
    magick convert -background none -density 1200 web/icon.svg -resize 512x512 web/icons/Icon-maskable-512.png
    
    echo.
    echo ✅ All icons generated successfully!
) else (
    echo ⚠️  ImageMagick not found!
    echo.
    echo Please install ImageMagick from:
    echo https://imagemagick.org/script/download.php
    echo.
    echo Or convert web/icon.svg manually to PNG
)

echo.
pause
