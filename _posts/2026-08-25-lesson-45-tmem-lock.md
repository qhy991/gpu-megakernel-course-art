---
layout: lesson
title: "第三把锁：TMEM 为什么能让 occupancy 从 2 变 1？"
slug: lesson-45-tmem-lock
lesson: 45
stage: "阶段三 · 打开 2 CTA 驻留的五把锁"
stage_description: "逐项审计 shared memory、register、TMEM、grid supply 与 worker identity。"
description: "TMEM 是独立的硬件准入资源；canonical Llama-1B 甚至申请了 512 列，却没有用它存数值 tile。"
takeaway: "资源是否被数值代码使用，与它是否影响 kernel 准入，是两件事。"
image: /lesson45/third_lock_tmem_16x9.png
tags: [TMEM, tcgen05, Occupancy, Blackwell]
read_time: 12
status: "SOURCE + HISTORICAL EXACT BINARY"
prev_slug: lesson-44-three-pages
prev_title: "把 7 页改成 3 页，为什么 Shared Memory 可能一字节没降？"
next_slug: lesson-46-tmem-manifest
next_title: "怎样让只有真正需要的 IType 才申请 TMEM？"
---

> **本课用词**：TMEM（Tensor Memory）是 Blackwell 的独立片上 tensor 资源；`tcgen05.alloc/dealloc` 是它的显式分配／释放指令；allocator 是管理这段资源生命周期的代码对象；entry metadata 是 CUBIN 对 kernel 资源需求的声明。

## TMEM 是什么

Blackwell Tensor Memory 是每 CTA/CTA-group 显式分配的片上资源。PTX 使用 `tcgen05.alloc` 申请列，结束时必须 `dealloc`。资源不足时 allocation 可以等待，因此它不仅是地址空间，也参与准入与生命周期。

## canonical 的意外事实

当前 canonical Llama-1B kernel 在入口无条件构造 `tensor_allocator<1,1>`，也就是每 CTA 申请 512 列 TMEM，生命周期从 persistent kernel 入口持续到退出。

但 Llama-1B 的实际 attention/matvec 走传统 register `mma.sync`，IType 目录没有调用 `tensor_alloc.allocate`。`tensor_wait/finish` 只是 CTA-local shared mbarrier token，不是 TMEM data wait。

所以准确结论是：

> 当前 512 列 TMEM 更像一个未被数值路径消费的 resource-admission contract。

不能画成“Attention accumulator 存在 TMEM”。

## 历史 exact A/B 说明了什么

Legacy 8B 有一对匹配 binary：两者 block、register 和 shared 容量都允许 2 CTA；full allocator CUBIN 带 TMEM entry metadata，occupancy query 为 1；no-allocator CUBIN 移除 marker 后 query 为 2。

这强力证明在那对 exact binary 中，512-column TMEM allocation contract 阻挡了第二 CTA。它不证明 canonical 当前删除 TMEM 就能 2 CTA，因为 canonical 仍被 227 KiB shared 与 64512 registers/CTA 锁住。

## 生命周期为何重要

硬件允许中途 alloc/dealloc，但当前 allocator 的 C++ 作用域是整个 kernel。某条 instruction 的 `tensor_finish` 不会把 TMEM 还给 SM，也不会触发新 CTA 入场。

与 shared page 一样，要区分“内容 token 已可复用”和“硬件准入资源已释放”。
