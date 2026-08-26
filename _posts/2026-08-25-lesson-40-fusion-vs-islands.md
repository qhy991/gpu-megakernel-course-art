---
layout: lesson
title: "最大融合一定最好吗？从 Megakernel 到 Island"
slug: lesson-40-fusion-vs-islands
lesson: 40
stage: "阶段二 · 找到真正值得保留的融合边界"
stage_description: "区分物理融合、Graph provider swap 与概念 island，不把不同实验合同拼成一个故事。"
description: "用同体 Graph 对照和负向切分控制，理解融合收益与资源包络成本之间的 U 型关系。"
takeaway: "融合不是越多越好，切分也不会自动让资源变小。"
beginner_question: "把所有计算塞进一个大 kernel，一定最快吗？"
beginner_analogy: "所有工序挤进一间厨房，传菜少了，却可能被最大设备占满；分成几间厨房有时更顺。"
beginner_skip: "可先忽略 Graph provider 和历史计时数据。"
image: /lesson40/maximum_fusion_vs_megakernel_islands_16x9-v3.png
tags: [Fusion, CUDA Graph, Megakernel Island, Launch Overhead]
read_time: 12
status: "MIXED EVIDENCE · ISLANDS UNMEASURED"
prev_slug: lesson-39-resident-eligible-issue
prev_title: "Resident、Eligible、Issue：31.25% occupancy 到底说明什么？"
next_slug: lesson-41-one-layer-seams
next_title: "一层 Llama 到底有几条切缝？"
---

> **本课用词**：individual-op 表示每个逻辑算子使用独立 kernel；resident Graph 表示常驻 kernel 执行整张图；provider swap 是在相同 Graph 外壳中替换实现路径；island 是少量 physical kernel 组成的融合分区。

## 两个极端

左端是 individual-op CUDA Graph：每个算子都有独立 kernel，资源容易专门化，但 launch、global handoff 和同步边界多。

右端是 whole-model resident megakernel：一个 persistent kernel 执行整张图，能复用 page、聚合边界并重叠不同角色，但所有 instruction 共享同一个最坏资源包络。

所谓 Megakernel island，是在两者之间寻找少量物理 kernel：每个 island 内保留真正有价值的融合，island 间用明确的 global seam 连接。

## 哪组数字可以公平比较

canonical Phase82 的同轮对照是 Llama-1B、M=1、16 层、pos0：

- individual-op CUDA Graph：约 `0.969 ms`；
- full-overlap resident Graph：约 `0.689 ms`；
- 两侧 100/100 bitwise；
- 同轮比值约 `1.409×`。

这说明当前 whole resident substrate 在这个合同中显著更强，但收益混合了 dispatcher 常驻、page 生命周期、边界聚合和合法 overlap，不能简化成“少 launch 了多少”。

## 一个很有用的负控

Legacy 8B 把 LMHead 拆成 dedicated helper，即使 helper 自身没有 spill，完整 forward 仍从 `2809.104` 变成 `2843.776 μs`，约慢 1.234%。后续 exact 审计还发现 helper 的 worker identity 有缺陷，因此它只能作为负向 screen，不能称为合法 cut。

但它仍提醒我们：资源变干净，不代表新边界成本会被抵消。

## Island 何时值得做

至少同时满足：

- 中间量真正不再 global materialize，或边界确实减少；
- exact CUBIN 资源包络随切分改变；
- whole-boundary A/B 为正；
- 正确性、内存序与重放门通过；
- 不把另一个模型、shape 或 profiler 工件套过来。

图中的 U 型曲线只是概念模型，不是实测曲线。当前 island 路线仍是 **PROPOSED · UNMEASURED**。

## 为什么会出现 U 型关系

融合较少时，主要成本来自 launch、global materialization 和边界同步；继续融合通常能删除这些成本。融合超过某个点后，最坏 register、shared、TMEM 与 block geometry 开始支配所有阶段，原本可专门化的小算子被迫背负整张图的资源包络。

每条 seam 都应独立计算：保留融合的收益来自删除边界、合法 overlap 和数据局部性；代价来自共享最坏资源包络与内部协议。不能先决定“两岛最好”再为它寻找理由。

## 公平比较必须锁住什么

候选必须使用同样的数学 body、精度、输入、权重、KV 状态、Graph replay 次数、reset 规则和计时边界。尤其不能让 individual arm 调用成熟库 kernel，而 resident arm 使用未调优 body，再把差异全部归因于执行组织。

还要保存 kernel census 与 exact binary hash，否则 B 臂可能实际 fallback 到 A，或一次 provider swap 改变了不止物理边界。

## 练习：评审一个三岛提案

假设切缝位于 Attention→OProj 与 UpGate→Down。为两条 seam 分别列出 payload、publication、额外 launch、可回收资源和可能丢失的 overlap。最后给出三个停止条件：资源包络未改变、正确性门失败、whole-boundary A/B 未过噪声。
