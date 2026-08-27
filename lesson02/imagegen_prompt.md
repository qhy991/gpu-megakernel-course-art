# Lesson 2 ImageGen prompt

Purpose: create a beginner teaching image that follows one newly generated decode token through one Llama layer and shows that attention reads previously stored K/V history.

Use case: scientific-educational

Asset type: Lesson 2 hero infographic for a Chinese GPU course

## 16:9 visual requirements

- Exact canvas: 1672×941 pixels, landscape 16:9.
- Dark navy blueprint background, cyan token/data paths, amber transformation stations, violet-blue memory cabinet, restrained neon glow.
- Polished flat vector-like technical illustration with five large stations, abundant spacing, and large Simplified Chinese text.
- Keep one luminous token block as the visual protagonist from start to finish.
- No formulas, matrix dimensions, small legends, photorealism, people, logos, watermark, or performance chart.

## Text (verbatim)

Main title:

“一枚 Token，怎样穿过一层 Llama？”

Short labels; render only these labels and no additional prose:

- “稳定尺度”
- “生成 Q/K/V”
- “写入记忆”
- “查询历史”
- “加工输出”

## Core composition

Draw a single left-to-right five-station pipeline. A bright cyan token block enters the first station and remains visually traceable across the whole image.

Station one uses a calibrated gauge to represent “稳定尺度”. Station two splits the token stream into three clearly distinct but compact beams marked by the single label “生成 Q/K/V”. Station three sends the K and V beams into a layered archive cabinet labeled “写入记忆”. Station four sends Q along a curved lookup arrow back toward that cabinet, then gathers selected V light into one output stream; label this station “查询历史”. Station five uses one amber transformation chamber labeled “加工输出” and sends the resulting block onward as the next layer input.

Keep the main path linear. The only curved path should be Q looking back into stored history. Make K/V storage visibly persistent while the current token continues forward.

## Misleading claims to avoid

- Do not show one decode step generating several future tokens in parallel.
- Do not depict KV Cache as model weights, permanent training memory, or a general database.
- Do not send V through position rotation; avoid a visual that suggests V follows the Q/K position-processing path.
- Do not imply that one layer is the complete Llama model.
- Do not add layer count, tensor shape, latency, throughput, percentage, or any invented performance number.
- Do not turn the pipeline into a dense architecture poster with extra stage names.
