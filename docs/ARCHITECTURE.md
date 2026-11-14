> **说明（随包发布版）**：本文是 ROpenManim 的架构决策记录（ADR-002）。
> 文中提到的 `scratch/`、教材手册与配套教程的目录，属于作者本机工作区的布局，
> **未随本仓库发布**；四套回归断言已按 `regression/` 的路径随仓库附上。
> 除此之外，结论与取舍与原始记录一致。

---

# ADR-002：ROpenManim —— 把 Manim 的数据模型搬到 R，而不是把 Python 依赖逐个搬过来

> 参照对象：`ManimCommunity/manim` v0.22.1（MIT，`manim/` 下 animation / mobject / renderer / scene / utils 五个子系统）
> 关联：`docs/ADR-001-绑定层设计.md`（ROpenCV 的生成器与引用对象约定）、`ROpenEigen`、`ROpenMaple`
> 日期：2026-11-13　状态：**已拍板，v0.0.1 已落地并通过实际应用检验**（三项决定见第九节，落地记录见第十一节；含齐次 3×3、4×4 与三维扩展）

---

## 一、结论

### 1.1 三句话

1. **Manim 没有可绑定的库边界。** 它不是 OpenCV、Eigen、Maple 那类"C ABI + 头文件"的库，而是一个 Python 应用：核心是 `Mobject → VMobject → 具体图元` 的类继承体系，加一套 `Animation` 协议。所以这里没有"生成器批量绑定"这条路可走（ROpenCV 那套 `spec.json → src/*.cpp` 的玩法在此不适用），只有**按架构参照重写**。
2. **"opengl → ROpenGL" 这条线建议砍掉。** Manim 的 OpenGL 渲染器（`moderngl` + `moderngl-window` + GLSL）只服务于实时交互预览（`-p` / `--renderer=opengl`）；成片质量由 Cairo 渲染器决定。R 侧已有 `rgl`（CRAN、成熟、直接驱动 OpenGL），再造一个 `ROpenGL` 是 3–5 人年，且没有下游收益。详见第三节 D 类。
3. **真正决定成败的不是图形 API，是数学公式排版。** 这是 R 生态唯一的空洞，必须自己补，而且**不能用 `plotmath`**——已实测对比（`scratch/probe_frames/math_compare.png`）：plotmath 的 `dx` 是正体、分式字重过大、上下限被压在积分号边缘，是"能读"但不是"教材"的水平。

### 1.2 一个必须先回答的岔路

在写任何代码前，有一个成本相差 20 倍的选择：

| 方案 | 做法 | 成本 | 优点 | 致命问题 |
|---|---|---|---|---|
| **A 原生渲染** | R 自己算几何、自己栅格化、自己编码 | 大（本 ADR 的主体） | 零 Python 依赖；可嵌入 R Markdown/Quarto；可控 | 画面永远"像"而不"是" manim |
| **B 代码生成** | R DSL → 生成 `.py` → 调 manim → mp4 | 小（约 2 周） | 像素级对齐 3b1b 观感 | R 包沦为薄壳；依赖 Python+manim；报错跨语言，调试痛苦 |
| **C 双后端** | 先把 A 的"绘制指令层"定死，B 只是第三个后端 | 中 | 平时用 A（快、纯 R），要交付高保真片时切 B | 需要一次架构自律 |

**建议 C**，且顺序是：先做 A 的骨架（指令层是 A、B 共用的），B 作为逃生舱后置。理由：A 的指令层一旦定死，B 后端只需实现 6 个动词（见 4.4），约 300 行；反过来先做 B 则永远做不出 A。

---

## 二、阶段 0-a 实测（已跑通，脚本留档）

全部在本机 R 4.6.0 / Windows x86-64 上实跑，脚本 `scratch/manim_feasibility.R`、`scratch/manim_frame_cost.R`。

