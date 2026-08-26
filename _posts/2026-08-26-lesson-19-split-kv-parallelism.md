---
layout: lesson
title: "Split-KV：把 8 个长任务拆成 128 个短任务"
slug: split-kv-parallelism
lesson: 19
stage: "基础四 · 三个真实优化机制"
stage_description: "用 Page-ready、Split-KV 和 Dynamic Tail 看懂等待、并行度与冗余工作。"
description: "解释长上下文 attention 的任务供给不足、16 路 partition 和稳定 partial reduction。"
takeaway: "Split-KV 用额外归并换取足够的 SM 并行任务。"
beginner_question: "为什么要把一个很长的注意力任务拆成许多小份？"
beginner_analogy: "像把几箱大货拆成许多小包，更多人能同时搬；搬完后再把结果汇总。"
beginner_skip: "可先忽略 GQA 分组和 partial reduction 的具体公式。"
image: /lesson19/lesson-19.png
tags: [Split-KV, Attention, GQA, Parallelism]
read_time: 14
status: "MEASURED · LEGACY DIRTY SOURCE"
prev_slug: page-granular-pipeline
prev_title: "把 128 KiB 大门拆成 8 个 Page-ready 小门"
next_slug: dynamic-tail
next_title: "Dynamic Tail：最后半块不做整块工作"
---

> **本课用词**：P16 表示每个 KV head 切成 16 个 partition；partial 是局部 attention；LSE 是稳定 softmax 合并所需的 log-sum-exp。

先给结论：这是你 Llama-8B Megakernel 中最强的单项机制之一。纯 Split-KV 把 4K/8K model-forward 分别改善约 `2.80×/4.27×`。但它当时还不是默认生成路径，严格数值稳定性也尚未完全封板。

## 为什么原来只有 8 个 attention 任务

Llama-3.1-8B 使用 GQA：

- 32 个 Query heads
- 8 个 KV heads
- 每个 KV head 被 4 个 Query heads 共享

你的 `PartialAttention` 指令以一个 KV head 为任务单位，同时计算对应的 4 个 Query heads。因此不切分 context 时：

```text
8 KV heads × 1 partition = 8 attention jobs / layer
```

context 从 128 增长到 8K，只会让这 8 个任务越来越长，并不会增加任务数。

而 B200 有 148 个 SM，你的 persistent grid 大约是 148 个 CTA、640 threads/CTA、1 CTA/SM。因此准确的判断是：

> attention 这一依赖波次只暴露 8 个长任务，无法喂饱 148 个常驻 worker。

这不等于“整个 kernel 始终只有 8 个 SM 工作”；图是并行度示意，不是完整时间线。

## 切成 16 份后发生了什么

调度器的结构是：

```text
for 8 KV heads:
    for 16 context partitions:
        create PartialAttention
```

因此每层得到：

```text
128 PartialAttention
+ 8 AttentionReduction
= 136 attention-side instructions
```

P1 原本有 8 个 partial、没有 reduction，所以净增加：

```text
136 - 8 = 128 instructions/layer
32 layers × 128 = 4096 instructions
```

实测全模型指令数也正好从 `22,804` 增至 `26,900`，差值就是 `4096`。这是非常漂亮的源码—运行时闭合证据。

KV block 是 16 tokens：

| Context | 总 KV blocks | P16 后每个 partial |
|---:|---:|---:|
| 4096 | 256 | 16 blocks，即 256 tokens |
| 8192 | 512 | 32 blocks，即 512 tokens |

128 个 partial jobs 已经接近 B200 的 148 个 SM，显著缓解了 grid starvation。

## 为什么 16 份结果不能直接平均

每个 partition 计算自己的局部 softmax，并保存：

```text
(LSEp, Op)
```

其中 `LSEp` 表示该分区的 softmax 总质量，`Op` 是局部归一化后的输出。

合并时：

\[
w_p=\exp(LSE_p-\max_q LSE_q)
\]

\[
O=\frac{\sum_p w_pO_p}{\sum_p w_p}
\]

所以分数更强的 partition 权重更大。减去最大 LSE 还能防止指数溢出。源码采用等价的 `exp2/log2` 表示。

一句话理解：

> 16 名分段阅卷员的结论不能简单取平均；看到更多高分证据的那一段必须拥有更大权重。

数学上可以正确合并，但浮点加法顺序变化会改变舍入结果，因此通常不会 bitwise identical。

## 性能数字必须拆开归因

| B=1 decode | 单分区 P1 | 纯 Split-KV P16 | P16 + Dynamic Tail |
|---:|---:|---:|---:|
| 4K | 10.063 ms | 3.589 ms，`2.8038×` | 3.535 ms，`2.8467×` |
| 8K | 17.288 ms | 4.050 ms，`4.2686×` | 4.011 ms，`4.3101×` |

