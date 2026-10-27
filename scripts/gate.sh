#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
compiler=${SD_SYSL:-sysl}
mkdir -p scratch
"$compiler" test . --no-default-features --timeout 60
"$compiler" test . --timeout 60
for target in thumbv6m-freestanding thumbv7em-freestanding thumb-freestanding riscv32-freestanding aarch64-freestanding; do
    "$compiler" build-c tools/portable --target "$target" -o "scratch/sd-$target.a"
    "$compiler" build-c tools/portable --features fat --target "$target" -o "scratch/sd-fat-$target.a"
done
