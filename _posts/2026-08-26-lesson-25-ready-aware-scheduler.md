---
layout: lesson
title: "Role-fluid 还不够，必须 Ready-aware"
slug: ready-aware-scheduler
lesson: 25
stage: "进阶一 · 正确性、生命周期与调度"
stage_description: "处理 release/acquire、epoch、驻留死锁和 Ready-aware 调度。"
description: "比较固定 per-SM 队列、阶段闭包与 ready queue，设计能在少量驻留 CTA 下持续推进的调度器。"
takeaway: "Worker 可以换角色仍不够；只有依赖闭合的任务才能占用驻留槽。"
image: /lesson25/lesson-25.png
tags: [Ready-aware, Scheduler, Queue, Role-fluid]
read_time: 10
status: "SCHEDULER PROPOSAL · UNMEASURED"
prev_slug: capacity-wait-for-graph
prev_title: "先算能住多少，再画谁等谁"
next_slug: partial-attention-readygroup
next_title: "一个 Partial Attention 到底在等什么？"
---

> **本课用词**：role-fluid 允许 worker 执行不同任务类型；ready-aware 只公开依赖已满足的任务；queue contention 是并发抢队列的成本。

核心结论：

> “任何 CTA 都能执行任何 opcode”解决的是谁来做；“只领取依赖已经满足的任务”解决的是能不能继续前进。

这里的 role-fluid 指 CTA 级别：每个 CTA 都包含 controller、loader、launcher、storer和8个consumer warp，因此可以执行不同 opcode；CTA 内部这些 warp 的角色仍然固定。

## 三种调度器的区别

| 调度方式 | 怎样取任务 | 部分驻留安全吗 |
|---|---|---|
| Legacy 固定队列 | 每个 CTA 永久拥有一列任务 | 否。owner 未驻留，producer 就不执行 |
| Canonical CLC | 任意 CTA/cluster 窃取一个尚未启动的 block index | 仍未证明。`pending` 不等于 `ready` |
| ReadyGroup 提案 | 任意 CTA 只领取依赖已经满足的 packet | 满足不变量后，可以证明任意 `K≥1` 前进 |

Canonical 的 global 模式不是软件 `atomicAdd(next)` 队列。它使用 Blackwell CLC 取消一个尚未启动的 block/cluster，并取得其索引。CLC 很适合负载均衡，但官方没有承诺返回顺序或检查任务的模型依赖。[NVIDIA CLC 文档](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cluster-launch-control.html)

当前 controller 是：

```text
CLC 取得 pending index
→ 复制对应 instruction
→ dispatch
→ instruction 内部才等待 global barrier
```

所以它可能先领取一个尚未 ready 的 consumer，再在 barrier 上占住 CTA。详细路径保存在 canonical controller 快照。

## 不要把每个 tile 都放进全局队列

P16 每层的现有 VM packet 数是：

```text
148 QKV
+ 128 Partial Attention
+   8 Attention Reduction
+ 256 OProj
+ 148 UpGate
+ 148 DownProj
= 836 packets/layer
```

完整32层加 LM head：

```text
836 × 32 + 148 = 26,900 packets/token
```

底层其实有94,288个逻辑 tile job，但现有 VM packet 已经会在 CTA 内顺序处理多个 tile。因此应调度26,900个 packet，不能重新膨胀成94,288个全局队列元素。

## ReadyGroup 怎么工作

编译器先按“相同前驱集合”分组，例如：

- QKV：按8个GQA semantic group记录完成情况。
- Partial：按8个KV head分组，每组16个partition。
- Reduction：同样按KV head分组。
- OProj：等待全部attention输出。
- UpGate/DownProj：按四个K-slice分组。

每个 group 保存不可变 packet 范围、ready generation和claim cursor：

```text
真实 read-set 满足
        ↓ release
发布 ready_epoch
        ↓ acquire
CTA claim 一个 chunk
        ↓
执行全部 packet
        ↓
等待 storer / TMA 协议真正完成
        ↓ release completion
最后完成者发布 successor
```

最重要的不变量是：

> packet 一旦被领取，就不能再等待尚未领取的跨 CTA producer。

旧源码中大量 instruction 内部存在：

```text
while (g.Bar[...] < expected)
    nanosleep()
```

例如 MatVecAdd等待路径。这些等待必须提升为scheduler的ready条件；第一版可以保留为debug assert，但不能继续自旋。

还有一个必须修的真实依赖：历史 Python DAG 对Partial主要枚举了K/V依赖，但Partial同样读取Q。静态顺序可能暂时掩盖了它；动态重排后，ready条件必须包含对应的4个Q head、K和V全部到达。

## 怎样减少 atomic，又不丢并行度

不要简单写“每次领取8个packet”。如果一个阶段只有148个packet，那么只会产生约19个chunk，绝大多数B200 SM都会闲置。

更合理的是均衡切分：

\[
C=\min(N_{\text{packets}},\ target_{\text{chunks}})
\]

\[
chunk_j=
[\lfloor jN/C\rfloor,\ \lfloor(j+1)N/C\rfloor)
\]

独占B200可先设：

```text
target_chunks = 148
```

例如256个OProj packet会切成148个、每个包含1–2个packet的chunk，仍保留148路设计并行度。

对应的设计估算是：

```text
23,444 chunk claims/token
46,888 claim + completion RMW/token
```

而 legacy 源码级计数约有：

```text
70,528 producer barrier RMW/token
+ 数量无上界的 spin loads
```

所以新调度器不一定增加原子总量。真正风险是少数 `next_chunk/done` cache line 的热点争用，必须靠SASS、NCU和paired latency判断；这些数字目前是设计估算，不是实测结果。

## 为什么它可以支持任意 K≥1

只要满足：

1. DAG有限且无环，root group已ready。
2. 至少一个CTA得到调度。
3. 任意resident CTA都能领取任意ready chunk。
4. 未驻留CTA不拥有唯一任务。
5. 领取后的packet一定有限完成。
6. 输出完成后用device-scope release发布；consumer acquire后读取。
7. ready为空但仍有inflight任务时继续等待，不能提前退出。
8. 只有terminal generation完成才退出。

那么可以按DAG拓扑顺序归纳：

```text
root完成
→ successor变ready
→ successor完成
→ …
→ LM head terminal完成
```

后续才入场的CTA只需观察terminal并立即退出。release/acquire的正式语义见 [CUDA C++ Memory Model](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cuda-cpp-memory-model.html)。

## 推荐实验顺序

1. 先审计每个旧 `g.Bar` wait，把真实read-set提升成显式前驱；dispatch时若条件不满足直接记录并trap。
2. 做193个核心节点的多kernel CUDA Graph，作为最容易证明的正确性/liveness oracle。
3. 实现单kernel ReadyGroup原型，分别 launch `148/296/592` 个blocks，强制出现queued waves。
4. P1/P16各运行至少1,000次，并加入随机延迟扰动。
5. 用debug packet bitmap确认最终恰好完成：

```text
P1  = 22,804 packets
P16 = 26,900 packets
```

6. 扫描 `target_chunks={37,74,148,296}`，同时看延迟、SM空闲、原子争用、controller long-scoreboard，以及是否增加stack/spill。
7. 只有在正确性稳定后，才尝试把独立scheduler completion与旧operator barrier合并。

Phase82 的约`0.688 ms`强结果来自static、cluster1路径，不是CLC性能或MPS安全证据。本课的ReadyGroup仍是设计提案，尚未实现和上机验证。
