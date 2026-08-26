---
layout: lesson
title: "Megakernel 怎样连续生成 Token"
slug: persistent-across-tokens
lesson: 9
stage: "基础二 · 从源码走进 Persistent Megakernel"
stage_description: "沿源码、队列与一枚 token 的生命周期理解设备端执行控制。"
description: "区分层内 CTA 常驻、每 token 一次 whole-model kernel 与跨 token 不退出的 decode engine，并说明 MPS 的位置。"
takeaway: "Persistent 描述生命周期；是否跨 token 常驻必须单独说明。"
beginner_question: "常驻 GPU 的程序怎样连续处理多个 token？"
beginner_analogy: "像值夜班工人留在工位，订单来了就接着做，不必每次重新报到。"
beginner_skip: "可先忽略跨 token 队列的内存一致性细节。"
image: /lesson09/lesson-09.png
tags: [Persistent Kernel, Decode, MPS, Lifetime]
read_time: 13
status: "SOURCE-AUDITED · LIFETIME MODEL"
prev_slug: llama-layer-dataflow
prev_title: "一层 Llama 在 Megakernel 里怎样流动"
next_slug: performance-ledger
next_title: "建立 Megakernel 性能账本"
---

> **本课用词**：per-token persistent 表示每个 token 重新 launch，但 CTA 在该次 forward 内常驻；cross-token engine 一次启动后处理多轮；MPS 是多进程 GPU 共享机制。

先给结论：

> 你 8 月的核心实现属于“每次 forward 内常驻”的 Megakernel。B=1 decode 时，一次 forward 对应一个新 token，但生成下一个 token 前，kernel 已经退出，Host 会再次启动它。

它不是“一次启动后永远不退出”的跨-token persistent engine。

---

## 1. 大模型生成分成两个阶段

假设用户输入：

```text
“今天天气”
```

## 第一阶段：Prefill

GPU 一次处理全部输入 token：

```text
“今天” “天气” ...
```

并把每层的 K/V 写进 KV Cache。

Prefill 的特点是：

- 同时处理多个 token；
- 更像矩阵乘矩阵；
- 并行度通常较高；
- 与 B=1 decode 的性能形态不同。

你的 8B Megakernel 主要针对第二阶段。

## 第二阶段：Decode

之后每次只生成一个 token：

```mermaid
flowchart LR
    P["Prompt Prefill"] --> K["建立 KV Cache"]
    K --> D0["Decode token 0"]
    D0 --> S0["选出 token 0"]
    S0 --> D1["Decode token 1"]
    D1 --> S1["选出 token 1"]
    S1 --> D2["Decode token 2"]
    D2 --> More["……"]
```

因为下一个 token 依赖上一个 token 的结果，所以无法提前同时计算：

```text
token 1 → token 2 → token 3
```

这也是 decode 延迟特别重要的原因。

---

## 2. 一次 token step 包含什么

一个完整 token step 通常是：

```text
上一个 token id
    ↓
Embedding
    ↓
32 层 Transformer
    ↓
Final RMSNorm
    ↓
LM Head
    ↓
Logits
    ↓
Sampling / Argmax
    ↓
新 token id
```

然后：

```text
position += 1
KV Cache 增加一格
再次执行下一轮
```

---

## 3. 你的两条实现，边界并不完全相同

## Hazy/KVM 风格

历史生成循环大致是：

```python
for each token:
    hidden = embedding(token_id)
    reset_barriers()
    update_position()

    launch_megakernel(
        32 transformer layers,
        final_norm,
        lm_head
    )

    token_id = argmax(logits)
    check_eos()
```

所以 kernel 外还有：

- Embedding；
- barrier reset；
- position 更新；
- argmax；
- EOS 检查；
- token 输出。

这里一次 token 仍需要一次 Megakernel launch。

## 你的 oMoE whole-forward cooperative 版本

后来的版本扩大了物理边界：

```text
单次 cooperative kernel:
    Embedding
    → 所有 Transformer 层
    → Final Norm
    → LM Head
    → Greedy Argmax
```

它比 KVM 版本覆盖得更完整。

但 Host 代码依然是：

```text
cudaLaunchCooperativeKernel(...)
cudaStreamSynchronize(...)
return
```

下一个 forward 还会重新启动一次。因此它仍然是：

> per-forward resident whole-model Megakernel

当 batch=1、一次 forward 只处理一个 decode token 时，也可以叫：

> per-token resident Megakernel

---

## 4. 三种架构放在时间线上比较

## CUDA Graph

```text
token 0: replay [kernel 1][kernel 2]...[kernel N]
token 1: replay [kernel 1][kernel 2]...[kernel N]
token 2: replay [kernel 1][kernel 2]...[kernel N]
```

Graph 降低 Host launch 开销，但 GPU 里仍有很多物理 kernel。

## 你的 per-token Megakernel

```text
token 0: launch [一个 kernel 内完成全部层] exit
token 1: launch [一个 kernel 内完成全部层] exit
token 2: launch [一个 kernel 内完成全部层] exit
```

CTA 在一次 forward 的整个过程中保持驻留，并在内部执行很多任务。

## 真正跨-token persistent engine

