#!/usr/bin/env bash
# 构建上游 libaom（CMake）→ <out>/prefix：静态 libaom.a。
# A/B 差异只由位置参数驱动：$3 = -march 值，$4 = 1 打开上游 RVV 移植。
# B 侧 AOM_TARGET_CPU=generic（纯 C，关掉所有 SIMD）；
# A 侧 AOM_TARGET_CPU=riscv64 + ENABLE_RVV=1，上游自己用 -march=rv64gcv 编 rvv 目标库。
set -euo pipefail
SRC=$1
OUT=$2
MARCH=${3:-rv64gc}
KERN=${4:-0}
mkdir -p "$OUT"
OUT=$(realpath "$OUT")
CPU=generic
EXTRA=(-DCMAKE_C_FLAGS="-march=${MARCH}" -DCMAKE_CXX_FLAGS="-march=${MARCH}")
if [ "${KERN}" = "1" ]; then
  CPU=riscv64
  EXTRA+=(-DENABLE_RVV=1)
fi
cmake -S "$SRC" -B "$OUT/bld" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$OUT/prefix" \
  -DAOM_TARGET_CPU="$CPU" \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_TOOLS=OFF -DENABLE_DOCS=OFF \
  -DENABLE_CCLIBS=OFF \
  -DCONFIG_AV1_ENCODER=1 -DCONFIG_AV1_DECODER=1 \
  -DCONFIG_MULTITHREAD=1 "${EXTRA[@]}"
cmake --build "$OUT/bld" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
cmake --install "$OUT/bld"
