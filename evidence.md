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
    <h2>四种常见标签</h2>
    <table><thead><tr><th>标签</th><th>含义</th><th>不能外推</th></tr></thead><tbody>
      <tr><td><strong>MEASURED</strong></td><td>有匹配的计时或 profiler 工件</td><td>不能自动变成 serving 结论</td></tr>
      <tr><td><strong>SOURCE-PROVEN</strong></td><td>源码足以证明几何、依赖或资源公式</td><td>不能当作实测性能</td></tr>
      <tr><td><strong>PROPOSED · UNMEASURED</strong></td><td>设计可执行，但尚未通过完整门</td><td>不能画 winner 徽章</td></tr>
      <tr><td><strong>WITHDRAWN</strong></td><td>旧结果被更强正确性或协议审计推翻</td><td>不能继续引用为收益</td></tr>
    </tbody></table>
    <h2>一次性能结论至少要回答</h2>
    <ol><li>跑到的真是候选路径吗？</li><li>输入、shape、KV、精度和同步边界一致吗？</li><li>输出满足预注册正确性门吗？</li><li>A/A 噪声与运行顺序是否控制？</li><li>事件计时、NCU range 和 serving wall 分别覆盖什么？</li><li>exact binary 的寄存器、spill、shared memory 与 TMEM 是否冻结？</li></ol>
    <blockquote>“没有观察到错误”不是内存协议证明；“occupancy 允许 2 CTA”也不是实际同时驻留，更不是性能提升。</blockquote>
  </div>
</section>

