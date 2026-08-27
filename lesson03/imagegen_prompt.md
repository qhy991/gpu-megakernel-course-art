# Lesson 3 ImageGen prompt

Purpose: create a beginner teaching image showing that the same execution has different measured durations when different stopwatch boundaries are used, so timing boundaries must be checked before interpreting performance numbers.

Use case: scientific-educational

Asset type: Lesson 3 hero infographic for a Chinese GPU course

## 16:9 visual requirements

- Exact canvas: 1672×941 pixels, landscape 16:9.
- Dark navy technical timeline background with cyan execution blocks, amber timing brackets, red only for the invalid comparison symbol.
- Crisp flat vector-like infographic, high contrast, generous whitespace, large readable Simplified Chinese typography.
- Show one horizontal execution timeline and three nested timing brackets; no dense profiler dashboard.
- No photorealism, people, logos, watermark, fake charts, or numerical measurements.

## Text (verbatim)

Main title:

“先看秒表边界，再看性能数字”

Short labels; render only these labels and no additional prose:

- “完整请求”
- “GPU 区间”
- “单个 Kernel”
- “不能混比”

## Core composition

Draw one wide execution timeline containing a small CPU preparation segment, several GPU work blocks, a small gap, and a final synchronization segment. Do not label the individual blocks with extra words.

Above the timeline, place three clearly nested stopwatch brackets. The longest bracket covers the entire timeline and is labeled “完整请求”. The middle bracket covers only the GPU interval and is labeled “GPU 区间”. The shortest bracket surrounds one GPU work block and is labeled “单个 Kernel”. Give the brackets different but coordinated colors and align their endpoints precisely with what each stopwatch includes.

On the right, show two otherwise similar stopwatch faces with different bracket icons behind them. Separate them with a bold orange-red prohibition mark and the label “不能混比”. The viewer should understand that all three measurements may be valid, but they answer different questions.

## Misleading claims to avoid

- Do not portray wall time, CUDA Event time, and one-kernel profiler duration as interchangeable.
- Do not imply that summing overlapping kernel durations always equals the full GPU interval.
- Do not equate GPU-busy time with arithmetic utilization or useful work.
- Do not add occupancy, bandwidth, stall percentages, latency values, speedup values, or any invented number.
- Do not mark one stopwatch as universally correct and the others as wrong.
