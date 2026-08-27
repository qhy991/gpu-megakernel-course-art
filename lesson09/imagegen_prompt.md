# Lesson 9 ImageGen prompt

Purpose: create a beginner teaching image that distinguishes a CTA staying resident during one token forward from a decode engine staying alive across multiple token iterations.

Use case: scientific-educational

Asset type: Lesson 9 hero infographic for a Chinese GPU course

## 16:9 visual requirements

- Exact canvas: 1672×941 pixels, landscape 16:9.
- Dark navy timeline background, cyan resident work, orange launch/exit boundaries, lime continuous cross-token loop.
- Crisp flat vector-like illustration with two large horizontal timelines, strong boundary markers, generous whitespace, large Simplified Chinese text.
- Reuse the same simple worker-CTA icon on both timelines for a fair visual comparison.
- No photorealism, people, logos, watermark, profiler chart, or performance numbers.

## Text (verbatim)

Main title:

“常驻多久，必须说清楚”

Short labels; render only these labels and no additional prose:

- “每 Token 启动”
- “层内常驻”
- “退出”
- “跨 Token 循环”

## Core composition

Use two stacked timelines.

The upper timeline contains three separate long chambers for three successive token iterations. Each chamber begins with a narrow orange launch gate, contains the same group of worker CTA icons moving through many internal layer tiles, and ends at a clear orange exit gate. Put “每 Token 启动” by the entrances, “层内常驻” inside the chambers, and “退出” at each chamber end.

The lower timeline has one launch entrance followed by one continuous loop that passes through three successive token markers without an exit between them. Label the loop “跨 Token 循环”. Add a few small unlabeled control icons around the loop—a sampler dial, stop sign outline, request queue, and memory-page tray—to hint that a cross-token engine requires more than adding a loop.

The visual question is lifetime only; keep mathematical work identical between the two timelines.

## Misleading claims to avoid

- Do not portray a per-token Megakernel as a cross-token persistent engine.
- Do not portray CUDA Graph as one physical kernel.
- Do not show future decode tokens being computed before the preceding token result exists.
- Do not imply that MPS creates additional SMs, registers, or shared memory.
- Do not imply that a cross-token engine is implemented by a trivial loop alone.
- Do not add latency, throughput, speedup, percentage, or any invented performance number.