因此需要修正上一课预告中的简写：

- `10.063→3.589 ms`、`17.288→4.050 ms` 才是纯 Split-KV。
- `3.535/4.011 ms` 还包含 DownProj Dynamic Tail。
- 不能把组合结果全部归因于 Split-KV。

为什么 8K 收益比 4K 更大？因为单分区任务随 context 变长，而 online-softmax reduction 的固定税主要取决于 partition 数、head 数和 head dimension，长 context 更容易摊薄这部分税。

为什么不是 16×？模型还有 QKV、O projection、MLP、LM head；此外还增加了 partial workspace、barrier 和 reduction。

## 为什么 partition 不是越多越好

实测策略是：

| 总序列长度 | Partitions |
|---:|---:|
| `<256` | 1 |
| `256–511` | 4 |
| `512–1024` | 8 |
| `>1024` | 16 |

部分 sweep：

- 4K：P16 `3.589 ms`，P8 `3.901 ms`
- 8K：P16 `4.050 ms`，P8 `4.801 ms`
- 1K：P8 `3.222 ms`，P16 `3.258 ms`
- 256：P4 最优，记录值 `3.041 ms`

短序列切得太碎，设置、TMA、partial 写回、barrier 和 reduction 的成本会超过并行收益。

但这里有一个重要集成缺口：

> `pick_num_attention_partitions()` 虽然实现了这条策略，默认 `LatencyScheduleBuilder` 和 generator 当时仍构建 P1 schedule；自动策略只在测试和 profile harness 中接通。

generator 会预先构建一次指令表，之后每个 token 只更新 `pos_id`，不会自动把 P1 schedule 换成 P4/P8/P16。比较合理的生产方案是预构建四套 schedule，依据 host 已知的 context bucket 零同步派发。

## 这项工作的证据等级

| 方面 | 判断 |
|---|---|
| 任务图机制 | 强：源码循环、任务数和总指令数精确闭合 |
| 内部性能 | 强：4K/8K 大幅收益，远超测量抖动 |
| 数值正确性 | 尚未封板 |
| 默认集成 | 未完成，强结果来自显式 harness |
| Serving 领先 | 未成立 |

正确性方面：

- 真实 tokenizer prefix、非零 BF16 KV 下，4K/8K 都达到 Top-1 `16/16`。
- 首轮最低 logits cosine 为 `0.999796/0.999706`。
- 后续 8K 复验曾出现 `0.997721`，低于预设的 `0.999` 严格门槛。
- 因此可以说 Top-1 在这些样本上稳定，但不能说严格数值正确性或 bitwise equivalence 已完成。

性能计时则主要是 zero-KV context-length probe 下的 32 层加 LM head CUDA model-forward；真实 KV 用于独立正确性实验。没有 attention-only timer，也不包含 tokenizer、sampling、请求排队或网络。

后来的公平审计显示：

- 4K：Megakernel 窄 model-forward 约 `282.1 tok/s`，SGLang 约 `282.0`，方向上接近持平。
- 8K：Megakernel `250.5`，SGLang `272.8`，约慢 `8.2%`。
- 两者计时边界仍不同，所以不能直接宣布端到端胜负，但足以否定“整体领先成熟系统已经成立”。

## 我认为最应优先补的三件事

1. 将 P1/P4/P8/P16 schedule portfolio 真正接入 generator，并测试 `255/256`、`511/512`、`1024/1025` 边界。

2. 修复并形式化 partial publication：历史源码在 global store 后发布 atomic counter，但显式 GPU release fence 被注释；reducer 轮询后直接 TMA 读取。这是潜在可见性风险，不是已确认 bug，应迁移 canonical release/acquire 协议。

3. 冻结 clean commit、dirty patch、构建命令、DSO SHA 和原始 P1/P16 paired samples，再补严格 logits/hidden error 与长重复测试。

## 与原始三个概念的关系

- Megakernel 是容器：Split-KV 改写容器内部的 attention DAG。
- Persistent kernel 提供常驻工人：Split-KV 给这些工人制造足够多的独立任务。
- MPS 管多进程共享：它不会自动把一个进程中的 8 个任务切成 128 个。
- 这也不是 Tensor Parallel：没有跨 GPU KV 分片或 NCCL，全部发生在单张 B200、同一 KV cache 内。

一句话记忆：

> Persistent kernel 解决“工人是否常驻”，Split-KV 解决“常驻工人有没有足够多的活”。

原始结果见 历史 REPORT 回执，任务图见 调度源码回执，默认生成路径见 generator 回执，本地摘要见 Research OS 日结。

下一课：Dynamic Tail——为什么 DownProj 最后的 2048 列，不该让 16 个 warps 假装处理完整的 4096 列。
