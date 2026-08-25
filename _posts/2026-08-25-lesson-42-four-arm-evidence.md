---
layout: lesson
title: "四臂实验：怎样给 Island 一个公平位置？"
slug: lesson-42-four-arm-evidence
lesson: 42
stage: "阶段二 · 找到真正值得保留的融合边界"
stage_description: "区分物理融合、Graph provider swap 与概念 island，不把不同实验合同拼成一个故事。"
description: "把 individual、islands、per-layer 与 whole resident 放进同一条证据梯，避免拼接不同实验。"
takeaway: "没有同体、同输入、同正确性门的四臂表，就没有 Island 冠军。"
image: /lesson42/four_arm_island_evidence_ladder_16x9.png
tags: [A/B Testing, CUDA Graph, Evidence, Correctness]
read_time: 11
status: "A/D MEASURED · B/C UNKNOWN"
prev_slug: lesson-41-one-layer-seams
prev_title: "一层 Llama 到底有几条切缝？"
next_slug: lesson-43-cut-resource-envelope
next_title: "切一刀，会自动降低寄存器和 Shared Memory 吗？"
---

> **本课用词**：arm 是受控实验中的一个候选分支；A/B/C/D 分别代表 individual、islands、per-layer 与 whole resident；同体对照表示模型、输入、数学、正确性门和计时边界都相同，只改变预注册变量。

## 四个实验臂

一条理想的 island 证据梯应该包含：

- A：individual-op CUDA Graph；
- B：若干物理 Megakernel islands；
- C：per-layer megakernel Graph；
- D：whole-model resident/full-overlap Graph。

四臂必须使用同一模型、权重、shape、instruction body、数值协议和计时边界。

## 现在真正闭合的是 A 与 D

Phase82 的 A/D 同轮数据约为 `0.969 ms → 0.689 ms`，两个执行顺序都约 `1.409×`，四个执行对象都通过 100 次 reset 与 bitwise audit。

`release_fenced_graph` 仍然是 whole-model，只是禁止 inter-op overlap，不能拿来冒充 per-layer C。

## 为什么 C 的旧数字不能用

旧控制矩阵里 per-layer 看起来很快，但同一日志已经记录 hidden/logit replay drift。一个不满足正确性的 arm 没有性能资格。

Phase82 exact harness 后来只重测 whole、fenced whole 与 individual，没有重新纳入 per-layer，因此 C 仍是 UNKNOWN。

## B 也不能靠拼图得到

GateUp→SwiGLU 的正向融合、Down→Norm 的负向实验、Aug17 provider swap 分别来自不同代码、shape 和物理边界。不能把它们的百分比拼成“两岛方案预测收益”。

真正的 B 必须存在 exact island CUBIN、Graph kernel census、边界消失证据和整臂计时。

## 最低验收线

- 100 reset bitwise 或预注册数值门；
- AB/BA 或 ABBA/BAAB 双顺序；
- exact ptxas/SASS/occupancy；
- context buckets 与 real KV；
- both-order p50 至少跨过噪声门；
- 任何桶回退时支持条件分发或归档。
