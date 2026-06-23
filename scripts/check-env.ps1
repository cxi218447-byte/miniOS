Write-Host "miniOS LoongArch environment check"
Write-Host ""

$commands = @(
    "wsl",
    "make",
    "qemu-system-loongarch64",
    "loongarch64-linux-gnu-gcc",
    "loongarch64-linux-gnu-objcopy",
    "gdb",
    "gdb-multiarch"
)

foreach ($cmd in $commands) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host ("[OK]      {0} -> {1}" -f $cmd, $found.Source)
    } else {
        Write-Host ("[MISSING] {0}" -f $cmd)
    }
}

Write-Host ""
Write-Host "WSL status:"
wsl --status
