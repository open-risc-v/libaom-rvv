#!/usr/bin/env bash
# 构建上游 libaom（CMake）→ <out>/prefix：静态 libaom.a。
# AOM_TARGET_CPU=generic：关掉所有 SIMD（x86/arm），纯 C —— riscv 侧没有可用的
# aom 汇编，两侧同口径才能谈位精确。
set -euo pipefail
SRC=$1
OUT=$2
cmake -S "$SRC" -B "$OUT/bld" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$OUT/prefix" \
  -DAOM_TARGET_CPU=generic \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_TOOLS=OFF -DENABLE_DOCS=OFF \
  -DENABLE_CCLIBS=OFF \
  -DCONFIG_AV1_ENCODER=1 -DCONFIG_AV1_DECODER=1 \
  -DCONFIG_MULTITHREAD=1
cmake --build "$OUT/bld" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
cmake --install "$OUT/bld"
