Add-Type -AssemblyName System.Drawing

$srcDir = "c:\Users\saavi\Desktop\offline-messaging\playstore\screenshots"
$destDir916 = "c:\Users\saavi\Desktop\offline-messaging\playstore\screenshots\9-16_1080x1920"
$destDirTablet = "c:\Users\saavi\Desktop\offline-messaging\playstore\tablet_screenshots"

if (-not (Test-Path $destDir916)) { New-Item -ItemType Directory -Path $destDir916 -Force }
if (-not (Test-Path $destDirTablet)) { New-Item -ItemType Directory -Path $destDirTablet -Force }

$targetWidth = 1080
$targetHeight = 1920

$images = Get-ChildItem -Path $srcDir -Filter "screenshot-*.png"

foreach ($imgFile in $images) {
    $src = [System.Drawing.Image]::FromFile($imgFile.FullName)
    
    # 1. Generate exact 9:16 (1080 x 1920)
    $bmp916 = New-Object System.Drawing.Bitmap($targetWidth, $targetHeight)
    $g916 = [System.Drawing.Graphics]::FromImage($bmp916)
    $g916.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g916.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g916.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    
    # Fill solid background #111111
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(17, 17, 17))
    $g916.FillRectangle($brush, 0, 0, $targetWidth, $targetHeight)
    
    # Scale to fit height 1920 with high quality
    $scale = 1920.0 / 2400.0
    $scaledW = [int]($src.Width * $scale)
    $scaledH = 1920
    $posX = [int](($targetWidth - $scaledW) / 2)
    
    $g916.DrawImage($src, $posX, 0, $scaledW, $scaledH)
    
    $outPath916 = Join-Path $destDir916 $imgFile.Name
    $bmp916.Save($outPath916, [System.Drawing.Imaging.ImageFormat]::Png)
    $g916.Dispose()
    $bmp916.Dispose()
    
    # 2. Generate Tablet Landscape (1920 x 1080 - 16:9)
    $bmpTab = New-Object System.Drawing.Bitmap(1920, 1080)
    $gTab = [System.Drawing.Graphics]::FromImage($bmpTab)
    $gTab.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gTab.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gTab.FillRectangle($brush, 0, 0, 1920, 1080)
    
    # Scale phone mockup to fit height ~980
    $tabScale = 1000.0 / 2400.0
    $tabW = [int]($src.Width * $tabScale)
    $tabH = [int]($src.Height * $tabScale)
    $tabX = [int]((1920 - $tabW) / 2)
    $tabY = [int]((1080 - $tabH) / 2)
    
    $gTab.DrawImage($src, $tabX, $tabY, $tabW, $tabH)
    $outPathTab = Join-Path $destDirTablet $imgFile.Name
    $bmpTab.Save($outPathTab, [System.Drawing.Imaging.ImageFormat]::Png)
    $gTab.Dispose()
    $bmpTab.Dispose()
    
    $brush.Dispose()
    $src.Dispose()
    Write-Output "Processed: $($imgFile.Name)"
}
