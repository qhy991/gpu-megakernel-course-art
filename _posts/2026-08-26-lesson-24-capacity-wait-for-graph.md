---
layout: lesson
title: "先算能住多少，再画谁等谁"
slug: capacity-wait-for-graph
lesson: 24
stage: "进阶一 · 正确性、生命周期与调度"
stage_description: "处理 release/acquire、epoch、驻留死锁和 Ready-aware 调度。"
description: "把 exact occupancy 资源账本与 wait-for graph 结合，系统检查跨 CTA 等待是否可能闭环。"
takeaway: "容量账本回答能住多少，等待图回答住进去后是否互相卡住。"
beginner_question: "怎样在运行前判断多个任务会不会互相堵死？"
beginner_analogy: "先数房间能住几人，再画出谁在等谁；座位不足或等待成环都危险。"
beginner_skip: "可先忽略寄存器和共享内存的精确容量计算。"
image: /lesson24/lesson-24.png
tags: [Occupancy, Wait-for Graph, Deadlock, Resources]
read_time: 10
status: "SOURCE-MODELED · OCCUPANCY CONTRACT"
prev_slug: residency-deadlock
prev_title: "同步写对了，为什么程序还会卡死？"
next_slug: ready-aware-scheduler
next_title: "Role-fluid 还不够，必须 Ready-aware"
---

> **本课用词**：wait-for graph 用有向边表示谁等待谁；occupancy API 计算资源上限；exact kernel 指真正被 launch 的 binary。

先给结论：你的 legacy 8B Megakernel 在单张空闲 B200 上，资源恰好允许每个 SM 驻留一个 CTA。`148 CTA ÷ 148 SM` 正好一波，没有余量。一旦只能部分驻留，逻辑上无环的模型 DAG，可能变成有环的资源等待图。

## 1. Legacy 8B 的真实容量

| 资源 | B200 每 SM | 每 CTA 使用 | 最多 CTA/SM |
|---|---:|---:|---:|
| Blocks | 32 | 1 | 32 |
| Threads | 2,048 | 640 | 3 |
| Warps | 64 | 20 | 3 |
| Registers | 65,536 | 61,440 | **1** |
| Shared memory | 233,472 B | 228,096 B | **1** |

所以：

\[
B_{SM}=\min(32,3,3,1,1)=1\ CTA/SM
\]

寄存器账目可以完全闭合：

```text
16 个 consumer warp × 32 × 104 registers
+ 4 个 service warp × 32 × 64 registers
= 61,440 registers/CTA
```

共享内存方面：

```text
dynamic shared memory = 214,015 B
ptxas static shared    = 10,784 B
显式合计               = 224,799 B
NCU runtime reported   = 228,096 B
```

保存的报告不足以继续解释其中约 3.3 KB 的统计差异，但不影响结论：寄存器和共享内存各自都已经把容量限制为一个 CTA。

若想达到两个 CTA/SM，必须同时满足：

```text
registers/CTA ≤ 32,768
shared memory/CTA ≤ 116,736 B
```

