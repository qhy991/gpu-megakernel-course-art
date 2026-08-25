---
layout: lesson
title: "怎样证明 READY/ACK 协议真的安全？"
slug: lesson-54-poison-litmus
lesson: 54
stage: "阶段四 · 用受控实验替代性能故事"
stage_description: "把资源、工作供给、内存序和 benchmark contract 拆成可以逐项推翻的实验。"
description: "用确定性 poison、握手门和 fault signature，让 READY_EARLY 与 ACK_EARLY 必然暴露。"
takeaway: "正例全绿不够；坏协议必须按预期失败，测试才算通过。"
image: /lesson54/canonical_r1c_poison_litmus_16x9.png
tags: [Poison Litmus, Memory Ordering, Mutation Test, Epoch]
read_time: 15
status: "DIAGNOSTIC PROPOSAL · UNMEASURED"
prev_slug: lesson-53-page-ready-r1c
prev_title: "三页以后还能流水吗？把 64 KiB 大门拆成两扇"
---

## 真实的一页怎样映射到 warp

canonical N=2048 时，一个 32 KiB page 由两笔 16 KiB TMA 填充；4 个 local consumer warp 各读连续 8 KiB：

- W0：byte `[0,8192)`，来自 TMA0；
- W1：byte `[8192,16384)`，来自 TMA0；
- W2：byte `[16384,24576)`，来自 TMA1；
- W3：byte `[24576,32768)`，来自 TMA1。

因此，只延迟 TMA1 时，稳定错误掩码应精确为 `1100`。

## 负控 A：READY_EARLY

先把整页写成重复的 `POISON(e)` tag。producer 只让 READY 统计 TMA0 的 16 KiB，并把 TMA1 锁在 probe 完成之后。

四个 consumer 等 READY 后立即读取：

- W0/W1 必须看到当前 epoch；
- W2/W3 必须看到 poison；
- bad mask 必须是 `1100`。

这不是 sleep 或概率调度。握手建立严格顺序：

```text
READY acquire < W2/W3 read poison < PROBE_DONE < issue TMA1
```

GOOD 版本则让两笔 TMA 都挂到 `expect_tx(32768)`，返回后 mask 必须是 `0000`。

## 负控 B：ACK_EARLY

暂停 W3 的最后读取，先让 W0–W2 读取并 ACK。

正确 `FINISHED expected=4` 时，loader 不能覆写；先释放 W3，W3 读取旧 epoch 并发第4个 ACK，之后才覆写。

错误 `expected=3` 时，第三个 ACK 就让 loader 获得 reuse 权。实验强制先完成下一 epoch 覆写，再放行 W3，于是 W3 必然读到 `NEXT(e+1)`。

## 三层 Verdict 必须分开

```text
DEVICE STATUS ≠ SUBJECT OUTCOME ≠ TEST VERDICT
```

负控可能 CUDA_SUCCESS 返回，但 subject 读到 poison。此时被测程序失败，mutation test 反而是 `PASS_MUTANT_KILLED`。

`NO_ACQUIRE` 即使 100 次全绿也只能标 `INCONCLUSIVE_BY_DESIGN`：硬件可能暂时表现更强，“没有保证”并不要求每次都观察到错误。

## 历史为什么提醒我们不能只跑正例

Phase73 的 relaxed direct 在短 20 次中幸存，但 resident Graph 已漂移；Phase79 扩到100次后 relaxed direct 也漂移，`0.617 ms / 1.493×` 被撤回。release 修复后才获得 100/100 bitwise。

那次修的是跨 CTA instruction publication，不是 R1c page protocol；它只能旁证“数据必须先于完成信号被发布”。

## Debug 与 Perf 必须两个 Hash

poison、gate、trace、heartbeat 会改变资源和调度。因此 debug-litmus CUBIN 与 release-perf CUBIN 必须分别冻结 hash。

任何把 debug latency 当性能，或用 release binary 运行缺少定向可观察性的 fault matrix，都应判无效。

