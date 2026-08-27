<!--
本文由 scripts/sync_lesson_readmes.rb 从对应的 _posts 文章确定性生成。
请编辑课程原文后重新运行同步脚本，不要单独修改本文件。
-->

# 第 3 课｜怎样读懂 GPU 性能报告

![第 3 课：怎样读懂 GPU 性能报告](./lesson-03.png)

> 按计时边界、资源准入、warp 可发射性和等待原因阅读 GPU 报告，避免被单个漂亮指标误导。

## 零基础先看这里

- **它在解决什么：**GPU 性能报告里，第一眼该看什么？
- **把它想成：**像看体检报告先核对姓名和采样条件，再看异常指标。
- **这次先不用懂：**可先忽略每个 NCU 缩写和计数器定义。

## 本课结论与证据状态

- **一句话结论：**先确认秒表和执行路径，再解释 profiler 指标。
- **证据状态：**HISTORICAL REPORT SYNTHESIS · BOUNDED
- **怎么看这个标签：**它表示结论的来源与适用范围，不是课程难度；可查看[中文证据规则](../evidence.md)。

## 完整课程正文

> **本课用词**：NCU 指 Nsight Compute；latency 是一次工作的时间；throughput 是单位时间完成量；GPU-busy 只描述时间线上是否有 GPU 工作。

先记住性能分析的黄金顺序：

```text
正确性 → 公平计时 → 找瓶颈 → 提出优化
```

不能先看到“occupancy 低”就开始减寄存器，也不能看到“long scoreboard 高”就直接宣布“显存带宽不够”。

性能报告更像体检：单个指标不是诊断，多个指标组合起来才有意义。

---

## 1. Latency：完成一次工作要多久

常见单位：

```text
1 ms = 1000 µs
```

例如：

```text
CUDA Graph：3.413 ms
Megakernel：5.352 ms
```

含义是 megakernel 用时为：

```text
5.352 / 3.413 = 1.568
```

即 latency 高 56.8%。可以说：

- Megakernel 用时是 Graph 的 `1.568×`；
- Graph 相对 Megakernel 有 `1.568×` speedup；
- Megakernel 不是“慢 56.8 倍”，而是“慢 56.8%”。

## Speedup 的公式

```text
speedup = baseline latency / candidate latency
```

你的 Qwen 结果：

```text
2.80 / 2.76 = 1.0145×
```

也就是约 1.45% speedup，对应 latency 下降约 1.43%。

---

## 2. Throughput：单位时间完成多少工作

吞吐量通常用：

```text
tokens/s
```

但一定要问“这里的 token 是怎样计算的”。

假设 B=16，每步耗时 3.45 ms：

```text
单序列生成速度：
1 / 0.00345 ≈ 290 token/s

16 条序列的聚合吞吐：
16 / 0.00345 ≈ 4638 token/s
```

两者都可能被写成 `tok/s`，但含义完全不同。

因此比较报告前必须确认：

- batch 是否相同；
- 是每序列吞吐还是聚合吞吐；
- 是 model forward 还是完整 serving；
- 是否包含 sampling、CPU、网络和 tokenizer。

---

## 3. Wall time、CUDA Event 和 NCU time

这三种时间不能随意混用。

## Wall time

CPU 看到的完整耗时，可能包含：

- Python/C++ 调用；
- CUDA Graph replay；
- 同步；
- 内存复制；
- GPU kernel；
- sampling。

最接近用户实际感受。

## CUDA Event time

测量两个 GPU event 之间的时间，适合测：

- 一个 kernel；
- 一段 CUDA Graph；
- model-forward。

它通常不包含 event 之外的 CPU 工作。

## NCU kernel duration

Nsight Compute 为了读取硬件计数器，可能反复 replay kernel。因此它主要用于诊断，不应直接代替正式 benchmark。

还有一个容易踩坑的地方：

> 把每个 kernel duration 相加，不一定等于整步 GPU 时间。

如果 kernel 有重叠：

```text
Kernel A：0 ───────── 10 µs
Kernel B：    4 ───────── 12 µs
```

相加是 18 µs，但实际时间区间只有 12 µs。

这也是早期 Qwen 报告里 kernel duration sum 大于 wall time，不能叫作“GPU-busy floor”的原因。

---

## 4. GPU-busy 不等于 GPU 算得很快

你的 CUDA Graph 达到约 98.3% GPU-busy。

它只表示：

> 98.3% 的时间里，GPU 上至少有 kernel 在运行。

它不表示：

- Tensor Core 达到 98.3%；
- SM 算术单元达到 98.3%；
- 98.3% 的 warp 在做有效计算。

一个 kernel 即使大部分时间都在 barrier 上等待，也仍然算 GPU-busy。

所以这两句话可以同时成立：

```text
GPU-busy = 98%
有用计算利用率很低
```

GPU-busy 主要帮助回答：

> kernel 之间还有没有明显空隙？

在你的 Graph 中答案是“已经很少”，所以纯 launch-fusion 的上限不高。

---

## 5. Occupancy：SM 能同时容纳多少 warp

