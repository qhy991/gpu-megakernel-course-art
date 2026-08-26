---
layout: lesson
title: "时间花在哪里，不等于时间能省多少"
slug: attribution-vs-savings
lesson: 17
stage: "基础三 · 学会审计性能证据"
stage_description: "从 NCU、PTX、SASS、实验卡和原始归档建立可复核的性能结论。"
description: "从真实 decode-floor 归因区分可见耗时、可消除耗时与 Amdahl 上限。"
takeaway: "Profiler 中显眼的 kernel 不等于可以被完整删除的时间。"
beginner_question: "为什么最耗时的 kernel 不一定最值得融合？"
beginner_analogy: "账单中最大的一项不代表能整项免单，真正可省的常常只是一部分。"
beginner_skip: "可先忽略 Amdahl 定律的正式推导。"
image: /lesson17/lesson-17.png
tags: [Attribution, Amdahl, Kernel Sum, Wall Time]
read_time: 14
status: "MEASURED ARCHIVE · ATTRIBUTION BOUNDED"
prev_slug: recompute-b200-archive
prev_title: "不先相信 RESULT.md：自己复算一次 B200 实验"
next_slug: page-granular-pipeline
next_title: "把 128 KiB 大门拆成 8 个 Page-ready 小门"
---

> **本课用词**：attribution 表示时间归属；removable time 是候选真正能删除的部分；kernel-sum 与 wall time 的统计边界不同。

先给结论：

> 这份B200实验表明，projection GEMM约占decode kernel工时总和的65%；QK+KV约占8%。但QK+KV即使被“魔法删除”，仍不足以单独完成1.10×目标。它只能是完整layer Megakernel的一块拼图。

## 1. 三种时间不是一回事

可以把GPU执行想象成多人搬家：

- `Wall time`：从开始到结束，用户实际等了多久。
- `Kernel-sum`：把每个工人的工作时间全部相加。
- `Recoverable time`：改变方案后真正能少做的那部分工作。

多人并行时，工时总和可以大于墙上时间。

## 归档中的三个场景

| 场景 | Wall | GPU工作 | 含义 |
|---|---:|---:|---|
| B=1 eager | 422.11ms | kernel-sum 14.84ms | 约96%花在host/launch间隙 |
| B16 CUDA Graph | full 2.623ms | replay 2.617ms | host gap只剩约0.005ms |
| NSYS聚合 | — | 2.939ms kernel-sum | 含重叠及warmup污染，不是wall |

原始证据：

- B=1 eager profile
- B16 Graph ledger
- NSYS角色汇总

图中的2.617ms和2.939ms来自不同测量block，只用于解释概念，不能直接相减归因。当前归档缺少原始NSYS timeline，无法精确判断那0.322ms分别来自多少重叠、warmup或profiler扰动。

## 2. GPU时间主要花在哪

从原始NSYS CSV重新求和：

```text
全部kernel duration = 771,670,699 ns
decode分类          = 749,441,482 ns
prefill分类         =  22,229,217 ns
```

算术与 角色JSON 完全闭合。

| 角色 | kernel-sum占比 |
|---|---:|
| Projection GEMM + LM head | 65.38% |
| Add-RMSNorm | 9.96% |
| Attention | 9.35% |
| SwiGLU | 5.77% |
| KV-store | 4.02% |
| QK-Norm+RoPE | 3.97% |
| 其他 | 约1.55% |

请注意表头：

> 这是`kernel-sum占比`，不是`端到端wall占比`。

它适合回答“GPU工时主要分布在哪”，不能直接回答“删除某角色会让wall下降多少”。

## 3. 归一化里还藏着一个坑

归档汇总器统一除以255个decode step：

```text
749.441482ms / 255 = 2.938986ms/step
```

但kernel实例数告诉我们，CSV还包含warmup：

```text
QK+KV等每层一次的kernel：
9288 = 36层 × 258次

258 = 255次正式decode + 3次capture warmup
```

SwiGLU则是：

```text
9432 = 36层 × 262次
```

它还混入了4次prefill相关执行。

所以统一除以255会把QK+KV的估算放大约1.18%。正确的结构性估算应按258次层执行归一。

这也是为什么性能分析必须同时检查：

- 总时间
- kernel实例数
- 模型层数
- warmup/capture边界

## 4. QK+KV为什么闭合不了1.10×

先算目标。

B16短context基线是 2.624878ms。

1.10×速度意味着：

\[
T_{\text{target}}=\frac{2.624878}{1.10}=2.386253\text{ ms}
\]

需要真正节省：

\[
2.624878-2.386253=0.238625\text{ ms}
\]

