---
layout: lesson
title: "Dynamic Tail：最后半块不做整块工作"
slug: dynamic-tail
lesson: 20
stage: "基础四 · 三个真实优化机制"
stage_description: "用 Page-ready、Split-KV 和 Dynamic Tail 看懂等待、并行度与冗余工作。"
description: "解释 DownProj 的 2048 短尾为何不应继续使用满 4096 的 TMA、warp 和 reduction 几何。"
takeaway: "尾块变短时，执行几何也应缩短，但整步收益受占比限制。"
beginner_question: "最后一小段数据，为什么不该按整块规模处理？"
beginner_analogy: "像货车只剩半车货，就不必再派满编装卸队；按实际货量安排人手更省事。"
beginner_skip: "可先忽略 TMA、warp 和 HMMA 的具体执行参数。"
image: /lesson20/lesson-20.png
tags: [Dynamic Tail, DownProj, Warp, HMMA]
read_time: 8
status: "MEASURED · LEGACY INCREMENTAL WIN"
prev_slug: split-kv-parallelism
prev_title: "Split-KV：把 8 个长任务拆成 128 个短任务"
next_slug: release-acquire-publication
next_title: "Flag 到了，数据就一定到了吗？"
---

> **本课用词**：DownProj 是 MLP 下投影；K-slice 是 reduction 维的一段；HMMA 是 Tensor Core 矩阵乘累加指令。

先记住一句话：

> Dynamic Tail 不是少从 HBM 读取很多权重，而是不再让半宽尾块执行整块的片上算术。

## 1. “尾块”是怎么产生的？

Llama-3.1-8B 的 MLP 中间维度是 14336。DownProj 要把它投影回 hidden size 4096，相当于计算一个 `4096 × 14336` 的矩阵向量乘。

Megakernel 将 reduction 维切成：

```text
14336 = 4096 + 4096 + 4096 + 2048
```

前三段都是完整的 4096，最后只剩 2048，因此叫 tail。

在你的实现里：

- 每个 consumer warp 处理 256 个 reduction columns
- 每个内部 weight page 处理 512 列
- 完整 4096 段需要 16 warps、8 pages
- 最后 2048 段只需要 8 warps、4 pages

这里的 page 是 Megakernel 内部的 16 KiB 权重 tile，不是操作系统页面，也不是 KV-cache page。

## 2. 旧实现浪费在哪里？

旧路径面对 2048 尾块，仍按完整 4096 stage 工作：

```text
有效：8 warps + 4 pages
冗余：8 warps + 4 pages
```

为了避免越界，旧代码会让无效 warp 的 activation 为零，并对缺失页面使用安全的重复地址。结果仍然正确，但多执行了：

- 无效的 tensor-core HMMA
- shared-memory 读写
- scratch/local-memory 工作
- 多余的同步和交接

也就是“答案为零，但仍认真算了一遍零”。

## 3. Dynamic Tail 改了什么？

每条 DownProj 指令携带 `reduction_elements`。尾块取值为 2048，于是运行时算出：

```text
active warps = ceil(2048 / 256) = 8
active pages = ceil(8 / 2) = 4
```

随后：

- loader 只加载4个有效权重页
- 前8个 warp 执行矩阵乘
- output semaphore 只等待8次数值到达
- storer 只归约8份有效 scratch

但要注意：另外8个 warp 并没有从 CTA 中物理消失。它们仍完成必要的 semaphore/page 生命周期收尾，只是退出了数值计算路径。

因此没有变化的是：

- 仍然一个物理 Megakernel launch
- 仍然 640-thread CTA
- 仍然 16 个 consumer warp 的静态配置
- 寄存器、shared-memory 配额和 occupancy 不变

## 4. NCU 是否支持这个解释？

支持，而且信号相当干净：

| 指标 | 变化 |
|---|---:|
| 完整 Megakernel duration | `3.610560 → 3.555936 ms`，`-1.51%` |
| HMMA work | `-3.23%` |
| shared-memory instructions | `-2.31%` |
| local loads | `-0.88%` |
| DRAM read bytes | 仅 `-0.0115%` |

如果这是 HBM 优化，DRAM bytes 应明显下降；实际几乎没变。下降的是片上指令，正好验证“删除无效尾块计算”的因果解释。

最终4K长预热结果也很接近：

```text
3.592344 → 3.534608 ms
节省 57.736 μs，延迟降低 1.607%
```

NCU 节省 54.624 μs，两种测量口径在绝对值上很好地闭合。

## 5. 为什么上下文越长，百分比越小？

它删除的是每层固定存在的 DownProj 尾块工作，绝对收益大致几十微秒：

| 位置 | 延迟下降 |
|---|---:|
| pos0 | `-2.445%` |
| 4K | `-1.607%` |
| 8K | `-1.060%` |

上下文越长，attention 占用的总时间越多。同样节省约几十微秒，除以更大的总延迟，百分比自然变小。

## 6. 正确性怎么样？

使用真实 tokenizer prefix 和非零 BF16 KV cache：

- 4K：Top-1 `16/16`，最低 cosine `0.999750376`
- 8K：Top-1 `16/16`，最低 cosine `0.999475360`
- hidden/logits 全部 finite
- 32层 DownProj completion barriers 全部达到预期值

它通过了已测范围，而且差异处于 baseline 自身跨进程重放噪声内；但不能称为 bitwise exact。

## 7. 这项成果的准确定位

这是一个非常具体的 Llama-8B shape specialization：

```text
[4096, 4096, 4096, 2048]
```

当前 CUDA 地址计算、barrier 分桶和8-warp reducer都围绕这个形状设计，不能直接宣传成支持任意尾部大小的通用 Dynamic-K 框架。

测量覆盖单张 B200上的“32层+LM head GPU model-forward”，不包含 tokenizer、sampling、HTTP、请求排队，也不是4卡扩展结果。

此外，实验二进制和报告被保留了，但相关源码当时仍位于 dirty worktree，尚未由干净的 canonical commit 完整固化。这也是它距离生产化仍差的一步。

源码与报告证据可从历史源码快照、实验报告快照和研究日结核对。
