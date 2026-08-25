---
layout: lesson
title: "最大融合一定最好吗？从 Megakernel 到 Island"
slug: lesson-40-fusion-vs-islands
lesson: 40
stage: "阶段二 · 找到真正值得保留的融合边界"
stage_description: "区分物理融合、Graph provider swap 与概念 island，不把不同实验合同拼成一个故事。"
description: "用同体 Graph 对照和负向切分控制，理解融合收益与资源包络成本之间的 U 型关系。"
takeaway: "融合不是越多越好，切分也不会自动让资源变小。"
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