可以把 occupancy 想成电影院的上座率。

- Theoretical occupancy：理论最多能坐多少人；
- Achieved occupancy：实际平均坐了多少人；
- Eligible warps：真正准备好、现在就能执行的人。

上座率高不代表观众都在看电影；他们也可能都在等放映。

## 你的一个 8B NCU 快照

特定 4K、p16 kernel 测到：

```text
148 CTA
640 threads/CTA = 20 warps/CTA
96 registers/thread
约 228 KiB shared memory/CTA
1 CTA/SM
occupancy ≈ 31.3%
eligible warps/cycle ≈ 0.251
```

解释：

- 148 个 CTA 正好覆盖 148 个 SM；
- 每个 SM 只能放一个 CTA；
- shared memory 和 registers 都是限制因素；
- 每个 SM 虽然驻留着 20 个 warp，但真正准备好执行的 warp 很少。

因此诊断不能只说“occupancy 31% 太低”，更准确的是：

> 有一定数量的 resident warps，但大部分时间没有足够的 ready warp 来隐藏等待。

---

## 6. Registers：最快，但用太多会产生压力

Register 是线程的私人高速存储。

Megakernel 容易使用很多 registers，因为 QKV、attention、MLP 等阶段的变量都存在同一个巨大函数中，编译器可能扩大变量的 live range。

高 register 数本身不是错误，因为 registers 很快。它在两种情况下才形成问题：

1. 限制每个 SM 可驻留的 CTA/warp；
2. 放不下时发生 spill。

## Spill 是什么

编译器发现 register 不够，会把变量放到所谓 local memory。

名称虽然叫 local，但它不是快速片上内存：

```text
Register spill
    ↓
Local address space
    ↓
L1 / L2 / HBM
```

所以 NCU 中看到：

```text
local load
local store
```

通常意味着溢出流量。

你的一个 legacy 8B profile 中约有：

```text
7.34M local loads
3.30M local stores
```

并且 local traffic 占大量 L1 sectors，说明 spill/local 状态是实际成本。

但不要反向推理：

> registers 很多 ≠ 一定 spill。

你的 Phase 13 虽然约 173 registers/thread、229 KiB shared memory，却记录为 zero spill。它仍然有 occupancy/resource coupling，但不能说它发生了 spill。

---

## 7. Shared Memory：CTA 的片上工作台

Shared memory 比 HBM 快得多，同一 CTA 的线程可以共享。

但它按 CTA 分配。假设每个 SM 能提供的 shared memory 大约只够一个 229 KiB CTA：

```text
CTA 1 占满工作台
CTA 2 无处落脚
```

即使减少 registers，也未必能让第二个 CTA 驻留，因为 shared memory 仍然是限制项。

这对 megakernel 特别重要：

> 某一个最吃 shared memory 的 phase，会限制整个 kernel 的驻留配置。

普通多-kernel 路径则可以：

- GEMM kernel 使用一种资源配置；
- RMSNorm kernel 使用另一种；
- Attention kernel 再使用第三种。

这叫资源配置解耦，也是 CUDA Graph 的重要优势。

---

## 8. Warp stall：warp 为什么没有发射指令

GPU scheduler 每个周期寻找 ready warp。

如果 warp 不能运行，NCU 会记录 stall reason。

| 指标 | 新手解释 | 常见原因 |
|---|---|---|
| `long_scoreboard` | 在等较慢的数据 | global/local load、依赖链 |
| `short_scoreboard` | 在等较近的数据或结果 | shared memory、短依赖链 |
| `barrier` | 在等其他线程/CTA | 同步过多、工作不均 |
| `wait` | 在等固定延迟执行单元 | Tensor Core、特殊函数 |
| `membar` | 在等内存可见性 | fence、release/acquire |
| `math_pipe_throttle` | 数学管线很忙 | 可能真的 compute-bound |
| `not_selected` | 已准备好，但调度器选择了别人 | 通常是好现象 |

你的某个全模型阶段曾出现大致：

```text
barrier：约 62.8%
long scoreboard：约 25.1%
```

这说明主要矛盾不是 CPU launch，而是：

- CTA/warp 在等待同步；
- 权重或中间数据依赖没有及时到达。

这也解释了为什么 page-granular readiness 有效：它让某页权重一到，相关 warp 就开始计算，不必等待整个阶段。

---

## 9. 带宽瓶颈和延迟瓶颈不是一回事

继续用仓库类比：

- Bandwidth：一小时最多能运多少卡车；
- Latency：叫一辆卡车后，要多久才能送到。

## 带宽瓶颈

```text
大量连续数据同时搬运
DRAM 接近满载
```

解决方向：

- 减少总字节数；
- 提高 cache reuse；
- 数据保留在 shared/TMEM/register。

## 延迟瓶颈

```text
发出一个 load
必须等它回来
才能发出下一步
```

此时 DRAM 总带宽可能只有很低比例，但 warp 仍然一直等。

典型组合：

```text
long scoreboard 很高
DRAM peak 利用率很低
```

