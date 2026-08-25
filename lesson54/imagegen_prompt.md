# Lesson 54 — deterministic poison litmus infographic

Purpose: generate the base diagnostic image for READY_EARLY and ACK_EARLY mutation tests. The later edit prompt records evidence-critical corrections applied to the final PNG.

Create a polished 16:9 teaching infographic, 1672×941 pixels, for a beginner CUDA/Megakernel course. Use a dark navy engineering-blueprint background, crisp flat vector style, high contrast, restrained neon green for correct, red/orange for broken, cyan for data movement, and purple only for historical evidence. All text must be sharp and legible. Do not invent any performance number. This is a diagnostic proposal, not a measured optimization.

Top title, exact Chinese:
“第54课｜怎么证明一把‘门’真的安全？”
Subtitle:
“正例全绿不够：坏协议必须按预期露馅”
Small upper-right badge:
“DIAGNOSTIC PROPOSAL · UNMEASURED”

Use three large panels across the middle.

LEFT PANEL — exact page anatomy. Heading:
“一页的真实解剖”
Draw exactly ONE 32 KiB horizontal page, split into exactly FOUR equal 8 KiB rooms. Label them, left to right:
“W0 · 8 KiB”  “W1 · 8 KiB”  “W2 · 8 KiB”  “W3 · 8 KiB”
Above the first two rooms draw one cyan delivery arrow labeled:
“TMA0 · 16 KiB”
Above the last two rooms draw a second cyan delivery arrow labeled:
“TMA1 · 16 KiB”
Under the page, exact sentence:
“两笔 TMA 都完成，READY 才能亮”
Use repeated small epoch tags “e” in the good rooms and red diagonal POISON hatching as the prefill background.

CENTER PANEL — READY_EARLY mutation. Heading:
“负控 A｜READY 提前”
Show a short causal timeline, left-to-right:
“TMA0 完成” → a wrongly lit green lamp “READY=1” → “W0/W1 读 e” and “W2/W3 读 POISON” → red badge “bad mask = 1100”
Show TMA1 visibly locked behind a red gate and label:
“TMA1 尚未发出”
Below, a compact GOOD lane in green:
“GOOD：TMA0 + TMA1 → READY → mask 0000”
Make it visually undeniable that READY_EARLY exposes exactly W2 and W3, not W0 and W1.

RIGHT PANEL — ACK_EARLY mutation. Heading:
“负控 B｜ACK 提前”
Draw four small consumer figures W0, W1, W2, W3. W3 is paused behind a red gate before its last read. W0–W2 each emit one checkmark ACK. Show a broken counter:
“错误门槛：3 / 4”
Then show overwrite of the same 32 KiB page with next epoch “e+1”, followed by W3 being released and reading “NEXT(e+1)” instead of “e”. Add red causal ribbon:
“3 ACK → 覆写 e+1 → W3 最后读取”
Below, green correct rule:
“GOOD：4 ACK → 才允许覆写”

Bottom section spans full width with four compact cards and one history card.

Card 1, green:
“正控”
“100/100 PASS_GOOD”

Card 2, red:
“必杀负控”
“100/100 PASS_MUTANT_KILLED”

Card 3, amber:
“NO_ACQUIRE 全绿”
“INCONCLUSIVE BY DESIGN”

Card 4, blue, split into two clearly separate hash chips:
“DEBUG LITMUS HASH” ≠ “RELEASE PERF HASH”
Small line:
“诊断延迟不能冒充性能”

Purple historical evidence card, exact text:
“历史警示｜Phase73→79”
“20次 exact/bitwise 全绿；100次才发现漂移”
“0.617 ms / 1.493× 已撤回”

At the very bottom place a wide verdict rail with exact labels separated by arrows:
“DEVICE STATUS ≠ SUBJECT OUTCOME ≠ TEST VERDICT”
And the final Chinese takeaway in larger type:
“坏程序按预期失败，测试才算通过。”

Accuracy constraints:
- Exactly four rooms W0–W3; exactly two TMA arrows, each covering exactly two rooms.
- The READY_EARLY bad mask is exactly 1100; GOOD mask exactly 0000.
- The ACK mutant threshold is exactly 3/4; correct threshold is exactly 4 ACK.
- Do not show latency for the proposed R1c mechanism.
- Historical 0.617 ms / 1.493× must be visibly crossed out or stamped “已撤回”, never presented as a win.
- No photographs, no decorative GPU chip, no fake charts, no extra numeric claims.
