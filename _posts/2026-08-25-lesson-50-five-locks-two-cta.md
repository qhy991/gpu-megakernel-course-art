---
layout: lesson
title: "2 CTA/SM 要打开哪五把锁？"
slug: lesson-50-five-locks-two-cta
lesson: 50
stage: "阶段四 · 用受控实验替代性能故事"
stage_description: "把资源、工作供给、内存序和 benchmark contract 拆成可以逐项推翻的实验。"
description: "Shared、register、TMEM、grid supply、worker identity 五个条件必须同时成立。"
takeaway: "occupancy=2 只是第二把门后的通行证，不是最终结果。"
image: /lesson50/five_locks_for_two_cta_16x9-v2.png
tags: [2 CTA, Occupancy, Grid Supply, Worker Identity]
read_time: 13
status: "SOURCE + HISTORICAL NEGATIVE CONTROLS"
prev_slug: lesson-49-two-island-p0
prev_title: "两岛 P0：怎样把一个想法变成可证伪候选？"
next_slug: lesson-51-r0-r5-tree
next_title: "R0–R5：五个实验臂为什么不能跳级？"
---

## 锁一：Shared Memory

当前 exact canonical user shared 约 232176 B，再加 driver reserved 后几乎占满 B200 每 SM 容量。要容纳两个 CTA，每 CTA 必须降到约一半以内。

三页/一阶段方案可以把 source envelope 降到约 99 KiB，但必须防止 scratch 回填。

## 锁二：Registers

当前 168 registers/thread × 384 threads = 64512 registers/CTA。B200 每 SM 65536 registers，因此双 CTA 要求每块不超过 32768。

保持 8 consumer + 4 service 时，consumer setmaxnreg 目标需要从 224 降到约 96；另一候选是 4 consumer/4 service、consumer192。两者都可能增加 spill 或降低并行度，必须看 exact CUBIN。

## 锁三：TMEM

512-column allocator metadata 在历史 matched binary 中能把 occupancy query 从 2 压到 1。canonical Llama-1B 不消费 TMEM 数值 tile，适合尝试 capability manifest，但这只是准入门。

## 锁四：Grid Supply

当前 per-SM queue 模式 grid 只有 148 blocks。即使 occupancy 允许 2 CTA，也没有第二批 CTA 可住。

要测试 2 CTA/SM，需要至少 296 个独立 logical worker，或在 cluster2 下 148 个 bundle，并重建 schedule/barrier targets。

## 锁五：Worker Identity

历史 LMHead helper 虽发出 grid296、query2，却仍用 `%smid` 索引 worker queue。同一 SM 的两个 CTA 会读同一行，后 148 行不可达。

所以必须使用唯一的 `blockIdx.x → logical_slot`，并验证 296 条队列恰好各消费一次。

## 最后的顺序

`FIT → FILL → FINISH → FASTER`

先证明资源容得下，再证明工作喂得满，再证明真实 KV 正确完成，最后才看延迟。任何跳步都会制造假阳性。

