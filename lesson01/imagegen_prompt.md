# Lesson 1 ImageGen prompt

Purpose: create a beginner teaching image that explains one idea only: a physical kernel boundary changes how intermediate data is handed off, while merely reducing the number of kernels does not guarantee a faster program.

Use case: scientific-educational

Asset type: Lesson 1 hero infographic for a Chinese GPU course

## 16:9 visual requirements

- Exact canvas: 1672×941 pixels, landscape 16:9.
- Dark navy engineering-blueprint background with subtle grid lines.
- Cyan for useful dataflow, orange for physical kernel boundaries and detours, lime only for a valid direct handoff.
- Crisp flat vector-like raster illustration, restrained glow, generous whitespace, large readable Simplified Chinese typography.
- One visual comparison, no dense dashboard, no photorealism, people, logos, watermark, benchmark chart, or decorative GPU chip.

## Text (verbatim)

Main title:

“Kernel 边界，决定数据要不要绕远路”

Short labels; render only these labels and no additional prose:

- “CPU 下单”
- “独立 Kernel”
- “HBM 中转”
- “同一 Kernel 直传”

## Core composition

Use a clean left-versus-right comparison around one glowing data block.

On the left, draw three separate blue processing chambers. Give each chamber a clear orange outline to represent a physical kernel boundary. The glowing data block leaves one chamber, travels down to a large warehouse-like memory tray, and is read back into the next chamber. Repeat the visible detour once so the route is unmistakably longer. Place “CPU 下单” near the entrance, “独立 Kernel” above the separated chambers, and “HBM 中转” beside the warehouse tray.

On the right, draw one continuous processing chamber containing three internal workstations. The same data block moves between workstations through short cyan arrows without leaving the chamber. Place “同一 Kernel 直传” beside this short handoff. Keep both sides comparable in workload; the only visual variable is the execution boundary and handoff path.

The image should make a beginner infer: boundaries can force a longer handoff, but the image is explaining a possible cost, not declaring a winner.

## Misleading claims to avoid

- Do not portray a Megakernel as automatically faster or always preferable.
- Do not imply that CUDA Graph merges multiple physical kernels.
- Do not show registers or shared memory surviving across separate kernel boundaries.
- Do not mix in the full GPU/SM/CTA/warp hierarchy.
- Do not add latency, percentage, speedup, throughput, occupancy, or any invented performance number.
- Do not add “winner”, trophy, checkmark verdict, or green speed badge.