| 项目 | 结果 | 说明 |
|---|---|---|
| Manim 相机坐标系可复刻 | ✅ | `frame_height = 8`，16:9 → 宽 14.222，`viewport(xscale, yscale)` 一次对齐 |
| 三次贝塞尔展平（自适应细分） | ✅ | R 层递归实现，`tol = 2e-4`，圆用 4 段 `k = 4/3(√2−1)` 与 Manim 同构 |
| 弧长参数化 + 截断（Create / DrawBorderThenFill 的内核） | ✅ | `path_trim(path, frac)`，60 行 R |
| 单帧绘制（几何 + grob 构建） | **2.7 ms** | 到 `pdf(NULL)`，1920×1080 当量 |
| 单帧栅格化 1920×1080（`png(type="cairo")`） | **19 ms** | 30 帧 0.58 s |
| 单帧栅格化 1920×1080（`ragg::agg_png`） | **61 ms** | 同一场景，慢 3 倍——ragg 的优势在字体与颜色管理，不在本场景 |
| 60 fps、1 分钟成片（3600 帧）估算 | **≈ 70 s**（cairo） | 单线程；几何不是瓶颈，栅格化才是 |
| 编码：`av::av_encode_video()`（av 0.9.6） | ✅ | 2 s / 30 fps 成片 2.4 s，`yuv420p` 直出 |
| LaTeX → dvisvgm（`--no-fonts --exact`）→ SVG 路径 | ✅ 0.8 s/式 | 一次性，可缓存 |
| SVG → `rsvg_raw()` → `rasterGrob` 贴回场景 | ✅ 8 ms/次 | 按目标像素尺寸栅格化，接缝无 |

### 2.1 五个已经踩到的坑（写进实现在先，别等踩）

1. **`grid` 的 `default.units` 默认是 `"npc"`**，不是 `"native"`。第一次整帧全黑，就是这个——传场景坐标必须显式 `default.units = "native"`。这是本 ADR 里代价最高的一课（一帧空白视频，肉眼不查就发出去了）。
2. **`rsvg_raw()` 返回 `(4, width, height)`**，而 `as.raster` 要 `(height, width, 4)`，必须 `aperm(raw, c(3, 2, 1))`。错向会得到一条被压扁的竖条。
3. **cairo 设备默认字体不含中日韩**：`grid.text("（base R）")` 出豆腐块。中文必须显式 `fontfamily`（"Microsoft YaHei" / "SimHei"），或走 `systemfonts` 注册。
4. **`png(type="cairo")` 的 `bg` 与 `grid.newpage()` 的时序**：先 `bg=` 再 `grid.newpage()` 会清成透明；底色要么用 `grid.rect()` 画，要么放到底层 backend 初始化里。
5. **`av` 的 `vfilter="format=yuv420p"`** 必须给，否则部分播放器不认 yuv444。

### 2.2 反面样本（保留作回归基线）

- `scratch/probe_frames/t19.png`：整帧合成（描边圆 + 直线 + 文本 + 公式），plotmath 版公式。
- `scratch/probe_frames/math_compare.png`：A = plotmath，B = LaTeX→路径。**这张图是 P3 阶段的验收依据**。

---

## 三、Manim 依赖清点与 R 侧处置

Manim 0.22.1 有 **24 个硬依赖 + 3 个可选**（`pyproject.toml`）。逐个判四类：

### A 类｜R 已有等价，不新建包

| 上游 | 在 Manim 里的角色 | R 侧 |
|---|---|---|
| `numpy` / `scipy` | 数组、ODE、空间索引 | base + **ROpenEigen**（已有）；ODE 用 `deSolve` |
| `pillow` | 位图、ImageMobject | `magick` / `png`（已装） |
| `colour` | 颜色空间、插值 | `farver`（已装） |
| `networkx` | `Graph` 场景的布局 | `igraph` 2.3.4（已装） |
| `tqdm` / `rich` | 进度条、终端渲染 | `cli` / `progress`；`rich` 在 R 里没有对应物，也不需要 |
| `click` / `cloup` | CLI | `optparse` / 自己 30 行 |
| `beautifulsoup4` | 拆 LaTeX 编译日志 | `xml2` / 正则 |
| `srt` | 字幕 | 20 行写文件 |
| `typing-extensions` / `decorator` | 语言层 | 不存在此问题 |
| `screeninfo` | 窗口尺寸 | `system()` 查询，或 `rgl` |
| `pygments` | `Code` 图元的语法高亮 | `sourcetools` 分词 + 自己上色；**v1 不做 `Code`**，成本不划算 |

### B 类｜R 有等价但接口不同，直接用、不包一层

| 上游 | R 侧 | 判断 |
|---|---|---|
| `manimpango`（Pango 文本排版） | **`systemfonts` 1.3.2 + `textshaping` 1.0.5** | 同一套 FreeType/HarfBuzz 管线，R 侧已是 CRAN 成熟件。**不建 ROpenPango** |
| `pycairo`（矢量绘制） | `grDevices` 的 cairo 设备 + `grid` | 见 4.4：v1 走 grid 后端；cairo 是"设备"，不需要绑 `cairo_t` 级 API |
| `av`（FFmpeg） | **`av` 0.9.6** | 同作者同底层（libav），已装 |
| `isosurfaces`（marching cubes） | `misc3d::marchingCubes` / `Rvcg` | 按需 |
| `svgelements` | 见 C 类 | 需要自己写解析器 |

