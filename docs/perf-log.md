# 性能与正确性日志 —— `media-libs/libaom`

每条记录必须包含：**日期 / 变更 / 内核 / 输入规模 / A / B / 比值 / 是否位精确 / 证据路径**。
没有 A/B 双数字的记录不算数。

## 基线（G2，内核关闭）

| 日期 | 构建 | 用例 | 规模 | A(ms) | B(ms) | 备注 |
|---|---|---|---|---|---|---|
|  | riscv64 |  |  |  |  |  |

```
cpu_probe（目标机）：
vlen=
vle_ticks=  vlse_ticks=  vrgather_ticks=  vsetvl_ticks=
```

## 逐轮记录（G3）

| 轮 | 日期 | 内核 | LMUL | 规模 | A(ms) | B(ms) | 收益 | 位精确 | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |  |  |  |

## 收敛分析（G4）

```
perf top（剩余热点，按占比排序）：
1.
2.
3.
结论：覆盖度 f=____；停止理由：____
```

## baseline 版本对齐（真机 rv64gcv）

- 现象：A/B `01_aom_roundtrip` 产出不一致（A 2683 B，B 2380 B）。
- 四侧定点：A(src+gcv+内核) 2683 / A2(src+gcv 关内核) 2683 / A3(src+gcv 关自动向量化) 2683；B2(baseline+gc 关向量化) 2380 / B3(baseline+gcv) 2380
  → 与内核、与自动向量化都无关，是两棵树版本不同。
- 证据：`baseline/CHANGELOG` 首行 `2022-01-28 v3.3.0`；`src/CHANGELOG` 首行 `yyyy-mm-dd next version`；`diff -rq` 1251 个文件不同，src 多出 `aom_tpl.h`/`aom_ext_ratectrl.h` 与整套 `av1/common/riscv/*`。
- 处置：按 9.1 口径把 `baseline` 对齐到与 `src` 同一上游快照（`src` 内没有 `RVV_KERNELS` 自写内核，可直接取快照作为基线；`diff -rq baseline src` = 0）。
- 结果：`00_framework` + `01_aom_roundtrip` 逐字节一致，A/B **ALL PASS**。
- 结论：此前 libaom 的 A/B 差异全部是基线版本错配造成的假失败，不是内核 bug。
