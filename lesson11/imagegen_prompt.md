# Lesson 11 ImageGen prompt

Purpose: create a beginner teaching image that distinguishes resident, active, eligible, and issued warps, making clear why many warps can be present while the scheduler still has almost nothing ready to run.

Use case: scientific-educational

Asset type: Lesson 11 hero infographic for a Chinese GPU course

## 16:9 visual requirements

- Exact canvas: 1672×941 pixels, landscape 16:9.
- Dark navy SM/factory schematic, blue resident workers, cyan active paths, amber waiting states, lime eligible/issued state.
- Crisp flat vector-like scientific illustration with one left-to-right funnel, generous spacing, large readable Simplified Chinese typography.
- Use abstract warp tiles or helmet-free worker icons; avoid realistic people.
- No dense NCU dashboard, logos, watermark, fake percentage chart, or performance number.

## Text (verbatim)

Main title:

“工人在场，不等于现在能开工”

Short labels; render only these labels and no additional prose:

- “Resident”
- “Active”
- “Eligible”
- “Issued”
- “等待原因”

## Core composition

Draw one large SM factory as a left-to-right state funnel.

At the broad “Resident” entrance, show many blue warp tiles already inside the SM. The “Active” section retains many unfinished tiles. Before “Eligible”, place several amber waiting gates: a material package in transit, a barrier light, and a dependency chain. Group these icons under “等待原因”. Only a few tiles pass the gates and glow cyan-lime as “Eligible”. At the narrow output, a scheduler gate selects one tile into an execution machine labeled “Issued”.

Use continuous identity marks on the warp tiles so viewers can see that a warp may be resident and active yet not eligible. The shrinking funnel represents readiness, not a literal fixed ratio.

## Misleading claims to avoid

- Do not equate occupancy or resident warps with useful utilization.
- Do not equate Active with currently executing an instruction.
- Do not imply that long-scoreboard waiting always means DRAM bandwidth is saturated.
- Do not declare a root cause from one stall category alone.
- Do not add B200 counter values, percentages, duration, speedup, throughput, or any invented measurement.
- Do not imply that a low Eligible count is solved by increasing theoretical arithmetic peak alone.
