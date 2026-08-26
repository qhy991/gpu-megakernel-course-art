---
layout: lesson
title: "先 Ready，再入队"
slug: ready-before-queue
lesson: 28
stage: "进阶一 · 正确性、生命周期与调度"
stage_description: "处理 release/acquire、epoch、驻留死锁和 Ready-aware 调度。"
description: "把 producer→scheduler→queue→worker 的四棒接力写成发布协议，并区分 queue ACK 与 payload ACK。"
takeaway: "任务必须在依赖闭合后才对 worker 可见。"
beginner_question: "为什么任务要准备齐全后，才能放进待办队列？"
beginner_analogy: "餐单只有在食材齐全后才交给厨师，否则会占着灶台干等。"
beginner_skip: "可先忽略 queue ACK 与 payload ACK 的编码方式。"
image: /lesson28/lesson-28.png
tags: [Ready Queue, Publication, ACK, CLC]
read_time: 11
status: "SCHEDULER PROPOSAL · SOURCE-MAPPED"
prev_slug: ready-is-not-counter
prev_title: "Ready 不是一个数字"
next_slug: compile-barrier-to-ready
next_title: "把 Barrier 编译成 Ready 调度"
---

> **本课用词**：queue ACK 表示任务已被领取；payload ACK 表示数据已消费可复用；CLC 是硬件对 pending CTA 的取消/领取机制，不是 Ready 任务队列。

结论：当前 legacy static 和 canonical CLC 都是“先领取任务，再在任务内部等依赖”。真正的 Ready-aware scheduler 必须反过来：**依赖闭合后，任务才对 worker 可见。**

## 1. CLC 不是 Ready queue

当前三条路径的区别是：

| 路径 | 怎么领取任务 | 何时检查依赖 |
|---|---|---|
| legacy static | `%smid` 读取固定队列 | 领取后，在算子里 spin |
| canonical static | `blockIdx.x` 读取固定列 | 领取后，在算子里等 barrier |
| canonical CLC | 偷取一个尚未启动的 CTA/cluster ID | 领取后，在算子里等 barrier |

canonical CLC 的真实顺序是：

```text
CLC 取得 pending CTA ID
→ 读取 instruction descriptor
→ 发布给本 CTA 的各个角色
→ 进入具体 operator
→ operator 内等待 src barrier
```

NVIDIA 对 CLC 的定义也是“取消尚未启动的 thread block/cluster，并取得其 ID”，它并不知道你的 Transformer DAG 哪个节点已经 Ready。[Cluster Launch Control 官方说明](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cluster-launch-control.html)

所以：

> CLC 回答“接下来偷哪份工作”，不回答“这份工作的输入到了没有”。

## 2. 为什么 claim-then-wait 有危险

假设只能同时驻留 K 个 CTA：

```text
K个CTA都领取了尚未Ready的consumer
        ↓
它们在barrier上等待
        ↓
K个residency slot全部被占住
        ↓
真正的producer CTA仍未被调度
        ↓
producer无法产生Ready
```

这就是资源环：

```text
consumer 等 producer
producer 等 CTA slot
CTA slot 被 consumer 占住
```

源码已经能证明“领取后的等待”和“residency pinning”存在；整体死锁目前仍是条件性风险，尚未在 B200 上实测复现。

## 3. 正确的四棒接力

完整发布链不能缺任何一棒：

```text
Producer:
  写 payload
  release 发布 Ready

Scheduler:
  acquire Ready
  写 task descriptor
  release 发布 queue cell

Worker:
  acquire queue cell
  读取 descriptor 和 payload
```

于是形成：

```text
payload write
  happens-before
scheduler
  happens-before
worker payload read
```

CUDA 的官方消息传递模型正是“普通写 → release flag → acquire flag → 普通读”。[CUDA C++ 内存模型](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cuda-cpp-memory-model.html)

如果 scheduler 读取 Ready 时使用 relaxed，或者 queue cell 使用 relaxed 发布，接力链都会在中间断掉。

## 4. Queue ACK 和 Payload ACK 不是一回事

这是很容易混淆的地方：

