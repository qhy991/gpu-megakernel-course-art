---
layout: lesson
title: "把 CPU Ready 模型翻译成 CUDA Controller"
slug: cuda-controller-memory-order
lesson: 31
stage: "进阶二 · 把依赖编译成可证伪系统"
stage_description: "把 barrier 转成 Ready 状态机，再用 poison、exact binary 和 manifest 闭合证据。"
description: "把 Atom→Group→Worker→ACK 状态机映射到 CUDA 原子、release/acquire 和 epoch 生命周期。"
takeaway: "relaxed 用于找路，release/acquire 用于数据交接，ACK 用于代际复用。"
beginner_question: "GPU 上的多个执行者怎样安全交接任务和数据？"
beginner_analogy: "像接力赛：先交棒，再确认对方接到，最后才能把这根棒交给下一轮。"
beginner_skip: "可先忽略 CUDA 原子 API 和具体内存顺序指令。"
image: /lesson31/lesson-31.png
tags: [CUDA Controller, Atomics, Release Acquire, Epoch]
read_time: 10
status: "CUDA CONTROLLER PROPOSAL · SOURCE-MAPPED"
prev_slug: one-worker-dag
prev_title: "一个 Worker 也能跑完整张 DAG"
next_slug: poison-sync-bugs
next_title: "用 Poison 抓出同步 Bug"
---

> **本课用词**：relaxed 不建立 payload 可见性；acq_rel 同时汇聚先前发布并发布自身更新；controller 维护 Ready 状态和任务领取。

这节课最重要的一句话是：

> Claim 解决“谁来做”，Acquire 解决“能不能读”，ACK 解决“什么时候可以覆盖”。

## 1. 把它想象成取快递

- `bitmap=1`：有人按门铃，只是提示这里“可能有任务”。
- `ready_epoch.acquire`：检查快递真的已经送到，而且内容可见。
- `lease CAS`：锁住当前这一批快递，防止仓库在你读取时换成下一批。
- `cursor.fetch_add`：领取唯一号码，决定你执行哪个任务。
- `task CAS`：最终验票，确保任务不会执行两次。
- `ACK + refs=0`：所有人都离开后，仓库才能复用。

所以看到 bitmap 绝不等于任务已经可以执行。

## 2. 冻结版本 c473 实际是什么

原始课程审计记录的是 `verda-b200x4` 上的 canonical 冻结版本：

- HEAD：`c473de3d5c90...`
- 工作树干净
- 当前仍然是 `claim/fetch → operator 内等待`
- 尚未实现图中的 Ready Controller

当前正确的数据可见性链大致是：

```text
Producer 写 payload
→ 等待 TMA store 真正完成
→ red.release.gpu.global.add(counter)

Consumer
→ ld.relaxed 轮询 counter
→ fence.acquire.gpu
→ 读取 payload
```

这条链本身是合理的。特别是 QKV 等路径，确实先执行 `cp.async.bulk.wait_group 0`，再发布完成计数。

但现有 `red.release` 不返回旧值，因此 producer 不知道：

```text
“我是第几个完成的？”
“我是不是最后一个？”
“现在该不该唤醒 successor？”
```

所以当前的 CLC `GLOBAL_WORK_QUEUE` 也不是 Ready Queue——它只是领取预制 instruction，领取之后仍可能进入 operator 等待依赖。

## 3. Ready Controller 的核心热路径

简化后的设计如下：

```cpp
gid = scan_bitmap_relaxed();        // 只找候选

e = ready_epoch.load(acquire);      // 输入真的可见

lease_CAS(e, OPEN, refs + 1);       // 锁住这一代

j = cursor.fetch_add(1, relaxed);   // 领取唯一任务号

task_CAS(e, UNCLAIMED, RUNNING);    // exactly once

execute_task();                     // Loader / Compute / Storer

old = atom.fetch_add(1, acq_rel);   // 发布输出并汇聚producer

if (old + 1 == target) {
    if (deps_left.fetch_sub(1, acq_rel) == 1) {
        successor.ready_epoch.store(e, release);
        bitmap.set_relaxed(successor);  // 只是提示
    }
}

task.store(DONE, release);
lease.refs--;
```