Qwen3-4B有36层，所以平均每层需要：

\[
0.238625/36=6.628\ \mu s
\]

再算QK+KV：

\[
T_{\text{QK+KV}}
=29{,}761{,}525+30{,}163{,}221
=59{,}924{,}746\text{ ns}
\]

按258次、36层归一：

\[
\frac{59{,}924{,}746}{258\times36}
=6.452\ \mu s/\text{layer}
\]

于是：

| 项目 | 每层时间 |
|---|---:|
| 达到1.10×必须节省 | 6.628µs |
| QK+KV全部成本 | 6.452µs |
| 仍缺 | 0.177µs |

也就是说：

> 即使QK-Norm、RoPE和KV-store全部变成零成本，仍然差一点。

真实融合更不可能把它们全部删掉，因为RMSNorm、旋转和写cache的数学工作仍然必须执行。

## 5. 这是否意味着Megakernel没机会？

不意味着。

把以下layer-local角色合起来：

- 两个Add-RMSNorm
- SwiGLU
- QK-Norm+RoPE
- KV-store

粗校正后约有：

\[
19.1\ \mu s/\text{layer}
\]

这仍是“全部免费删除”的gross ceiling，不是可实现收益。但它说明：

- QK+KV-only边界太窄
- 完整层的数据流仍有数学空间
- 真正机会来自多个真实边同时优化

例如：

- QKV accumulator直接交给QK-Norm/RoPE
- Gate/Up结果直接进入SwiGLU
- Down结果直接进入residual/AddNorm
- 减少中间global-memory物化
- 让生产者和消费者按tile/page粒度交接

这才是layer Megakernel的问题。

## 6. `reachability=144`是什么意思

reachability.json显示：

| Self-native实现 | Decode capture |
|---|---:|
| SwiGLU | 144 |
| QKNorm | 0 |
| RoPE-store | 0 |
| KV-store | 0 |
| RMSNorm A/B | 0 |

但144不是“每个token运行144次”。

工具的顺序是：

```text
Python构造Graph
→ adapter计数器增加
→ Graph被捕获
→ 后续GPU replay不再进入Python
```

源码明确说明replay不重新进入Python：native_fragment.py。

因此：

- `>0`：该实现被烘焙进Graph
- `=0`：该Graph没有走这个实现
- 不能用它计算稳态kernel调用次数
- 真正调用次数需要过滤过warmup的NSYS timeline

当前main的静态路径仍是vendor QK fusion、ATen KV写入、可替换SwiGLU：model.py。但历史SHA已无法checkout，本次也没有在当前SHA重新运行B200 reachability，因此不能把旧的144/0称为“今日runtime实测”。

## 7. 为什么归档的`STOP`没有否定Megakernel

这项 TASK本来就是：

- measurement-only
- 0个优化候选
- 预期结果STOP
- 只判断已有standalone native seam是否值得继续

因此它的STOP准确含义是：

> 在当时合同下，没有一个现成、可达、未被历史实验否定的standalone native替换值得继续。

它没有测试：

- 同一数学body下Graph与Resident的差异
- 跨kernel中间数据交接
- 完整层调度
- page-level readiness
- resident CTA执行器

所以不能外推成“single-layer Megakernel失败”。

## 8. 下一项正确实验：Same-body Graph vs Resident

| 实验臂 | 内容 | 回答的问题 |
|---|---|---|
| P | 当前production CUDA Graph | 能否打赢当前产品路径 |
| G | 相同device bodies组成的多kernel Graph | 匹配后的架构基线 |
| R | 相同device bodies组成的resident layer kernel | Resident组织是否有价值 |

必须固定：

- 相同数学和精度
- 相同tile与warp ownership
- 相同Attention算法
- 相同layout和舍入点
- 相同输入、权重、KV状态

只允许改变“谁来调度这些stage”。

判决：

- `R`不快于`G`：Resident组织本身STOP
- `R`快于`G`但输给`P`：架构成立，operator body不够强
- `R`稳定打赢二者且完整模型过gate：Megakernel候选成立

## 9. 本课最值得记住的四句话

```text
Reachability：有没有走到这条路？
Kernel-sum：GPU工时花在哪里？
Gross ceiling：用魔法最多能擦掉多少？
Paired wall：用户最终到底快了多少？
```

最后补一条证据健康检查：当前归档文件总计只有255,317字节，而 META声称原始evidence为18,057,590字节；逐次wall样本、原始NSYS report/SQLite和历史Git对象均已缺失。因此这是一份可复算聚合结果、但不能完整重建实验的历史归档。
