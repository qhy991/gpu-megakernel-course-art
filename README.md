# GPU Megakernel 实战课（Lessons 36–54）

面向新手的中文 GPU/CUDA systems 博客课程。当前公开第 36–54 课，围绕
B200/Blackwell megakernel 的 page pipeline、Split-KV、shared-memory
分页、CTA 资源封套、TMEM、Megakernel island、受控实验树和 poison
litmus 展开。每课包含完整正文、16:9 图解、证据边界和前后导航。

课程站点：<https://qhy991.github.io/gpu-megakernel-course-art/>

## 目录结构

每个 `lessonNN/` 目录保存配图资产；正文位于 `_posts/`：

- `*_16x9.png` —— 最终成图（1672×941，深蓝工程蓝图风格，中文标注）
- `imagegen_prompt.md` —— 该图的完整 ImageGen 提示词（含精确文案锁定）
- `imagegen_edit_prompt.md` —— 视觉 QA 修正提示词（只改证据关键细节）
- 同图多版本以 `-v2`／`-v3` 后缀保留迭代历史

## 证据纪律

图内颜色语义在整套课程中固定：红色 = CURRENT 阻塞事实，琥珀色 =
PROPOSAL·UNMEASURED，绿色 = 已通过的必要检查。配图不展示性能结论或
胜者徽章；撤回的结果（如 `0.617 ms / 1.493×`）以历史警示卡片呈现。

## 本地预览

仓库使用 GitHub Pages 支持的 Jekyll 结构。安装 Jekyll 后运行：

```bash
bundle exec jekyll serve --baseurl /gpu-megakernel-course-art
```

## 用途

正文可作为独立博客阅读；图片与提示词归档保证后续课次延续同一视觉语言。
