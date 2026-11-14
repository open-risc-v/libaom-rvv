#!/usr/bin/env bash
# libaom G3：上游 av1/common/riscv/*_rvv.c（convolve / compound_convolve / wiener /
# cdef_block，高低比特深各一套）+ aom_ports/riscv_cpudetect.c 运行时派发。
# A = ENABLE_RVV=ON @ rv64gcv，B = ENABLE_RVV=OFF @ 同一 march。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${IMAGE:-rvv-cross:2}
MARCH=${MARCH:-rv64gcv}
OUT=build/rvv-k

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}; mkdir -p ${OUT}
for side in on off; do
  opt='-DENABLE_RVV=ON'
  if [ \"\$side\" = off ]; then opt='-DENABLE_RVV=OFF'; fi
  cmake -S baseline -B ${OUT}/\$side/bld -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/${OUT}/\$side/prefix \
    -DAOM_TARGET_CPU=riscv -DBUILD_SHARED_LIBS=OFF \
    -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_TOOLS=OFF -DENABLE_DOCS=OFF -DENABLE_CCLIBS=OFF \
    -DCONFIG_AV1_ENCODER=1 -DCONFIG_AV1_DECODER=1 -DCONFIG_MULTITHREAD=1 \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=${MARCH} -O3' \$opt > ${OUT}/\$side-cfg.log 2>&1 \
      || { tail -25 ${OUT}/\$side-cfg.log; exit 1; }
  cmake --build ${OUT}/\$side/bld -j > ${OUT}/\$side-build.log 2>&1 \
      || { tail -25 ${OUT}/\$side-build.log; exit 1; }
  cmake --install ${OUT}/\$side/bld > /dev/null

  cmake -S . -B ${OUT}/\$side/harness -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=${MARCH} -O3' -DPKG_PREFIX=/work/${OUT}/\$side/prefix > /dev/null 2>&1
  cmake --build ${OUT}/\$side/harness -j > ${OUT}/\$side-harness.log 2>&1 \
      || { tail -15 ${OUT}/\$side-harness.log; exit 1; }
  qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/\$side/harness/aom_harness ${OUT}/\$side/frames.bin > ${OUT}/\$side/hash.txt
done

echo '--- A：ENABLE_RVV=ON ---'; cat ${OUT}/on/hash.txt
echo '--- B：ENABLE_RVV=OFF ---'; cat ${OUT}/off/hash.txt
cmp -s ${OUT}/on/hash.txt ${OUT}/off/hash.txt && echo '== 功能一致' || echo '== 功能不一致'
"
