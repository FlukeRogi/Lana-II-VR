# Turns a sky scan (tests\scan_sky.ps1) into Shade: lines in skybox\skyboxes.txt, between the scan markers.
# Each backdrop is compared with its own usual brightness, taken from the bright end of each stop's picture, which
# follows the sky rather than trees or hills in front of it. Only darkening is used, small changes and single-stop
# blips are ignored, and colour changes are applied at half strength so a painted sunset doesn't overwhelm the sky.
param([string]$Scan = "$env:USERPROFILE\AppData\LocalLow\LanaVR2\lab\scan\sky_walk.txt",
      # Backdrops whose changes Tint: lines already follow. Chapter 5 is underground throughout, under the cave tint.
      [string[]]$Skip = @('Chapter 01 Backdrop', 'Chapter 05 Backdrop'))
$ErrorActionPreference = 'Stop'
$c = [Globalization.CultureInfo]::InvariantCulture
$Root = Split-Path $PSScriptRoot -Parent
$map = "$Root\skybox\skyboxes.txt"
# The backdrop each level uses, from the game's scene list the scan saved alongside.
$backdrops = @{}
foreach ($line in Get-Content (Join-Path (Split-Path $Scan) 'scenes.txt')) { $p = $line -split ' \| '; if ($p.Count -ge 2) { $backdrops[$p[0].Trim()] = $p[1].Trim() } }
$rows = foreach ($line in Get-Content $Scan) {
    $p = $line -split '\|'
    if ($p[6] -match 'PP Death') { continue }  # Lana died there, and the game greys the picture.
    $t = $p[5] -split ',' | ForEach-Object { [double]::Parse($_, $c) }
    [pscustomobject]@{ B = $backdrops[$p[0]]; X = [double]$p[1]; R = $t[0]; G = $t[1]; Bl = $t[2]; Lum = ($t[0] + $t[1] + $t[2]) / 3 }
}
$lines = @()
foreach ($g in ($rows | Where-Object { $_.B -and $Skip -notcontains $_.B } | Group-Object B)) {
    $sorted = @($g.Group | Sort-Object Lum); $ref = $sorted[[int][math]::Floor($sorted.Count * 0.75)]
    # Stops a few units apart are the same place, measured twice where two levels overlap.
    $stops = @($g.Group | Group-Object { [math]::Round($_.X / 5) } | ForEach-Object {
        $m = $_.Group
        [pscustomobject]@{ X = ($m | Measure-Object X -Average).Average; R = ($m | Measure-Object R -Average).Average; G = ($m | Measure-Object G -Average).Average; Bl = ($m | Measure-Object Bl -Average).Average; Lum = ($m | Measure-Object Lum -Average).Average }
    } | Sort-Object X)
    $v = foreach ($s in $stops) { [math]::Min(1.0, $s.Lum / $ref.Lum) }
    $dark = for ($i = 0; $i -lt $stops.Count; $i++) { $v[$i] -lt 0.92 -and (($i -gt 0 -and $v[$i - 1] -lt 0.92) -or ($i -lt $stops.Count - 1 -and $v[$i + 1] -lt 0.92)) }
    if (-not ($dark -contains $true)) { continue }
    $out = @()
    for ($i = 0; $i -lt $stops.Count; $i++) {
        $s = $stops[$i]
        if ($dark[$i]) {
            $rel = $s.Lum / $ref.Lum
            $ch = foreach ($pair in @(@($s.R, $ref.R), @($s.G, $ref.G), @($s.Bl, $ref.Bl))) {
                # A channel that is nearly absent in the usual sky gives an unsteady ratio, so it follows the brightness alone.
                $ratio = if ($pair[1] -gt 0.15) { ($pair[0] / $pair[1]) / $rel } else { 1.0 }
                [math]::Max(0.15, [math]::Min(1.0, $v[$i] * (1 + 0.5 * ($ratio - 1))))
            }
        } else { $ch = 1, 1, 1 }
        $text = '{0:F2} {1:F2} {2:F2}' -f $ch[0], $ch[1], $ch[2]
        # Only the stops either side of a change are kept.
        $prev = if ($i -gt 0) { $out[-1].Text } else { $null }
        $next = if ($i -lt $stops.Count - 1) { 'next' } else { $null }
        $out += [pscustomobject]@{ X = $s.X; Text = $text }
    }
    $kept = for ($i = 0; $i -lt $out.Count; $i++) { if ($i -eq 0 -or $i -eq $out.Count - 1 -or $out[$i].Text -ne $out[$i - 1].Text -or $out[$i].Text -ne $out[$i + 1].Text) { $out[$i] } }
    $lines += "Shade: $($g.Name) = " + (($kept | ForEach-Object { ('{0:F0} ' -f $_.X) + $_.Text.Replace(',', '.') }) -join ' | ')
}
$begin = '# --- Shades from the sky scan (tools\make_shades.ps1). Hand changes here are replaced on the next run.'
$end = '# --- End of scanned shades'
$text = Get-Content $map
$keep = @(); $inside = $false
foreach ($l in $text) { if ($l -eq $begin) { $inside = $true; continue }; if ($l -eq $end) { $inside = $false; continue }; if (-not $inside) { $keep += $l } }
while ($keep.Count -and $keep[-1] -eq '') { $keep = $keep[0..($keep.Count - 2)] }
$keep += '', '# Shades follow places where the game''s own painted sky darkens or changes colour along a level. Each stop is', '# a distance along the level, then red, green and blue strengths, with smooth changes between stops.', '# Shade: Backdrop name = distance red green blue | distance red green blue | ...', $begin
$keep += $lines
$keep += $end
Set-Content $map $keep -Encoding ascii
$lines
