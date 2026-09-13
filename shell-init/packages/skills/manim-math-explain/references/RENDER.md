# 渲染与导出（Phase 5）

## 预览 vs 成片

| 用途 | 命令习惯 | 说明 |
|---|---|---|
| 开发预览 | `manim -pql` | 低质量，快 |
| 验收 | `manim -pqm` | 中等 |
| 成片 | `manim -pqh` | 高；耗时 |

竖屏加分辨率与环境变量：

```bash
MANIM_FORMAT=portrait manim -pqh scenes/01_hook.py Hook -r 1080,1920
```

输出默认在 `media/videos/...`；验收通过后复制到 `exports/landscape|portrait/`。

---

## 推荐导出流水线

1. 全场景 `-pql` 冒烟（横+竖）  
2. Checkpoint 5 确认规格与配音方式  
3. 成片渲染  
4. 若有分场文件：按 outline 顺序拼接（ffmpeg）  
5. 配音：TTS 或真人；**音画以口播为轴**微调静音间隙  
6. 抖音策略 B：单独渲染 short 场景  

### 拼接示例

```bash
# 生成 filelist.txt 后
ffmpeg -f concat -safe 0 -i filelist.txt -c copy exports/landscape/full.mp4
```

---

## 音频

| 方式 | 何时 |
|---|---|
| 后期真人 | 教学质量优先 |
| TTS | 快速迭代；中文选自然音色 |
| Manim Voiceover 插件 | 想要时间码自动对齐时（可选，不强制） |

`narrations/*.txt` 是文案真相源。合成前让用户扫一眼。

异常：某段 TTS 过长 → 口播仍偏书面，回 Phase 2 改短。

---

## Checkpoint 5 检查表

```
□ 全部场景横屏成片路径
□ 全部场景竖屏成片路径（或策略 B 的 short）
□ 音频方案确认
□ 片头片尾是否需要统一（系列）
□ 字幕：烧录 / soft sub / 平台自动（数学符号建议烧录关键式）
```

---

## 字幕注意

- 公式在字幕里写「人话」或简单 Unicode，避免一长串 LaTeX  
- 竖屏字幕避开底部 UI；可放中上辅助区或依赖平台自动字幕 + 画面大字  

---

## 交付物清单

```
exports/
  landscape/full.mp4
  portrait/full.mp4          # 或 short.mp4
  narrations_export.md       # 可选，方便配音演员
  cover_notes.md             # 标题候选 + 本集一问
```
