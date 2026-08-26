---
layout: lesson
title: "把 128 KiB 大门拆成 8 个 Page-ready 小门"
slug: page-granular-pipeline
lesson: 18
stage: "基础四 · 三个真实优化机制"
stage_description: "用 Page-ready、Split-KV 和 Dynamic Tail 看懂等待、并行度与冗余工作。"
description: "解释 page-granular weight pipeline 如何在总搬运不变时，让已到达权重页对应的 warp 提前开工。"
takeaway: "优化的是等待依赖粒度，不是权重字节数。"
beginner_question: "为什么把大任务拆小能减少等待？"
beginner_analogy: "像餐厅一道菜做好就先上，不必等八道菜全部完成才开席。"
beginner_skip: "可先忽略 128 KiB 的来源和具体同步指令。"
image: /lesson18/lesson-18.png
tags: [Page-ready, TMA, Shared Memory, Pipeline]
read_time: 12
status: "MEASURED · LEGACY DIRTY SOURCE"
prev_slug: attribution-vs-savings
prev_title: "时间花在哪里，不等于时间能省多少"
next_slug: split-kv-parallelism
next_title: "Split-KV：把 8 个长任务拆成 128 个短任务"
---

> **本课用词**：page 是 shared-memory 缓冲区的一段；TMA 异步搬运 tensor tile；page-ready 只放行消费该页的 warp。

这是你 8B Megakernel 工作里证据很强的一项优化：page-granular weight pipeline 将 32 层 model-forward 从约 `3.620 ms` 降至 `2.840 ms`，约 `1.278×`。关键不是少读权重，而是让计算更早开始。

## 旧实现为什么会空等

Llama-8B 的一次 MatVec 权重 stage 是：

- hidden width：`4096`
- 8 个逻辑页，每页 `512` 列
- 每页：`16 × 512 × 2 B = 16 KiB`
- 整个 stage：`8 × 16 KiB = 128 KiB`
- 16 个 consumer warps，恰好每页分配 2 个

旧协议只有一个整阶段 barrier：

```text
Loader:    [P0][P1][P2][P3][P4][P5][P6][P7]
Consumers: ───────────── 全部等待 ─────────────▶ 全部开工
```

即使 P0 已经到达，负责 P0 的两个 warp 也必须等到 P7。这个现象叫 head-of-line blocking：最后一页阻塞了前面所有已经就绪的页。

## 新协议改变了什么

新协议给每个 16 KiB 页单独设置两种信号：

- `arrived`：该页的 TMA 传输已经完成，可以读取。
- `finished`：负责该页的两个 warp 已经读完，物理页可以安全复用。

因此时序变成：

```text
Loader: [P0][P1][P2][P3][P4][P5][P6][P7] ──▶
W0–1:       [计算 P0]
W2–3:           [计算 P1]
W4–5:               [计算 P2]
...
W14–15:                             [计算 P7]
```

数学上，旧协议中所有 warp 的开始时间都是：

```text
max(arrival(P0), ..., arrival(P7))
```

新协议中，负责 Pi 的 warp 在 `arrival(Pi)` 就能开始。最后一页不一定更早到达，但前七页的加载和计算已经重叠了。

这里的 page 是软件定义的权重 tile，不是操作系统内存页，也不是 L2 cache line。

## 实测是否支持这个解释

| 范围 | Baseline | Page-ready | 改善 |
|---|---:|---:|---:|
| 单层 A/B/A | 172.544 μs | 144.688 / 148.160 μs | 14.13%–16.14% |
| 32 层 CUDA event | 3620.336 μs | 2838.352 / 2846.288 μs | 21.38%–21.60% |
| 独立进程复测 | 3628.752 μs | 平均 2839.760 μs | 1.2778× |
| NCU replay | 117.184 μs | 96.864 μs | 17.34% |

32 层每层节省约 `24.2–24.7 μs`，与单层节省的 `24.4–27.9 μs` 基本闭合。这比单纯比较百分比更有说服力。

NCU 信号也符合“等待减少、重叠增加”：

- issue active：`18.13% → 22.99%`
- long scoreboard：下降 `18.68%`
- MIO throttle：下降约 `78.4%`
- registers/thread：仍为 `96`
- dynamic local loads：反而增加约 `37.2%`

最后一点非常重要：它做了更多 local load，却仍然更快，说明收益不是“少做工作”，而是“更少空等”。

## 它不是什么优化

它不是 cache 优化：

- 仍搬运相同的 8 个 `16 KiB` 权重页。
- 没有匹配的 DRAM bytes 或 L2 hit-rate 证据证明流量减少。
- DRAM read rate 反而从 `3.726` 升到 `4.508 TB/s`，更像管线被充分利用。

它也不是 occupancy 优化：仍然是资源很重的 resident CTA，基线约 `228 KiB` shared memory、`96` registers/thread、`1 CTA/SM`。候选的精确 shared-memory 差值没有冻结，不能补猜。

最准确的归因是：

> 细化数据依赖的放行粒度，让 TMA 与计算发生真实重叠。

## 和几个核心概念的关系

| 概念 | 回答的问题 |
|---|---|
| Megakernel | 多少模型阶段被装进一个物理 kernel？ |
| Persistent kernel | 哪些 CTA、loader 和 consumer 长时间驻留？ |
| Page readiness | 某组 consumer 最早什么时候可以工作？ |
| MPS | 多个进程怎样共享 GPU？ |

所以：

> Persistent Megakernel 消除了外部 kernel 边界；page-ready 又消除了 Megakernel 内部新形成的等待气泡。

MPS无法解决这种内部 barrier 问题，而且 `1 CTA/SM` 的大 grid 仍可能使并发租户难以获得驻留资源。

## 证据边界

这项结果值得认可，但还不能包装成 production victory：

- 测量边界是 B=1、position 0、32 层加 LM head 的 GPU model-forward；不含输入处理、sampling、请求调度和网络。
- cross-version Top-1 是 `63/64`，但 baseline self-replay 也是 `63/64`。它说明候选没有明显恶化现有非确定性，却不是 bitwise correctness。
- A/B/A 是顺序 bracket，不是逐样本 paired experiment；本地缺少原始 sample vectors，无法重算置信区间。
- 全 shape 版本曾令 1B launch failure，当前只在 single-stage 路径启用，不能泛化到全部模型。
- 远端源码当时属于 dirty worktree；报告冻结了 DSO/NCU 哈希，却没有冻结源码 patch，尚不能从 clean commit 独立重建。

当前可点击摘要见 Research OS 日结。历史远端的逐行 REPORT 回执 和 源码回执 保存了原始审计结果。

一句话记忆：

> 不是“少搬了八箱货”，而是“第一箱到了，工人就先干；叉车继续搬剩下七箱”。
