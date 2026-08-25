---
layout: default
title: 关于课程
description: GPU Megakernel 实战课的学习路线、适合人群与证据来源。
permalink: /about/
---
<section class="plain-page shell">
  <p class="section-index">ABOUT THE COURSE</p>
  <h1>给第一次接触 Megakernel 的你。</h1>
  <div class="prose">
    <p>Megakernel 不是“把所有算子塞进一个 CUDA 文件”这么简单。它更像一台常驻 GPU 的小型执行引擎：不同 warp 扮演 controller、loader、consumer、storer；shared-memory page 在指令间复用；TMA、barrier、global counter 与调度器共同维持正确性。</p>
    <blockquote>本课程的目标不是让你背下某个 B200 实现，而是学会问：谁在等待谁？数据何时可见？资源何时真正释放？一个数字到底证明了什么？</blockquote>
    <h2>适合谁</h2>
    <ul><li>会写基础 CUDA，但第一次接触 persistent kernel。</li><li>能看懂 block、warp、shared memory，却不熟悉 TMA、mbarrier、TMEM。</li><li>正在做推理系统或 kernel 优化，希望建立严格的 benchmark contract。</li></ul>
    <h2>为什么从第 36 课开始</h2>
    <p>课号延续真实研究日志。第 36–54 课形成了一条独立、完整的进阶线：先从一个已经测过的 page-ready 优化进入，再逐层追问资源、调度、内存序和实验设计。更早课程会在证据整理完成后继续公开。</p>
    <h2>证据来源</h2>
    <p>课程区分 clean canonical source、历史 dirty snapshot、冻结报告、exact CUBIN/NCU 与设计提案。图上的 <strong>CURRENT</strong>、<strong>MEASURED</strong>、<strong>PROPOSED · UNMEASURED</strong> 不是装饰，而是结论的边界。</p>
  </div>
</section>