### C 类｜确实缺，但**不单独成包**，进 ROpenManim 的 `src/` 或 `R/`

| 缺什么 | 处置 | 何时需要 |
|---|---|---|
| SVG `path` 的 `d` 属性解析（M/L/C/Q/A/Z + 变换） | `R/` 里约 200 行状态机；解出的控制点直接进贝塞尔内核 | P1（`SVGMobject`） |
| Bézier 布尔运算（Union / Intersection / Difference / Exclusion） | 先**展平后用 `polyclip`**（已装）；精度要求高时再引 `skia-pathops` | P2，且 v1 可只做展平近似 |
| 三角剖分（`mapbox-earcut`） | **v1 不做**。`grid::pathGrob(rule = "evenodd")` 原生支持带洞填充，不需要三角剖分 | 只在将来上 OpenGL 后端时才需要 |
| Bézier 求交 / 弧长解析解 | 数值解（细分 + 二分）够用；C++ 化只在性能不够时做 | P4 之后 |

> 这一格是本 ADR 与"逐个对应"思路分歧最大的地方：**上游拆成 26 个包，是因为 PyPI 的分发粒度细、且这些包各自有独立用户。earcut 之于 R 没有独立用户，它只是 ROpenManim 的一个内部算法。**

### D 类｜明确不移植

| 上游 | 理由 |
|---|---|
| `moderngl`、`moderngl-window` | 实时交互预览专用。成片不用；R 侧要交互就用 `rgl`。**ROpenGL 不做** |
| `dearpygui`（可选 GUI） | 同上 |
| `watchdog` | `-w` 自动重渲染。R 里 `later` + 文件 mtime 轮询 50 行即可，或干脆不做 |
| GLSL shader 体系 | 只在 OpenGL 渲染器里生效；v1 不做渐变以外的着色 |

### 3.1 结论：**只出一个包 `ROpenManim`**，外加一个可选的 `ROpenManimTex`

判断标准不是"上游怎么拆"，而是两条：**(1) 有没有独立于 ROpenManim 的使用者；(2) 有没有独立的系统依赖。**

- 按这条，earcut / pathops / svg 解析都不该拆——没有第二个用户。
- 唯一够格拆的是 **LaTeX 排版**：它依赖外部 TeX Live + `dvisvgm`（重系统依赖，要 `SystemRequirements` 单独声明、要运行时探测、要有回退），且 `ggplot2`、`ROpenCV` 的标注迟早也想用。所以 `ROpenManimTex`（或先作为内部命名空间，验明有外部需求再拆）是合理的第二个包。
- **不建议**照搬成 8 个包：一个包 = 一套 `R CMD check` 门禁 + 一条版本兼容链。ROpenCV / ROpenEigen / ROpenMaple 三个包各自的 `.Rcheck`、install 日志、preclean 反复，已经把这个成本演示过一遍了。

---

## 四、目标架构

### 4.1 分层

```
   ┌────────────────────────────────────────────┐
 5 │ 输出：mp4 / gif / 单帧 png / svg / pdf     │  encoder
   ├────────────────────────────────────────────┤
 4 │ 相机 + 绘制指令列表（IRT）                  │  camera
   ├────────────────────────────────────────────┤
 3 │ 动画 / 时间轴（rate_func, lag_ratio）       │  animation
   ├────────────────────────────────────────────┤
 2 │ 场景树（add/remove/z-order/updater）        │  scene
   ├────────────────────────────────────────────┤
 1 │ 图元几何（贝塞尔、描边、填充、变换）        │  mobject
   └────────────────────────────────────────────┘
         ↓ 每层都只依赖下一层的**数据结构**
   backend:  grid(v1) │ cairo(v2) │ opengl(按需) │ manim-emit(逃生舱)
```

### 4.2 第 1 层：图元几何（mobject）

- 内部表示与 Manim 一致：**一条图元 = 若干条三次贝塞尔子路径**（`points` 为 `n×3`，第三列 z 先恒 0）。这样 `Transform` 的"点数对齐"（`align_points`）逻辑可以直接照搬，是 Manim 能做 morph 的根本原因。
- R 侧对象形态照 **ROpenCV 的 `cvMat` 做法**：`externalptr` + finalizer，R 里只持引用，不拷贝；`plot()`/`print()` 走 S3，不改数据。
- 尽量用**纯 R + 向量化**实现几何。实测 60 帧总耗时 1.83 s 里几何不是瓶颈（纯绘制 2.7 ms/帧），**v1 不需要为几何写 C++**。C++ 只在两个地方值得上：贝塞尔布尔的精确求交、以及单帧图元数 > 2000 时的批量展平。

