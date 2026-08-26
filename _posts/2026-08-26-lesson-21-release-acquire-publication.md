---
layout: lesson
title: "Flag 到了，数据就一定到了吗？"
slug: release-acquire-publication
lesson: 21
stage: "进阶一 · 正确性、生命周期与调度"
stage_description: "处理 release/acquire、epoch、驻留死锁和 Ready-aware 调度。"
description: "用跨 CTA producer-consumer 解释为什么原子 flag 正确不等于 payload 已可见。"
takeaway: "完成信号必须在数据之后 release，读取数据必须在看到信号后 acquire。"
beginner_question: "看到“完成”标志时，数据为什么可能还没准备好？"
beginner_analogy: "厨师要先把菜放到窗口再按铃；服务员听见铃后，才能放心取菜。"
beginner_skip: "可先忽略 release/acquire 对应的指令和语法。"
image: /lesson21/lesson-21.png
tags: [Release, Acquire, Memory Ordering, CTA]
read_time: 10
status: "SOURCE + HISTORICAL CORRECTNESS EVIDENCE"
prev_slug: dynamic-tail
prev_title: "Dynamic Tail：最后半块不做整块工作"
next_slug: epoch-aba-ring
next_title: "为什么一个 Ready Bit 不够？"
---

> **本课用词**：release 发布之前的写入；acquire 让之后的读取观察已发布数据；payload 是被 flag 保护的实际数据。

先记住本课最重要的式子：

```text
Control readiness ≠ Data visibility
看到“完成计数” ≠ 一定看到对应的新数据
```

## 1. 用取餐柜理解

假设：

- 厨师把餐放进柜子：写入 `payload`
- 屏幕显示“可以取餐”：更新 `flag`
- 顾客看到屏幕：读取 `flag`
- 顾客打开柜子：读取 `payload`

正确顺序应该是：

```text
放好餐 → 亮取餐灯 → 看见灯 → 打开柜子
```

如果协议只保证“灯的更新是原子的”，却没有规定餐和灯之间的顺序，顾客可能看到绿灯，但内存模型并不保证柜子里的新餐已经对他可见。

这不是说硬件每次都会这样，而是程序没有获得“绝不会这样”的规范保证。

## 2. 四个很容易混淆的概念

| 概念 | 解决什么 | 不解决什么 |
|---|---|---|
| `volatile` | 让代码重新访问这个地址 | 不提供跨线程同步和内存顺序 |
| atomicity | 多个 CTA 更新计数时不会丢更新 | relaxed atomic 不自动发布 payload |
| ordering | 规定 payload 与 flag 的先后关系 | 不决定保证覆盖哪些线程 |
| scope | 决定 block、GPU 或 system 中谁受保证 | scope 正确不能替代 ordering |

CUDA 的传统 `atomicAdd()` 是 device-scope，但内存顺序是 relaxed，只保证原子更新，不自动产生 fence。[NVIDIA CUDA 文档](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cpp-language-extensions.html#legacy-atomic-functions)

CUDA C++ 的 `volatile` 也不适合充当跨线程同步原语；它既不保证 atomicity，也不保证 memory ordering。[NVIDIA volatile 说明](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cpp-language-support.html#volatile-qualified-variables)

## 3. 你的 legacy 8B 路径有什么风险？

历史源码中反复出现同一种模式：

```cpp
// Producer CTA
store_payload();
atomicAdd(flag, 1);       // relaxed

// Consumer CTA
while (*(volatile int*)flag < target) {
    // spin
}
load_payload();
```

它存在于：

- PartialAttention → AttentionReduction
- AttentionReduction → OProj
- OProj → UpGate
- UpGate → DownProj
- DownProj → 下一层或 LM head

例如 PartialAttention 写完 partial 后，GPU fence 被注释掉，随后用 `atomicAdd` 更新计数；AttentionReduction 则通过 `volatile` 轮询计数，然后直接加载 partial。legacy 源码快照

这里：

- `atomicAdd` 保证计数不会被并发更新写坏；
- `.gpu`/device scope 足以覆盖同一张GPU上的不同SM；
- 但缺少 release/acquire ordering；
- `warp::sync()`、CTA group sync 只能同步本 CTA；
- `tma::store_async_wait()`不能代替消费者侧 acquire。

所以准确结论是：

> legacy 8B 的跨SM发布协议缺少规范保证，属于高优先级正确性风险；但目前没有证据证明某次8B坏 logits 就是它造成的。

## 4. canonical mk-v2 如何修复？

canonical helper 使用的是：

```cpp
// Producer
write_payload();
red.release.gpu.global.add(flag, 1);

// Consumer
do {
    value = ld.relaxed.gpu.global(flag);
} while (value != target);

fence.acquire.gpu;
read_payload();
```

含义是：

1. Producer 写 payload。
2. `release` 发布完成计数，并约束此前写入。
3. Consumer 用廉价的 relaxed load 循环等待。
4. 只有观察到目标值后，才执行一次 acquire fence。
5. acquire 之后再读 payload。

“relaxed load读到对应发布值，然后执行 acquire fence”是PTX正式定义的 acquire pattern；它与 producer 的 release pattern建立 `synchronizes-with`。[PTX release/acquire 规范](https://docs.nvidia.com/cuda/parallel-thread-execution/#release-and-acquire-patterns)

你的 canonical 默认还设置了：

```cpp
RELEASE_GLOBAL_BARRIERS = true
```

对应实现见 canonical helper快照。

`.gpu` scope只覆盖同一GPU。若未来涉及CPU或另一张GPU，需要重新审计 `.sys` scope、内存类型和硬件支持。

## 5. 这个问题真的复现过吗？

在同系 Hazy 1B 实验里复现过：

- Phase73：短测20次全部 bitwise，通过，得到约 `0.617 ms`
- Phase79：扩大到100次后出现漂移，旧成绩被撤回
- Phase80–81：定位到 producer barrier只有 relaxed publication
- 改成 GPU-scope release、保留 acquire 后：四个路径均达到 `100/100 exact、bitwise`
- Phase82：在正确协议上重新开放 overlap，达到约 `0.689 ms`

证据见 Phase79–82报告快照。

要注意：不是“release让程序变快”。真实因果是：

```text
release/acquire 修复正确性
        ↓
系统才有资格安全开放 inter-op overlap
        ↓
合法 overlap 带来性能收益
```

## 6. 为什么 Megakernel 特别容易踩坑？

普通顺序 CUDA kernels 之间有明确的执行边界。Megakernel 把几十个阶段放进同一个长寿命 kernel：

```text
loader → consumer → reducer → storer → 下一层
```

这些角色可能分布在不同 CTA、不同 SM，因此原来由 kernel/Graph 边界提供的顺序，现在必须由内部协议重新表达。

所以 persistent Megakernel 的每条数据边都需要同时回答：

```text
谁写数据？
谁发布完成？
谁等待？
等待原语有 acquire 吗？
scope 覆盖双方吗？
buffer 何时允许复用？
```

此外，release/acquire也不能代替TMA自己的完成等待和proxy规则；两套协议都必须正确。

一句话收束：

> Flag 是“可以取了”的通知；release/acquire 才是“通知出现时，东西确实已经放好”的交接合同。
