# Doubles the size of every sky skyboxes.txt lists, into "Fantasy Skybox Upscaled", using Real-ESRGAN from tools\dl.
# Skies already done are skipped, so it can be stopped and run again. pack_skies.ps1 -Source then packs the results.
param([string[]]$First = @('FS002_Night_Moonless', 'FS017_Night_Moonless'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$R = Split-Path $PSScriptRoot -Parent
$exe = Get-ChildItem "$R\tools\dl\realesrgan\app" -Recurse -Filter 'realesrgan-ncnn-vulkan.exe' | Select-Object -First 1
$models = Join-Path $exe.DirectoryName 'models'
$work = "$R\Fantasy Skybox Upscaled"; New-Item -ItemType Directory -Force $work | Out-Null
$pad = 128
$listed = Get-Content "$R\skybox\skyboxes.txt" | Where-Object { $_ -match '^\s*[^#\s].*=\s*\S+\.lvsky\s*$' } | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension((($_ -split '=', 2)[1]).Trim()) } | Select-Object -Unique
$names = @($First | Where-Object { $listed -contains $_ }) + @($listed | Where-Object { $First -notcontains $_ })
foreach ($name in $names) {
    $final = "$work\$name.png"
    if (Test-Path $final) { "$name already done"; continue }
    $src = Get-ChildItem "$R\Fantasy Skybox" -Recurse -Filter "$name.png" | Select-Object -First 1
    if (-not $src) { throw "$name isn't in Fantasy Skybox" }
    $temp = "$work\_temp"; if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }; New-Item -ItemType Directory $temp | Out-Null
    # The panorama's left and right edges meet behind the player, so each side gets a strip of the other before upscaling.
    $img = [Drawing.Image]::FromFile($src.FullName); $w = $img.Width; $h = $img.Height
    $padded = New-Object Drawing.Bitmap ($w + 2 * $pad), $h, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [Drawing.Graphics]::FromImage($padded); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
    $g.DrawImage($img, (New-Object Drawing.Rectangle $pad, 0, $w, $h), (New-Object Drawing.Rectangle 0, 0, $w, $h), 'Pixel')
    $g.DrawImage($img, (New-Object Drawing.Rectangle 0, 0, $pad, $h), (New-Object Drawing.Rectangle ($w - $pad), 0, $pad, $h), 'Pixel')
    $g.DrawImage($img, (New-Object Drawing.Rectangle ($pad + $w), 0, $pad, $h), (New-Object Drawing.Rectangle 0, 0, $pad, $h), 'Pixel')
    $g.Dispose(); $img.Dispose()
    $padded.Save("$temp\in.png", [Drawing.Imaging.ImageFormat]::Png); $padded.Dispose()
    $t = Get-Date
    $p = Start-Process $exe.FullName -ArgumentList @('-i', "`"$temp\in.png`"", '-o', "`"$temp\out.png`"", '-n', 'realesrgan-x4plus-anime', '-s', '4', '-m', "`"$models`"") -WorkingDirectory $exe.DirectoryName -NoNewWindow -PassThru -Wait -RedirectStandardError "$temp\err.txt" -RedirectStandardOutput "$temp\log.txt"
    if (-not (Test-Path "$temp\out.png")) { throw "$name failed, upscaler exit $($p.ExitCode)" }
    # Crop the padding off and reduce from 4x to 2x, which gives cleaner results than asking the model for 2x directly.
    $up = [Drawing.Image]::FromFile("$temp\out.png")
    $out = New-Object Drawing.Bitmap ($w * 2), ($h * 2), ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [Drawing.Graphics]::FromImage($out); $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($up, (New-Object Drawing.Rectangle 0, 0, ($w * 2), ($h * 2)), (New-Object Drawing.Rectangle ($pad * 4), 0, ($w * 4), ($h * 4)), 'Pixel')
    $g.Dispose(); $up.Dispose()
    $out.Save("$final.tmp", [Drawing.Imaging.ImageFormat]::Png); $out.Dispose()
    Move-Item "$final.tmp" $final -Force
    Remove-Item $temp -Recurse -Force
    '{0} {1}x{2} {3:N1} MB (was {4:N1} MB) in {5:N0} s' -f $name, ($w * 2), ($h * 2), ((Get-Item $final).Length / 1MB), ($src.Length / 1MB), ((Get-Date) - $t).TotalSeconds
}
'all done'
