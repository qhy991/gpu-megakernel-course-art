# GPU Megakernel 实战课（Lessons 36–54）

这是一套面向 GPU/CUDA 初学者的中文博客课程。它以 B200/Blackwell 上的
Megakernel 研究为背景，从“一个 warp 为什么在等”讲到“怎样用负控证明并发
协议真的安全”。每课都有完整正文、16:9 图解、证据状态和前后课导航。

- **在线课程：** <https://qhy991.github.io/gpu-megakernel-course-art/>
- **第一次阅读：** 从[第 36 课](https://qhy991.github.io/gpu-megakernel-course-art/lessons/lesson-36-page-ready/)顺序开始
- **遇到缩写：** 查[术语表](https://qhy991.github.io/gpu-megakernel-course-art/glossary/)
- **遇到性能数字：** 先读[证据规则](https://qhy991.github.io/gpu-megakernel-course-art/evidence/)

## 阅读前需要什么

建议先知道 CUDA 的 thread、warp、block 和 shared memory 是什么。不要求预先
了解 TMA、TMEM、persistent kernel、mbarrier 或 Nsight Compute；这些术语都在
课程术语表中用同一套定义解释。

本课程的 `page` 指 shared-memory 缓冲区中的一段，不是操作系统虚拟内存页；
`CTA` 与 CUDA thread block 同义；`island` 指少量物理 kernel 组成的融合分区。

## 19 课在讲什么

| 阶段 | 课次 | 学完后应能回答 |
| --- | --- | --- |
| 一：看懂真实瓶颈 | 36–39 | page-ready 为什么缩短等待？Split-KV 为什么增加并行任务？resident、eligible、issue 有何区别？ |
| 二：找到融合边界 | 40–43 | 最大融合为何不总是最好？物理 cut 保存什么状态？为什么切开不会自动降低资源？ |
| 三：审计驻留资源 | 44–48 | shared memory、register、TMEM 如何共同限制 CTA/SM？什么时候切分才值得？ |
| 四：设计可证伪实验 | 49–54 | 怎样逐项打开 2 CTA/SM 的五把锁？如何用 READY/ACK poison litmus 杀死错误协议？ |

课号延续真实研究日志，所以从 36 开始；第 36–54 课本身构成独立完整的一卷，
不依赖尚未发布的前 35 课。

## 怎样读一篇课文

每篇文章顶部固定给出三件事：

1. **要解决的问题**：本课只回答哪个问题。
2. **读完应能复述**：应该带走的最短结论。
3. **证据状态**：结论是实测、源码可证、待验证设计，还是已撤回历史结果。

正文中的数字必须连同模型、shape、计时边界和正确性门一起理解。例如，
CUDA Event 的 model-forward 时间不等于 HTTP serving wall；occupancy query 返回
2 也不等于 NCU 已观察到两个 CTA 同时驻留。

## 证据标签

| 标签 | 表示什么 | 不表示什么 |
| --- | --- | --- |
| `MEASURED` | 有匹配的计时或 profiler 工件 | 不自动代表生产服务性能 |
| `SOURCE-PROVEN` | 源码足以证明形状、依赖或资源公式 | 不代表性能已经测量 |
| `PROPOSED · UNMEASURED` | 设计具体且可执行，但尚未通过资格门 | 不是推荐上线的 winner |
| `WITHDRAWN` | 旧结果被更强的正确性或协议审计推翻 | 不能继续引用为收益 |

混合标签表示同一课同时使用不同等级的材料；正文会逐段说明哪些结论属于哪一层。

## 仓库结构

```text
_posts/                  19 篇课程正文
_layouts/                Jekyll 页面骨架
assets/css, assets/js/   课程站样式与交互
assets/images/           课程总封面与生成提示词
lesson36/ ... lesson54/  每课的 16:9 图片；部分目录包含生成/修订提示词
about.md                 适合人群与阅读路线
evidence.md              证据标签和性能结论检查表
glossary.md              全课程统一术语表
```

图片文件说明：

- `*_16x9.png`：最终教学图，标准尺寸为 1672×941。
- `imagegen_prompt.md`：生成该图时使用的提示词；它是复现资产，不是课程正文。
- `imagegen_edit_prompt.md`：视觉审校后的定向修订提示词。
- `-v2`、`-v3`：保留的历史视觉版本；文章 front matter 中的 `image` 字段决定线上使用哪一张。

## 配图颜色含义

- 红色：当前阻塞事实或必须失败的错误路径。
- 琥珀色：提案或尚未测量的假设。
- 绿色：已经通过的必要检查，不等于“整体性能冠军”。
- 青色／蓝色：数据流、控制流或中性结构。

配图不会把待测设计画成赢家。撤回数字只会作为历史警示出现。

## 本地预览与发布

站点使用 GitHub Pages 支持的 Jekyll 结构。仓库当前由
`.github/workflows/pages.yml` 在 `main` 分支 push 后构建并部署。

本机已经安装兼容版本的 Ruby、Bundler 与 Jekyll 时，可运行：

```bash
bundle exec jekyll serve --baseurl /gpu-megakernel-course-art
```

若本机环境与 GitHub Pages 的 Ruby 版本不同，应以 Actions 的正式构建结果为准。

无需启动 Jekyll，也可以先运行仓库自带的结构检查：

```bash
ruby scripts/check_course_docs.rb
```

它会检查课号连续性、必填 metadata、逐课术语说明、主章节、前后导航、引用图片以及 16:9 比例。

## 新增或修改课程时的检查清单

- front matter 包含唯一 `slug`、课号、阶段、摘要、结论、图片、标签、阅读时间和证据状态；
- 第一次出现的新缩写已在正文解释，或已加入 `glossary.md`；
- 性能数字写明模型、shape、计时边界和正确性条件；
- `prev_slug`／`next_slug` 能形成连续课程链；
- 图片存在且图中文字不超出正文证据；
- `git diff --check`、内部链接、图片路径和 GitHub Pages 构建全部通过。
