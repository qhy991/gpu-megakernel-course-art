---
layout: lesson
title: "两岛 P0：怎样把一个想法变成可证伪候选？"
slug: lesson-49-two-island-p0
lesson: 49
stage: "阶段四 · 用受控实验替代性能故事"
stage_description: "把资源、工作供给、内存序和 benchmark contract 拆成可以逐项推翻的实验。"
description: "以 Attention island + MLP island 为例，冻结工作量、seam、resource manifest 与失败条件。"
takeaway: "先写清候选怎样失败，再开始实现。"
image: /lesson49/two_island_falsifiable_p0_16x9.png
tags: [Two Islands, P0, Falsifiability, Llama-1B]
read_time: 12
status: "PROPOSED · UNMEASURED"
prev_slug: lesson-48-when-to-split
prev_title: "什么时候应该切开 Megakernel？"
next_slug: lesson-50-five-locks-two-cta
next_title: "2 CTA/SM 要打开哪五把锁？"
---

## 最小两岛怎么切

自然 seam 选在 OProj → UpGate：

- Attention island：QKV → Attention → OProj；
- MLP island：UpGate → deterministic Down；
- LMHead 单独保留。

16 层每层调用两个 island，最后一次 LMHead，因此每 token 是 33 个 compute launches。它不是 33 个 Dispatcher；三个 Dispatcher/CUBIN 对象会被跨层复用。

## 工作量必须闭合

canonical deterministic schedule：

- Attention island：每层 284 instructions；
- MLP island：每层 424 instructions；
- LMHead：148 instructions；
- 总计 `16 × (284 + 424) + 148 = 11476`。

纯切分不能偷偷少任务。若总 instruction 变了，先解释是优化、漏任务还是不同 schedule。

## Seam 需要保存什么

两岛之间只传已有的 global `hidden[2048]` BF16，约 4 KiB。K/V cache、weights 与 scalar 保持持久。

但是每个有 barrier 的 Dispatcher 启动前还会清零自己的 barrier tensor；Graph 中除了 33 个 compute launch，还可能有 reset/memset node，必须用实际 Graph census，而不是心算节点数。

## 为什么 P0 还没有性能资格

按现源码独立编译 Attention-only 与 MLP-only，二者仍然是：

- 384 threads；
- 168 registers/thread；
- max dynamic shared 230400 B；
- occupancy query 1 CTA/SM。

也就是说，单纯“切成两个 CUBIN”没有 right-size 资源。

## 可证伪条件

- 若 exact resource 没变，资源假设失败；
- 若 hidden/logits 或 real-KV 轨迹不一致，正确性失败；
- 若 Graph census 与预注册不符，path identity 失败；
- 若 A/B 双顺序不过噪声门，性能假设失败；
- 若只在 pos0 赢，不能升级为 production dispatch。

