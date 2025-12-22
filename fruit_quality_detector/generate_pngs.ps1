# Icon Generation for Fruit Quality Detector
Write-Host "🎨 Generating Icons..." -ForegroundColor Magenta

# Check for ImageMagick
$magick = Get-Command magick -ErrorAction SilentlyContinue

if ($magick) {
    Write-Host "✓ ImageMagick found" -ForegroundColor Green
    
    # Create icons directory if not exists
    if (!(Test-Path "web/icons")) {
        New-Item -ItemType Directory -Path "web/icons" -Force | Out-Null
    }
    
    # Generate icons
    Write-Host "Generating favicon (48x48)..." -NoNewline
    magick convert -background none -density 1200 web/icon.svg -resize 48x48 web/favicon.png 2>&1 | Out-Null
    if (Test-Path "web/favicon.png") { Write-Host " ✓" -ForegroundColor Green } else { Write-Host " ✗" -ForegroundColor Red }
    
    Write-Host "Generating Icon-192.png..." -NoNewline
    magick convert -background none -density 1200 web/icon.svg -resize 192x192 web/icons/Icon-192.png 2>&1 | Out-Null
    if (Test-Path "web/icons/Icon-192.png") { Write-Host " ✓" -ForegroundColor Green } else { Write-Host " ✗" -ForegroundColor Red }
    
    Write-Host "Generating Icon-512.png..." -NoNewline
    magick convert -background none -density 1200 web/icon.svg -resize 512x512 web/icons/Icon-512.png 2>&1 | Out-Null
    if (Test-Path "web/icons/Icon-512.png") { Write-Host " ✓" -ForegroundColor Green } else { Write-Host " ✗" -ForegroundColor Red }
    
    Write-Host "Generating Icon-maskable-192.png..." -NoNewline
    magick convert -background none -density 1200 web/icon.svg -resize 192x192 web/icons/Icon-maskable-192.png 2>&1 | Out-Null
    if (Test-Path "web/icons/Icon-maskable-192.png") { Write-Host " ✓" -ForegroundColor Green } else { Write-Host " ✗" -ForegroundColor Red }
    
    Write-Host "Generating Icon-maskable-512.png..." -NoNewline
    magick convert -background none -density 1200 web/icon.svg -resize 512x512 web/icons/Icon-maskable-512.png 2>&1 | Out-Null
    if (Test-Path "web/icons/Icon-maskable-512.png") { Write-Host " ✓" -ForegroundColor Green } else { Write-Host " ✗" -ForegroundColor Red }
    
    Write-Host ""
    Write-Host "✅ All icons generated!" -ForegroundColor Green
} else {
    Write-Host "⚠️  ImageMagick not found!" -ForegroundColor Yellow
    Write-Host "Install from: https://imagemagick.org/script/download.php" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or convert web/icon.svg manually using:" -ForegroundColor Cyan
    Write-Host "  • https://svgtopng.com" -ForegroundColor Gray
    Write-Host "  • https://cloudconvert.com/svg-to-png" -ForegroundColor Gray
}
