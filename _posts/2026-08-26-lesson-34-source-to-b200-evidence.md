---
layout: lesson
title: "从源码到 B200 的四层证据链"
slug: source-to-b200-evidence
lesson: 34
stage: "进阶二 · 把依赖编译成可证伪系统"
stage_description: "把 barrier 转成 Ready 状态机，再用 poison、exact binary 和 manifest 闭合证据。"
description: "连接 Source、PTX、SASS、Runtime，并解释 JIT cache key 或 binary provenance 断链为何使结论失效。"
takeaway: "四层都有证据仍不够；它们必须属于同一个 exact CUBIN。"
beginner_question: "为什么源码、机器代码和运行结果必须来自同一次构建？"
beginner_analogy: "菜谱、出炉照片和品尝记录必须对应同一炉面包，否则证据无法互相证明。"
beginner_skip: "可先忽略 PTX、SASS 的指令细节和哈希算法。"
image: /lesson34/lesson-34.png
tags: [Provenance, PTX, SASS, Runtime]
read_time: 9
status: "PROVENANCE AUDIT · REAL CACHE GAP"
prev_slug: two-cta-litmus
prev_title: "双 CTA Poison Litmus"
next_slug: experiment-envelope
next_title: "实验档案袋：怎样保存一个可复核结论"
---

> **本课用词**：provenance 是工件来源链；JIT cache key 决定 binary 复用；source/PTX/SASS/runtime 是四个不同证据层。

这节课解决一个常见误区：

> “源码写对了”“程序跑绿了”，都不等于 GPU 协议已经被证明正确。

## 1. 四层证据分别证明什么

| 层 | 新手理解 | 能证明 | 不能证明 |
|---|---|---|---|
| Source | 人写的计划 | 希望执行的顺序、生命周期 | 编译器最终保留了什么 |
| PTX | NVIDIA 虚拟指令合同 | release/acquire、scope、TMA wait 的规范语义 | B200 最终使用什么机器指令 |
| SASS | exact cubin 的机器码 | 实际指令、控制流、寄存器和 spill | 所有可能的运行时交错 |
| Runtime | B200 现场录像 | 这批运行观察到了什么 | 错误永远不会发生 |