### 4.3 第 3 层：动画（Manim 的灵魂，且完全无图形依赖）

这一层是纯数学，**没有理由做不好**，也最容易做成"看起来像但不是"的样子。必须实现的语义：

| 概念 | 语义（照 Manim，别自创） |
|---|---|
| `rate_func` | `smooth` / `smoothstep` / `there_and_back` / `rush_into` 等 12 个，全是对 `[0,1]→[0,1]` 的函数 |
| `AnimationGroup` | 成员同时开始，`lag_ratio` 决定错峰比例（**不是** `Succession`） |
| `Succession` | 串行，`run_time` 相加 |
| `Transform` | 源/目标点数对齐后线性插值 + 可选 `path_arc` |
| `Animation` 生命周期 | `begin()` → 每帧 `interpolate(alpha)` → `finish()`；`Scene.play` 期间才允许 `updater` 生效 |

### 4.4 第 4 层：相机与绘制指令（本 ADR 最关键的设计）

**帧 ≠ grob 树。帧 = 已排序的绘制指令列表。** grob 树只属于 grid 后端。

```r
# 相机每帧产出的东西（这个结构一经定死，后端可换）
irt <- list(
  list(op = "path",  xy = matrix, closed = TRUE, fill = "evenodd",
       style = list(fill = "#58C4DD", stroke = NA, lwd = 0)),
  list(op = "stroke", xy = matrix, style = list(col = "#58C4DD", lwd = 5,
       lineend = "round", linejoin = "round")),
  list(op = "text",  str = "ROpenManim", x = 0, y = 2.6,
       style = list(size = 34, family = "sans", weight = "bold")),
  list(op = "image", raster = array, x = 0, y = -2.1, w = 2.05, h = 0.9)
)
```

后端只需要实现 **6 个动词**：`path` / `stroke` / `text` / `image` / `clip`（可省）/ `flush`。

- `grid` 后端：`path` → `grid::pathGrob(rule=)`；`stroke` → `grid::lines(default.units="native")`；`text` → `grid::textGrob` + `systemfonts`；`image` → `rasterGrob`。
- `manim` 后端（方案 B 的逃生舱）：把 IRT 反序列化成 `manim` 的 `VMobject` 构造调用，交给 Python 出片。
- `cairo` 后端（v2）：绕过 grid，直接 `cairo_t` 级绘制，解决 R1 的裁剪问题（见第八节）。

**这个抽象的收益是可验证的**：`manim_frame_cost.R` 里同一帧在 cairo 与 ragg 两种设备上渲染，切换的只是 6 个动词的实现，上层零改动。

### 4.5 第 5 层：编码

- 帧目录 → `av::av_encode_video(frames, fps, vfilter="format=yuv420p")`。
- 单帧/静图 → `png()` 直出，或 `svg()` / `cairo_pdf()` 出矢量（**这是 R 相对 manim 的独有优势**：教学讲义要的是可缩放矢量图，不是 mp4）。
- `gif` → `gifski`（按需）。

---

## 五、API 对齐（用户视角）

| Manim | ROpenManim | 备注 |
|---|---|---|
| `class MyScene(Scene)` / `construct()` | `scene(...)` + `play_*(...)` 序列 | R 无类继承需要，用闭包环境 |
| `self.play(...)` | `scene$play(...)` 或管道 `|>` | 见 9.1 |
| `Create` / `Write` / `FadeIn` / `FadeOut` | 同名函数 | 底层都是 `path_trim` + alpha |
| `Transform` / `ReplacementTransform` | 同名 | 点数对齐后插值 |
| `Indicate` / `Circumscribe` / `Flash` | 后置 | 组合动画，可用已有件拼 |
| `Text` / `MarkupText` | `text()` | `systemfonts` + `textshaping`，原生支持中日韩 |
| `MathTex` / `Tex` | `mathtex()` | dvisvgm → SVG → raster（见 2.1 坑 2/3） |
| `Axes` / `NumberPlane` / `NumberLine` | `axes()` / `plane()` / `number_line()` | 数学量用 ROpenEigen |
| `plot()` / `ParametricFunction` | `plot_fn()` | 采样由相机自适应细分 |
| `VGroup` / `Group` | `vgroup()` | R 里就是个 list + 类标记 |
| `always_redraw` | `always_redraw()` | updater 机制 |
| `Scene.render()` | `render(scene, out, fps, quality)` | |
| `manim -ql file.py Scene` | `render_file("x.R", quality="l")` | 可选，v1 可只有 `render()` |

