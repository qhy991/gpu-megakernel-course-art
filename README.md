# GPU Megakernel 实战课（Lessons 1–54）

这是一套面向 GPU/CUDA 初学者的中文博客课程。它以 B200/Blackwell 上的
Megakernel 研究为背景，从“一个 warp 为什么在等”讲到“怎样用负控证明并发
协议真的安全”。每课都有完整正文、16:9 图解、证据状态和前后课导航。

- **在线课程：** <https://qhy991.github.io/gpu-megakernel-course-art/>
- **第一次阅读：** 从[第 1 课](https://qhy991.github.io/gpu-megakernel-course-art/lessons/gpu-kernel-mental-model/)顺序开始
- **遇到缩写：** 查[术语表](https://qhy991.github.io/gpu-megakernel-course-art/glossary/)
- **遇到性能数字：** 先读[证据规则](https://qhy991.github.io/gpu-megakernel-course-art/evidence/)

## 阅读前需要什么

建议先知道 CUDA 的 thread、warp、block 和 shared memory 是什么。不要求预先
了解 TMA、TMEM、persistent kernel、mbarrier 或 Nsight Compute；这些术语都在
课程术语表中用同一套定义解释。

本课程的 `page` 指 shared-memory 缓冲区中的一段，不是操作系统虚拟内存页；
`CTA` 与 CUDA thread block 同义；`island` 指少量物理 kernel 组成的融合分区。

## 54 课在讲什么

| 学习段 | 课次 | 学完后应能回答 |
| --- | --- | --- |
| 基础心智模型 | 1–10 | GPU 如何执行？token 怎样流过 Llama？融合、Graph 与 Persistent Kernel 的边界在哪里？ |
| 性能证据与真实优化 | 11–20 | 怎样连接 NCU、PTX、SASS 和原始实验档案？Page-ready、Split-KV 与 Dynamic Tail 各解决什么？ |
| 同步、生命周期与调度 | 21–35 | release/acquire、epoch、ACK 和驻留死锁如何闭合？怎样把 barrier 编译成 Ready 调度？ |
| B200 资源与融合边界 | 36–48 | 为什么最大融合不总是最好？shared memory、register、TMEM 如何共同限制 CTA/SM？ |
| 可证伪的双 CTA 实验 | 49–54 | 怎样逐项打开 2 CTA/SM 的五把锁？如何用 READY/ACK poison litmus 杀死错误协议？ |

第 1–35 课已从原始课程记录恢复，第 36–54 课保留原有研究日志编号；两部分现已接成连续的 54 课学习路线。

## 怎样读一篇课文

每篇文章顶部固定给出三件事：

1. **要解决的问题**：本课只回答哪个问题。
2. **读完应能复述**：应该带走的最短结论。
3. **证据状态**：结论是实测、源码可证、待验证设计，还是已撤回历史结果。

正文中的数字必须连同模型、shape、计时边界和正确性门一起理解。例如，
CUDA Event 的 model-forward 时间不等于 HTTP serving wall；occupancy query 返回
2 也不等于 NCU 已观察到两个 CTA 同时驻留。

## 详细文档标准

本仓库不接受只有结论和图片的短提纲。每课至少应包含：

- 面向零基础读者的“问题—类比—暂时忽略”三句入口；
- 本课用词、问题边界与一句话结论；
- 从真实 shape、状态或时间线出发的逐步解释；
- 数据、控制或资源生命周期，而不只描述算子名称；
- 实测、源码可证、历史快照与待测提案的明确分界；
- 常见误读、失败条件或不能外推的范围；
- 页面末尾的复述、证据边界与外推范围自检；进阶课另有专属动手练习。

自动检查要求每篇正文不少于 1,500 个字符；第 36–54 课还要求至少六个主章节和一项本课专属练习。字符数只是防止正文退化的下限，不替代技术审校。

三个零基础字段也有长度上限：它们负责搭桥，不负责在开头重讲整篇文章。技术细节统一留给正文逐层展开。

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
_posts/                  54 篇课程正文（网站的内容源）
_layouts/                Jekyll 页面骨架
assets/css, assets/js/   课程站样式与交互
assets/images/           课程总封面与生成提示词
lesson01/ ... lesson54/  每课的完整 README 文档、16:9 图片及可选生成/修订提示词
about.md                 适合人群与阅读路线
evidence.md              证据标签和性能结论检查表
glossary.md              全课程统一术语表
scripts/                 文档同步与课程完整性检查
```

每个 `lessonXX/README.md` 都能在 GitHub 中直接阅读，包含零基础入口、证据状态、
完整课程正文、读完自检、配图、线上地址和相邻课程导航。它由对应的 `_posts` 文章确定性生成，
因此修改课程原文后应运行：

```bash
ruby scripts/sync_lesson_readmes.rb
ruby scripts/sync_lesson_readmes.rb --check
```

第一条命令批量更新 54 份目录文档；第二条命令逐字检查它们是否仍与网站正文同步。

图片文件说明：

- front matter 的 `image` 字段：决定网站实际使用哪张最终教学图；标准尺寸为 1672×941。
- `imagegen_prompt.md`：用于生成或复现该图的提示词与视觉规格；它不是课程正文。
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
ruby scripts/sync_lesson_readmes.rb --check
```

它会检查课号连续性、必填 metadata、逐课术语说明、主章节、前后导航、引用图片、16:9 比例，
并阻止不同课程继续复用同一张图片。同时会检查详细正文长度；进阶课程还必须包含足够的
主章节和课后练习。第二条命令会检查每课目录中的 GitHub 文档是否与对应网站文章完全同步。

## 新增或修改课程时的检查清单

- front matter 包含唯一 `slug`、课号、阶段、摘要、结论、图片、标签、阅读时间和证据状态；
- 第一次出现的新缩写已在正文解释，或已加入 `glossary.md`；
- 性能数字写明模型、shape、计时边界和正确性条件；
- `prev_slug`／`next_slug` 能形成连续课程链；
- 图片存在且图中文字不超出正文证据；
- `git diff --check`、内部链接、图片路径和 GitHub Pages 构建全部通过。
