Use case: scientific-educational
Asset type: 16:9 beginner CUDA systems lesson infographic, 1672×941 landscape
Primary request: Create a polished, technically exact Chinese teaching infographic comparing a stage-wide 64 KiB readiness gate with two page-ready 32 KiB gates inside a three-page canonical MegaKittens matvec proposal.

Scene/backdrop: dark navy engineering blueprint background, subtle CUDA-grid texture, crisp cyan/amber/purple accents, generous spacing, flat 2D vector-like technical illustration, no photorealism.

Audience and objective: a Chinese-speaking CUDA beginner. The visual must make one idea obvious: same bytes, same pages, same math; only the synchronization dependency is finer, allowing a wavefront across iterations.

Composition/framing:
- Full-width header.
- Main upper 62% split into two equal cards: left R1b STAGE-WIDE, right R1c PAGE-READY.
- A thin center arrow labeled "只改同步粒度".
- Lower 30% contains three compact cards: UNCHANGED ledger, historical legacy evidence, measurement gate.
- Footer provenance ribbon.

Header text, verbatim:
"第53课｜三页也能流水吗？"
Subtitle, verbatim:
"把 64 KiB 大门拆成两扇 32 KiB 小门"

LEFT CARD — exact title text:
"R1b · STAGE-WIDE"
Draw exactly THREE physical page blocks:
1. one blue block "LID0 · AUX + O0/O1/O2"
2. one amber block "LID1 · PAGE 0 · 32 KiB"
3. one amber block "LID2 · PAGE 1 · 32 KiB"
Draw exactly FOUR 16 KiB TMA arrows total, two entering PAGE 0 and two entering PAGE 1.
Put one large red gate spanning both amber pages, exact text "64 KiB READY".
Behind the gate draw exactly EIGHT warp chips W0 W1 W2 W3 W4 W5 W6 W7, all blocked together.
Under them print "1 READY · 1 FINISHED(count=8)" and "BASE SEM = 9".
Timeline with two iterations, verbatim labels:
"ITER i: LOAD P0 → LOAD P1 → W0…W7"
"ITER i+1: 等全部 8 个 ACK"
Use a red vertical idle gap before the second iteration.

RIGHT CARD — exact title text:
"R1c · PAGE-READY · PROPOSED"
Draw the SAME exact three physical page blocks with the same sizes and labels.
Draw exactly FOUR 16 KiB TMA arrows total, two per amber page.
Draw TWO separate green gates:
"PAGE 0 READY · 32 KiB" leading only to exactly four warp chips W0 W1 W2 W3;
"PAGE 1 READY · 32 KiB" leading only to exactly four warp chips W4 W5 W6 W7.
Show a diagonal wavefront timeline: while PAGE 1 of ITER i is still being consumed by W4–W7, PAGE 0 of ITER i+1 is loaded and consumed by W0–W3. Use translucent diagonal arrows, not a misleading full barrier.
Print the exact lifecycle once:
"2×16 KiB TMA → READY → 4 WARPS → ACK → REUSE"
Print "2 READY · 2 FINISHED(count=4)" and "BASE SEM = 11".
Add a small note: "P0 保留末尾 8-warp page release，避免混入第二变量".

LOWER LEFT CARD exact heading "UNCHANGED":
"3 PAGES · 99,328 B DYNAMIC"
"4 TMA / ITER · 64 KiB / ITER"
"8 CONSUMER WARPS · SAME MATVEC"
"OUTPUT DEPTH = 3 · GRID 不变"
Add a small crossed-out badge: "NOT 2 CTA/SM".

LOWER CENTER PURPLE CARD exact heading:
"历史旁证｜LEGACY 8B · 非 CANONICAL"
"128 KiB 大门 → 8×16 KiB 小门"
"全模 3.620 → 2.842 ms · 约 −21.5%"
"16→8 KiB 仅 −0.033～−0.152% · 已撤回"
Small footnote: "同为 depth=1，但模型、页、warp 组均不同；不能迁移收益率。"

LOWER RIGHT CARD exact heading "HOW TO PROVE":
Use a four-step row:
"POISON / PHASE" → "SASS" → "NCU SOURCE-PC" → "ABBA LATENCY"
Below it print:
"TMA bytes 必须相同"
"看 eligible / issue / wait-PC，不猜 stall 名字"
"同步更细 ≠ 一定更快"

Footer exact text:
"CURRENT c473 SOURCE FACTS ｜ R1c PROPOSAL · UNMEASURED"
"先放行能算的人，不代表最后一人一定更早到。"

Style/medium: premium editorial technical infographic, crisp flat geometric shapes, high contrast, restrained glow, readable Chinese sans-serif typography, precise arrows and counts.
Color palette: navy #071426; cyan #35C8FF; amber #F6B84A; green #39D98A; red #FF5F66; purple #A68BFF; off-white text.

Constraints:
- Exactly three physical page blocks on EACH main side.
- Exactly four TMA arrows and eight warp chips on EACH main side.
- Right side must visibly group warps 4+4, never 2+6 or other counts.
- Do not imply page-ready changes total data, TMA count, shared-memory footprint, occupancy, or grid.
- Do not show a speedup number for canonical R1c.
- Keep historical 8B numbers inside the purple card and label them non-canonical.
- Render every quoted string verbatim with no extra words.
- No logos, mascots, photorealistic GPU, watermark, or decorative fake charts.

Avoid: illegible tiny text, wrong page count, wrong warp count, replacing KiB with KB, invented percentages, green winner trophy, bar charts implying measured R1c latency.
