---
layout: lesson
title: "Split-KV：把长上下文注意力摊到更多 SM"
slug: lesson-37-split-kv
lesson: 37
stage: "阶段一 · 看懂真实执行瓶颈"
stage_description: "从已经测过的 Legacy 8B 优化出发，建立 page、warp、TMA 与等待粒度的直觉。"
description: "从每个 KV head 一条任务扩展到 16 个 partition，再用稳定 LSE reduction 合并结果。"
takeaway: "长上下文慢，不一定是算得多，也可能是并行任务太少。"
image: /lesson37/legacy8b_split_kv_16x9.png
tags: [Attention, Split-KV, Reduction, GQA]
read_time: 11
status: "MEASURED · FULL MODEL-FORWARD"
prev_slug: lesson-36-page-ready
prev_title: "Page-ready：为什么 128 KiB 大门会让 Megakernel 空等？"
next_slug: lesson-38-dynamic-tail
next_title: "Dynamic Tail：最后 2048 维为什么不该让 16 个 warp 都工作？"
---

> **本课用词**：P1/P16 表示每个 KV head 被切成 1/16 个上下文 partition；partial 是一个 partition 的局部 attention 结果；GQA（Grouped-Query Attention）让多个 Q head 共享较少的 K/V head；LSE 是稳定 softmax 合并使用的 log-sum-exp。

## P1 为什么喂不饱 B200

Llama-8B 有 8 个 KV head。若每个 KV head 只创建一个 attention task，那么一层只有 8 条并行任务。B200 有 148 个 SM，大量执行容量在等待。

Split-KV 把每个 KV head 的上下文再切成 `P=16` 份：

- `8 × 16 = 128` 个 PartialAttention；
- 每个 partial 同时服务 GQA 对应的 4 个 Q head；
- 每个 KV head 再创建 1 个 AttentionReduction；
- attention 子图一层合计 136 个节点。

## 每个 partial 做什么

4K context 有 256 个 16-token KV block，因此每个 partition 处理 16 个 block；8K context 则是 512 个 block，每个 partition 处理 32 个。

每个 partial 输出两样东西：局部向量 `O_p` 与局部 log-sum-exp `L_p`。Reduction 不能简单平均，而要用稳定的 base-2 LSE 合并：

```text
M = max(L_a, L_b)
a = 2^(L_a - M)
b = 2^(L_b - M)
O = (a O_a + b O_b) / (a + b)
L = M + log2(a + b)
```

## 性能数字该怎样读

纯 Split-KV 的完整 32 层 model-forward + LM head：

- pos0：P1 `2.842 ms`；
- 4K：P1 `10.063 ms` → P16 `3.589 ms`；
- 8K：P1 `17.288 ms` → P16 `4.050 ms`。

`3.535 ms / 4.011 ms` 是后续再叠加 Dynamic Tail 的组合结果，不能全部归给 Split-KV。上述计时也不是 attention-only，更不是 HTTP serving wall。

## 一个漂亮的闭合证据

P16 相比 P1，每层净增 `128` 条 scheduler instruction；32 层净增 `4096` 条。完整任务数从 `22804` 变为 `26900`，差值恰好是 `32 × 128`。

这说明 profile 确实跑到了设计的 P16 DAG，而不是某个 fallback。

## 新手检查表

- 先数 task，不要只数 FLOP。
- Reduction 必须保留稳定 softmax 数值协议。
- 完整 megakernel 计时不能冒充 attention-only。
- 长上下文强 winner 不代表短上下文也该选 P16。
