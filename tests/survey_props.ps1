# Lists the copyable, textured props in several levels, for choosing the 3D scenery. Writes tests\props\<level>.txt.
# The game must already be running with Lab commands on, at the main menu.
param([string[]]$Scenes = @('Chapter 03 Scene 10', 'Chapter 06 Scene 10', 'Chapter 06 Scene 20', 'Chapter 06 Scene 30', 'Chapter 02 Scene 10', 'Chapter 01 Scene 200', 'Chapter 05 Scene 100', 'Chapter 10 Scene 10'))
. "$PSScriptRoot\lab.ps1"
$out = "$Root\tests\props"; New-Item -ItemType Directory -Force $out | Out-Null
foreach ($s in $Scenes) {
    $r = Lab "propload $s" 12
    $list = Lab 'propnames' 3
    [void](Lab "propunload $s" 4); [void](Lab 'propgc' 3)
    $lines = $list -split "`n"
    $textured = @($lines | Where-Object { $_ -match '\| tex=' -and $_ -notmatch 'tex=none' -and $_ -notmatch 'SpriteProp|Quad \(' })
    $lines | Set-Content "$out\$($s -replace ' ', '_').txt" -Encoding utf8
    "{0}: {1} textured of {2}" -f $s, $textured.Count, ($lines[1] -replace '.*pairs=(\d+).*', '$1')
}
