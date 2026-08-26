---
layout: lesson
title: "怎样让只有真正需要的 IType 才申请 TMEM？"
slug: lesson-46-tmem-manifest
lesson: 46
stage: "阶段三 · 打开 2 CTA 驻留的五把锁"
stage_description: "逐项审计 shared memory、register、TMEM、grid supply 与 worker identity。"
description: "设计 fail-closed 的 kernel resource manifest：Llama-1B 声明 0 列，真正 tcgen05 IType 显式声明 256/512 列。"
takeaway: "资源能力必须由编译期合同声明，漏标要编译失败。"
image: /lesson46/tmem_capability_manifest_16x9.png
tags: [Resource Manifest, IType, Fail-closed, JIT]
read_time: 12
status: "PROPOSED · SOURCE-MAPPED"
prev_slug: lesson-45-tmem-lock
prev_title: "第三把锁：TMEM 为什么能让 occupancy 从 2 变 1？"
next_slug: lesson-47-peak-live-resources
next_title: "Peak-live：为什么资源不能把百分比相加？"
---

> **本课用词**：resource manifest 是编译期资源需求清单；fail-closed 表示漏写能力声明时直接编译失败；JIT cache key 决定运行时编译结果能否复用；oracle 是手工构造、用于核对自动方案的参考实现。

## 为什么不能全局写死 allocator

一个 physical megakernel 会把所有 dispatch case 编进同一个 entry。只要入口无条件构造 TMEM allocator，即使实际运行的 IType 不用 TMEM，CUBIN 仍携带分配协议和 entry metadata。

更合理的做法是让每个 IType 声明资源需求，再由 Dispatcher 聚合成 kernel-level manifest。

## 最小 Python 合同

```python
@dataclass(frozen=True)
class TMemRequirement:
    columns: int = 0
    cta_group: int = 1

class IType:
    tmem = TMemRequirement()
```

Llama-1B IType 保持默认 `columns=0`。真正调用 `.allocate()` 的 GEMM、generic attention 或 Llama70B IType 显式声明 256/512 列与 group。

Dispatcher 聚合时必须检查：

- nonzero group 必须一致；
- 目前 allocator 只接受 256/512；
- group2 要求 cluster size 2；
- manifest 必须进入生成 source，从而进入 JIT cache key。

## 为什么要 fail-closed

无 TMEM 路径不能提供一个“看起来能 allocate、但地址未初始化”的空对象。正确设计是 `NoTensorAllocator::allocate(...) = delete`。

这样，如果某个 IType 真调用 TMEM 却忘记声明，JIT 会在编译期失败，而不是悄悄生成错误结果。

## 四臂资格实验

- A：当前无条件 512-column allocator；
- B：手写 no-TMEM oracle，只移除真实 allocator；
- C：manifest 版本，Llama-1B 自动选择 no-TMEM；
- D：真正使用 tcgen05 的正控，必须保留 TMEM marker 和数值正确性。

B/C 的 normalized SASS、资源与输出应等价；D 若误标为 0 必须编译失败。

## 不要许诺 2 CTA

manifest 只解决“不要申请不需要的 TMEM”。canonical Llama-1B 的 shared 与 register 仍各自限制 1 CTA/SM。资源能力系统本身可以在“正确、无稳定回退”时合入，但不能声称性能提升。

## Manifest 应怎样传播

能力必须从 IType 声明进入 compiler 汇总，再进入 physical kernel 申请。任一并发 IType 需要 TMEM，该 physical island 就必须申请；不能由 host 根据“通常不会走到”猜测。汇总还应 fail-closed：未知 IType 或缺失字段默认需要资源，避免静默生成错误 binary。

## 为什么按 Physical Island 汇总

manifest 的作用域不是整模型，也不是单条动态 instruction，而是共享同一 exact binary/驻留包络的并发集合。把 TMEM IType 切进独立 island 后，no-TMEM island 才可能获得独立合同；只在同一 megakernel 内加 `if` 不会自动改变 binary 资源属性。

## 练习：补一张清单

为四个 IType 写 `uses_tmem`、columns、证据来源和未知字段策略。构造一个错误标为 0 的真实 tcgen05 正控，要求编译或资格门失败。若它仍静默运行，manifest 尚未形成可执行合同。