```text
launch once
    └─ token 0
       └─ sample
          └─ token 1
             └─ sample
                └─ token 2
                   └─ ...
```

它的 kernel 可能几秒甚至几分钟都不退出。

---

## 5. 为什么你的实现也叫 persistent

“Persistent kernel”里的 persistent 不一定表示：

```text
永远不退出
```

更常见的含义是：

```text
CTA 不做完一个 tile 就退出
CTA 保持驻留
CTA 连续领取和执行很多任务
```

你的 worker CTA 会在一次 launch 内执行：

```text
Layer 0 QKV
Layer 0 Attention
Layer 0 MLP
Layer 1 QKV
...
Layer 31 MLP
LM Head
```

所以执行方式是 persistent 的。

但它只在一次 forward 内 persistent，不跨 token persistent。

可以把它想成工厂：

- CUDA Graph：每道工序都换一批工人，但调度流程已经录好。
- 你的 Megakernel：同一批工人完成一件产品的所有工序，完成后下班。
- 跨-token engine：工人一直不下班，连续生产很多产品。

---

## 6. 跨-token engine 不是简单加一个 `while`

看起来似乎只要这样：

```cpp
__global__ void persistent_decode_engine(...) {
    while (true) {
        embedding();
        run_32_layers();
        lm_head();
        sample();
        position++;
    }
}
```

但真实服务还必须解决：

## Sampling

不仅是 argmax，还可能有：

```text
temperature
top-k
top-p
随机数状态
重复惩罚
词表约束
```

## 停止条件

```text
EOS
最大 token 数
stop string
用户取消
超时
```

## 多请求

服务器通常同时处理很多用户：

```text
请求 A 正在生成第 20 个 token
请求 B 刚完成 prefill
请求 C 已被取消
请求 D 的 KV Cache 需要分配
```

## 动态调度

请求会不断加入和退出，batch 形状会变化：

```text
时刻 0：A B C
时刻 1：A B C D
时刻 2：A C D
```

而你的 Megakernel 调度和 tensor shape 大多是在启动前确定的。

## KV Cache 管理

还需要：

- page 分配；
- page 回收；
- prefix cache；
- 请求间隔离；
- context 超限处理；
- 多 GPU KV 搬运。

因此跨-token persistent engine 实际上不再只是一个“大 kernel”，而是一个小型的 GPU 操作系统。

---

## 7. MPS 在这里扮演什么角色

MPS 管的是：

> 多个进程怎样共享一张 GPU。

它不会增加 SM、寄存器或 shared memory。

如果你的 Megakernel 启动约 148 个 CTA，并且每个 CTA 因线程数、shared memory、TMEM 等资源只能做到每 SM 驻留一个，那么在它执行的几毫秒内：

```text
Megakernel 占据几乎全部 SM
```

即使打开 MPS，另一个进程也可能没有资源让自己的 CTA 驻留。

可以把 MPS 想成公寓管理员：

- MPS 可以允许两个租客使用同一栋楼；
- 但如果租客 A 已经占满所有房间；
- 管理员不能凭空创造新房间。

## Legacy 实现还有一个更严格的问题

你早期 VM 用物理 `%smid` 决定 worker queue：

```text
当前 CTA 落在 SM 17
→ 读取 queue 17
```

这隐含假设：

```text
148 个 CTA 恰好同时运行
并且恰好一 CTA 对应一个物理 SM
```

MPS 并不保证这种映射。

如果其他进程占用资源，可能出现：

- 某个 SM 的 queue 被重复执行；
- 某个 queue 没有 worker；
- event 永远等不到；
- kernel 卡住或结果错误。

后来的 canonical controller 改用：

```text
blockIdx.x → queue id
```

这样不再依赖物理 SM 编号，解决了正确性层面的 MPS 风险。

但资源占满造成的性能争用仍然存在。

---

## 8. 现在可以精确命名你的几条工作

| 工作 | 准确名称 |
|---|---|
| Qwen Q/K Norm + RoPE | 每层 micro-fusion |
| CUDA Graph 中替换 SwiGLU | Graph 内算子优化 |
| B16 cooperative whole-forward | per-forward resident whole-model Megakernel |
| B1 8B GPU-VM | per-token whole-model persistent Megakernel |
| 尚未实现 | 跨-token persistent decode/serving engine |

最重要的是：

```text
Megakernel     描述物理执行边界
Persistent     描述 CTA 生命周期与取任务方式
Cross-token    描述是否跨越多次生成迭代
MPS            描述多个进程如何共享 GPU
```

这四个维度不能混成一个概念。

## 新手自测

1. 一个 kernel 包含 32 层，就一定跨 token 吗？  
   **不一定。它可能处理完一个 token 就退出。**

2. CUDA Graph 是一个 Megakernel 吗？  
   **不是。Graph 内通常仍有很多物理 kernel。**

3. 打开 MPS 就能让两个满占 SM 的 Megakernel 高效并发吗？  
   **不能。MPS 不会创造额外硬件资源。**

4. 你的 8B VM 为什么可以叫 persistent？  
   **因为 CTA 在一次 launch 内保持驻留并连续执行很多 tile instruction。**