不能诊断成 bandwidth-bound，应该诊断为 memory-latency/依赖链问题。

解决方向包括：

- 同时发出更多独立 load；
- 双缓冲；
- TMA 异步搬运；
- 提前加载下一页；
- 增加可执行 warp；
- 缩短依赖链。

---

## 10. Tensor Core utilization

QKV、O、Gate/Up、Down 都是矩阵乘，应该尽量使用 Tensor Core。

你的最初标量全模型 kernel 没有 Tensor Core 指令，因此即使 launch 只有一个，矩阵计算质量也远落后于 CUTLASS。

后来嵌入的关键 Blackwell 组件包括：

- `tcgen05.mma`：B200 Tensor Core 矩阵乘指令；
- TMEM：Tensor Core accumulator 存储；
- TMA：异步搬运大块 tensor 数据。

对于矩阵乘形状，如果 NCU 显示 Tensor Core activity 为 0%，通常是严重红灯。

但 Tensor Core utilization 低也可能是：

- 数据来不及送到；
- tile 形状不合适；
- 同步或依赖阻塞；
- 网格太小。

仍然不能只看一个指标。

---

## 11. Grid、wave 和 tail

B200 有 148 个 SM。

如果只有 8 个 CTA：

```text
8 个 CTA / 148 个 SM
```

至少 140 个 SM 没有工作。

这就是你的 B=1、8 KV-head attention 原始问题。

Split-KV 将其变成大约 128 个 partial jobs，虽然增加 reduction，却显著提高并行度。

## Tail effect

假设 148 个 SM 完成大部分工作后，只剩 5 个 CTA：

```text
前半段：148 个 SM 忙
尾部：    5 个 SM 忙，143 个 SM 等
```

平均利用率可能看起来尚可，但最后长尾会拖慢整个 kernel。只有时间线/PM sampling 才容易看出这种形状。

---

## 12. 正确性指标也有强弱

性能优化首先必须正确。

| 检查 | 能证明什么 | 局限 |
|---|---|---|
| Top-1 一致 | 最终选中的 token 相同 | 其他 logits 可能差很多 |
| Cosine 接近 1 | 整个向量方向接近 | 不保证逐元素完全一致 |
| Exact trajectory | 多步 token 序列一致 | 仍可能掩盖内部差异 |
| Bitwise exact | 每一位都相同 | 最强，但某些合法算法天然不确定 |
| Negative control | 测试能抓到故意错误 | 防止测试形同虚设 |

你的 Phase79 是很好的案例：

```text
20 次 replay：看起来正确
100 次 replay：发现偶发 race
```

最终加上 GPU-scope release/acquire 后，Phase82 才达到 100/100 bitwise。

因此 resident 跨 CTA 程序不能只跑几次。

---

## 13. 什么叫公平基线

直接比较前必须相同：

```text
模型
权重
输入 token
位置与 KV Cache
精度
输出定义
计时边界
```

三种常见对照回答不同问题：

| 对照 | 回答的问题 |
|---|---|
| Resident vs 相同 instruction bodies 的 Graph | 设备常驻控制本身是否有效 |
| Resident vs tuned production Graph | 整套实现是否有产品竞争力 |
| Model-forward vs streamed serving | 不能直接比较，需要统一边界 |

所以这两件事可以同时为真：

- Phase82 相对相同算子 Graph 快 `1.343×`；
- 当前 canonical 分支仍慢于 Hazy upstream 或成熟 SGLang。

前者证明机制有效，后者说明整套 executor/系统还没有领先。

## 读报告的六问法

以后看到任何“优化成功”，按顺序问：

1. 正确吗？检查的是 Top-1、cosine 还是 bitwise？
2. 比的是同一个边界吗？子图、model-forward、token step 还是 serving？
3. 时间怎么测的？wall、CUDA Event 还是 NCU replay？
4. 主要时间花在哪里？不是只看总时间。
5. 指标是否形成闭环？例如 long scoreboard 是否落在具体 load 源码行？
6. 整模型提升是否符合局部占比？防止把子图 2× 写成系统 2×。

按这套方法看，你的 legacy 8B megakernel可以概括为：

> 它成功占据整张 B200，但并没有让足够多 warp 持续处于 ready 状态；固定网格、内部 barrier、长延迟依赖和资源耦合压过了 launch 减少的收益。后来的 split-KV、page readiness 与局部 handoff，才逐项解决这些具体问题。

## 读完自检

1. 先不看上文，用自己的话回答：GPU 性能报告里，第一眼该看什么？
2. 再对照本课结论：先确认秒表和执行路径，再解释 profiler 指标。
3. 根据 `HISTORICAL REPORT SYNTHESIS · BOUNDED`，说出这条结论能证明什么、不能外推什么。

## 继续学习

- [在线阅读本课](https://qhy991.github.io/gpu-megakernel-course-art/lessons/read-gpu-performance-report/)
- [← 上一课 · 第 2 课：一枚 Token 如何穿过 Llama](../lesson02/)
- [下一课 · 第 4 课：Megakernel 优化决策树 →](../lesson04/)
