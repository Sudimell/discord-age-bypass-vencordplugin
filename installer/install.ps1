param(
    [Parameter(Mandatory = $true)][string]$VencordPath,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$plugin = Join-Path $PSScriptRoot "..\plugin\ageVerificationBypass"
$target = Join-Path $VencordPath "src\userplugins\ageVerificationBypass"
$dist = Join-Path $VencordPath "dist"
$vcd = Join-Path $env:APPDATA "Vencord"
$live = Join-Path $vcd "dist"
$bak = Join-Path $vcd "dist.avb-backup"
$bakOld = Join-Path $vcd "dist.avb-backup.old"
$key = "AgeVerificationBypass"

if (-not (Test-Path (Join-Path $VencordPath "pnpm-lock.yaml"))) { throw "not a vencord checkout: $VencordPath" }
if (-not (Test-Path (Join-Path $VencordPath "src\userplugins"))) { throw "vencord checkout has no src\userplugins: $VencordPath" }
if (-not (Test-Path $plugin)) { throw "plugin sources missing: $plugin" }

if ($DryRun) { Write-Host "ok"; exit 0 }

if (Test-Path $target) { Remove-Item -Recurse -Force $target }
Copy-Item -Recurse $plugin $target

Push-Location $VencordPath
try {
    pnpm test:ts
    if ($LASTEXITCODE -ne 0) { throw "typecheck died" }

    pnpm build --disable-updater
    if ($LASTEXITCODE -ne 0) { throw "build died" }
} finally {
    Pop-Location
}

if (Test-Path $bakOld) { Remove-Item -Recurse -Force $bakOld }
if (Test-Path $bak) { Move-Item $bak $bakOld }
robocopy $live $bak /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "backup died" }

Remove-Item -Recurse -Force $live
New-Item -ItemType Directory -Force $live | Out-Null
robocopy $dist $live /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "copy died" }

$settings = Join-Path $vcd "settings\settings.json"
if (Test-Path $settings) {
    $json = Get-Content $settings -Raw | ConvertFrom-Json
    if (-not $json.PSObject.Properties["plugins"]) {
        $json | Add-Member -NotePropertyName plugins -NotePropertyValue ([pscustomobject]@{})
    }
    $json.plugins | Add-Member -NotePropertyName $key -NotePropertyValue ([pscustomobject]@{
        enabled = $true; spoofClientBuild = $true; spoofAgeStatus = $true
    }) -Force
    [IO.File]::WriteAllText($settings, ($json | ConvertTo-Json -Depth 64), (New-Object Text.UTF8Encoding($false)))
}

Write-Host "installed"