这意味着平均寄存器必须从 96 降到约 51/thread，同时共享内存几乎减半。只改 `__launch_bounds__` 或只减少几个 page 都不够。B200 的硬件上限可查 [NVIDIA Blackwell Tuning Guide](https://docs.nvidia.com/cuda/blackwell-tuning-guide/)。

注意：

```text
theoretical occupancy = 20 resident warps / 64 = 31.25%
```

这不等于“只用了31.25%的GPU”。148个SM仍可以全部被占据；occupancy 描述的是每个 SM 内驻留了多少 warp。

## 2. 真实 P16 数据链

一层的逻辑方向是：

```text
Down[l-1]
   │ 1024 arrivals
   ▼
QKV + RoPE + KV
   │ 每个 Q/K/V head 8 tiles
   ▼
Partial Attention ×128
   │ 每个 Q head 收到 16 partitions
   ▼
Attention Reduction ×8
   │ attn done = 32
   ▼
OProj
   │ O done = 256
   ▼
UpGate + SwiGLU
   │ [256, 256, 256, 128]
   ▼
DownProj
   │ Down done = 1024
   ▼
下一层 QKV
```

这是一个严格向前的计算 DAG，没有逻辑回边。

但是 legacy 调度器把指令轮询分给148条永久 CTA 队列。实际存在：

- 256个 OProj task，其生产者覆盖全部148条队列。
- 148个 UpGate task，恰好每条队列一个。
- 每个 UpGate 都要等 `O done = 256`。

如果只驻留了部分 CTA，最小资源环就是：

```text
已驻留 UpGate CTA
      ↓ 等 O counter = 256
缺失的 O producer 在未驻留队列
      ↓ 需要 SM slot
SM slot 被正在等待的 CTA 占住
      └───────────────↺
```

因此：

> 计算 DAG 无环，不代表资源等待图无环。

`__nanosleep()` 只能减少轮询压力，不会释放 CTA 的寄存器、共享内存或 residency slot，所以不能打破这个环。

## 3. 为什么“容量够”仍不等于“保证同时入住”

`cudaOccupancyMaxActiveBlocksPerMultiprocessor` 给出的是 exact kernel 配置下的最大活跃 block 数量，不是资源预约；cluster kernel 还需要查询 `cudaOccupancyMaxActiveClusters`。[CUDA Occupancy API](https://docs.nvidia.com/cuda/cuda-runtime-api/group__CUDART__HIGHLEVEL.html) 也明确区分了计算出的容量与实际运行环境。

普通 CUDA launch 不保证 block 的调度顺序或整个 grid 原子入住。需要全网格同步时，应使用有容量检查的 cooperative launch；但更稳妥的设计是让算法本身支持部分驻留。[CUDA Cooperative Groups](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cooperative-groups.html)

图中的“MPS 可见74个SM”只是示意，不是已经测到的结果。MPS 会改变当前 context 看到的计算容量，而且 percentage limit 不等于专属资源预留。[NVIDIA MPS 文档](https://docs.nvidia.com/deploy/mps/when-to-use-mps.html)

所以目前最严谨的判断是：

- 独占空闲 B200：已经观察到148 CTA完成执行。
- 部分驻留：源码中存在明确的资源死锁路径。
- MPS 死锁：高严重度风险，但历史上尚未实测复现。

## 4. Canonical 版本改进了什么

clean canonical 快照的默认配置是：

```text
384 threads/CTA
cluster = 2
dynamic shared = 230,400 B
static shared  =   2,048 B
total          = 232,448 B = 227 KiB
```

共享内存同样已经证明最多一个 CTA/SM。

canonical 使用 `blockIdx.x` 选择逻辑队列，消除了 legacy `%smid` 带来的物理SM身份假设；但这没有自动解决部分驻留的前进性问题。

另外：

- `cluster=2` 只保证每组两个 CTA 协同调度，不保证整个 grid 同时驻留。
- PDL 处理相邻 kernel 的依赖重叠，不是全网格 admission。
- Phase82 的约 `687.77 µs` 强结果实际使用 `cluster_size=1`。
- 当时没有冻结 exact ptxas、函数属性、active-block/cluster 查询，因此不能用它证明默认 cluster2 或 MPS-safe。

## 5. 下一次上机应怎样直接定罪或洗清

最小实验卡：

1. 冻结 exact cubin SHA，并读取 registers、static/dynamic shared memory和cluster要求。
2. 在每个实际 CUDA context 内读取 `visible_sm`，查询 active blocks和active clusters。
3. 启动前检查：

```text
requested grid ≤ exact queried capacity
cluster geometry 合法
```

4. 给诊断版本增加：

```text
started_blocks
finished_blocks
关键 barrier counters
```

5. 在独占、MPS单客户和MPS双客户下分别运行。若超时出现：

```text
started_blocks < grid
并且已启动 CTA 正在等待未启动 CTA 才能产生的 counter
```

这才是直接的 occupancy-deadlock 证据。

本课证据来自2026年8月23日保存的远端审计快照，并非今天的实时远端 HEAD。核心源码入口是 legacy资源记录 和 实际等待边记录。
