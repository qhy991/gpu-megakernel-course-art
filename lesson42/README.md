<!--
本文由 scripts/sync_lesson_readmes.rb 从对应的 _posts 文章确定性生成。
请编辑课程原文后重新运行同步脚本，不要单独修改本文件。
-->

# 第 42 课｜四臂实验：怎样给 Island 一个公平位置？

![第 42 课：四臂实验：怎样给 Island 一个公平位置？](./four_arm_island_evidence_ladder_16x9.png)

> 把 individual、islands、per-layer 与 whole resident 放进同一条证据梯，避免拼接不同实验。

## 零基础先看这里

- **它在解决什么：**怎样公平证明一种 kernel 切法更好？
- **把它想成：**赛车必须跑同一赛道、同一距离并用同一计时器；否则成绩不能直接比较。
- **这次先不用懂：**可先忽略 A/B/C/D 编号和旧实验的具体数值。

## 本课结论与证据状态

- **一句话结论：**没有同体、同输入、同正确性门的四臂表，就没有 Island 冠军。
- **证据状态：**A/D MEASURED · B/C UNKNOWN
- **怎么看这个标签：**它表示结论的来源与适用范围，不是课程难度；可查看[中文证据规则](../evidence.md)。

## 完整课程正文

> **本课用词**：arm 是受控实验中的一个候选分支；A/B/C/D 分别代表 individual、islands、per-layer 与 whole resident；同体对照表示模型、输入、数学、正确性门和计时边界都相同，只改变预注册变量。

## 四个实验臂

一条理想的 island 证据梯应该包含：

- A：individual-op CUDA Graph；
- B：若干物理 Megakernel islands；
- C：per-layer megakernel Graph；
- D：whole-model resident/full-overlap Graph。

四臂必须使用同一模型、权重、shape、instruction body、数值协议和计时边界。

## 现在真正闭合的是 A 与 D

Phase82 的 A/D 同轮数据约为 `0.969 ms → 0.689 ms`，两个执行顺序都约 `1.409×`，四个执行对象都通过 100 次 reset 与 bitwise audit。

`release_fenced_graph` 仍然是 whole-model，只是禁止 inter-op overlap，不能拿来冒充 per-layer C。

## 为什么 C 的旧数字不能用

旧控制矩阵里 per-layer 看起来很快，但同一日志已经记录 hidden/logit replay drift。一个不满足正确性的 arm 没有性能资格。

Phase82 exact harness 后来只重测 whole、fenced whole 与 individual，没有重新纳入 per-layer，因此 C 仍是 UNKNOWN。

## B 也不能靠拼图得到

GateUp→SwiGLU 的正向融合、Down→Norm 的负向实验、Aug17 provider swap 分别来自不同代码、shape 和物理边界。不能把它们的百分比拼成“两岛方案预测收益”。

真正的 B 必须存在 exact island CUBIN、Graph kernel census、边界消失证据和整臂计时。

## 最低验收线

- 100 reset bitwise 或预注册数值门；
- AB/BA 或 ABBA/BAAB 双顺序；
- exact ptxas/SASS/occupancy；
- context buckets 与 real KV；
- both-order p50 至少跨过噪声门；
- 任何桶回退时支持条件分发或归档。

## 四臂各自回答什么

A→C 回答 per-layer 组织是否值得；C→D 回答跨层常驻与 overlap 是否继续贡献；A→B 回答少量 island 是否删掉最有价值的边界；B→D 回答资源专门化能否补偿新增 seam。四个差值不是同一个问题，不能只看最终排名。

## 一张合格结果表

除 p50/p90 外，还要记录 path identity、kernel/Graph census、binary hash、正确性强度、资源包络和 workload bucket。A/B/C/D 应采用 ABBA 或随机交错，降低频率、温度与后台负载的时间漂移。未运行的臂明确写 `NOT RUN`；正确性失败的延迟只用于诊断，不参与排名。

## 练习：识别无效拼图

给出 A=1B pos0、B=8B 4K、D=1B pos0 的三组数字，解释为什么不能画 A→B→D 加速曲线。然后列出让 B 合法入表所需冻结的模型、shape、body、reset、正确性和计时合同。

## 读完自检

1. 先不看上文，用自己的话回答：怎样公平证明一种 kernel 切法更好？
2. 再对照本课结论：没有同体、同输入、同正确性门的四臂表，就没有 Island 冠军。
3. 根据 `A/D MEASURED · B/C UNKNOWN`，说出这条结论能证明什么、不能外推什么。

## 继续学习

- [在线阅读本课](https://qhy991.github.io/gpu-megakernel-course-art/lessons/lesson-42-four-arm-evidence/)
- [← 上一课 · 第 41 课：一层 Llama 到底有几条切缝？](../lesson41/)
- [下一课 · 第 43 课：切一刀，会自动降低寄存器和 Shared Memory 吗？ →](../lesson43/)
