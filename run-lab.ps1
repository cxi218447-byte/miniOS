# 一键：clean + 编译 + 运行（经 WSL Ubuntu）
# 用法：在仓库根目录执行  .\run-lab.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

& "$PSScriptRoot\make.ps1" clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& "$PSScriptRoot\make.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[run-lab] starting QEMU (exit: Ctrl-a then x)" -ForegroundColor Cyan
& "$PSScriptRoot\make.ps1" run
exit $LASTEXITCODE
