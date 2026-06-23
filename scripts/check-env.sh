#!/usr/bin/env sh
set -eu

echo "miniOS LoongArch environment check"
echo

for cmd in make qemu-system-loongarch64 loongarch64-linux-gnu-gcc \
    loongarch64-linux-gnu-objcopy gdb gdb-multiarch; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '[OK]      %s -> %s\n' "$cmd" "$(command -v "$cmd")"
    else
        printf '[MISSING] %s\n' "$cmd"
    fi
done

echo
echo "Versions:"
for cmd in qemu-system-loongarch64 loongarch64-linux-gnu-gcc make; do
    if command -v "$cmd" >/dev/null 2>&1; then
        "$cmd" --version | sed -n '1p'
    fi
done
