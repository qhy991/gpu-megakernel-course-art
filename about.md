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
    <h2>开始前需要知道什么</h2>
    <p><strong>不要求 GPU 基础。</strong>每课开头先用一个日常问题和生活类比建立直觉，再进入技术解释。第一次出现缩写时可直接查<a href="{{ '/glossary/' | relative_url }}">术语表</a>；公式、指令名和性能计数器可以先跳过，不影响理解主线。</p>
    <h2>适合谁</h2>
    <ul><li>会写基础 CUDA，但第一次接触 persistent kernel。</li><li>能看懂 block、warp、shared memory，却不熟悉 TMA、mbarrier、TMEM。</li><li>正在做推理系统或 kernel 优化，希望建立严格的 benchmark contract。</li></ul>
    <h2>完整学习路线</h2>
    <p>课程现已完整公开第 1–54 课。第 1–10 课建立 GPU、Llama 数据流、融合边界与 Persistent Megakernel 的基础；第 11–35 课学习性能证据、同步、生命周期与 Ready-aware 调度；第 36–54 课进入真实 B200 优化、资源包络、TMEM 与双 CTA 实验。</p>
    <h2>怎样阅读每一课</h2>
    <ol><li>先读“零基础先看这里”，只抓住问题和类比。</li><li>再看“一句话结论”和配图，不懂缩写先不打断阅读。</li><li>需要动手时再读技术推导，并区分 <strong>MEASURED</strong>、<strong>SOURCE-PROVEN</strong> 与 <strong>PROPOSED</strong>。</li><li>最后用检查表、失败条件或练习复述结论。</li></ol>
    <p>第一次阅读建议从第 1 课顺序开始。若只解决一个具体问题，也可从课程首页按标题跳转，但进阶课程会默认读者已经理解前文的证据等级、数据发布与资源生命周期。</p>
    <h2>证据来源</h2>
    <p>课程区分 clean canonical source、历史 dirty snapshot、冻结报告、exact CUBIN/NCU 与设计提案。图上的 <strong>CURRENT</strong>、<strong>MEASURED</strong>、<strong>PROPOSED · UNMEASURED</strong> 不是装饰，而是结论的边界。</p>
  </div>
</section>
