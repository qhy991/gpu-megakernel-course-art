---
layout: lesson
title: "一层 Llama 在 Megakernel 里怎样流动"
slug: llama-layer-dataflow
lesson: 8
stage: "基础二 · 从源码走进 Persistent Megakernel"
stage_description: "沿源码、队列与一枚 token 的生命周期理解设备端执行控制。"
description: "把玩具队列映射到真实 Llama 层，区分片上直通、跨 CTA 发布和必须落全局内存的边。"
takeaway: "融合边界应跟随数据所有权，而不是跟随算子名字。"
image: /lesson08/lesson-08.png
tags: [Llama, Dataflow, Ownership, CTA]
read_time: 12
status: "SOURCE-AUDITED · CANONICAL + LEGACY"
prev_slug: build-minimal-megakernel
prev_title: "亲手搭一个最小 Megakernel"
next_slug: persistent-across-tokens
next_title: "Megakernel 怎样连续生成 Token"
---

> **本课用词**：片上直通表示 producer 与 consumer 在可共享的 register/shared 作用域内交接；跨 CTA 发布需要可见性协议；seam 是候选切分边界。

先学会读图：

- 绿色：数据留在寄存器、TMEM 或 shared memory，直接交给下一步。
- 橙色：任务跨 CTA，需要 event 和 release/acquire。
- 蓝色：访问 HBM、权重或需要跨 token 保存的 KV Cache。
- CTA 0～3：只是四个示例 worker；真实 B200 上大约有 148 个 resident CTA。
- 每个 CTA 只负责一部分 tile，不是每个 CTA 都独立计算完整模型层。

## 1. 输入：一个 token 的隐藏向量

以你的 Llama 8B 实验为例，一层的输入大约是：

```text
hidden size = 4096
dtype       = BF16
数据量       = 4096 × 2 bytes ≈ 8 KiB
```

这 8 KiB 激活看起来很小，但每一层都要读取巨大的权重矩阵。

所以 B=1 decode 的特点是：

> 激活很小，权重很大；GPU 经常在等待权重，而不是没有算力。

---

## 2. RMSNorm → QKV Projection

第一步先归一化隐藏向量，再计算：

```text
Q = x_norm × Wq
K = x_norm × Wk
V = x_norm × Wv
```

Llama 8B 的大致形状是：

```text
Q heads  = 32
KV heads = 8
head dim = 128
```

因此：

```text
Q：32 × 128 = 4096
K： 8 × 128 = 1024
V： 8 × 128 = 1024
```

QKV 合计产生 6144 个 BF16 元素。

这里真正昂贵的是加载 `Wq/Wk/Wv`。你的 page-granular pipeline 把权重切成约 16 KiB 的 page：

```text
旧方式：
等完整阶段的权重到齐 → 开始计算

页级方式：
page 0 到达 → 负责它的 warp 立刻计算
page 1 到达 → 另一组 warp 继续计算
……
```

这就是你单层获得约 14%～16%、32 层整体约 21.7% 内部改进的来源：不是减少数学运算，而是减少等待。

---

## 3. RoPE 与 KV Append

RoPE 给 Q、K 加上位置信息：

```text
Q_rotated = RoPE(Q, position)
K_rotated = RoPE(K, position)
```

然后：

- Q 只服务当前 token；
- K、V 还要被未来所有 token 使用。

因此 K/V 不可能永远只留在 shared memory：

```text
K、V → 写入持久化 KV Cache
```

KV Cache 是模型跨 token 的记忆，所以最终必须进入全局显存。

一个容易混淆的模型差异：

- Llama 3.1：QKV 后直接做 RoPE，没有 Q/K RMSNorm。
- Qwen3：Q、K 还各有一次 RMSNorm，然后才做 RoPE。

你 7 月的 Qwen 工作只融合了：

```text
Q/K RMSNorm + RoPE
```

而不是整层 Megakernel。

---

## 4. Attention：为什么需要 Split-KV

Attention 可以简化为：

```text
scores = Q × K_cache
prob   = softmax(scores)
output = prob × V_cache
```

Llama 8B 只有 8 个 KV heads。如果一个 KV head 只产生一个任务：

```text
8 个任务 → 喂给 148 个 SM
```

大量 SM 没有足够工作。

Split-KV 把上下文长度切开：

```text
KV head 0:
    context part 0
    context part 1
    ...
    context part 15
```

于是大约变成：

```text
8 KV heads × 16 partitions = 128 个 partial-attention 任务
```

这就接近 B200 的 148 个 SM。

每个任务算出局部结果：

```text
partial output
partial max
partial softmax sum
```

最后再做一次 online-softmax reduction。

这解释了为什么你的 Split-KV 在长上下文上非常有效：

