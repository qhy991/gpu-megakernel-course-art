# Lesson 7 ImageGen prompt

Purpose: create a beginner teaching image showing how a small operator DAG becomes per-CTA task queues inside one resident Megakernel, with events for cross-CTA dependencies and an on-chip page for a same-CTA handoff.

Use case: scientific-educational

Asset type: Lesson 7 hero infographic for a Chinese GPU course

## 16:9 visual requirements

- Exact canvas: 1672×941 pixels, landscape 16:9.
- Dark navy engineering background, cyan DAG arrows, blue CTA lanes, amber wait states, lime publication signals and on-chip handoff.
- Crisp flat vector-like technical illustration, generous spacing, large Simplified Chinese labels, restrained neon glow.
- Use exactly four worker lanes so the scheduling transformation is easy to follow.
- No code listing, tiny instruction fields, photorealism, people, logos, watermark, or performance chart.

## Text (verbatim)

Main title:

“一张任务图，怎样变成 GPU 内部队列？”

Short labels; render only these labels and no additional prose:

- “任务依赖”
- “CTA 队列”
- “等待事件”
- “片上交接”
- “发布完成”

## Core composition

In the upper third, draw a minimal DAG: one normalization node fans out to four parallel linear-tile nodes, and each linear tile connects to its matching activation tile. Place “任务依赖” beside this graph.

In the center, pass the graph through a clean scheduler/converter device without adding another text label. In the lower half, show exactly four horizontal worker CTA lanes labeled together by “CTA 队列”. Each lane contains a short ordered sequence of matching task blocks.

The first lane completes the shared normalization task and lights one small event beacon labeled “发布完成”. The other three lanes begin with an amber gate labeled “等待事件”; once the beacon is lit, cyan arrows let them proceed. Within every lane, connect its linear tile directly to its activation tile through one glowing page/workbench labeled “片上交接”. Make the cross-CTA event and same-CTA page visually distinct.

## Misleading claims to avoid

- Do not present teaching pseudocode or the diagram as a complete compilable implementation.
- Do not let a consumer read data before the producer publishes completion.
- Do not route the same-CTA page handoff through HBM.
- Do not imply that all DAG nodes can run at the same time regardless of dependencies.
- Do not add 148-CTA hardware details, latency, speedup, percentage, or any invented performance number.
- Do not imply that putting operators in one kernel automatically creates true dataflow handoff.
