---
layout: lesson
title: "切一刀，会自动降低寄存器和 Shared Memory 吗？"
slug: lesson-43-cut-resource-envelope
lesson: 43
stage: "阶段二 · 找到真正值得保留的融合边界"
stage_description: "区分物理融合、Graph provider swap 与概念 island，不把不同实验合同拼成一个故事。"
description: "物理 cut 会释放上一 kernel 的资源，但下一 kernel 若继承同一 Config，仍会重新申请同样的大包络。"
takeaway: "切开会重置状态，不会自动 right-size 资源。"
image: /lesson43/cut_resets_state_not_resource_envelope_16x9.png
tags: [Shared Memory, Registers, Occupancy, Physical Cut]
read_time: 10
status: "SOURCE-PROVEN · EXACT REBUILD SIDECAR"
prev_slug: lesson-42-four-arm-evidence
prev_title: "四臂实验：怎样给 Island 一个公平位置？"
next_slug: lesson-44-three-pages
next_title: "把 7 页改成 3 页，为什么 Shared Memory 可能一字节没降？"
---

> **本课用词**：resource envelope 是一个 CTA 入场时必须一次满足的 shared memory、register、thread 与 TMEM 资源合同；exact CUBIN 是真正被测试的 GPU binary；occupancy API 只计算“资源上允许驻留几个 CTA”，不观察运行时行为。

## 当前 canonical 的资源包络

clean c473（课程使用的一份 canonical source snapshot 标识）的默认 kernel 是 384 threads、12 warps，其中 8 个 consumer 与 4 个 service warp。源码配置推导：

- 7 个 32 KiB page；
- dynamic shared `230400 B`；
- source-modeled static 约 `2048 B`；
- 总计约 227 KiB/CTA。

B200 每 SM 约 228 KiB shared memory，并为每 block 保留额外空间。因此 shared memory 单项已经把上限钉在 1 CTA/SM。

## Cut 前后发生什么

物理 kernel 结束时，上一 CTA 的 registers、shared memory 与 TMEM 生命周期结束。下一 kernel 启动时会重新准入。

但是，如果两个 island 都继承 `default_config`，dispatcher 仍会给每个 kernel 传同一个 `230400 B` dynamic shared，warp 角色也仍使用 224/56 的 register target。

所以图上看到的是：

```text
Island A：占满 → 退出 → 释放
Island B：再次占满 → 退出 → 释放
```

不是两个较小 CTA 自动同时驻留。

## 2 CTA 的必要门

若想让一张 B200 的同一 SM 同时容纳两个 CTA，至少要同时满足：

- 每 CTA 总 shared ≤ 约一半 SM 容量；
- 每 CTA exact registers ≤ 32768；
- thread/warp/block 限额允许；
- TMEM/cluster metadata 不阻挡；
- exact occupancy query 返回 2；
- launch 真的提供第二批独立工作。

资源门是 AND，不是 OR。

## 证据层级

源码公式只能给上界。真正的链条应是：

`source geometry → exact CUBIN attrs → occupancy API → NCU/timeline → paired latency`

Phase82 没有冻结 timed exact CUBIN、ptxas、SASS 与 NCU，因此不能拿后验重建物的资源数字冒充原实验制品。
