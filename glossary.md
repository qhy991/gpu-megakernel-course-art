---
layout: default
title: 术语表
description: GPU Megakernel 实战课使用的 CUDA、Blackwell、调度和实验术语。
permalink: /glossary/
---
<section class="plain-page shell">
  <p class="section-index">GLOSSARY</p>
  <h1>先把缩写翻译成人话。</h1>
  <div class="prose">
    <p>本页不是 CUDA 百科，而是这套课程的统一词典。同一个词在后续课程中始终使用这里的含义。第一次遇到不熟悉的缩写时，可以从这里查起。</p>

    <h2>执行层级</h2>
    <dl>
      <dt><strong>Thread（线程）</strong></dt><dd>CUDA 中最小的编程执行单元。</dd>
      <dt><strong>Warp（线程束）</strong></dt><dd>通常由 32 个线程组成，硬件以 warp 为单位选择并发射指令。</dd>
      <dt><strong>CTA / Thread Block（线程块）</strong></dt><dd>一组能共享 shared memory、barrier 和生命周期的线程。本文把 CTA 与 block 当作同义词。</dd>
      <dt><strong>SM（Streaming Multiprocessor）</strong></dt><dd>GPU 上接纳并执行 CTA 的处理器。一个 CTA 只能驻留在一个 SM 上。</dd>
      <dt><strong>Resident（驻留）</strong></dt><dd>CTA 已进入 SM，所需寄存器和 shared memory 已分配；不代表它此刻能发射指令。</dd>
      <dt><strong>Eligible（可发射）</strong></dt><dd>warp 当前没有被依赖、barrier 或内存等待挡住，可以被 scheduler 选择。</dd>
      <dt><strong>Issue（发射）</strong></dt><dd>scheduler 在当前周期真正选中一个 eligible warp 并发出指令。</dd>
      <dt><strong>Occupancy（占用率）</strong></dt><dd>SM 上 active warp/CTA 相对硬件上限的资源准入指标。它不是 GPU 利用率，也不直接等于性能。</dd>
    </dl>

    <h2>Kernel 与调度</h2>
    <dl>
      <dt><strong>Kernel</strong></dt><dd>一次 GPU 程序入口及其 grid。一次 kernel launch 会创建一批 CTA。</dd>
      <dt><strong>Persistent Kernel（常驻内核）</strong></dt><dd>CTA 长时间驻留并从队列反复领取任务，而不是每个逻辑算子都重新 launch。</dd>
      <dt><strong>Megakernel（巨型内核）</strong></dt><dd>在一个 physical kernel 中容纳多个算子或调度阶段的实现。它可以减少边界，但也让不同阶段共享同一个最坏资源包络。</dd>
      <dt><strong>Island（内核岛）</strong></dt><dd>介于“每个算子一个 kernel”和“整张图一个 kernel”之间的物理切分；岛内融合，岛间通过明确的 global seam 交接。</dd>
      <dt><strong>Dispatcher</strong></dt><dd>读取 instruction/任务并选择对应实现的调度入口。一个 Dispatcher 不一定对应一次 launch。</dd>
      <dt><strong>IType（Instruction Type）</strong></dt><dd>课程所分析运行时中的指令类型或 dispatch case，例如 Attention、OProj、DownProj。</dd>
      <dt><strong>DAG（有向无环图）</strong></dt><dd>用节点表示任务、用有向边表示依赖的执行图。</dd>
      <dt><strong>Seam / Cut（接缝／切分）</strong></dt><dd>两个物理 kernel 或 island 之间的边界；跨过它通常要保存 global 状态并建立可见性协议。</dd>
    </dl>

    <h2>内存、搬运与同步</h2>
    <dl>
      <dt><strong>Shared Memory（共享内存）</strong></dt><dd>CTA 内线程共享的片上存储，容量会参与 CTA 能否进入 SM 的准入计算。</dd>
      <dt><strong>Page（页）</strong></dt><dd>本课程中特指 shared-memory 大缓冲区内被独立管理的一段，不是操作系统虚拟内存页。</dd>
      <dt><strong>TMA（Tensor Memory Accelerator）</strong></dt><dd>Hopper/Blackwell 上用于异步搬运多维 tensor tile 的硬件机制。TMA 完成与 consumer 可开始读取之间通常由 mbarrier 协调。</dd>
      <dt><strong>mbarrier</strong></dt><dd>shared memory 中的异步 barrier，可追踪到达线程或事务字节数。</dd>
      <dt><strong>READY / arrived</strong></dt><dd>producer 声明数据已准备好，consumer 可以读取的信号。</dd>
      <dt><strong>ACK / finished</strong></dt><dd>consumer 声明读取已完成，producer 可以安全覆写该缓冲区的信号。</dd>
      <dt><strong>Epoch / Phase（轮次／相位）</strong></dt><dd>区分同一循环缓冲区不同代数据的编号；mbarrier 常只保存 epoch 的奇偶 parity。</dd>
      <dt><strong>TMEM（Tensor Memory）</strong></dt><dd>Blackwell 的显式片上 tensor 存储资源，通过 <code>tcgen05.alloc/dealloc</code> 管理。它与普通 shared memory 不同，也可能影响 CTA 准入。</dd>
    </dl>

    <h2>模型与算子</h2>
    <dl>
      <dt><strong>QKV</strong></dt><dd>Attention 前生成 Query、Key、Value 的投影。</dd>
      <dt><strong>GQA（Grouped-Query Attention）</strong></dt><dd>多个 Q head 共享较少的 K/V head；课程中的 Llama-8B 每个 KV head 对应 4 个 Q head。</dd>
      <dt><strong>Split-KV</strong></dt><dd>把一个 KV head 的上下文区间分成多个 partition 并行计算，再合并 partial attention。</dd>
      <dt><strong>LSE（Log-Sum-Exp）</strong></dt><dd>稳定 softmax 合并所需的对数归一化量。</dd>
      <dt><strong>OProj / UpGate / DownProj</strong></dt><dd>分别表示 attention 输出投影、MLP 上投影与门控、MLP 下投影。</dd>
      <dt><strong>LMHead</strong></dt><dd>把最后的 hidden state 投影为词表 logits 的输出层。</dd>
    </dl>

    <h2>工具与证据</h2>
    <dl>
      <dt><strong>NCU（Nsight Compute）</strong></dt><dd>NVIDIA 的 kernel profiler。课程引用的 duration、warp stall 和吞吐指标来自特定 profile 合同，不能自动等同于服务端端到端延迟。</dd>
      <dt><strong>PTX / SASS / CUBIN</strong></dt><dd>PTX 是虚拟指令表示，SASS 是目标 GPU 机器指令，CUBIN 是包含机器码和资源 metadata 的二进制。</dd>
      <dt><strong>JIT（Just-In-Time compilation）</strong></dt><dd>运行时根据配置生成并编译 kernel；资源 manifest 必须进入 cache key，避免错误复用旧 binary。</dd>
      <dt><strong>A/B、A/B/A、ABBA/BAAB</strong></dt><dd>交错运行 baseline 与 candidate 的顺序设计，用来降低温度、频率和时间漂移造成的偏差。</dd>
      <dt><strong>Bitwise</strong></dt><dd>逐比特完全一致的正确性标准；它比“数值大致接近”更严格，但仍不能单独证明并发协议在所有执行中都安全。</dd>
      <dt><strong>Falsifier / 负控</strong></dt><dd>被设计来推翻某个解释的实验。好的负控应在错误实现上按预期失败。</dd>
      <dt><strong>PhaseNN</strong></dt><dd>研究日志中的实验阶段编号，例如 Phase82。它帮助定位工件，不代表 CUDA 或硬件版本。</dd>
      <dt><strong>c473</strong></dt><dd>课程引用的一份 canonical source snapshot 的内部标识。它只用于区分源码基线，不是 NVIDIA 产品名。</dd>
      <dt><strong>Canonical / Legacy</strong></dt><dd>canonical 是当前 clean reference baseline；Legacy 是较早历史实现。二者的模型、shape 或代码可能不同，证据不能无条件互相迁移。</dd>
      <dt><strong>Dirty worktree</strong></dt><dd>测量时源码目录含未提交修改。结果仍可作为历史证据，但复现性和 binary 身份弱于 clean、冻结的提交。</dd>
      <dt><strong>Model-forward / Serving wall</strong></dt><dd>model-forward 是一次模型前向计算的计时边界；serving wall 还可能包含排队、调度、采样、通信和框架开销。两者不能互称。</dd>
      <dt><strong>HMMA / ILP / MIO</strong></dt><dd>HMMA 指 Tensor Core 矩阵乘累加指令；ILP 是单线程或 warp 内的指令级并行；MIO 是 NCU 对 shared-memory 等内存输入输出管线的指标类别。</dd>
    </dl>

    <h2>单位</h2>
    <ul>
      <li><strong>KiB</strong>：1024 bytes；<strong>MiB</strong>：1024 KiB。</li>
      <li><strong>μs</strong>：微秒；<strong>ms</strong>：毫秒。</li>
      <li><strong>BF16</strong>：每元素 2 bytes 的 16-bit 浮点格式。</li>
      <li><strong>M=1</strong>：矩阵乘法中 token/batch 方向只有一行，常见于单 token decode。</li>
    </ul>
  </div>
</section>
