#!/usr/bin/env bash
# 真实包用例：libaom AV1 编码 5 帧（generic C，AOM_Q）→ 解码回环。
set -euo pipefail
: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"
case "$STAGE" in
  gen) ;;
  run)
    [ -x "$BIN/aom_harness" ] || { echo "缺少 $BIN/aom_harness" >&2; exit 1; }
    "$BIN/aom_harness" "$OUT/hash.txt" > /dev/null
    grep -q "fnv_px=" "$OUT/hash.txt" || { echo "探针未产出" >&2; exit 1; }
    ;;
  *) echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
