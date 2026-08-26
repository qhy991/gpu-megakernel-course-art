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

> **本课用词**：2 CTA/SM 指同一个 SM 同时驻留两个 thread block；grid supply 是 launch 是否提供足够多的独立 CTA；worker identity 是每个 CTA 如何获得唯一任务槽；cluster2 把两个 CTA 组成一个协作 cluster，是另一种执行合同。

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

## 五把锁为什么是 AND

shared 和 register 决定静态准入，TMEM/cluster 决定额外硬件合同，grid supply 决定是否有第二个 CTA 可调度，worker identity 决定两个 CTA 是否执行不同工作。任一项为假，最终都不能得到“两个有用 CTA 同驻留”。

尤其要区分 query 与 observation：occupancy API 返回 2 只说明资源模型允许；NCU 或时间线看到 2 才说明运行时发生；两 CTA 都完成唯一任务且结果正确，才说明这次同驻留有用。

## Worker Identity 的 Exactly-once 门

为 296 个 logical slot 准备位图或计数器。每个 CTA 用 `blockIdx.x` 或明确 bundle ID claim 唯一 slot；结束时记录访问次数。验收必须同时满足 296 个 slot 全部恰好一次、无重复、无遗漏、barrier target 与实际 producer 数一致。

## 练习：给失败分类

对以下现象分别定位哪把锁：query=1；query=2 但 grid148；grid296 但后148队列从未访问；两 CTA 同驻留但 logits 漂移；正确且同驻留却变慢。最后一个不是资格失败，而是性能 verdict。