PTX 是一种虚拟 ISA，仍需继续翻译成目标 GPU 的机器码；`cuobjdump` 和 `nvdisasm` 才能反汇编 cubin 中的 SASS。[NVIDIA PTX ISA](https://docs.nvidia.com/cuda/parallel-thread-execution/)、[NVIDIA Binary Utilities](https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html)

## 2. canonical 当前的实际编译链

实时核验仍为 clean：

```text
verda-b200x4
/home/qinhaiyan/megakernel-canonical-20260811
HEAD = c473de3d5c90...
```

当前流程是：

```text
dispatcher.py 生成 CUDA source
        ↓
NVRTC 编译 sm_100a
        ↓
nvrtcGetCUBIN()
        ↓
内存中的 cubin bytes
        ↓
cuModuleLoadData()
        ↓
B200 执行
```

NVRTC 官方也明确区分 PTX 与 cubin；指定真实架构 `sm_100a` 时可以直接取得 cubin。[NVIDIA NVRTC](https://docs.nvidia.com/cuda/nvrtc/index.html)

但当前代码只调用 `nvrtcGetCUBIN`，没有调用 `nvrtcGetPTX`，所以 standalone cubin 里并不自动保存可供审计的 PTX。

## 3. 我们实际反汇编了一次当前 lowering

我用当前 clean c473 源码编译了一个最小 barrier probe，没有运行，只检查编译结果：

```text
arch:    sm_100a
size:    154,816 bytes
REG:     8
STACK:   0
SPILL:   0
CUBIN SHA256:
a622823a58184ce69324d5ecbb04f055dcb5ec6b8dcc61402f9b00a32a2b443c
```

源码中的 release：

```ptx
red.release.gpu.global.add.u32
```

在这份 exact cubin 中变成了：

```text
MEMBAR.ALL.GPU
ERRBAR
CGAERRBAR
REDG.E.ADD.STRONG.GPU
```

relaxed 轮询：

```ptx
ld.relaxed.gpu.global.u32
```

变成：

```text
LDG.E.STRONG.GPU
```

随后独立的 acquire fence：

```ptx
fence.acquire.gpu
```

变成：

```text
CCTL.IVALL
```

这给新手两个重要提醒：

1. 一个 PTX 操作可能下沉成多条 SASS。
2. SASS 出现 `STRONG.GPU`，不代表它就是 C++ 的 acquire；这里对应的 PTX 明明是 relaxed，真正的 acquire 是后面的 `CCTL.IVALL`。

所以不能只搜索一个助记符就宣布“内存协议正确”，必须检查整段控制流。

## 4. 当前发现的 JIT 缓存陷阱

当前缓存键实际只有：

```text
KEY =
Driver version
+ SM architecture
+ kernel symbols
+ generated source string
```

但没有包含：

```text
COMMON_NVRTC_FLAGS
NVRTC/compiler version
Git HEAD 与 dirty 状态
ThunderKittens revision
megakittens.cuh / utils.cuh / operator headers
CUDA headers
```

而生成的顶层 source 主要只是：

```cpp
#include "megakittens.cuh"
```

头文件内容本身不在 cache key 中。因此存在这种可能：

```text
header 已经修改
    ↓
顶层 generated source 没变
    ↓
cache key 没变
    ↓
加载旧 cubin
```

这不证明当前已经发生 stale-cubin；实时检查时缓存目录为空。但它说明现有缓存合同无法证明：

> “当前加载的 cubin 一定由眼前这份 headers、flags 和 compiler 生成。”

而 canonical 基线复现脚本又显式关闭了 JIT 文件缓存，所以历史测量使用的 exact cubin 目前也没有留在磁盘上。

## 5. 怎样闭合证据链

正确的 audit 模式应该同时保存：

```text
generated_source.cu
generated_source.sha256

kernel.ptx
kernel.cubin
kernel.cubin.sha256

kernel.sass
kernel.sass.sha256

compiler_flags.txt
compiler_log.txt
environment.json
result.json
```

然后遵循严格顺序：

```text
保存 cubin
   ↓
重新读取保存的 cubin
   ↓
把这一份加载到 GPU
   ↓
反汇编同一份文件
   ↓
result.json 记录同一个 cubin SHA
```

缓存键还要加入 flags、NVRTC 版本，以及 headers 的依赖闭包哈希或预处理后源码哈希。只加入 Git SHA 不够，因为 dirty header 仍可能被漏掉。

## 6. GOOD 与三个负控怎么验收

下面是下一步实验门，不是已经取得的结果：

| 版本 | 静态 SASS 要求 | 运行判定 |
|---|---|---|
| `GOOD` | TMA full-wait → READY release；READY acquire → payload load；全部读完 → ACK | 4 seeds × 100k epochs 必须全绿 |
| `READY_EARLY` | READY 明确位于 TMA 完成前 | 强制交错后 100/100 读到指定 poison |
| `NO_ACQUIRE` | payload load 前确实没有 acquire/fence | 出错可定罪；全绿仍是 `INCONCLUSIVE` |
| `ACK_EARLY` | ACK 位于部分 payload 读取前 | 强制覆盖后 100/100 出现 mixed epoch |

还有两条硬规则：

- mutation 源码不同，但 SASS 顺序没有改变：`MUTATION_NOT_REALIZED`，运行结果全部作废。
- 任意 Host timeout：说明 harness 或活性失败，不能冒充“负控成功”。

## 新手记忆法

```text
Source：施工图
PTX：法律合同
SASS：现场真正使用的机器
Runtime：有限长度的监控录像
```

监控录像没拍到事故，不代表施工一定合法；但故意拆掉护栏后，报警器必须能稳定响。

本课已经完成 current c473 barrier 的实际 cubin/SASS 审计；完整双 CTA litmus 仍未实现和实跑。下一课可以继续看一份完整的 artifact manifest：如何用一个 SHA 从错误结果一路追到 exact SASS。