命名纪律（沿用 ROpenCV 的结论）：**导出面只有 `rm_` 之外的公共构造器与动画函数；内部 `.Call`/`.rm_*` 一律不导出**；不要 `exportPattern`。

---

## 六、v1 明确不做（范围边界）

| 不做 | 原因 |
|---|---|
| 3D 场景（`ThreeDScene`、`Surface`） | 需要正确的深度排序与投影；P5 再议，用自写正交投影，不引 OpenGL |
| OpenGL 实时交互（`-p`、窗口预览） | 见 D 类。R 里要预览就 `rgl` |
| 插件系统（`manim.plugins`） | R 的扩展机制是包，不是插件 |
| `-w` 文件监视 | 收益/成本比低 |
| GLSL shader、`ShaderMobject` | 只在 OpenGL 渲染器里有意义 |
| Jupyter 交互 | Quarto 里用 `render()` 出片即可 |

---

## 七、阶段计划与验收口径

沿用 ROpenCV 的门禁习惯：**每个阶段都要有一个可重跑的验收脚本，脚本输出数字，不输出"看起来没问题"**。

| 阶段 | 内容 | 验收（硬指标） |
|---|---|---|
| **P0 地基**（1 周） | IRT 数据结构、grid 后端 6 动词、编码链路 | 同一场景 3 秒成片；几何定位误差 < 0.5 px（用已知坐标的方块顶点反查像素）；无空白帧断言（每帧非背景像素占比 > 0） |
| **P1 图元**（2–3 周） | Line / Circle / Polygon / Rectangle / Arrow / Arc / Brace / `vgroup` / 变换（shift、scale、rotate、set_fill） | 12 个图元的位置/包围盒与手算值逐条比对 |
| **P2 动画**（2–3 周） | 12 个 `rate_func`、Create / Write / FadeIn/Out / Transform / AnimationGroup / Succession | `lag_ratio=0.5` 时第 2 个子动画的起始帧号精确到 ±1 帧；`Transform` 的 alpha=0/0.5/1 三点位置可断言 |
| **P3 文本与公式**（2 周） | `text()`（含 CJK）、`mathtex()`（dvisvgm + 缓存） | `math_compare.png` 同尺寸复核；同一公式重复 100 次只编译 1 次（缓存命中率断言） |
| **P4 坐标系**（1–2 周） | `axes()`、`plot_fn()`、`number_line()` | `sin` 曲线在 3 个采样点的像素坐标与解析值一致 |
| **P5 3D**（按需） | 正交投影 + 画家算法排序 | 立方体 8 顶点遮挡关系正确（**已落地**：正交/透视相机 + 两级深度排序 + 12 个三维图元，见 11.5；未做真正的面遮挡剔除） |

**不要**用 SSIM 与 manim 逐帧比对作为验收指标——字体渲染不同，永远过不了，且会诱导把时间花在像素对齐上。要的是**几何与时间轴的等价**。

**2026-11-13 落地注记**：P0–P4 的最小闭环已在 `ROpenManim/` 跑通；P1 因
`LinearAlgebraLabManual` 第七章的实际需求提前铺齐（新增 23 个图元，连同既有 8 个共 31 个），
并补上「矩阵连续作用整组图元」的动画层。随后按同一路径扩到齐次 3×3（平移与二维射影）
与 4×4 / 三维（相机 + 画家算法），P5 因此提前落地。实际验收一律用可重跑的数值断言：
`scratch/rm_assert.R` 16 条（时间轴）、`scratch/rm_p1_assert.R` 40 条（图元与变换）、
`scratch/rm_homogeneous_assert.R` 42 条（齐次 3×3）、`scratch/rm_3d_assert.R` 74 条
（4×4 / 相机 / 三维）、教材侧 `scripts/check_motion.R` 44 条（资源 / 引用 / HTML），
五套均 0 FAIL。

---

## 八、风险（按"会不会让项目死掉"排序）

