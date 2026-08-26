---
layout: lesson
title: "三种 Pipeline：为什么一个数字 3 会指三件不同的事？"
slug: lesson-52-pipeline-depth-vs-pages
lesson: 52
stage: "阶段四 · 用受控实验替代性能故事"
stage_description: "把资源、工作供给、内存序和 benchmark contract 拆成可以逐项推翻的实验。"
description: "区分外层 instruction pipeline、matvec weight-input pipeline 与 output scratch pipeline。"
takeaway: "改 input depth 时，output scratch 与 instruction ring 不应该跟着变。"
beginner_question: "为什么三个都叫 pipeline，却不能一起修改？"
beginner_analogy: "餐厅的订单队列、烹饪托盘和装盘区是三套周转系统；数量碰巧相同，也不是同一件事。"
beginner_skip: "可先忽略 mbarrier parity、页编号和取模方式。"
image: /lesson52/r1_pipeline_depth_vs_pages_16x9.png
tags: [Instruction Pipeline, Input Pipeline, Output Scratch, Page Release]
read_time: 14
status: "SOURCE-PROVEN · R1A PROPOSED"
prev_slug: lesson-51-r0-r5-tree
prev_title: "R0–R5：五个实验臂为什么不能跳级？"
next_slug: lesson-53-page-ready-r1c
next_title: "三页以后还能流水吗？把 64 KiB 大门拆成两扇"
---

> **本课用词**：depth 是同一类缓冲区能同时保留的轮次数；instruction slot、weight-input stage 和 output scratch slot 是三套独立循环结构；parity 是 mbarrier 用来区分相邻 epoch 的奇偶位。

## 三套彼此独立的 pipeline

1. **Instruction pipeline = 2**：controller 同时维护相邻两条 instruction slot。
2. **Matvec input pipeline = 3**：一条 instruction 内，三组 weight buffer 轮转。
3. **Output scratch pipeline = 3**：八个 consumer 的 partial 在 LID0 内使用三个 512 B scratch slot。

input 和 output 当前都按 `i % 3` 轮转，只是数字碰巧相同。R1a 只把 weight input 变为 depth1；output scratch 仍然是 depth3，外层 instruction ring 仍然是2。

## 七个 page 的精确职责

- LID0：activation/aux/output scratch；
- LID1/2：weight stage0；
- LID3/4：weight stage1；
- LID5/6：weight stage2。

每个 input stage 两页，共 64 KiB；loader 每页发两笔 16 KiB TMA。8 个 consumer 中，每页 4 个 warp，每 warp 读 8 KiB。

## arrived、finished、page release 是三层协议

- `weights_arrived`：本轮 TMA 数据已经到 shared；
- `weights_finished`：本 instruction 的 consumer 已读完，loader 可覆写下一轮；
- `page_finish`：跨 instruction 的物理 page ownership 可以转交。

混淆这三层，最容易制造提前覆写或无谓等待。

## R1a 为什么还要改 release order

input depth 改成1后，LID3–6 从未使用，应最早释放；LID1/2 在最后 iteration 释放；LID0 由 storer 最后释放。因此保留7页时，安全声明是：

```text
{3, 4, 5, 6, 1, 2, 0}
```

若沿用旧三阶段 remainder 分支，实验虽然可能不立刻算错，却会改变下一 instruction 的物理页映射和等待，污染因果归因。

## 最便宜的 falsifier

先独立测试 `iters=1..7`，覆盖 phase 翻转与 stage reuse；UpGate 另测偶数 `2/4/6`。随后才跑完整 Attention/MLP island。

## 用三个坐标给状态命名

调试日志不要只写 `stage=1`，而应同时打印 instruction epoch、weight iteration/stage、output scratch slot。例如 `(inst_epoch=7, weight_iter=4, scratch=1)`。这样看到 poison 或超时时，才能判断错误发生在哪套循环，而不是猜某个模糊的“第三阶段”。

## Depth1 的理想代价

depth3 可以隐藏后续 weight TMA，depth1 必须在同一对 page 上交替等待 FINISHED 与 READY。它减少 shared footprint，但可能暴露 load latency。R1a 的任务就是独立测出这笔代价；R1b 再判断释放 shared 是否打开新准入。两者相加不一定等于最终双 CTA 收益，因为 residency 会改变调度。

## 练习：手算 Phase

对 instruction epoch 5、`iters=4` 写出每轮 weight parity、output slot 与最终 page release 顺序。再对 epoch 6 重复一次，确认 parity 翻转不会影响 `i % 3` 的 scratch 选择。
