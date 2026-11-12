# setup-ffmpeg.ps1
# Installs ffmpeg 9.0.2 (full build) for camera capture.
# winget proved unreliable on the reference machine (Delivery Optimization
# timeouts), so the primary path downloads the official Gyan.dev build through
# the ghfast.top GitHub mirror and verifies the SHA256 from the winget manifest.
[CmdletBinding()]
param(
    [string]$Version = '9.0.2',
    [string]$Sha256 = '759D0A9831C436A0EB331AD36F236C06CB04AAA0005DA46571F0E9D3D9206F6B',
    [string]$InstallRoot = (Join-Path $env:USERPROFILE 'tools'),
    [switch]$TryWingetFirst
)

$ErrorActionPreference = 'Stop'
try {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
} catch { }

function Add-UserPath([string]$dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($current -split ';' | Where-Object { $_ })
    if ($parts -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $dir) -join ';'), 'User')
    }
    if (($env:Path -split ';') -notcontains $dir) {
        $env:Path = $env:Path + ';' + $dir
    }
}

$existing = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[ffmpeg] already available: $($existing.Source)" -ForegroundColor Green
    & $existing.Source -version 2>&1 | Select-Object -First 1
    exit 0
}

if ($TryWingetFirst) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host '[ffmpeg] trying winget Gyan.FFmpeg...' -ForegroundColor Cyan
        try {
            & winget install --id Gyan.FFmpeg --exact --silent `
                --accept-source-agreements --accept-package-agreements 2>&1 | Out-Host
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [Environment]::GetEnvironmentVariable('Path', 'User')
            $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
            if ($cmd) {
                Write-Host "[ffmpeg] installed via winget: $($cmd.Source)" -ForegroundColor Green
                exit 0
            }
        } catch {
            Write-Host "[ffmpeg] winget failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

$zipName = "ffmpeg-$Version-full_build.zip"
$mirror = "https://ghfast.top/https://github.com/GyanD/codexffmpeg/releases/download/$Version/$zipName"
$direct = "https://github.com/GyanD/codexffmpeg/releases/download/$Version/$zipName"

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
$tmp = Join-Path $env:TEMP ($zipName + '.' + [guid]::NewGuid().ToString('N') + '.tmp')

$ok = $false
foreach ($u in @($mirror, $direct)) {
    try {
        Write-Host "[ffmpeg] downloading $Version (~150 MB)..." -ForegroundColor Cyan
        Write-Host "  GET $u"
        Invoke-WebRequest -Uri $u -OutFile $tmp -UseBasicParsing -TimeoutSec 1800
        $size = (Get-Item $tmp).Length
        if ($size -lt 50MB) { throw "download too small: $size bytes" }
        Write-Host ("[ffmpeg] downloaded {0:N1} MB, verifying SHA256..." -f ($size / 1MB))
        $hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
        if ($hash -ne $Sha256) {
            throw "SHA256 mismatch. expected $Sha256 got $hash"
        }
        $ok = $true
        break
    } catch {
        Write-Host "  failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}
if (-not $ok) {
    throw 'ffmpeg download failed. Install ffmpeg manually (winget install Gyan.FFmpeg) and re-run deploy.ps1.'
}

Expand-Archive -LiteralPath $tmp -DestinationPath $InstallRoot -Force
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

$binDir = Get-ChildItem -Path $InstallRoot -Recurse -Filter 'ffmpeg.exe' |
    Select-Object -First 1 | ForEach-Object { $_.DirectoryName }
if (-not $binDir) { throw 'ffmpeg.exe was not found after extraction.' }

Add-UserPath $binDir
Write-Host "[ffmpeg] installed: $binDir" -ForegroundColor Green
& (Join-Path $binDir 'ffmpeg.exe') -version 2>&1 | Select-Object -First 1
