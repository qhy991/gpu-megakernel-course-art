---
layout: lesson
title: "双 CTA Poison Litmus"
slug: two-cta-litmus
lesson: 33
stage: "进阶二 · 把依赖编译成可证伪系统"
stage_description: "把 barrier 转成 Ready 状态机，再用 poison、exact binary 和 manifest 闭合证据。"
description: "把 poison 实验拆成 Host 准入、共享状态、Producer、Consumer 和 ACK 五层伪代码。"
takeaway: "Litmus 必须锁死执行顺序，才能区分真正的同步保证与偶然成功。"
image: /lesson33/lesson-33.png
tags: [Litmus, Two CTA, Pseudocode, Memory Model]
read_time: 10
status: "DIAGNOSTIC PSEUDOCODE · NOT IMPLEMENTED"
prev_slug: poison-sync-bugs
prev_title: "用 Poison 抓出同步 Bug"
next_slug: source-to-b200-evidence
next_title: "从源码到 B200 的四层证据链"
---

> **本课用词**：litmus 是最小并发语义测试；双 CTA 表示 producer/consumer 位于不同 block；host admission 先证明两个 CTA 能同时进入。

这项实验不测 Megakernel 有多快，而是回答一个更基础的问题：

> Producer 宣布“数据好了”以后，另一个 SM 上的 Consumer 是否真的能读到正确数据？Consumer 用完以后，Producer 是否真的可以安全覆盖？

最重要的两个门铃：

- `READY(e)`：第 `e` 代数据已经落地，允许开始读。
- `ACK(e)`：第 `e` 代数据已经读完，允许下一次覆盖。

## 1. Host：确保两个 CTA 真能同时运行

```cpp
compile_exact_sm_100a_cubin();

set_dynamic_smem(kernel, 128_KiB);   // 每 CTA
active = occupancy(kernel, 128, 128_KiB);

assert(active == 1);
assert(active * sm_count >= 2);

launch_cooperative(
    grid  = 2,
    block = 128,
    smem  = 128_KiB
);
```

128 KiB 是“每个 CTA”的资源。B200 每个 SM 无法同时容纳两个这样的 CTA，因此两个 CTA 会落在不同 SM；但最终仍必须用精确 cubin 的 occupancy 查询确认，不能只靠纸面计算。Occupancy API 返回指定 kernel 每个 SM 最多可驻留的 block 数。[NVIDIA Occupancy API](https://docs.nvidia.com/cuda/cuda-runtime-api/group__CUDART__OCCUPANCY.html)

cooperative launch 保证这两个 CTA 都被准入；普通 launch 加自旋并不能提供这个保证。[NVIDIA Driver API](https://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__EXEC.html)

kernel 内再核验：

```cpp
entered_mask == 0b11;
smid[0] != smid[1];
```

## 2. Producer：先送达，再发 READY

```cpp
for (epoch e = 1; e <= N; ++e) {
    wait_acquire(ACK, e - 1);       // 上一代已经用完

    fill_global_with_poison(e);     // 先放明显错误的旧数据
    store_release(POISON_READY, e);

    wait_acquire(PRIMED, e);        // Consumer 已经读过 poison

    fill_shared_with_expected(e);
    __syncthreads();

    if (threadIdx.x == 0) {
        tma_store_async(global, shared);
        tma_commit();

        tma_wait_group_0();         // 完整等待目标 global 写入完成
        store_release(READY, e);    // 此后才允许 Consumer 读取
    }

    wait_acquire(ACK, e);
}
```

关键顺序只有三步：

```text
TMA store
    ↓
完整 wait_group 0
    ↓
release READY
```

不能使用 `.wait_group.read 0`：它只保证 TMA 已经读完 shared source，不保证 global destination 已经完成。PTX 对两者有明确区分。[NVIDIA PTX ISA](https://docs.nvidia.com/cuda/parallel-thread-execution/#data-movement-and-conversion-instructions-cp-async-bulk-wait-group)

## 3. Consumer：先 acquire READY，全部读完再 ACK

```cpp
for (epoch e = 1; e <= N; ++e) {
    wait_acquire(POISON_READY, e);

    verify_poison(e);               // 证明测试起点确实是旧数据
    store_release(PRIMED, e);

    // 每个实际读取 payload 的线程都观察一次 acquire。
    wait_acquire(READY, e);

    validate(epoch, index, guard);
    reduce_mismatch_count();

    __syncthreads();                 // 整个 CTA 都已经读完

    if (threadIdx.x == 0) {
        if (mismatch_count == 0)
            store_release(ACK, e);
        else
            store_release(ABORT, ERROR_PAYLOAD);
    }
}
```

这里不能让某个线程检查完自己的部分就提前 ACK。ACK 的含义是：

> 整个 Consumer CTA 对这一代 payload 的最后一次读取已经结束。

device-scope release/acquire 正是不同 CTA 之间建立 payload 可见性的基本模式。[CUDA C++ Memory Model](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cuda-cpp-memory-model.html)

## 4. 三个故意写错的版本

| 负控 | 故意破坏什么 | 可能观察到什么 |
|---|---|---|
| READY 放到 TMA wait 前 | “数据落地后才能发布” | 读到 poison 或半新半旧 |
| acquire 改成 relaxed | 去掉跨 CTA happens-before | 硬件可能暂时掩盖，未失败也不能证明安全 |
| ACK 放到读取前 | “用完后才能覆盖” | Producer 写入下一代，出现 mixed epoch |

其中前后两个应增加确定性延迟握手，使错误版本稳定被定罪；`relaxed` 负控可能因为 B200 的实际一致性表现而长期不暴露，只能作为诊断项。

## 5. Watchdog 不是简单 `return`

任何轮询都必须有超时：

```text
timeout
  → release ABORT
  → 唤醒另一 CTA
  → Producer 检查是否有 outstanding TMA
  → 原 issuer lane 执行完整 wait/drain
  → 两个 CTA 安全退出
```

不能直接 `trap` 或提前退出：另一个 CTA 可能永远卡在门铃上，尚未完成的 TMA 也可能继续访问已经失效的 shared memory。

Host 还要把每个用例放在独立子进程，并设置硬超时，以处理 device watchdog 无法收回的非法访问或永久 barrier。

## 6. 最终必须检查 SASS

GOOD 版本至少要证明：

```text
Producer:
UTMASTG → commit → full wait → release READY

Consumer:
acquire READY → payload LDG → CTA 汇合 → release ACK
```

而且从任何 TMA issue 到任何 `EXIT` 的控制流路径，都必须经过 full-wait cleanup。不能只在反汇编文本中找到一条 wait 就算通过。

## 当前代码状态

实时核验的 canonical 仓库仍为 clean `c473de3d`：

- 已有 `sm_100a` NVRTC → cubin 编译链。
- 已有 shared→global TMA store、commit、完整 wait wrapper。
- launch helper 已支持 cluster 和 PDL。
- 当前 helper 尚未暴露 cooperative 参数，不过 Driver binding 和 B200 都支持；可直接调用 cooperative API，或给 helper 增加对应 launch attribute。

因此，这一课定义的是一份可落地的实验合同；litmus 尚未写入仓库，也尚未在 B200 上运行。下一课应把它变成真正的 JIT 测试，并逐条核验 PTX、SASS、负控定罪率与安全退出。
