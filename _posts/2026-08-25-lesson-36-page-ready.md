---
layout: lesson
title: "Page-ready：为什么 128 KiB 大门会让 Megakernel 空等？"
slug: lesson-36-page-ready
lesson: 36
stage: "阶段一 · 看懂真实执行瓶颈"
stage_description: "从已经测过的 Legacy 8B 优化出发，建立 page、warp、TMA 与等待粒度的直觉。"
description: "把一个 128 KiB stage-wide 门拆成八个 16 KiB page-ready 门，理解“数据总量没变，等待却缩短”的原因。"
takeaway: "优化的不是搬运字节数，而是谁必须等谁。"
image: /lesson36/legacy8b_page_ready_16x9-v2.png
tags: [TMA, Shared Memory, Page Pipeline, Legacy 8B]
read_time: 10
status: "MEASURED · LEGACY DIRTY SOURCE"
next_slug: lesson-37-split-kv
next_title: "Split-KV：把长上下文注意力摊到更多 SM"
---

## 先从仓库里的真实形状开始

Legacy Llama-8B 的 hidden dimension 是 4096。一次 matvec 权重输入可以看成 `16 × 4096 × BF16`，总计 **128 KiB**。

源码把它切成八页：

- 每页 `16 × 512 × 2 B = 16 KiB`；
- 16 个 consumer warp 分到八页，每页 2 个 warp；
- 每个 warp 消费半页，也就是 8 KiB。

旧协议只有一把 stage-wide 的 `arrived` 门。八笔 16 KiB TMA 全部完成后，16 个 warp 才能一起开始。于是 page0 即使早已到达，负责 page0 的 warp 仍在等 page7。

## Page-ready 改了什么

新协议为每页建立独立的 `arrived/finished` semaphore：

1. loader 发出 page0 的 TMA；
2. page0 到达后，只唤醒它的两个 warp；
3. loader 继续提交 page1、page2；
4. 每页的两个 consumer 完成后，分别归还自己的 page token。

总 TMA 次数、tile 大小、数学运算和权重字节数都没有变化。变化的是**依赖粒度**：从“所有人等所有页”变成“每组人只等自己的页”。

## 为什么这不是 Cache 优化

报告显示的是 issue active 上升、long scoreboard 和 MIO throttle 下降。源码仍然发相同的 16 KiB TMA，也没有一组匹配的 cache hit 或 DRAM-byte A/B 可以证明缓存命中改善。

所以准确说法是：

> page-ready 缩短了 load-to-use 的假依赖，让搬运和计算重叠得更早；它不是“少读了权重”。

## 已测到什么

历史 B200 A/B/A 中，单层和完整 32 层 forward 都出现了稳定正向差异；NCU 的 one-layer replay 也同向。不过这些工件来自 Legacy 8B dirty worktree，不是 clean canonical Llama-1B。

这组数据可以证明“Legacy 8B 的 stage-wide 等待过粗”，不能直接证明后续 canonical 三页方案也会获得同样幅度。

## 新手检查表

- 画清楚每页由几个 TMA 填满。
- 画清楚每个 warp 读取哪一段字节。
- 区分 `arrived`、`finished` 与跨 instruction 的 page release。
- 只在总工作保持不变时，把差异归因于 readiness 粒度。

