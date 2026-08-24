Use case: scientific-educational
Asset type: 16:9 beginner GPU systems course infographic, matching the visual language of Lesson 51
Primary request: Explain exactly what the canonical Llama-1B Megakernel's seven 32-KiB shared-memory pages buy, and cleanly separate experiment R1a (reduce weight-input pipeline depth) from R1b (reduce physical pages). This is a source-audited proposal, not a performance result.

Scene/backdrop: dark navy engineering blueprint grid, crisp neon cyan outlines, amber/yellow pipeline elements, green verification elements, small red warning accents. Premium technical-course slide, highly readable, generous spacing, no decorative clutter.

Composition/framing:
- Wide 16:9 canvas, 1672×941 style.
- Top title and a narrow strip showing three independent clocks.
- Main body: three large left-to-right panels named CURRENT R0, R1a, R1b.
- Bottom: one compact workload strip, one measurement strip, and a footer evidence boundary.

Text (verbatim; render all exactly, no extra words):

TITLE:
"第52课｜7页买了什么？三段权重流水"
SUBTITLE:
"R1a先减流水｜R1b再减物理页"

TOP STRIP:
"指令环 = 2"
"权重输入 = 3"
"输出暂存 = 3"
"三套独立流水，别混在一起"

LEFT PANEL HEADER:
"CURRENT R0"
Show seven equal page blocks, each clearly labeled 32 KiB:
Blue workbench block: "LID0 · AUX + O0/O1/O2"
Three amber pairs:
"S0 · LID1/2"
"S1 · LID3/4"
"S2 · LID5/6"
Exact labels:
"1 + 3×2 = 7 pages"
"动态 SMEM = 230,400 B"
Inside LID0 show three tiny result trays O0, O1, O2 and label "3×512 B output scratch".
Below, draw three horizontal role lanes with overlapping colored blocks:
"LOADER" loads S0, S1, S2 ahead;
"8 CONSUMERS" computes the preceding stage;
"STORER" drains O0, O1, O2.
Label the overlap: "LOAD NEXT ∥ COMPUTE NOW ∥ STORE PREV"

CENTER PANEL HEADER:
"R1a · 3→1 INPUT STAGE"
Show LID0 plus active LID1/2 in color; LID3–6 remain visible but gray/hatched and marked unused.
Exact labels:
"仍分配 7 pages"
"动态 SMEM 仍 230,400 B"
"只测流水损失"
Draw the weight timeline mostly serialized:
"LOAD S0 → COMPUTE S0 → REUSE → LOAD S1"
Keep three small output trays O0/O1/O2 active and label:
"OUTPUT 仍是 3 stages"
Small release-order line:
"unused 3,4,5,6 → weights 1,2 → LID0"

RIGHT PANEL HEADER:
"R1b · 7→3 PAGES"
Show exactly three page blocks: LID0 plus one amber pair LID1/2. Do not draw extra pages.
Exact labels:
"动态 SMEM = 99,328 B"
"固定 scratch = 128 B / instruction stage"
"source envelope = 101,376 B / CTA"
"只测物理 SMEM"
Red warning card:
"scratch 若回填"
"总量仍 227 KiB"
"= 假优化"

BOTTOM WORKLOAD STRIP:
"短包：QKV 1/2 · O 1"
"长包：UpGate 6/8 · Down 3/4 · LMHead 54/55"
Large badge:
"86.4% weight iterations 来自长包"
Tiny qualifier:
"canonical 16-layer deterministic schedule · derived"

BOTTOM MEASUREMENT STRIP:
Left arrow card:
"R0 ↔ R1a"
"TMA bytes / math 不变"
"看 overlap、eligible、issue、wait-PC"
Right arrow card:
"R1a ↔ R1b"
"input algorithm 不变"
"看 exact SMEM 与 paired latency"
Final warning:
"R1b 仍不等于 2 CTA/SM"
"REG · TMEM · GRID 还没开锁"

FOOTER:
"CURRENT SOURCE FACTS · canonical c473 · clean"
"R1a / R1b = PROPOSAL · UNMEASURED"
"页变少 ≠ 自动更快；它先拿延迟隐藏去换容量。"

Style/medium: polished flat vector-like raster infographic, sharp geometry, subtle GPU circuit motifs, technical schematic arrows, high contrast, readable Chinese sans-serif typography.

Constraints:
- Exactly seven pages in CURRENT R0: one blue LID0 plus six amber pages in three pairs.
- Exactly three pages in R1b: LID0 plus LID1 and LID2.
- Output stages O0/O1/O2 live inside LID0; they must not look like extra 32-KiB pages.
- Make R1a visibly keep seven allocated pages even though only LID1/2 are active.
- Do not imply measured speedup, measured slowdown, or 2-CTA success.
- Do not conflate instruction pipeline 2 with weight input pipeline 3 or output pipeline 3.
- No logos, watermark, photorealistic GPU, bar chart, speedometer, winner badge, or invented performance number.
