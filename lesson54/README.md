<!--
本文由 scripts/sync_lesson_readmes.rb 从对应的 _posts 文章确定性生成。
请编辑课程原文后重新运行同步脚本，不要单独修改本文件。
-->

# 第 54 课｜怎样证明 READY/ACK 协议真的安全？

![第 54 课：怎样证明 READY/ACK 协议真的安全？](./canonical_r1c_poison_litmus_16x9.png)

> 用确定性 poison、握手门和 fault signature，让 READY_EARLY 与 ACK_EARLY 必然暴露。

## 零基础先看这里

- **它在解决什么：**程序运行正确，为什么还要故意制造错误？
- **把它想成：**门锁不能只用正确钥匙测试；还要故意用错钥匙，并确认它确实打不开。
- **这次先不用懂：**可先忽略 poison 数值、warp 掩码和 watchdog 实现。

## 本课结论与证据状态

- **一句话结论：**正例全绿不够；坏协议必须按预期失败，测试才算通过。
- **证据状态：**DIAGNOSTIC PROPOSAL · UNMEASURED
- **怎么看这个标签：**它表示结论的来源与适用范围，不是课程难度；可查看[中文证据规则](../evidence.md)。

## 完整课程正文

> **本课用词**：poison litmus 是先写入可识别毒值、再用严格握手暴露错误时序的小测试；mutant 是故意注入 READY_EARLY 或 ACK_EARLY 的错误实现；fault signature 是预注册的错误 warp 掩码或 epoch 值。

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

## Host 准入与 Watchdog

在解释内存序前，先证明 producer/consumer CTA 能同时进入且位于预期 SM/cluster。否则 consumer 没读到 poison，可能只是 producer 已完整结束后它才入场。heartbeat 记录双方到达各个 gate 的次序；watchdog 超时时，两边走统一 abort 协议，避免一个 CTA 退出、另一个永久自旋。

## 一张完整 Fault Matrix

至少包含 GOOD、READY_EARLY、ACK_EARLY、NO_ACQUIRE、错误 epoch 和重复 ACK。每个 mutant 预注册可判定签名：

| Mutant | 期望观察 |
| --- | --- |
| READY_EARLY | W2/W3 poison，mask `1100` |
| ACK_EARLY | 被暂停 W3 读到下一 epoch |
| wrong epoch | stale/next tag 或拒绝 claim |
| duplicate ACK | 提前复用或计数越界 |
| NO_ACQUIRE | 失败可定罪，全绿仍不闭合保证 |

GOOD 必须零 poison、零 mixed epoch、零 timeout；mutant 按签名失败才算测试系统通过。

## 从 Litmus 到生产结论

Litmus 证明的是一个最小协议在目标 binary/硬件上的可观察行为，不自动证明完整 Megakernel 所有路径安全。移植时要逐条映射 producer、payload、scope、epoch、ACK 和 reuse；release/perf binary 还需独立正确性回放、exact SASS 与 paired latency。

## 课程结业练习

选择课程中的一条跨 CTA 数据边，写出 GOOD 与两个 mutant，冻结 CUBIN hash、admission、fault signature 和 verdict 规则。最后分别写一句 safety 结论、liveness 结论与 performance 结论，禁止相互替代。

## 读完自检

1. 先不看上文，用自己的话回答：程序运行正确，为什么还要故意制造错误？
2. 再对照本课结论：正例全绿不够；坏协议必须按预期失败，测试才算通过。
3. 根据 `DIAGNOSTIC PROPOSAL · UNMEASURED`，说出这条结论能证明什么、不能外推什么。

## 继续学习

- [在线阅读本课](https://qhy991.github.io/gpu-megakernel-course-art/lessons/lesson-54-poison-litmus/)
- [← 上一课 · 第 53 课：三页以后还能流水吗？把 64 KiB 大门拆成两扇](../lesson53/)