这里有三个不同层次：

1. `cursor` 只是快速分票。
2. `task CAS` 才是最终的 exactly-once 保证。
3. `ready_epoch acquire` 才允许读取输入数据。

## 4. 为什么需要 release/acquire

假设两个 CTA 分别写 `X` 和 `Y`：

```text
P0：写X → counter 0→1
P1：写Y → counter 1→2
```

若两个 RMW 使用 `acq_rel`，最后到达的 P1 可以汇聚前面 P0 的发布，再把完整的 `X+Y Ready` 发布给消费者：

```text
X/Y payload
→ Atom acq_rel fan-in
→ Group pending acq_rel fan-in
→ ready_epoch release
→ Worker ready_epoch acquire
→ 安全读取X/Y
```

普通 `atomicAdd` 只能保证数字不丢，不能自动证明 payload 可见；CUDA 的旧式原子函数默认是 relaxed，也不会自动充当内存栅栏。[CUDA 原子函数](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cpp-language-extensions.html)

跨 CTA 应使用 device-scope release/acquire；block scope 不足以同步另一个 CTA。[CUDA C++ 内存模型](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cuda-cpp-memory-model.html)

TMA 还属于异步代理，必须先证明对应 store 已完成，再发布 Ready，不能把“已经发出 TMA”当成“数据已经可读”。[PTX ISA](https://docs.nvidia.com/cuda/parallel-thread-execution/)

## 5. 最隐蔽的问题：epoch ABA

没有 lease 时可能发生：

```text
Worker：看到 Ready(epoch=e)
Worker：暂停

Retirer：看到 refs=0
Retirer：把槽位重置为 epoch=e+1

Worker：恢复
Worker：修改了已经属于 e+1 的任务
```

仅仅在任务里携带 epoch 仍然不够，因为“检查 epoch”和“开始操作”之间存在空隙。

正确方案是把：

```text
epoch + phase + refs
```

打包进同一个原子字，用一次 CAS 同时完成：

```text
确认 epoch 正确
确认 phase 仍为 OPEN
refs 加一
```

回收时顺序必须是：

```text
OPEN
→ RETIRING        // 先关门，禁止新 Worker
→ 等 refs == 0
→ RETIRED
→ 初始化 epoch+1
```

这就是图中 ACK 的真正意义：不只是“计算结束”，而是“旧一代已经没人再碰”。

## 6. 在 B200 上怎样落地

第一版建议：

- Controller warp 只有 lane 0 扫 bitmap、acquire、claim。
- 领取成功后，32 lanes 继续复用现有的两次 warp-wide 搬运，把256B instruction 放入 shared ring。
- Loader、Consumer、Storer 主体尽量不动。
- 148个 CTA 应旋转 bitmap 起点，不能全部争抢最低 bit。
- P0 先用 `cluster_size=1`；cluster=2 必须按两个 CTA 一个 bundle 领取并共同 ACK。
- 保留现有 reuse waits：输入 Ready 与输出缓冲区可覆盖是两个不同条件。
- 保留 QKV 的细粒度 subregion 发布，不能全部退化成 instruction 尾部发布。
- Ready 元数据放 side table，不扩展现有固定256B instruction ABI。

## 7. 两个必须实测的实现方案

不能预判谁更快：

- Arm A：保留 `RED release`，由 controller observer 检测 counter 达标，再发布 successor。
- Arm B：改为返回旧值的 `ATOM acq_rel`，最后到达的 producer 直接推送 successor。

Arm A 的 producer 更轻，但需要轮询；Arm B 推进更及时，但增加返回值、依赖链和更强内存序。

最终必须依次检查：

```text
correctness / poison test
→ K=1..148 活性测试
→ ptxas 寄存器、栈和 spill
→ exact cubin 的 SASS
→ NCU 机制指标
→ 无 profiler 的配对延迟
```

因此，图中的 Ready Controller 是已经完成源码级设计的下一步，不是当前 c473 已实现的性能结果。下一课最适合讲：如何用“延迟写入 + poison 数据”在 B200 上确定性抓出错误的 Ready publication。