- Queue ACK：worker 已把工作单复制出来，queue cell 可以放下一张工作单。
- Payload ACK：计算和所有 TMA 访问已经结束，输入/输出缓冲区才可以覆盖。
- Epoch：只有 Payload ACK 和所有旧引用都完成后，才能从 `e` 前进到 `e+1`。

因此，queue cell 的序号不能替代 ReadyGroup 的 `DONE/retired_epoch`。

NVIDIA 的 producer-consumer 示例同样使用两套单向同步：“buffer 已填满”以及“buffer 已消费、可重新填充”。[CUDA 异步 barrier](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/async-barriers.html)

## 5. 最适合你项目的 P0 设计

第一版不建议立即实现复杂的有界 MPMC payload queue。更稳健的结构是：

```text
不可变 instruction table
+
ReadyGroup descriptor
+
authoritative ready_epoch/task_state
+
ready bitmap（仅作为查找提示）
```

当前 canonical compiler 已经为每条 instruction 计算了完整的 `src_barriers + targets`。可以把具有相同依赖签名的任务编成 ReadyGroup：

```text
所有前驱完成
→ deps_left 最后一次 acq_rel 归零
→ release 发布 ready_epoch
→ 任意 CTA acquire 后 claim chunk
```

bitmap 只能表示“这里可能有活”，真正的执行许可仍来自：

```text
acquire ready_epoch
+
epoch-tagged CAS:
UNCLAIMED → CLAIMED
```

任务领取后，算子内部的全局 dependency spin 应变成断言；CTA 内 page/TMA/instruction-ring 的局部等待继续保留。

## 6. 为什么它可以支持 K ≥ 1

只要满足：

1. DAG 有限且无环，至少有一个 root Ready。
2. 任意 resident CTA 都能领取任意 Ready task。
3. 未 Ready 的任务不可领取。
4. 领取后的任务只等待本 CTA 发起的异步工作，不等待尚未领取的兄弟任务。
5. 完成后一定发布 successor 或 terminal。
6. queue full 时不能让所有 CTA 原地阻塞。

那么即使只有一个 CTA resident，它也能：

```text
root → successor → … → terminal
```

逐步把整个 DAG 做完。性能可能很差，但活性仍成立。

## 7. 不要预设它会更快

legacy 8B/P16 的源码精确计数是：

```text
836 VM tasks/layer
32 layers + LM head
= 26,900 tasks/token
```

其中 Attention 有：

```text
128 Partial + 8 Reduction
= 136 tasks/layer
= 4,352 tasks/token
```

static queue 没有动态 task-claim 原子开销；ReadyGroup 会增加 cursor、epoch、claim 和完成计数。它消除了无上界 spin，却引入了有界调度成本。

历史归档里，4K/P16 的 RR→离线 DAG 调度只变化 `-0.190%`，属于噪声；固定 SM pool 和 progressive wavefront 反而退化。这说明：

> Ready-aware 首先是活性和可组合性设计，不是自动提速按钮。大型 MatVec 仍需要充分利用148个SM。

## 8. 最关键的实验

先做一个小 DAG：

```text
Producer → 128 Partial → 8 Reduction → Reuse
```

扫：

```text
K = 1, 2, 4, 8, 16, 32, 64, 96, 128, 148
```

故意让 claim-then-spin 路径先领取至少 K 个未 Ready consumer：

- claim-then-spin：应被 watchdog 检出 timeout。
- Ready-only：必须对所有 `K ≥ 1` 完成。
- 每个 `(epoch, task)` 必须恰好执行一次。
- 记录 `claimed_unready`、spin cycles、queue full、stale completion。

再用上一课的精确边界：

```text
seq_len=1025
P=16
p_cur=12
```

把最新 KV block 填成 epoch poison，延迟 producer。ReadyGroup 版本必须做到：

```text
0 poison
0 mixed epoch
0 stale DONE
```

最后才做同会话 AB/BA latency、exact binary 的 ptxas/SASS，以及 NCU 的 atomic、barrier、eligible-warps 和 duration 审计。

证据边界：legacy 仍是 dirty `7309cec`；canonical 是 clean `c473de3`。Phase82 使用的是默认 static 模式，因此不能作为 CLC 或 ReadyGroup 的正确性证明。这里的 ReadyGroup 仍是经源码推导的设计提案，不是已实现成果。
