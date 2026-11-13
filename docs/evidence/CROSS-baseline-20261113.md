# 交叉编译基线（riscv64）— libaom

## 口径
- 只编 baseline，`MARCH=rv64gc`，镜像 `rvv-cross:2`
- **`AOM_TARGET_CPU=generic`**：关掉 x86/arm 全部 SIMD，纯 C；native 侧同样 generic
- 探针 `test/pkg_aom.c`：AV1 128×96 ×5 帧，AOM_Q（min=max=30）、cpu-used=8、单线程、
  lag_in_frames=0、tile rows/columns=0；码流与解码 I420 一起哈希

## 坑
- 交叉时 `CMAKE_CXX_COMPILER` 落在宿主 `/usr/bin/c++`（rvv-cross:1 没有 riscv g++），
  C 对象被宿主 ld 链接 → `Relocations in generic ELF (EM: 243)`。换 `rvv-cross:2` 解决。
- `aom_codec_decode()` 新签名是 4 参（无 `pad`），5 参会编不过。

## 结果
| 侧 | 输出 |
|---|---|
| riscv64 | `frames=5 bytes=2683 fnv_bit=d74bacb1c99a8c30 dec_frames=5 fnv_px=ab53811322a88564` |
| native | 同左 |

**全字段一致**。

## 复现
```bash
cd ~/work/libaom-rvv
./test/run_ab.sh && ./scripts/cross-baseline.sh
```
