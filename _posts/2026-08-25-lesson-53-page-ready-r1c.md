---
layout: lesson
title: "三页以后还能流水吗？把 64 KiB 大门拆成两扇"
slug: lesson-53-page-ready-r1c
lesson: 53
stage: "阶段四 · 用受控实验替代性能故事"
stage_description: "把资源、工作供给、内存序和 benchmark contract 拆成可以逐项推翻的实验。"
description: "R1c 在 depth1/3page 基线上，仅把每轮 stage-wide arrived/finished 拆成两个 page-local 门。"
takeaway: "一组 buffer 也能做页内流水，只要每页有独立 ready 与 reuse ACK。"
image: /lesson53/canonical_r1c_page_ready_16x9.png
tags: [R1c, mbarrier, Page-ready, Reuse ACK]
read_time: 14
status: "PROPOSED · UNMEASURED"
prev_slug: lesson-52-pipeline-depth-vs-pages
prev_title: "三种 Pipeline：为什么一个数字 3 会指三件不同的事？"
next_slug: lesson-54-poison-litmus
next_title: "怎样证明 READY/ACK 协议真的安全？"
---

> **本课用词**：R1b 是已经把 input pipeline 缩为一层、物理 page 缩为三页的基线；R1c 只进一步拆细 READY/FINISHED；page-local 表示每个 32 KiB page 有自己的信号；ACK 是 consumer 完成读取后的复用确认。

## R1c 的唯一变量

R1c-P0 必须相对正确的 R1b 比较，并保持：

- input depth1；
- 3 个 physical page；
- dynamic shared 99328 B；
- output pipeline3；
- 8 consumer；
- 最后 iteration 的 8-warp 共同 page release。

唯一变化是把一把 64 KiB stage-wide `weights_arrived/finished`，拆成两套 32 KiB page-local semaphore。

## 每页怎样工作

一个 32 KiB page 由两笔 `16 × 512 × BF16 = 16 KiB` TMA 填满，供 4 个 warp 消费。

loader 对每页执行：

```text
wait FINISHED(page)
expect READY(page, 32768 bytes)
issue 2 × 16 KiB TMA
```

consumer 只等待自己的页，读完后 4 个 warp 分别 release-arrive 到该页 FINISHED。

于是 page0 的四个 warp 全部完成后，loader 可以开始下一 iteration 的 page0，不再等待 page1 的慢 warp。

## 什么没有变化

- 每轮仍是四笔 16 KiB TMA；
- 总 weight bytes 仍是 64 KiB；
- 数学和 output reduction 不变；
- 动态 semaphore 数量虽从9变11，但底层固定32槽，SMEM 不变；
- 跨 instruction 仍等8个 consumer 汇合后一起归还两页。

最后一点把 P0 与未来的 page-local cross-instruction release 分开。后者是第二变量，应叫 R1c+ P1。

## Phase 怎样算

软件 iteration epoch 记为 `e`，mbarrier parity 是 `e & 1`。每页独立翻相：

- loader 覆写前等 `!(e & 1)`；
- consumer 等 READY 的 `e & 1`；
- 四个 ACK 完成该页 FINISHED 当前 phase。

output scratch 仍按 `i % 3` 选择槽，跨 instruction page token 又使用外层 instruction epoch。三种 phase 不应混用。

## 为什么 Lesson 36 只能作旁证

Legacy 8B 的正结果也是 depth1，但它拆的是 `8 × 16 KiB / 2 warps`；R1c 是 `2 × 32 KiB / 4 warps`，TMA 聚合和消费者分组不同。因此它支持“readiness 粒度值得测”，不能迁移收益幅度。
