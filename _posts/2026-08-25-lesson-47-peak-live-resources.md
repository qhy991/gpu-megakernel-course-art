---
layout: lesson
title: "Peak-live：为什么资源不能把百分比相加？"
slug: lesson-47-peak-live-resources
lesson: 47
stage: "阶段三 · 打开 2 CTA 驻留的五把锁"
stage_description: "逐项审计 shared memory、register、TMEM、grid supply 与 worker identity。"
description: "用时间线计算每种资源的峰值存活量，区分内容复用与 CUDA 准入配额。"
takeaway: "资源是向量；同一种资源取时间峰值，不同资源取各自的 floor。"
image: /lesson47/peak_live_resources_16x9.png
tags: [Liveness, Resource Envelope, setmaxnreg, Page Lifetime]
read_time: 11
status: "SOURCE-PROVEN · CONCEPTUAL FORMULA"
prev_slug: lesson-46-tmem-manifest
prev_title: "怎样让只有真正需要的 IType 才申请 TMEM？"
next_slug: lesson-48-when-to-split
next_title: "什么时候应该切开 Megakernel？"
---

## Peak-live 的公式

对单一资源 `r`，物理 kernel 的峰值需求是：

```text
P_r = max_t Σ alive_i(t) × usage(i, r)
```

若两个阶段严格顺序并复用同一资源，峰值接近 `max(A,B)`；若允许重叠，则可能接近 `A+B`。

但 shared memory、register、TMEM 是不同坐标，不能把“shared 80% + register 60%”相加成 140%。CTA/SM 是各资源上限取 floor 后再取最小值。

## Page finish 释放了什么

`page_finish` 只表示某个物理 page 的内容所有权可以交给下一 instruction。页仍位于同一个 CTA 在 launch 时申请的 `extern __shared__` blob 中。

所以它降低冲突与等待，却不会在 kernel 中途把 shared-memory quota 还给 SM，也不会让第二 CTA 临时入住。

## Register 也不会按 instruction 归还给 SM

consumer warpgroup 在 persistent loop 前执行 `setmaxnreg.inc`，service warp 执行 `dec`。它们是在同一 CTA 的 register pool 内重新分配预算，不是向整个 SM 动态释放 CTA 准入容量。

编译器会复用 dead local value 的 register slot，但 occupancy 看到的是整个 entry 的资源合同。

## TMEM 为何不同又相同

硬件上 TMEM 可以显式中途 alloc/dealloc；但 current allocator 在 kernel 入口构造、出口析构，因此实际生命周期仍覆盖整个 CTA。

这再次说明：硬件能力和这份代码的作用域必须分开描述。

## 新手时间线

`CTA 入场 → 一次拿到 shared/register/TMEM envelope → instruction0/1 内容交错复用 → page token 循环 → 所有 instruction 完成 → CTA 退出 → 资源真正归还`

理解这条时间线后，就不会把“page 已 free”误写成“occupancy 已提高”。

