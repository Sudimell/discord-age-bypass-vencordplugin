param(
    [Parameter(Mandatory = $true)][string]$Action,
    [string]$A,
    [string]$B
)

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host $msg; exit 1 }

$required = @("patcher.js", "preload.js", "renderer.js", "renderer.css", "vencordDesktopMain.js", "vencordDesktopPreload.js", "vencordDesktopRenderer.js", "vencordDesktopRenderer.css")

function CheckDist($dir) {
    foreach ($f in $required) {
        $p = Join-Path $dir $f
        if (-not (Test-Path $p)) { Fail "missing $f" }
        if ((Get-Item $p).Length -le 0) { Fail "empty $f" }
    }
}

switch ($Action) {
    "check" {
        CheckDist $A
        Write-Host "dist ok"
    }

    "expand" {
        if (Test-Path $B) { Remove-Item -Recurse -Force $B }
        Expand-Archive -Path $A -DestinationPath $B -Force
        CheckDist $B
        Write-Host "expanded"
    }

    "ispatched" {
        $found = $false
        foreach ($app in Get-ChildItem (Join-Path $env:LOCALAPPDATA $A) -Directory -Filter "app-*" -ErrorAction SilentlyContinue) {
            $asar = Join-Path $app.FullName "resources\app.asar"
            if (-not (Test-Path $asar)) { continue }
            $head = [IO.File]::ReadAllText($asar, [Text.Encoding]::UTF8)
            if ($head -match "Vencord" -and $head -match "patcher\.js") { $found = $true }
        }
        if ($found) { Write-Host "patched" } else { Fail "not patched" }
    }

    "vencorddir" {
        $state = Join-Path $env:APPDATA "vesktop\state.json"
        $dir = $null
        if (Test-Path $state) {
            try { $dir = (Get-Content $state -Raw | ConvertFrom-Json).vencordDir } catch { }
        }
        if (-not $dir) { $dir = Join-Path $env:APPDATA "vesktop\sessionData\vencordFiles" }
        Write-Host $dir
    }

    "enable" {
        if (-not (Test-Path $A)) { Fail "no settings file: $A" }
        $json = Get-Content $A -Raw | ConvertFrom-Json
        if (-not $json.PSObject.Properties["plugins"]) {
            $json | Add-Member -NotePropertyName plugins -NotePropertyValue ([pscustomobject]@{})
        }
        $json.plugins | Add-Member -NotePropertyName AgeVerificationBypass -NotePropertyValue ([pscustomobject]@{
            enabled = $true; spoofClientBuild = $true; spoofAgeStatus = $true
        }) -Force
        [IO.File]::WriteAllText($A, ($json | ConvertTo-Json -Depth 64), (New-Object Text.UTF8Encoding($false)))
        Write-Host "enabled in $A"
    }

    "disable" {
        if (-not (Test-Path $A)) { exit 0 }
        $json = Get-Content $A -Raw | ConvertFrom-Json
        if ($json.PSObject.Properties["plugins"] -and $json.plugins.PSObject.Properties["AgeVerificationBypass"]) {
            $json.plugins.PSObject.Properties.Remove("AgeVerificationBypass")
            [IO.File]::WriteAllText($A, ($json | ConvertTo-Json -Depth 64), (New-Object Text.UTF8Encoding($false)))
        }
        Write-Host "removed from $A"
    }

    default { Fail "unknown action $Action" }
}