| # | 风险 | 判断 | 对策 |
|---|---|---|---|
| **R1** | `grid` 的裁剪只有矩形 viewport，Manim 少数效果依赖任意路径裁剪 | **真实限制**，且在 P1 就会遇到 | v1 用"先几何求交再绘制"绕过；把 `cairo` 后端排到 v2（IRT 已隔离，换后端不动上层） |
| R2 | 画面"像而不像"：字体、线宽、抗锯齿与 manim 有肉眼可见差异 | 必然 | 定位改成"R 原生教学动画工具"，不宣称 manim 复刻；要像素级就用方案 B 后端 |
| R3 | `grid` 单线程 19 ms/帧，复杂场景线性退化 | 可接受但要知道 | 3600 帧 ≈ 70 s；超 2000 图元时把展平搬到 C++，或按帧并行（`parallel` 分包） |
| R4 | TeX Live 是重系统依赖，CRAN 不能假设 | 真实 | `Suggests: tinytex` + 运行时探测（`Sys.which("dvisvgm")`）；缺失时回退 plotmath 并在 warning 里说清降级 |
| R5 | `gradient` 填充：Manim 用 shader，grid 只有 `linearGradient` / `radialGradient` | 中 | 够用；`InterpolateColor` 一类效果改为分层绘制 |
| R6 | 引用语义陷阱（ROpenCV §3.5 的教训） | 会重演 | `mobject` 用引用对象，但**所有"修改"必须走显式函数并返回 invisible**；`a$shift()` 与 `shift(a)` 两种都允许，禁止"赋值即拷贝"的错觉 |

---

## 九、三个决定（2026-11-13 已拍板）

### 9.1 API 风格

| 选项 | 形态 | 代价 |
|---|---|---|
| **a. R6/环境方法**（建议） | `scene$play(create(circle))` | 最贴近 manim 教程心智；`$` 在 R 里争议小 |
| b. 纯管道 | `scene() |> add(circle) |> play(create(circle))` | R 味最正，但 `play` 的时序语义在管道里会变模糊 |
| c. 双轨 | a 为内核，另给管道糖 | 多 300 行，但两头讨好 |

**我的建议：a + c 的薄糖。**

### 9.2 范围

先做"教学短视频最小闭环"（`text()` + `mathtex()` + `Transform` + `axes()` + 出 mp4），还是先把 P1 图元铺齐？

**建议前者**：你的实际用途（高数/线代实验讲义配套动画）90% 是"一个公式变形 + 一条曲线 + 一段标注"，图元铺到 30 个不如先把这四件事做到能用。

### 9.3 v1 是否接受 grid 后端 + 已知裁剪限制

接受 → P0 一周能出片；不接受 → 先做 cairo 后端（Windows 上要么链 R 自带 cairo，要么 vendor，估 2–3 周且构建风险高）。

**建议接受**，理由：IRT 已经把后端隔离，这不是一次性赌注。

### 9.4 拍板结果（用户确认，2026-11-13）

1. **API 风格**：采用 9.1 a —— R6 / 环境方法；**未做** c 的管道糖，先把内核做实。
2. **范围**：先做最小闭环。但 `LinearAlgebraLabManual` 第七章提出「整组图元被矩阵连续作用」
   的需求后，按用户授权提前铺齐 P1（新增 23 个图元，共 31 个）并新增 `apply_matrix()`
   动画层。注意实际检验得出的结论与 9.2 的预想不同，见 11.2。
3. **v1 后端**：接受 grid + 矩形裁剪；cairo 后端仍后置，IRT 隔离保持不变。

落地状态与实际检验见第十一节。

---

## 十、与现有工作的接口

- **`ROpenMaple` × `ROpenManim`**：`maple_eval()` 拿到的符号结果可以直接驱动动画序列（"把 `∫x²dx` 的每一步 Maple 化简结果生成一段 `Transform` 链"）。这是 Python manim 做不到的，也是你这个组合的真实差异点——**CAS 驱动、结果可核验的数学动画**，正好接上 CalculusLabPilot 的"冲突—反例"叙事。
- **`ROpenEigen`**：`axes()` 的刻度、`plot_fn()` 的采样、3D 变换矩阵都直接用。
- **`ROpenCV`**：`ImageMobject` 与画面合成（把实验截图叠进动画）。

---

## 十一、落地记录（2026-11-13）

### 11.1 代码与验收

| 产物 | 位置 | 验收 |
|---|---|---|
| 包骨架 v0.0.1 | `ROpenManim/`（`R/` 下 15 个文件） | `scratch/rm_assert.R` **16 PASS / 0 FAIL** |
| P1 图元 + 线性变换动画层 | `R/primitives.R`、`R/anim-linalg.R`、手写 `NAMESPACE` | `scratch/rm_p1_assert.R` **40 PASS / 0 FAIL** |
| 教材第七章 | `LinearAlgebraLabManual/07-motion.qmd`、`animations/`（40 个文件） | `make_animations.R` 8 PASS；`check_motion.R` **44 PASS / 0 FAIL**；全书 `quarto render` 12/12 EXIT=0 |
| 齐次 3×3 变换（平移 / 绕点旋转 / 投影） | `R/geometry.R` 的射影求值、`R/anim-linalg.R` 的 6 个矩阵构造器 | `scratch/rm_homogeneous_assert.R` **42 PASS / 0 FAIL**；`scratch/rm_homogeneous_demo.R` 出 4 帧 + 4.1 s 成片；旧三套回归与教材六段成片**逐字节不变** |
| 齐次 4×4 与三维（相机 / 12 个三维图元） | `R/homogeneous3d.R`、`R/primitives3d.R`、`R/camera.R`、`scene$set_camera()` | `scratch/rm_3d_assert.R` **74 PASS / 0 FAIL**；教材选做 08 实拍验证（`det A = 6` 与秩 2 压平） |

