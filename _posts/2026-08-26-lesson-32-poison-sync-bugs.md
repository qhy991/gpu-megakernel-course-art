---
layout: lesson
title: "用 Poison 抓出同步 Bug"
slug: poison-sync-bugs
lesson: 32
stage: "进阶二 · 把依赖编译成可证伪系统"
stage_description: "把 barrier 转成 Ready 状态机，再用 poison、exact binary 和 manifest 闭合证据。"
description: "设计毒值、延迟门和故障签名，让缺失 TMA 等待或 release/acquire 的错误稳定暴露。"
takeaway: "正例全绿不够；错误实现必须被测试稳定杀死。"
image: /lesson32/lesson-32.png
tags: [Poison, Mutation Test, TMA, Correctness]
read_time: 8
status: "DIAGNOSTIC DESIGN · UNMEASURED"
prev_slug: cuda-controller-memory-order
prev_title: "把 CPU Ready 模型翻译成 CUDA Controller"
next_slug: two-cta-litmus
next_title: "双 CTA Poison Litmus"
---

> **本课用词**：poison 是预填的可识别错误值；mutant 是故意破坏协议的实现；fault signature 是预注册的错误模式。

这一课不优化速度，而是先造一个“同步报警器”：

> 正确代码不能报警；故意破坏协议后，报警器必须有能力抓住它。

## 1. Poison 是什么

假设当前是第 `E` 轮：

```text
Producer 应该写入：E
Global buffer 原来保存：E-1
```

`E-1` 就是 poison。Consumer 看见 `READY(E)` 后，如果仍读到：

- 全部 `E-1`：数据还没写完；
- 一部分 `E-1`、一部分 `E`：mixed epoch；
- `E` 但 guard 不对：部分写入或地址错误。

实际测试不会只存一个数字，而会给每条记录加入：

```cpp
{ epoch_low, epoch_high, index, guard_hash }
```

这样能够精确判断“旧数据、混合数据还是错误地址”。

## 2. 三种协议

| 实验臂 | 顺序 | 正确解释 |
|---|---|---|
| 正确 | TMA store → wait 0 → release Ready → acquire Ready → read | 必须始终零错误 |
| 提前发布 | Ready 发布时 TMA 尚未完成 | 允许读到 poison |
| 没有 acquire | TMA 已完成，但 Consumer 只 relaxed poll | 内存模型不保证 payload 可见 |

图中红色“错误 A”是更强的测试夹具校准：

```text
先发布Ready
→ 强制等Consumer读完poison
→ Producer才写数据
```

它不是对生产错误的原样模拟，而是为了证明报警器没有失明，必须 `100/100` 抓到 poison。

真实的“发出 TMA 后立即 Ready，但不执行 wait”仍然是错误协议；然而 TMA 引擎可能在 Consumer 读取前自己完成，所以它不保证每次表现出错误。

黄色“没有 acquire”也是同理：

> 连续一百万次没读到旧数据，只能说“弱行为尚未观察到”，不能说 relaxed 协议已被证明安全。

## 3. canonical c473 冻结版本做对了什么

原始课程审计记录的是 `verda-b200x4` 上的以下冻结状态：

```text
仓库  /home/qinhaiyan/megakernel-canonical-20260811
HEAD  c473de3d5c90...
状态  clean
目标  sm_100a
```

QKV 的源码顺序是：

```text
Q/K/V 写入 shared
→ TMA shared→global
→ cp.async.bulk.wait_group 0
→ red.release.gpu.global.add
```

Attention Consumer 则是：

```text
ld.relaxed.gpu.global 轮询
→ fence.acquire.gpu
→ 发起 Q/K/V load
```

PTX 对非 `.read` 的 `cp.async.bulk.wait_group 0` 定义包含等待 destination write 完成，并让结果对发起线程可见。[NVIDIA PTX bulk wait-group](https://docs.nvidia.com/cuda/parallel-thread-execution/#data-movement-and-conversion-instructions-cp-async-bulk-wait-group)

单GPU跨CTA同步使用 GPU/device scope；block scope只覆盖同一个线程块。[CUDA C++内存模型](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/cuda-cpp-memory-model.html)

因此当前源码意图是有根据的。但目前没有与这次配置精确绑定、冻结下来的最终 cubin/SASS，所以不能把“源码顺序正确”扩大成“B200机器码已经完成审计”。

## 4. 两个 CTA 怎么做实验

建议启动两个很小的 cooperative CTA：

```text
CTA 0：Producer
CTA 1：Consumer
```

当前 B200 实测条件：

```text
148 SM
支持 cooperative launch
每个测试 CTA 使用128 KiB shared memory
```

由于一个 SM 放不下两个这样的 CTA，再检查 occupancy 和 `%smid`，就能要求 Producer、Consumer 实际驻留在不同 SM。Cooperative launch 的容量仍需根据最终 kernel 资源预检查。[CUDA cooperative launch](https://docs.nvidia.com/cuda/cuda-runtime-api/group__CUDART__EXECUTION.html)

每轮流程：

```text
1. Buffer保留上一轮E-1
2. Consumer先确认自己确实能读到E-1
3. Producer在shared中生成E
4. 按当前实验臂执行TMA和Ready协议
5. Consumer逐条检查epoch/index/guard
6. Consumer发布ACK
7. Producer收到ACK后才能进入E+1
```

ACK 很重要，否则 Producer 可能在 Consumer 检查期间就覆盖下一代数据。

## 5. 为什么先用普通 Global Load

第一阶段让 Consumer 使用普通 global load：

```text
Producer TMA completion
+ release/acquire
+ Consumer普通读取
```

这样失败原因比较单一。

它通过以后，再增加 Consumer TMA-load 版本：

```text
generic读取通过
TMA读取失败
```

此时问题便可以缩小到 Consumer 侧的 generic→async proxy 路径，而不是把两端的 TMA 问题混在一起。

## 6. 验收标准

| Gate | 必须满足 |
|---|---|
| 准入 | 两个CTA均启动、不同SM、无超时 |
| 报警器校准 | 强制提前Ready负控 `100/100` 读到poison |
| 正确协议 | 4个seed × 100,000轮，零poison、零mixed、零timeout |
| 无acquire诊断 | 失败可定罪；没失败只能写“未观察到” |
| Epoch/ACK | 旧epoch任务不能修改新epoch状态 |
| 最终机器码 | 保存exact cubin，确认TMA wait、release、acquire、payload load顺序 |

每个等待循环还必须有 watchdog。发现超时时，两个 CTA 都应安全退出；不能直接让一个 CTA `trap`，留下另一个永久自旋。

## 7. Litmus 不是 Benchmark

Poison 测试会加入：

- 数据填充；
- 强制延迟；
- watchdog；
- 大量计数器；
- 错误记录；
- cooperative admission。

这些都会改变寄存器、内存流量和调度。

因此必须生成两套独立制品：

```text
LITMUS binary：验证协议，会故意制造极端情况
PERF binary：删除poison、delay和调试计数，正式计时
```

它们分别保存自己的源码、编译参数和二进制哈希。消防演习耗时不能当作商场正常营业速度。
