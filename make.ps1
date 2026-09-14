# Windows helper: run GNU make inside WSL Ubuntu.
# In PowerShell, from repo root, type EXACTLY:
#   .\make.ps1 clean
#   .\make.ps1
#   .\make.ps1 run
# Do NOT type: make clean   (Windows has no "make")

$ErrorActionPreference = "Continue"
$winPath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$winPath = (Resolve-Path -LiteralPath $winPath).Path

if ($winPath -notmatch '^([A-Za-z]):\\(.*)$') {
    Write-Host "Cannot map Windows path to WSL: $winPath" -ForegroundColor Red
    exit 1
}
$drive = $Matches[1].ToLowerInvariant()
$rest = $Matches[2] -replace '\\', '/'
$wslPath = "/mnt/$drive/$rest"

$makeArgs = if ($args.Count -gt 0) { ($args -join ' ') } else { '' }
$inner = if ($makeArgs) { "make $makeArgs" } else { "make" }

# Escape for single-quoted bash string: only need to handle single quotes
$bashCd = $wslPath -replace "'", "'\''"

Write-Host "[make.ps1] $inner" -ForegroundColor Cyan
Write-Host "[make.ps1] WSL dir: $wslPath" -ForegroundColor DarkGray

$bash = "cd '$bashCd' && $inner"
& wsl.exe -d Ubuntu -- bash -lc $bash
exit $LASTEXITCODE
