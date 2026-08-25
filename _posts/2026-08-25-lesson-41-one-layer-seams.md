---
layout: lesson
title: "一层 Llama 到底有几条切缝？"
slug: lesson-41-one-layer-seams
lesson: 41
stage: "阶段二 · 找到真正值得保留的融合边界"
stage_description: "区分物理融合、Graph provider swap 与概念 island，不把不同实验合同拼成一个故事。"
description: "沿 QKV、Attention、OProj、UpGate、DownProj 和 LMHead，逐条盘点跨边界状态。"
takeaway: "决定切不切的，不是算子名字，而是边界上必须保存什么。"
image: /lesson41/llama1b_one_layer_island_seams_16x9.png
tags: [Llama, Seam, Tensor Lifetime, Dispatcher]
read_time: 12
status: "SOURCE-PROVEN · CANONICAL C473"
prev_slug: lesson-40-fusion-vs-islands
prev_title: "最大融合一定最好吗？从 Megakernel 到 Island"
next_slug: lesson-42-four-arm-evidence
next_title: "四臂实验：怎样给 Island 一个公平位置？"
---

> **本课用词**：canonical 指当前用于推导的 clean reference baseline；IType 是 Dispatcher 能执行的一类逻辑指令；seam 是候选切分边界；physical launch 指真正提交到 GPU 的一次 kernel 启动，不等同于一个算子名字。

## 先纠正“一个算子就是一个 kernel”

canonical Llama-1B 一层有五个主要逻辑调用点：QKV、Attention、OProj、UpGate、DownProj。MatVecAdds 被 OProj 和 DownProj 两次复用；deterministic Down 内部还包含 partials 与 fixed reduction。

这些是 IType 调用或 dispatcher stage，不一定等于五个 unique class，也不一定等于五个 physical CUDA launch。

## 主要 seam 上有什么

以 batch1、BF16 为例：

- QKV → Attention：`q[2048]`，约 4 KiB；另外 K/V 原位追加到 cache；
- Attention → OProj：`attn_out[2048]`，约 4 KiB；
- OProj → UpGate：`hidden[2048]`，约 4 KiB，且是 residual 的同一 global pointer；
- UpGate → Down：`silu_out[8192]`，约 16 KiB；
- deterministic Down 内部：`partials[4,2048]` FP32，约 32 KiB；
- 最后 hidden → LMHead，输出 logits 约 250.5 KiB。

这些是逻辑 payload 或源码形状，不是 NCU 实测 DRAM bytes。缓存、sector、重复读取和协议元数据都另算。

## 哪条 seam 更自然

OProj → UpGate 只需要已有 global hidden，因此是最容易建立正确性的物理 cut。反过来，QKV → Attention 还涉及 Q 与 K/V cache 的发布，Down 内部又有 partial buffer 和 reduction tree。

但“正确性边界自然”不等于“性能一定好”。切开后每个 dispatcher 是否仍拿 227 KiB shared、同样寄存器目标和 TMEM allocator，必须查 exact binary。

## 物理 cut 会重置什么

新 kernel 会重建 register、shared pages、动态 semaphore 和 tensor allocator；global weights、KV cache、hidden、persistent internal buffer 仍存在。

因此 physical cut 真正增加的是：launch/Graph node、global handoff、barrier reset 和新资源准入。它不会自动删除 global tensor，也不会自动降低 per-CTA shared memory。
