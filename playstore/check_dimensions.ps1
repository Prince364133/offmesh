Add-Type -AssemblyName System.Drawing

$files = Get-ChildItem -Path "playstore" -Recurse -Include *.png

foreach ($f in $files) {
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        [PSCustomObject]@{
            FileName = $f.Name
            Width = $img.Width
            Height = $img.Height
            Aspect = [math]::Round($img.Width / $img.Height, 3)
            SizeKB = [math]::Round($f.Length / 1024, 1)
        } | Format-Table -AutoSize
        $img.Dispose()
    } catch {
        Write-Error "Error reading $($f.Name)"
    }
}