- 4K 上下文：内部约 2.85×；
- 8K 上下文：内部约 4.31×。

它解决的不是 launch overhead，而是并行度不足。

---

## 5. O Projection + Residual

Attention 输出经过 O projection：

```text
attn_projected = attention_output × Wo
x_after_attn   = residual + attn_projected
```

当 attention 被拆成多个 partition 时，边界会变复杂：

```text
多个 Attention CTA
        ↓
合并 partial results
        ↓
O Projection CTA
```

这是典型的橙色边：

- 数据来自不同 CTA；
- 消费者必须确认所有必要分片已经完成；
- 需要正确的 release/acquire；
- 过粗的全局 barrier 会让所有 CTA 一起等待。

---

## 6. Gate/Up → SwiGLU：最理想的片上边

MLP 前半部分计算两个投影：

```text
gate = x × W_gate
up   = x × W_up

silu_out = SiLU(gate) × up
```

Llama 8B 的中间维度约为 14336。

这是一个非常适合真正融合的边，因为同一个输出 tile 同时需要：

```text
gate tile
up tile
```

理想路径是：

```text
Gate/Up accumulator
        ↓
寄存器或 TMEM
        ↓
SiLU(gate) × up
        ↓
只保存最终结果
```

而不是：

```text
Gate 写 HBM
Up 写 HBM
SwiGLU 再读两遍 HBM
```

因此图中特别把它标为绿色。

这也是为什么“同 CTA ownership”很重要：生产者和消费者必须对同一个 tile 负责，否则仍要通过全局 workspace 交接。

---

## 7. Down Projection + Residual：最难的边

Down projection 把 14336 维压回 4096 维：

```text
down = silu_out × W_down
x_next = x_after_attn + down
```

困难在于一个输出元素通常来自很多输入分片的累加：

```text
partial 0 ┐
partial 1 ├→ reduce → residual add
partial 2 ┤
partial 3 ┘
```

这些 partial 可能由不同 CTA 产生。

而下一层 RMSNorm 又需要完整的 4096 维向量：

```text
所有 Down partial 完成
        ↓
确定性 reduction
        ↓
Residual Add
        ↓
下一层 RMSNorm
```

所以这是最难消除的跨 CTA 边界。

你过去的实验也证明了：

- 仅删除 residual workspace，不一定变快；
- 把同步细化成大量 tile tag，也可能因为检查成本而变慢；
- 必须把输出所有权、reduction 顺序和下一层 Norm 一起设计。

---

## 真实实现中的 7 类指令

你历史 Llama Megakernel 的应用层 opcode 大致是：

| Opcode | 指令内容 |
|---:|---|
| 1 | RMSNorm + QKV MatVec + RoPE + KV Append |
| 2 | Partial Attention |
| 3 | Attention Reduction |
| 4 | O Projection + Residual |
| 5 | RMSNorm + Gate/Up + SiLU |
| 6 | Down Projection + Residual |
| 7 | Final RMSNorm + LM Head |

图中把部分步骤拆开，是为了帮助理解数据流；代码里 opcode 1 实际已经把前几个逻辑步骤合在一个 instruction body 中。

但这里要分清两层“指令”：

```text
应用层 instruction：
    RMSNorm_QKV_RoPE_Append

硬件指令：
    ld、st、mma、barrier、atomic……
```

一个应用层 instruction 内部仍包含大量真正的 GPU 指令。

---

## 为什么“在同一个 kernel 里”仍可能很慢

即使七类 opcode 都放进同一个物理 kernel，数据仍可能这样走：

```text
Opcode A
→ 写 global workspace
→ atomic 通知
→ Opcode B 等待
→ 从 global workspace 重读
```

这只是控制面融合，还没有实现真正的数据流融合。

更理想的是：

```text
Opcode A
→ register/TMEM/shared page
→ 同一 owner 立即执行 Opcode B
```

所以你的研究结果可以用一句话概括：

> Megakernel 的价值不来自“kernel 数量变成 1”，而来自让正确的数据，在正确的时间，直接到达正确的 CTA/warp。

四项代表性结果也分别对应四种原因：

| 实验 | 真正解决的问题 |
|---|---|
| Q/K Norm + RoPE 微融合 | 减少少量小算子边界 |
| Split-KV | 增加长上下文并行任务 |
| Page-granular pipeline | 权重一页到达就开始算 |
| Gate/Up → SwiGLU handoff | 让生产者与消费者共享片上数据 |

你可以把整个系统记成一个工厂：

```text
Controller      = 调度员
Instruction     = 工单
CTA             = 工人小组
Shared page     = 小组工作台
Event/semaphore = 交接签收单
HBM             = 大仓库
KV Cache        = 跨 token 保存的档案库
```
