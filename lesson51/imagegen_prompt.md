# Lesson 51 ImageGen prompts

## Base prompt

Use case: scientific-educational

Asset type: Lesson 51 beginner GPU course infographic, 16:9

Primary request: Create a polished dark-navy blueprint infographic that teaches controlled CUDA experiments. Exact canvas 1672×941. Simplified Chinese plus short English technical labels. Crisp flat vector style, high contrast, readable typography, no photorealism, no people, no logos, no winner badge.

Top title, verbatim:
“第51课｜R0→R5：每次只拧一个旋钮”

Subtitle, verbatim:
“父子比较 = 因果｜跨级比较 = 猜测”

At upper left, show two separate baseline cards:
“W · WHOLE” / “production reference”
and
“R0 · TWO-ISLAND ANCHOR” / “3-stage · 7 pages · 8C224 · TMEM512 · grid148”

Between them place a small bracket with exact text:
“W→R0 只测 seam tax” / “不是资源收益”

Across the main center, draw a left-to-right laboratory experiment tree with five large numbered stages, connected by arrows. Amber means PROPOSAL · UNMEASURED.

Stage 1 card exact:
“R1 · SHARED”

- “R1a：3→1 stages” / “仍分配 7 pages”
- “R1b：7→3 pages” / “230,400→99,328 B”
- “先测流水税，再测物理 SMEM”

Stage 2 card exact:
“R2 · REGISTERS”

- upper branch: “R2a：8C224→8C96” / “nominal 31,744”
- lower branch: “R2b0：8C→4C，仍224” then arrow to “R2b：4C224→4C192” / “nominal 31,744”
- “exact CUBIN + spill gate”

Stage 3 card exact:
“R3 · TMEM”

- “R3a：512→256”
- “R3b：512→0”
- “admission only · NO SPEED CLAIM”

Stage 4 card exact:
“R4 · WORK SUPPLY”

- “workers / grid / schedule”
- “148→296”
- “blockIdx.x → logical slot”
- “每个任务恰好一次”

Stage 5 card exact:
“R5 · READY-ONLY”

- “BLOCKED → QUEUED → RUNNING → DONE”
- “绝不 claim 未 ready 的任务”

On the right side add a small gray diagnostic-only card:
“DIAGNOSTICS ONLY”

- “launch_bounds(...,2)”
- “cooperative launch”
- “cluster2 = separate lane”

These are not part of the main R0→R5 causal chain.

Across the lower section, draw a five-gate evidence ladder, exact labels:
“COMPILE” → “EXACT CUBIN” → “REAL-KV BITWISE” → “USEFUL CTA > 148” → “ABBA LATENCY”

Below the ladder show four small test chips:

- “W-wide · FILL”
- “W-invert · LIVENESS”
- “W-narrow · HONEST USEFUL COUNT”
- “real-KV · PRODUCTION”

At bottom right, a compact red warning card with exact lines:
“DO NOT SKIP”

- “grid296 ≠ 296 correct workers”
- “occupancy2 ≠ faster”
- “−2% apparent wins：REAL-KV FAIL”

Bottom full-width footer exact:
“CURRENT canonical c473 · clean · cluster1 main lane｜PROPOSAL · UNMEASURED”

Second exact sentence:
“先证明谁在做什么，再测做得多快。”

Color semantics:

- blue/cyan = current measured/source anchors;
- amber = proposed unmeasured changes;
- green = evidence gates only;
- red = invalid inference or rejected historical evidence.

Make the experiment tree the dominant visual. Preserve every number exactly. Do not add any other measurements or performance claims.

## Final correction prompt

Edit the supplied Lesson 51 infographic conservatively. Preserve the exact 1672×941 canvas, all colors, title, subtitle, W and R0 cards, R1/R3/R4/R5 cards, evidence ladder, four test chips, diagnostic card, red warning card, footer, every number, and every other word.

Make only two corrections:

1. Inside the “R2 · REGISTERS” card, fix the causal arrows. R2a and R2b0 are parallel sibling branches from the R1b parent, not a sequence. Remove the downward arrow from “R2a：8C224→8C96” to “R2b0：8C→4C，仍224”. Draw a clean fork:
   - upper branch ends at “R2a：8C224→8C96 / nominal 31,744”
   - lower branch goes first to “R2b0：8C→4C，仍224”, then downward to “R2b：4C224→4C192 / nominal 31,744”
   The diagram must visually make it impossible to read R2a→R2b0.
2. In the R4 card, render the exact identifier: “blockIdx.x → logical slot”. Use uppercase I exactly as written.

Change nothing else. Keep crisp readable typography and no new claims.
