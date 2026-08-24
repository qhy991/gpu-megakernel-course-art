# Lesson 50 ImageGen prompt

Create a polished 16:9 scientific educational infographic, exact canvas 1672×941, Simplified Chinese, dark navy blueprint background, crisp flat vector style, high contrast, no photorealism, no logos, no people. This is Lesson 50 in a beginner GPU course.

TITLE at top, exact:
“第50课｜2 CTA/SM：五把锁必须同时打开”
Subtitle exact:
“能装下 ≠ 有工作 ≠ 能完成 ≠ 更快”

Central metaphor: one large B200 SM as a two-room apartment / hardware bay with two equal outlined rooms labeled “CTA #0” and “CTA #1”. Five visible padlocks around it, each attached to one clean information card. Use red for CURRENT blocked facts, amber for PROPOSAL · UNMEASURED, green only for already-passed necessary checks. Never show a winner badge or speedup claim.

Five numbered lock cards, keep every number and wording exact:

① SHARED MEMORY
red: “CURRENT 227 KiB/CTA ✕”
white: “2 CTA 预算 ≈ 113 KiB/CTA”
amber: “3-page 候选 ≈ 99 KiB/CTA ?”

② REGISTERS
red: “CURRENT 64,512/CTA ✕”
white: “要求 ≤ 32,768/CTA”
amber: “8C/96 或 4C/192 ?”
small amber: “exact CUBIN 才能判定”

③ TMEM
red: “CURRENT 512 cols ✕”
amber: “256 或 0 ?”
small amber: “ELF / SASS + correctness”

④ WORK SUPPLY
red: “CURRENT grid = 148 ✕”
amber: “需要 ≈296 CTAs”
small amber: “并重建 schedule / targets”

⑤ PROGRESS
red: “普通 launch + global wait：未证明”
amber: “cooperative admission”
amber second line: “或 ready-only worker pool”
small white: “不能等待尚未启动的 producer”

Add a compact GREEN side panel, exact:
“THREAD / WARP CHECK 已通过”
“2×384 = 768 ≤ 2048”
“2×12 = 24 ≤ 64”

Across the bottom, a four-step arrow pipeline, large exact labels:
“FIT”
“exact occupancy ≥ 2”
→
“FILL”
“实际供给 ≈296”
→
“FINISH”
“real-KV exact · no hang”
→
“FASTER”
“paired latency 证明”

At lower right, a separated purple historical evidence card with exact text:
“SEPARATE LEGACY 8B CONTROL”
“2 CTA helper · 0 spill”
“2809.104 → 2843.776 µs”
“+1.234% SLOWER”
small footer: “不同实现；只证明 occupancy 2 也可能更慢”

At very bottom in a strong warning strip:
“CURRENT canonical c473：五把锁尚未同时打开｜PROPOSAL · UNMEASURED”
Second small exact sentence:
“Occupancy = 2 只是允许入住，不是已经入住，更不是速度翻倍。”

Visual hierarchy: title, central two-room SM, five locks, bottom FIT→FILL→FINISH→FASTER chain. Make all typography readable. Use proper multiplication sign ×, ≤, ≈, arrow →, and microseconds symbol µs. Do not add extra numbers.

## Final correction prompt

Edit the supplied infographic conservatively. Preserve the entire image, layout, dimensions, title, all five lock cards, central B200 SM, green thread/warp panel, FIT→FILL→FINISH→FASTER chain, every number, and all colors exactly as they are.

Only change the lower-right purple card titled “SEPARATE LEGACY 8B CONTROL”:

- Keep “2 CTA helper · 0 spill”
- Keep “2809.104 → 2843.776 µs”
- Keep “+1.234% SLOWER”
- Add a prominent small red/orange stamp inside that purple card, exact English text: “CORRECTNESS NOT CERTIFIED”
- Replace the tiny Chinese footer of that purple card with exact text: “worker-ID bug；仅作性能负向下界”

Do not modify any other text or geometry. Maintain exact 1672×941 16:9 canvas and crisp readable typography.