八段动画中必做六段各 4.7–5.9 s、选做两段 6.99 / 7.46 s，均 720p / 24 fps，
全部离线预渲染。`_quarto.yml` 的 `project.resources` 登记 `animations/`，
全书渲染后 `_book/animations/` 完整（40 个文件），12 个 HTML 页面的侧边栏均带第七章，
全书无未解析交叉引用与 `mjx-merror`。

### 11.2 实际应用检验修正了 9.2 的判断

9.2 原以为「图元铺到 30 个不如先把四件事做到能用」。教材第七章给出的反馈是：
**真正缺的不是形状数量，而是「整组图元被矩阵连续作用」这一能力**。行列式面积塌陷、
$A^{-1}$ 还原、特征方向、二次型旋转，全都是「同一组图元沿 $M(f)=(1-f)I+fA$
逐帧变形」，而不是两幅静止形状之间的插值。因此新增 `apply_matrix()` /
`apply_inverse()` / `rotate_group()` / `shift_group()` 四个动画；P1 的 23 个新图元
是**为这条能力提供可组合的素材**才铺的，不是为凑数量。

这条反馈也反过来支持 4.4 的 IRT 设计：矩阵作用在 `state` 的纯数据支持点上，
与后端无关，所以六个机理共用同一套时间轴实现，换 cairo 后端时无需改动动画层。

### 11.3 仍未变的三条边界

- **ROpenGL 不做**（第三节 D 类）；R 侧交互用 `rgl`。
- **只出一个包** `ROpenManim`（3.1）；本次新增的图元与动画都进同一个包，没有拆包。
- **公式禁 plotmath**（1.1）；`mathtex()` 走 LaTeX → dvisvgm → 贝塞尔，第七章的
  公式切换因此是可变形矢量而非贴图。

### 11.4 齐次 3×3 扩展（2026-11-13 续）

`apply_matrix()` 已接受 **2×2 线性矩阵或 3×3 齐次矩阵**（2×2 自动提升，向后完全兼容）。
新增 `homogeneous_matrix()` / `translation_matrix()` / `affine_matrix()` /
`perspective_matrix()` / `projection_matrix()` / `rm_compose()`；`rotate_group()` 加了 `about`
（绕任意点）、`shift_group()` 改为齐次平移的糖。

三条设计要点值得记进架构：

1. **代表元归一化**：齐次矩阵差一个标量倍表示同一变换，但插值路径
   $M(f)=(1-f)I+fA$ 依赖代表元。统一令 $m_{33}=1$，路径才唯一可复现。
2. **两条求值路径**：仿射（$m_{3,*}=(0,0,1)$）与贝塞尔凸组合可交换，直接变换控制点；
   射影（$w_v\ne1$）下三次贝塞尔变成有理曲线、不再保形，故先展平成折线、
   只对折线顶点做透视除法——射影保直线，折线顶点精确则整段精确。
   这再次印证 4.4 的 IRT 抽象：变换落在纯数据 `state` 上，与后端无关。
3. **消失线**：$w_v=0$ 从折线段内部穿过时，该线段应映成两条不相连的射线。
   只检测端点会连出一条横跨整屏的假直线，故按 $w$ 变号把子路径断开，并在
   `prepare()` 一次性给出 warning。消失线落在画面外时无此开销。

### 11.5 齐次 4×4 与三维（2026-11-13 再续）

`apply_matrix()` 再接受 **4×4**（3×3 视为三维线性部），并新增
`apply_matrix3d()` / `apply_inverse3d()` / `rotate3d_group()` / `shift3d_group()`、
7 个 4×4 构造器（含 `rotation4_matrix()` 的 Rodrigues 绕任意轴）、
12 个三维图元与 `camera3d()` / `project_point()`。

四条设计决定：

1. **后端不动**。grid 后端只吃二维，所以三维投影放在 `compile()` 里、绘制之前。
   这不是权宜——4.4 的 IRT 本来就把"相机产出什么"和"后端怎么画"分开；
   后端永远只看见屏幕空间折线，将来换 cairo 也不需要为三维改一行。
