---
layout: default
title: 证据规则
description: 读懂课程中 measured、source-proven、proposed 与 withdrawn 的严格含义。
permalink: /evidence/
---
<section class="plain-page shell">
  <p class="section-index">EVIDENCE RULES</p>
  <h1>先知道数字能证明什么。</h1>
  <div class="prose">
    <p>证据标签描述的是<strong>结论的来源与适用范围</strong>，不是文章质量评分。一个待测设计可以写得很完整，但在测量完成前仍必须标为 <strong>PROPOSED · UNMEASURED</strong>。</p>
    <h2>四种常见标签</h2>
    <table><thead><tr><th>标签</th><th>含义</th><th>不能外推</th></tr></thead><tbody>
      <tr><td><strong>MEASURED</strong></td><td>有匹配的计时或 profiler 工件</td><td>不能自动变成 serving 结论</td></tr>
      <tr><td><strong>SOURCE-PROVEN</strong></td><td>源码足以证明几何、依赖或资源公式</td><td>不能当作实测性能</td></tr>
      <tr><td><strong>PROPOSED · UNMEASURED</strong></td><td>设计可执行，但尚未通过完整门</td><td>不能画 winner 徽章</td></tr>
      <tr><td><strong>WITHDRAWN</strong></td><td>旧结果被更强正确性或协议审计推翻</td><td>不能继续引用为收益</td></tr>
    </tbody></table>
    <h2>标签后的修饰词</h2>
    <ul>
      <li><strong>CANONICAL</strong>：来自当前 clean reference baseline；<strong>LEGACY</strong>：来自较早历史实现。</li>
      <li><strong>EXACT BINARY / CUBIN</strong>：资源数字来自与该检查匹配的 GPU binary；没有 exact 时只能写源码推导。</li>
      <li><strong>DIRTY SOURCE</strong>：测量来自含未提交修改的历史 worktree，复现身份较弱。</li>
      <li><strong>MIXED EVIDENCE</strong>：同一课含多种证据强度，必须逐段阅读边界。</li>
      <li><strong>UNKNOWN / UNMEASURED</strong>：该实验臂尚未获得有效结果；不是零收益，也不是负收益。</li>
    </ul>
    <h2>一次性能结论至少要回答</h2>
    <ol><li>跑到的真是候选路径吗？</li><li>输入、shape、KV、精度和同步边界一致吗？</li><li>输出满足预注册正确性门吗？</li><li>A/A 噪声与运行顺序是否控制？</li><li>事件计时、NCU range 和 serving wall 分别覆盖什么？</li><li>exact binary 的寄存器、spill、shared memory 与 TMEM 是否冻结？</li></ol>
    <blockquote>“没有观察到错误”不是内存协议证明；“occupancy 允许 2 CTA”也不是实际同时驻留，更不是性能提升。</blockquote>
    <h2>从弱到强的资源证据链</h2>
    <ol><li><strong>源码几何</strong>：根据数组、page、thread 和配置公式推导理论需求。</li><li><strong>Exact CUBIN</strong>：冻结真正计时 binary 的寄存器、stack、spill、shared memory 与 TMEM metadata。</li><li><strong>Occupancy API</strong>：证明资源模型允许多少 CTA 驻留；它仍不是观察结果。</li><li><strong>NCU 或 timeline</strong>：观察执行时是否真的出现目标驻留、等待与指令变化。</li><li><strong>Paired latency</strong>：在正确性和路径身份都通过后，判断候选是否跨过噪声门。</li></ol>
    <h2>读一个性能数字时补齐这张卡</h2>
    <table><thead><tr><th>字段</th><th>应该写清楚</th></tr></thead><tbody>
      <tr><td>对象</td><td>模型、层数、M/N/K、context、精度与硬件</td></tr>
      <tr><td>路径</td><td>实际执行的 provider、Graph census、kernel/CUBIN hash</td></tr>
      <tr><td>时间边界</td><td>isolated kernel、整张 model-forward、NCU range 或 serving wall</td></tr>
      <tr><td>正确性</td><td>bitwise、容差、real-KV、reset/replay 次数与失败签名</td></tr>
      <tr><td>噪声控制</td><td>A/A、双顺序、样本数、p50/p95 和预注册阈值</td></tr>
      <tr><td>结论边界</td><td>能支持什么；不能外推到什么模型、shape 或部署合同</td></tr>
    </tbody></table>
    <p>课程中的 NCU、CUBIN、PTX、SASS、A/B/A 等缩写见<a href="{{ '/glossary/' | relative_url }}">术语表</a>。</p>
  </div>
</section>
