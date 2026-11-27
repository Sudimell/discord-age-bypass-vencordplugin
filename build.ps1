<#
.SYNOPSIS
    builds the plugin in a vencord checkout and installs it

.PARAMETER VencordPath
    path to a vencord checkout that already has pnpm install

.PARAMETER Dev
    dev build with maps and devtools. for poking

.PARAMETER NoRestart
    dont restart dsc after install

.PARAMETER DebugPort
    restart dsc with --remote-debugging-port=9222 for cdp
#>
param(
    [Parameter(Mandatory = $true)][string]$VencordPath,
    [switch]$Dev,
    [switch]$NoRestart,
    [switch]$DebugPort
)

$ErrorActionPreference = "Stop"

$pluginName = "ageVerificationBypass"
$source = Join-Path $PSScriptRoot "plugin/$pluginName"
$target = Join-Path $VencordPath "src/userplugins/$pluginName"
$dist = Join-Path $VencordPath "dist"
$live = Join-Path $env:APPDATA "Vencord/dist"

if (-not (Test-Path (Join-Path $VencordPath "pnpm-lock.yaml"))) {
    throw "$VencordPath doesnt look like a vencord checkout"
}
if (-not (Test-Path $source)) {
    throw "no plugin source at: $source"
}

New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
Copy-Item -Recurse $source $target

Push-Location $VencordPath
try {
    $buildArgs = @()
    if ($Dev) { $buildArgs += "--dev" } else { $buildArgs += "--disable-updater" }

    pnpm test:ts
    if ($LASTEXITCODE -ne 0) { throw "typecheck died" }

    pnpm build @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "build died" }
} finally {
    Pop-Location
}

if (Test-Path $live) {
    $backup = Join-Path $env:APPDATA "Vencord/dist.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item -Recurse $live $backup
    Write-Host "backed up old dist to $backup"
}

New-Item -ItemType Directory -Force -Path $live | Out-Null
Copy-Item -Recurse -Force (Join-Path $dist "*") $live

$settingsFile = Join-Path $env:APPDATA "Vencord/settings/settings.json"
$pluginKey = "AgeVerificationBypass"
if (Test-Path $settingsFile) {
    $json = Get-Content $settingsFile -Raw | ConvertFrom-Json
    if (-not $json.plugins.PSObject.Properties[$pluginKey]) {
        $json.plugins | Add-Member -NotePropertyName $pluginKey -NotePropertyValue ([pscustomobject]@{ enabled = $true })
        $json | ConvertTo-Json -Depth 32 | Set-Content $settingsFile
        Write-Host "plugin registered and enabled"
    }
}

if ($NoRestart) { return }

Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 4

$exe = Get-ChildItem "$env:LOCALAPPDATA/Discord/app-*/Discord.exe" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { throw "Discord.exe not found" }

$exeArgs = @()
if ($DebugPort) { $exeArgs += "--remote-debugging-port=9222" }
Start-Process $exe.FullName -ArgumentList $exeArgs
Write-Host "restarted dsc"
