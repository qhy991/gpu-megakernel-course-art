---
layout: lesson
title: "为什么一个 Ready Bit 不够？"
slug: epoch-aba-ring
lesson: 22
stage: "进阶一 · 正确性、生命周期与调度"
stage_description: "处理 release/acquire、epoch、驻留死锁和 Ready-aware 调度。"
description: "解释 instruction ring 重用时的 epoch、ABA、ACK 和 backpressure，避免新旧代混淆。"
takeaway: "Ready 只证明本代可读，ACK 才保护槽位何时可复用。"
image: /lesson22/lesson-22.png
tags: [Epoch, ABA, Ring Buffer, ACK]
read_time: 8
status: "SOURCE-PROVEN · LIFETIME MODEL"
prev_slug: release-acquire-publication
prev_title: "Flag 到了，数据就一定到了吗？"
next_slug: residency-deadlock
next_title: "同步写对了，为什么程序还会卡死？"
---

> **本课用词**：epoch 区分循环缓冲区的数据代；ABA 是值回到原样导致观察者误认同一代；backpressure 阻止 producer 提前覆盖。

最重要的一句话：

> `READY` 表示“这一代可以读”；`ACK/finished` 表示“这一代已经没人再读，可以覆盖”。

上一课的 release/acquire 只解决第一句。环形缓冲区还必须解决第二句。

## 1. ABA 是什么？

同一个槽位反复使用：

| 使用次数 | epoch | phase | 内容 |
|---|---:|---:|---|
| 第一代 | 0 | 0 | Payload A |
| 第二代 | 1 | 1 | Payload B |
| 第三代 | 2 | 0 | Payload C |

phase 发生了：

```text
0 → 1 → 0
A → B → A
```

表面值重新变成了 `0`，但里面已经不是第一代数据。

如果生产者可以连续覆盖两次，一个还在等待第一代的慢消费者可能把第三代误认成第一代——这就是 ABA。

因此：

```text
phase = epoch & 1
```

只能区分相邻两代，不能独立承担完整身份识别。

## 2. 安全复用需要两份合同

发布合同：

```text
写 payload
→ arrived.release
→ arrived.acquire
→ 读取 payload
```

它保证“新数据确实可见”。

复用合同：

```text
最后一次读取/异步操作完成
→ finished.release
→ finished.acquire
→ 下一代覆盖槽位
```

它保证“旧用户确实已经离开”。

即使换成完整的 64 位 epoch，也不能省掉 ACK：epoch 能发现覆盖，却不能阻止数据已经被覆盖。

## 3. 你的 canonical controller 如何做

clean canonical 实现默认是两槽 instruction ring：

```text
i=0  → S0, generation 0
i=1  → S1, generation 0
i=2  → S0, generation 1
i=3  → S1, generation 1
i=4  → S0, generation 2
```

当 controller 准备执行 `i=2`、复用 `S0` 时，它必须：

1. 等待 `S0` 第一代的 `instruction_finished`。
2. 确认所有 worker 都已完成。
3. 销毁旧动态 semaphore。
4. 覆盖 instruction、scratch 和页映射。
5. 发布新的 `instruction_arrived`。

默认共有 12 个角色 warp，controller 不参与完成计数，因此 `instruction_finished` 等待其余 11 个 worker 的确认。

所以它真正的安全条件是：

> 同一个 slot 最多只有一个尚未确认的 generation。

到 `i=4` 时，phase 虽然再次回到原值，但 `S0` 的 generation 1 已经被全部确认，旧消费者不可能仍停留在 generation 0。

核心路径可在这份历史 canonical 源码快照中核对。

## 4. 为什么源码只允许 1 或 2 stages？

instruction slot 自己有完成确认，但物理 page 和 tensor 使用的是 `iter & 1` parity，并不会每次重新初始化。

两级流水时，`i+2` 想复用同一个 parity，必须先经过 `i` 的全员完成确认。若直接把流水深度改成 3 或 4，`i+2` 可能在 `i` 仍持有页面时携带相同 parity 被发布，安全证明就失效了。

所以“把 stage 数从 2 改成 4”不是普通性能旋钮，还需要重新设计 page/tensor 的 generation 与回收协议。

NVIDIA 的规范也明确把 parity 限定为当前或紧邻前一 phase；它不是无限代数的序号。[CUDA 异步 Barrier 文档](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/async-barriers.html)

## 5. ACK 必须代表“最后一次真实使用结束”

下面这些情况都会破坏协议：

- 漏掉一次 `page_finish`：后续指令永久等待。
- 重复 `finish`：barrier 可能提前翻相。
- 第一个 consumer 完成就代表所有 consumer 完成。
- TMA/WGMMA 只是发射完，尚未真正完成，就发布 ACK。
- semaphore 数量登记错误，销毁了未初始化对象或遗留旧对象。

因此每个 IType 都必须证明：

```text
claim 一次
→ wait 一次
→ 完成全部同步/异步访问
→ finish 恰好一次
```

仓库自己的IType 生命周期规则也把错误计数标为未定义行为。

## 6. 性能证据不要混淆两种 ring

仔细核对后：

- release-safe instruction ring 的 stage2/3/4 扫描只有实验提案，没有冻结实测结果。
- Phase73 的 instruction stage1/2 短测曾得到 `648.556 → 617.378 μs`，约 `1.0505×`；但后来100次审计发现旧 publication 漂移，因此该数字已经撤回。
- Phase99 的 ring3/4/6 实际是 UpGate **output ring**，instruction pipeline 始终固定为 stage2。深度4/6约快1.5%–1.7%，100/100 bitwise，但没有达到预注册采用门槛，所以被拒绝。Phase99 历史报告快照

这说明：

> 增大 ring 只能增加“容忍延迟的容量”；如果瓶颈是计算、store completion 或依赖链，更深的 ring 不会自动增加吞吐。
