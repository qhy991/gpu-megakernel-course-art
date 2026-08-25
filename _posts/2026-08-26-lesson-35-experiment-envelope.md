---
layout: lesson
title: "实验档案袋：怎样保存一个可复核结论"
slug: experiment-envelope
lesson: 35
stage: "进阶二 · 把依赖编译成可证伪系统"
stage_description: "把 barrier 转成 Ready 状态机，再用 poison、exact binary 和 manifest 闭合证据。"
description: "把源码、编译参数、binary hash、正确性、profile 和计时装进统一 manifest。"
takeaway: "有 SHA 只证明文件身份；完整档案才能证明结论身份。"
image: /lesson35/lesson-35.png
tags: [Manifest, Reproducibility, Hash, Evidence]
read_time: 8
status: "EVIDENCE MANIFEST · WORKED EXAMPLE"
prev_slug: source-to-b200-evidence
prev_title: "从源码到 B200 的四层证据链"
next_slug: lesson-36-page-ready
next_title: "Page-ready：为什么 128 KiB 大门会让 Megakernel 空等？"
---

> **本课用词**：manifest 是结构化实验清单；hash 标识字节内容；environment 记录硬件和软件条件；verdict 是按预注册规则得到的判定。

Manifest 可以理解为实验的“档案袋目录”：

> JSON 是目录，cubin、SASS、日志才是物证，SHA-256 是物证指纹，verdict 是鉴定意见。

## 1. 为什么要拆成三张收据

```text
BUILD RECEIPT
源码 + Headers + Flags → exact CUBIN
            │ build_id
            ▼
RUN RECEIPT
exact CUBIN + GPU + Launch + 输入 → 原始结果
            │ run_id
            ▼
VERDICT RECEIPT
冻结的规则 + 原始结果 → 可以下什么结论
```

这样，同一个 cubin 可以运行多个 seed、上下文长度和负控，而不需要重复修改 Build 记录。

收据冻结以后不能原地修改。若改变样本数、容差或预期错误，必须产生新的 revision。

## 2. 当前真实 barrier probe 的档案

刚才生成的 probe 当前有：

```yaml
repository:
  head: c473de3d5c90...
  dirty: false
  thunderkittens: 0b55588d2769...

build:
  target: sm_100a
  cache: disabled

artifacts:
  source:
    size: 440
    sha256: fc415530...b24
  cubin:
    size: 154816
    sha256: a622823a...443c
  nvdisasm:
    sha256: 1ca03275...121

resources:
  registers: 8
  stack: 0
  spill_store: 0
  spill_load: 0

ptx:
  status: missing
  reason: "nvrtcGetPTX was not called"

runtime:
  status: not_run

evidence_scope: STATIC_ONLY
```

NVRTC 可以分别取得 PTX 与 cubin；当前工程只取了 cubin。[NVIDIA NVRTC](https://docs.nvidia.com/cuda/nvrtc/index.html)

我们用 `cuobjdump` 和 `nvdisasm` 读取的都是 SHA 为 `a622…443c` 的同一个 cubin。[NVIDIA Binary Utilities](https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html)

## 3. `STATIC_ONLY` 不是绿色 PASS

严格设计里至少要并列保存五本账：

| 状态 | 回答什么 |
|---|---|
| `artifact_integrity` | 文件 SHA 是否匹配 |
| `source_provenance` | 它来自哪份源码和工具链 |
| `static_verification` | SASS/CFG 是否满足静态要求 |
| `runtime_execution` | GPU 是否完整执行 |
| `test_expectation` | 结果是否符合冻结预期 |

当前 probe 更准确的状态是：

```yaml
artifact_integrity: PASS
source_provenance: PARTIAL
static_verification: PASS
runtime_execution: NOT_RUN
test_expectation: NOT_EVALUATED
scope: STATIC_ONLY
```

为什么来源还是 `PARTIAL`？因为编译时没有封存完整的传递 header 依赖闭包，也没有把 source→cubin 的关系写入不可变证明。当前 HEAD、clean 状态和 header SHA 是事后实时核验值，证据很强，但不是完整的密码学绑定。

因此它只能支持：

> “这份 exact cubin 中，barrier primitives 被下沉成了这些 SASS。”

不能支持：

- kernel 已在 B200 上运行；
- 两个 CTA 成功通信；
- 没有死锁；
- correctness 通过；
- 性能更快。

## 4. SHA 能与不能证明什么

SHA 能证明：

```text
现在拿到的文件
=
当时标记的那串字节
```

SHA 不能证明：

```text
文件是谁生成的
声明的编译命令是否真实
该 cubin 是否真的执行过
算法是否正确
性能是否更好
```

一句话：

> SHA 证明身份和完整性，不证明语义真实性。

## 5. 缺失值不能含糊处理

没有捕获 PTX 时，正确写法是：

```json
{
  "role": "ptx",
  "status": "missing",
  "path": null,
  "sha256": null,
  "missing_reason": {
    "code": "not_collected",
    "detail": "nvrtcGetPTX was not called"
  }
}
```

不能写：

```json
{"ptx_sha256": "e3b0..."}  // 这是空文件的SHA，不是PTX证据
```

同样：

- `mismatches: 0` 表示实际测量为零。
- `mismatches: null` 表示根本没测。
- 字段被省略则连“为什么没测”也不知道。

## 6. 机器失败，测试反而可能 PASS

负控最容易产生误解：

```yaml
variant: READY_EARLY
device_status: RECORD_MISMATCH
subject_outcome: EXPECTED_BUG_EXPOSED
test_verdict: PASS
```

这是因为测试目标本来就是故意拆掉 READY 护栏，检查报警器能否抓到指定 poison。

但如果观察到的是：

```yaml
device_status: CUDA_ILLEGAL_ADDRESS
```

即使 GPU 也“失败了”，它仍不是预期 poison 签名：

```yaml
subject_outcome: WRONG_FAILURE_MODE
test_verdict: FAIL
```

所以最终不能只保存一个模糊的 `status: PASS`。

## 新手记忆法

```text
Build：这是谁？
Run：它做了什么？
Verdict：根据哪条规则，允许说什么？
```

当前 `mk-evidence/v1` 是本课提出的加固格式，不是 c473 已有功能。下一课可以用这套档案袋重新阅读你最强的 page-pipeline 结果：为什么 `3.62 → 2.84 ms` 是可信的 Megakernel model-forward 证据，却还不能直接写成端到端 serving 加速。
