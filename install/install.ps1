# Installs or removes LanaVR2. Run through "Install LanaVR2.bat".
param(
    [ValidateSet('Install', 'Uninstall', 'Ask')][string]$Action = 'Ask',
    [string]$GameDir = ''
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

function Find-Game {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam = 'C:\Program Files (x86)\Steam' }
    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libraries += $m.Groups[1].Value.Replace('\\', '\') }
    }
    foreach ($l in $libraries) {
        $p = Join-Path $l 'steamapps\common\Planet of Lana 2'
        if (Test-Path (Join-Path $p 'Planet of Lana 2.exe')) { return $p }
    }
    return ''
}

Write-Host 'Welcome to the Planet of Lana II virtual screen VR mod by FlukeRogi' -ForegroundColor Cyan
Write-Host ''
if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir 'Planet of Lana 2.exe'))) {
    Write-Host 'Could not find Planet of Lana II in your Steam libraries.' -ForegroundColor Red
    $GameDir = Read-Host 'Paste the game folder path (the one containing "Planet of Lana 2.exe")'
    if (-not (Test-Path (Join-Path $GameDir 'Planet of Lana 2.exe'))) { throw "Planet of Lana 2.exe is not in: $GameDir" }
}
Write-Host "Game folder: " -NoNewline -ForegroundColor Gray; Write-Host $GameDir -ForegroundColor White
Write-Host ''

if (Get-Process 'Planet of Lana 2' -ErrorAction SilentlyContinue) { throw 'Please close Planet of Lana II first.' }

if ($Action -eq 'Ask') {
    $c = Read-Host 'Type 1 to install LanaVR2, or 2 to uninstall it'
    Write-Host ''
    $Action = switch ($c) { '1' { 'Install' } '2' { 'Uninstall' } default { throw 'Nothing was changed.' } }
}

if ($Action -eq 'Install') {
    Copy-Item (Join-Path $here 'payload\*') $GameDir -Recurse -Force
    # The developer test mode blocks saves and Steam achievements, so a player's install must never have it on.
    $cfg = Join-Path $GameDir 'BepInEx\config\com.lanavr.planetoflana2.cfg'
    if (Test-Path $cfg) {
        $text = Get-Content $cfg
        $fixed = $text -replace '^LabCommands = true', 'LabCommands = false'
        if (($fixed -join "`n") -ne ($text -join "`n")) { Set-Content $cfg $fixed -Encoding utf8; Write-Host 'Switched off the developer test mode, which blocks saves and achievements.'; Write-Host '' }
    }
    Write-Host 'LanaVR2 is installed. Start Planet of Lana II from Steam.' -ForegroundColor Green
    Write-Host ''
    Write-Host 'The first start may take up to a minute or two depending on your PC.' -ForegroundColor Yellow
    Write-Host 'This is a first time only setup - loading again afterwards will be fast.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Please refer to the README.txt for further mod information.' -ForegroundColor Gray
    return
}

# Uninstall: the mod's own files always go. The BepInEx loader stays if other mods are using it.
$plugins = Join-Path $GameDir 'BepInEx\plugins'
if (Test-Path (Join-Path $plugins 'LanaVR2')) { Remove-Item (Join-Path $plugins 'LanaVR2') -Recurse -Force }
$cfg = Join-Path $GameDir 'BepInEx\config\com.lanavr.planetoflana2.cfg'
if (Test-Path $cfg) { Remove-Item $cfg -Force }
$others = @(Get-ChildItem $plugins -ErrorAction SilentlyContinue)
if ($others.Count -gt 0) {
    Write-Host "LanaVR2 is removed. BepInEx stays, because other mods are in $plugins." -ForegroundColor Yellow
    return
}
foreach ($item in 'BepInEx', 'dotnet', 'winhttp.dll', 'doorstop_config.ini', '.doorstop_version', 'changelog.txt') {
    $p = Join-Path $GameDir $item
    if (Test-Path $p) { Remove-Item $p -Recurse -Force }
}
Write-Host 'LanaVR2 and BepInEx are removed, and the game is back to its original files.' -ForegroundColor Green
