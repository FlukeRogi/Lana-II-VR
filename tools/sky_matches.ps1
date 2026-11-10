# Makes backdrop_previews\sky_matches.png: each backdrop capture beside the sky skyboxes.txt gives it, for reviewing
# the matches by eye. Uses the full-scene captures in backdrop_previews\full where they exist.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$R = Split-Path $PSScriptRoot -Parent
$previews = Join-Path $R 'backdrop_previews'
$pack = Get-ChildItem (Join-Path $R 'Fantasy Skybox') -Recurse -Filter *.png
$pairs = Get-Content (Join-Path $R 'skybox\skyboxes.txt') | Where-Object { $_ -match '^(Main Menu|Chapter .*) = (\S+)\.lvsky\s*$' } |
    ForEach-Object { $p = $_ -split ' = '; [pscustomobject]@{ Backdrop = $p[0].Trim(); Sky = [IO.Path]::GetFileNameWithoutExtension($p[1].Trim()) } }
$w = 384; $h = 216; $label = 22; $cols = 2
$rows = [math]::Ceiling($pairs.Count / $cols)
$sheet = New-Object Drawing.Bitmap ($cols * 2 * $w + ($cols - 1) * 12), ($rows * ($h + $label))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::FromArgb(24, 24, 24)); $g.InterpolationMode = 'HighQualityBilinear'
$font = New-Object Drawing.Font 'Segoe UI', 11, ([Drawing.FontStyle]::Bold)
for ($i = 0; $i -lt $pairs.Count; $i++) {
    $x = ($i % $cols) * (2 * $w + 12); $y = [math]::Floor($i / $cols) * ($h + $label)
    $name = $pairs[$i].Backdrop -replace '[^A-Za-z0-9]+', '_'
    $shot = @("$previews\full\$name.png", "$previews\$name.png") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($shot) { $img = [Drawing.Image]::FromFile($shot); $g.DrawImage($img, $x, $y + $label, $w, $h); $img.Dispose() }
    else { $g.DrawString('(not captured)', $font, [Drawing.Brushes]::Gray, $x + 120, $y + $label + 90) }
    $src = $pack | Where-Object BaseName -eq $pairs[$i].Sky | Select-Object -First 1
    if ($src) {
        # The middle half of the panorama, around the horizon: roughly what surrounds the screen.
        $img = [Drawing.Image]::FromFile($src.FullName)
        $crop = New-Object Drawing.RectangleF ($img.Width * 0.25), ($img.Height * 0.25), ($img.Width * 0.5), ($img.Height * 0.5)
        $g.DrawImage($img, (New-Object Drawing.RectangleF ($x + $w), ($y + $label), $w, $h), $crop, [Drawing.GraphicsUnit]::Pixel); $img.Dispose()
    }
    $g.DrawString("$($pairs[$i].Backdrop)  ->  $($pairs[$i].Sky)", $font, [Drawing.Brushes]::White, $x + 2, $y + 2)
}
$out = Join-Path $previews 'sky_matches.png'
$sheet.Save($out, [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $sheet.Dispose()
$out