2. **`dim` 标记 + 一次性投影**。`state` 增加 `dim`（默认 `2L`，三维为 `3L`）。
   只有 `dim == 3` 才被相机投影；投影后立刻改回 `2L`，防止 `transform()` /
   morph 传递 state 时二次投影。文字、公式、轴标签留 `dim = 2`，并给 `-Inf` 深度，
   按深度升序排序后固定最上层——否则标注会被透视拉歪或被几何盖住。
3. **两级深度排序**。子路径按自身平均深度排（物体内部前后关系），
   state 按整体平均深度排（画家算法：远的先画）。这与 Manim 的
   `Camera` 输出 `z_index` 是同一件事的简化版。
4. **相机不是线性代数**。透视缩放来自 `camera3d()` 的 `focal / depth`，
   换 `type` 不改变 $\det A$、秩或体积。这条边界写进了教材选做 08 的
   `.caution` 块，因为学生最容易把"近大远小"误当成矩阵的性质。

教材侧的证据：选做 07 用 3×3 演示"平移不固定原点"（金色原点不动、网格整体平移）
与"平行线收敛到消失点"；选做 08 用 4×4 演示 $\lvert\det A\rvert = 6$ 时体积放大 6 倍、
秩 2 正交投影把立方体压成 $xy$ 平面上的片。两段都配 base R 实算
（`det`、`qr`、投影幂等 $P^2=P$），动画与实算互为校验。

调试中确认的两处细节也值得记：消失线（$x=-1/p$，在左）与消失点（$x=+1/p$，在右）
是两个不同对象，教材正文已显式区分；线束取 $y\in[-2.2,2.2]$、$x\in[-3.0,3.0]$，
再往外射影后会贴边或压住右侧文字。

性能上有一处与预期不符：三维片段并不与二维同量级。`08-3d-volume` 179 帧 720p
出片 31–37 s（175–205 ms/帧），约为二维（30 ms/帧）的 5–6 倍。原因是半透明面填充
与子路径数量，**不是**投影与排序——后者在 `compile()` 里只占几毫秒。
要提速应先减面片 / 关填充，而不是优化相机。这条也写进了 README 的性能节。

### 11.6 仍未解决

morph 的精确贝塞尔对齐（子路径数不同仍退化 crossfade）、任意路径裁剪（需 cairo 后端）、
帧间并行、`Image` / `Code` / gif / svg 导出；射影分支每帧重建折线，
`transform()` 与之串联时点数会变（v1 接受）。三维侧：未做一般 $n$ 维、
光照与遮挡面剔除、真正的近裁剪；相机不能做关键帧动画；P5 的 3D 场景图
（父子层级、相机轨道）未启动。

---

## 附：本 ADR 的验证脚本

| 文件 | 作用 |
|---|---|
| `scratch/manim_feasibility.R` | 端到端：贝塞尔展平 → 弧长截断 → 整帧 → 60 帧 → mp4 |
| `scratch/manim_frame_cost.R` | 成本拆解：纯绘制 / cairo / ragg / 小分辨率 |
| `scratch/texprobe/m.tex` `m.svg` | LaTeX → dvisvgm 路径化样本 |
| `scratch/probe_frames/t19.png` | 整帧合成样本（含 plotmath 版本） |
| `scratch/probe_frames/math_compare.png` | plotmath vs LaTeX 排版对比（P3 验收基线） |
| `scratch/rm_3d_assert.R` | 齐次 4×4 / 相机 / 三维的 74 条数值断言（P5 验收） |

### 附：配套教程（2026-11-14）

`ROpenManimTutorial/` 把本 ADR 的取舍写成了可运行的教材（19 章 + 3 附录）。
与本决策直接对应的章节：第 1–3 章讲「帧 = 指令列表 / 两个绘制动词」；第 10–12 章把
齐次 3×3、4×4 与相机投影的实算逐条摊开；第 13 章拆 `render()` 的四步与四档 `quality`；
第 15 章把 17 个坑排成「症状 → 原因 → 修法」；第 16 章用三个综合项目验证「组的边界、
纯函数、画布边界」三条纪律；第 17 章的 API 表由 `formals()` 与 `NAMESPACE` 现场对账。

教程侧的 `scripts/check_tutorial.R` 与本节的表互补：本 ADR 管包的行为，那份脚本管
书有没有写全（章节、插图、mp4、章末链接、88 个导出）。写书过程中还反向修掉了包里
两个真实缺陷：`render()` 的 `keep_frames` 接了不用、`play()` 多给一个动画时静默吞掉
第二个参数（现已报错并提示改用 `animation_group()`）。
