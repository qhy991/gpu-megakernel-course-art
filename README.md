# GPU Megakernel 课程配图（Lessons 36–54）

初级 GPU/CUDA systems 课程的成套 16:9 教学信息图与生成提示词，主题围绕
B200/Blackwell megakernel 设计：page-pipeline 时序边界、shared-memory
分页与驻留资格、CTA 资源封套（shared memory / registers / tmem）、
megakernel 岛屿划分与切分判据、受控实验树（R0–R5）、canonical
Llama-1B matvec 与 poison litmus 等。

## 目录结构

每个 `lessonNN/` 目录对应一课：

- `*_16x9.png` —— 最终成图（1672×941，深蓝工程蓝图风格，中文标注）
- `imagegen_prompt.md` —— 该图的完整 ImageGen 提示词（含精确文案锁定）
- `imagegen_edit_prompt.md` —— 视觉 QA 修正提示词（只改证据关键细节）
- 同图多版本以 `-v2`／`-v3` 后缀保留迭代历史

## 证据纪律

图内颜色语义在整套课程中固定：红色 = CURRENT 阻塞事实，琥珀色 =
PROPOSAL·UNMEASURED，绿色 = 已通过的必要检查。配图不展示性能结论或
胜者徽章；撤回的结果（如 `0.617 ms / 1.493×`）以历史警示卡片呈现。

## 用途

图片被课程讲义引用；提示词归档保证同风格续作课次时可复现视觉语言。
