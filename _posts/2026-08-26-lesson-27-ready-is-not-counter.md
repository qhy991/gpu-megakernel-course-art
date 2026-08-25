---
layout: lesson
title: "Ready 不是一个数字"
slug: ready-is-not-counter
lesson: 27
stage: "进阶一 · 正确性、生命周期与调度"
stage_description: "处理 release/acquire、epoch、驻留死锁和 Ready-aware 调度。"
description: "区分原子计数完整性、payload 可见性、代际身份和安全复用四层含义。"
takeaway: "计数器到达只证明事件数量，不自动证明数据、epoch 和生命周期。"
image: /lesson27/lesson-27.png
tags: [Ready, Atomic, Visibility, Lifetime]
read_time: 9
status: "SOURCE + MEMORY-MODEL GAP"
prev_slug: partial-attention-readygroup
prev_title: "一个 Partial Attention 到底在等什么？"
next_slug: ready-before-queue
next_title: "先 Ready，再入队"
---

> **本课用词**：atomicity 保证更新不丢；visibility 保证数据可见；identity 证明属于哪一代；lifetime 证明缓冲区尚未被覆写。

结论先说：你 legacy 8B Megakernel 的全局计数器能保证“加法不丢”，却没有完整保证“看到计数后，payload 一定可读”。canonical `c473de3` 已补上 release/acquire；如果未来做跨 token 常驻，还必须再加 ACK、epoch 和 backpressure。

## 1. 用快递理解四个概念

- payload：包裹。
- Ready：门铃——“本代包裹已经可以取”。
- ACK：签收回执——“消费者已经读完，可以覆盖缓冲区”。
- epoch：快递批次号——防止把上一代门铃误认成本代门铃。

legacy 协议近似是：

```text
写 payload
atomicAdd(counter)       // relaxed
消费者 volatile 轮询
读 payload
```

问题是：

```text
原子性 ≠ 内存排序
volatile ≠ acquire
```

`atomicAdd` 保证 counter 增量正确，却不自动把此前的普通写入/TMA 写入发布给其他 CTA；`volatile` 也不是跨线程同步原语。这一点由 NVIDIA 的 [原子函数语义](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cpp-language-extensions.html)和 [volatile 指南](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cpp-language-support.html)明确规定。

## 2. 源码审计结果

legacy dirty HEAD `7309cec`：

- QKV 完成 TMA store 后，执行 legacy `atomicAdd`。
- Partial/Reduction/O projection 用 `volatile int` 轮询 counter。
- 多处 GPU fence 已被注释。
- Partial 用普通 global store 写 O/LSE，Reduction 随后用 TMA 读取，还需要审计 generic→async proxy 的桥接。

因此它存在正式的内存模型缺口，但这次没有声称已经在 B200 上复现错误。

canonical clean `c473de3` 已改成：

```text
producer:
    payload 写完
    red.release.gpu.global.add

consumer:
    ld.relaxed.gpu.global 轮询
    fence.acquire.gpu
    读取 payload
```

这正是 [CUDA 内存模型](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cuda-cpp-memory-model.html)和 [PTX release/acquire pattern](https://docs.nvidia.com/cuda/parallel-thread-execution/)支持的消息传递形式。

不过，最终涉及 TMA 的路径仍应通过 SASS 与 poison litmus，确认所需的 global async-proxy bridge 确实存在。

## 3. 为什么短 correctness 会骗人

你的真实历史实验非常有说服力：

- Phase73：relaxed 版本只测20次，全部正确，约 `0.617 ms`。
- Phase79：扩到100次后出现漂移，撤回 `0.617 ms / 1.493×` 主张。
- Phase82：改为设备级 release/acquire 后，100/100 bitwise，通过时间约 `0.689 ms`。
- 保守 matched individual Graph 对照仍约 `1.343×`。

所以核心教训是：

> 并发错误不是“每次都会错”；20次正确只能说明错误窗口比较窄。

这里的 `1.343×` 也不能全部叫 launch 收益，它还包含常驻调度、page 生命周期、边界变化和 inter-op overlap。

## 4. 套回 KV head 0

对于 Llama-8B 的一个 GQA group：

```text
Q0、Q1、Q2、Q3：各8个block
K0、V0：各8个block
```

每个 Partial 都必须等待 `Q_READY`。但只有包含“当前 token 最新 KV block”的那个 partition，才必须额外等待 `KV_READY`。

设：

```text
N = ceil(seq_len / 16)
C = ceil(N / P)
p_cur = floor((N - 1) / C)
```

当 `seq_len=1025, P=16`：

```text
N=65, C=5, p_cur=12
```

legacy 源码却只让 `p=15` 等新 K/V；而 `p=15` 已为空，真正读取最新 block 64 的 `p=12` 没有等待。这是一个精确的源码级同步缺口，尚待 GPU 延迟/poison 实验复现。

## 5. 推荐的 ReadyGroup 合同

每个 `(layer, KV head, epoch)` 至少维护：

```text
epoch
produced      // 哪些Q/K/V块已经完成
published     // 哪些Partial已经发布
done          // 哪些Partial已经完成
refs / retired_epoch
```

正确顺序是：

```text
producer:
  等待全部异步写完成
  release/acq_rel 发布 produced

scheduler:
  acquire produced
  只发布已经 ready 的 Partial

worker:
  acquire 领取任务
  读 payload
  release 发布 done

最后一个 Partial:
  发布 Reduction

Reduction 完成:
  发布 ACK / retired_epoch

下一代:
  acquire ACK 后才允许覆盖 slot
```

只检查 epoch 不够：旧 worker 可能“检查通过后暂停”，slot 被重置成下一代，再回来污染新状态。必须同时有引用计数或队列 ACK，保证复用前已经没有旧参与者。

## 6. 可证伪实验

最关键的一条 GPU 实验是：

1. 固定 `seq_len=1025, P=16`。
2. 把最新 K/V block 填成带 epoch 的 NaN poison。
3. 故意延迟真正的 K/V producer。
4. 先让 `p=12` 尝试执行。
5. legacy 应能暴露 poison；ReadyGroup 必须持续零 mismatch。
6. 再注入一个延迟到下一 epoch 的旧 completion，验证它无法修改新 `done` mask。

性能上，源码计数估算显示 P16 当前 attention 依赖路径约有 `904 RMW/layer`，32层共 `28,928 RMW/token`，还不含无上界的轮询 load。保守 ReadyGroup 可降到约 `536 RMW/layer`；但动态队列本身也会引入原子操作，所以目前只能叫“有优化空间”，不能先宣布速度收益。

证据边界也要保留：legacy 是实时 dirty worktree；canonical 是 clean `c473de3`；当前 per-token host reset 加 kernel completion 提供了粗粒度代际保护，但它还不是跨 token persistent engine。
