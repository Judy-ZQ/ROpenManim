# ROpenManim（v0.0.1）

Manim 的 R 侧实现：**帧 = 绘制指令列表**，v1 后端只实现 path / stroke 两个动词，
默认用 grid 画到任意 R 图形设备，再由 av 编码成 mp4。

仓库：<https://github.com/Judy-ZQ/ROpenManim>　|　许可：GPL-2　|　架构取舍见
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

## 安装（Windows 优先）

**要求**：R ≥ 4.2.0。本包是**纯 R 包**（`NeedsCompilation: no`），
不需要 Rtools、不需要 Python、不需要单独安装 ffmpeg，Windows / macOS / Linux 通用。

### 方式 A：下载 zip 直接装（推荐）

1. 在本仓库的 [Releases](https://github.com/Judy-ZQ/ROpenManim/releases) 页下载
   `ROpenManim_0.0.1.zip`（Windows binary）；若尚未发布 Release，可取仓库
   `dist/` 下的同名文件。
2. 在 R 里执行（换成你实际的下载路径）：

```r
install.packages("C:/Users/me/Downloads/ROpenManim_0.0.1.zip",
                 repos = NULL, type = "win.binary")
```

> RStudio 用户也可以走菜单 `Tools → Install Packages → Install from:
> Package Archive File`，直接选这个 zip。

### 方式 B：从 GitHub 装源码

```r
install.packages("remotes")                    # 只需一次
remotes::install_github("Judy-ZQ/ROpenManim")
```

因为包里没有任何 C/C++ 代码，这条命令在 Windows 上**同样不需要 Rtools**。

### 方式 C：源码 tarball

```r
install.packages("ROpenManim_0.0.1.tar.gz", repos = NULL, type = "source")
```

### 依赖与可选功能

`R6` / `grid` / `grDevices` / `systemfonts` / `av` 会随安装自动补齐。
Windows 上请从 CRAN 装**二进制版** `av`（默认即是），它自带 FFmpeg 编解码库，
所以出 mp4 不需要另装 ffmpeg。

只有 `mathtex()`（LaTeX 公式）需要本机 TeX 与 `dvisvgm`。**公式是可选功能**：
不用公式，文字、图元、变换、三维与出片全部可用。

### 装完先验证

```r
library(ROpenManim)
packageVersion("ROpenManim")                  # 0.0.1
?ROpenManim-package                           # 包级帮助
?scene                                        # 分组帮助（8 组覆盖 88 个导出）

circ <- circle_obj(r = 1.5, style = list(stroke = "#58C4DD", stroke_width = 6))
s <- scene(background = "#0E1116")
s$add(circ)
render_frame(s, "first.png", t = 0, quality = "m")   # 当前目录出现 1280x720 PNG
```

出一段 mp4（`quality = "m"` 是 720p/30fps，起步快；`"h"` 是 1080p/60fps）：

```r
s$play(create(circ, run_time = 1))
render(s, "first.mp4", quality = "m")
```

### 常见问题

| 症状 | 原因与处理 |
|---|---|
| 中文变成一串方框 | `text()` / `label_obj()` 默认 `family = "sans"`；Windows 上显式给 `family = "Microsoft YaHei"` |
| `mathtex()` 报找不到 dvisvgm | 公式是可选功能；装 TeX 发行版并把 `dvisvgm` 放进 PATH |
| `render()` 报 av 相关错 | 从 CRAN 重装二进制版 `av`：`install.packages("av")` |
| 报 `play() 只支持一个动画` | `scene$play()` 每次只收一个动画；多个请用 `animation_group(...)` |
| `library()` 提示 `text` / `transform` 被遮蔽 | 正常：本包沿用 Manim 风格的同名函数；要用 base R 的请写 `base::transform()`、`graphics::text()` |
| 中文注释在 GBK 环境下 `source()` 报错 | 把 `LC_CTYPE` 切回 UTF-8；**用安装包不受影响**，只有直跑源码才会遇到 |

架构与取舍的完整记录见 `docs/ARCHITECTURE.md`。
v1 口径（已拍板）：R6 方法式 API；最小闭环 = `text` + `mathtex` + `Transform` +
`axes` + mp4；grid 后端 + 矩形裁剪，cairo 后端后置。

## 配套教程

配套的 Quarto 教程是**独立项目** `ROpenManimTutorial`：19 章 + 3 个附录，从第一个圆讲到
三维曲面，含 Manim 经典示例的 R 复现、十七个坑的排错表、三个综合项目、88 个导出的
API 速查，以及全书回归索引。本包**不依赖**该教程；教程的公共 setup 直接 `source()`
本仓库 `R/` 下的 15 个源文件——改一行源码重渲染即可看到效果。

> **2026-11-13 实际应用检验已通过**：配套教材《线性代数实验手册》新增第七章
> 「动态图示：用 ROpenManim 看见机理」，八段机理动画（6 必做 + 2 选做）全部由本包
> 离线预渲染，Quarto 渲染与资源验收 44 项全过。为满足该教材需求，P1 图元已提前铺齐
> （新增 23 个，连同原有 8 个共 31 个），并新增矩阵连续作用的动画层。
> 同日把 `apply_matrix()` 扩到**齐次 3×3**（平移 / 绕任意点旋转 / 射影投影），
> 随后再扩到**齐次 4×4 与三维**（`camera3d()` 投影 + 画家算法排序 + 12 个三维图元）。
> 2×2 行为向后完全兼容。

## 已实现（可用）

| 能力 | 入口 | 状态 |
|---|---|---|
| 基础图元 | `line_obj()` `circle_obj()` `rect_obj()` `square_obj()` `polygon_obj()` `arrow_obj()` `dot_obj()` `vgroup()` | ✅ |
| P1 图元（23 个） | `grid_obj()` `unit_square_obj()` `basis_arrows_obj()` `vector_obj()` `quad_form_curve_obj()` `arc_obj()` `sector_obj()` `ellipse_obj()` `triangle_obj()` `brace_obj()` `double_arrow_obj()` `dashed_line_obj()` `angle_obj()` `right_angle_obj()` `number_line_obj()` `parametric_curve_obj()` `area_under_obj()` `polygon_fill_obj()` `label_obj()` `matrix_obj()` `cross_obj()` `tick_obj()` `span_line_obj()` | ✅ |
| 文本 | `text(str, size, family, color)` | ✅ 轮廓转贝塞尔；中文需显式 `family=` |
| 公式 | `mathtex(tex, size, color)` | ✅ LaTeX→dvisvgm→SVG 路径解析；按内容 md5 缓存 |
| 坐标系 | `axes()` `plot_fn()` | ✅ 轴/箭头/刻度/刻度数字/轴标签 |
| 动画 | `create()` `fade_in()` `fade_out()` `transform()` `animation_group()` `succession()` | ✅ 按局部时间求值，可跳帧；`transform()` 支持 vgroup 与单目标广播 |
| 矩阵动画 | `apply_matrix()` `apply_inverse()` `rotate_group()` `shift_group()` | ✅ 接受 2×2 / 3×3 / 4×4；逐帧把 $M(f)=(1-f)I+fA$ 作用到整组图元 |
| 齐次矩阵工具 | `homogeneous_matrix()` `translation_matrix()` `affine_matrix()` `perspective_matrix()` `projection_matrix()` `rm_compose()` | ✅ 平移 / 绕点旋转 / 透视 / 正交投影 / 复合 |
| 齐次 4×4 工具 | `homogeneous4_matrix()` `translation4_matrix()` `affine4_matrix()` `rotation4_matrix()` `projection4_matrix()` `perspective4_matrix()` `rm_compose4()` | ✅ 三维线性 / 平移 / 绕轴旋转（Rodrigues）/ 投影 / 射影 |
| 三维变换动画 | `apply_matrix3d()` `apply_inverse3d()` `rotate3d_group()` `shift3d_group()` | ✅ 2×2 与 3×3 也会被 `apply_matrix()` 自动分派到对应路径 |
| 三维图元（12 个） | `line3d_obj()` `polyline3d_obj()` `cube3d_obj()` `parallelepiped3d_obj()` `axes3d_obj()` `grid3d_obj()` `plane3d_obj()` `vector3d_obj()` `basis3d_obj()` `point3d_obj()` `surface3d_obj()` | ✅ |
| 相机 | `camera3d()` `project_point()` | ✅ look-at；正交 / 透视；按深度排序；`dim = 2` 对象不参与投影 |
| 场景 | `scene()` → `$add()` `$play()` `$wait()` `$compile(t)` `$set_camera()` | ✅ R6；入场动画起点前自动隐藏对象；`succession()` 链式传递终态 |
| 输出 | `render_frame()` `last_frame()` `render(file, quality, fps)` | ✅ mp4（av） |

## 用法

```r
sc <- scene(background = "#0E1116")
ax <- axes(c(0, 3), c(0, 3), width = 8, height = 5, x = -2.4, y = -0.8,
           axis_labels = c("x", "y"))
sc$add(ax)
p <- plot_fn(ax, function(x) x^2, 0, 1.8, color = "#58C4DD"); sc$add(p)
lab <- text("vector morph", size = 40, color = "#83C167")
lab$move_to(3.0, 3.1); sc$add(lab)
mt  <- mathtex("\\int_0^1 x^2\\,dx = \\frac{1}{3}"); mt$move_to(2.6, 1.7); sc$add(mt)
## Transform 会把 a 变成 b（含位置），目标必须自己定位，否则公式会飞回原点
mt2 <- mathtex("\\int_0^1 x^3\\,dx = \\frac{1}{4}"); mt2$move_to(2.6, 1.7)

sc$play(create(p, run_time = 1.2))
sc$play(fade_in(lab, run_time = 0.6, shift = -0.3))
sc$play(transform(mt, mt2, run_time = 1.0))

render(sc, "demo.mp4", quality = "h", fps = 30)
```

线性变换是另一套写法：把**整组**图元交给一个矩阵，而不是给每个图元单独写动画。

```r
A <- matrix(c(0.5, 0.5, 0.5, 0.5), 2, 2, byrow = TRUE)   # 秩 1，det = 0
geom <- vgroup(grid_obj(c(-2, 2), c(-2, 2), 1),
               unit_square_obj(), basis_arrows_obj(labels = NULL))
sc <- scene(); sc$add(geom)
sc$play(create(geom, run_time = 0.8))
sc$play(apply_matrix(geom, A, run_time = 2.4))            # 整张网格压成一条线
## 换成可逆矩阵（如剪切 matrix(c(1, .8, 0, 1), 2, 2)）时，
## 可再接 sc$play(apply_inverse(geom, A)) 把整组图元推回原位
```

## 齐次 3×3：平移、绕点旋转与投影

`apply_matrix(obj, A)` 同时接受 **2×2 线性矩阵**（自动提升为齐次）与 **3×3 齐次矩阵**；
2×2 的旧行为逐点不变——教材六段成片重生成后 md5 与 `_book/` 副本逐字节一致。

约定：`v = (x, y, 1)`，变换写作 `v %*% t(m)`：

```text
m = [ A  b ]     A = 2x2 线性部；b = 平移，位于 m 第三列的前两项
    [ w  1 ]     w = 射影部，w_v = w[1]*x + w[2]*y + 1
```

射影时 `(x', y') = (A(x,y) + b) / w_v`。

| 构造器 | 作用 |
|---|---|
| `homogeneous_matrix(A, b, w)` | 通用，`m = [A b; w 1]` |
| `translation_matrix(dx, dy)` | 平移 |
| `affine_matrix(A, b)` | 线性 + 平移 |
| `perspective_matrix(p, q, ...)` | 透视，`w_v = 1 + p*x + q*y`；`...` 可再给 `A` / `b` |
| `projection_matrix(v)` | 正交投影到 `span(v)`，秩 1、`det = 0` |
| `rm_compose(m1, m2, ...)` | 按作用先后复合（先 `m1` 后 `m2`），内部是 `m2 %*% m1` |

```r
sc <- scene(); sc$add(geom)
sc$play(apply_matrix(geom, translation_matrix(1.6, 0.9)))     # 平移
sc$play(rotate_group(geom, pi / 3, about = c(1.5, 1.5)))      # 绕非原点旋转
sc$play(apply_matrix(geom, perspective_matrix(-0.12, 0)))     # 透视梯形
```

三条实现要点：

1. **代表元归一化**：齐次矩阵差一个标量倍表示同一变换，但插值路径
   `M(f)=(1-f)I+fA` 依赖代表元。统一令 `m[3,3]=1`，路径才唯一可复现；
   `m[3,3]=0` 直接拒绝（原点会被映到无穷远）。
2. **两条求值路径**：仿射（`m[3,] = (0,0,1)`）与贝塞尔的凸组合可交换，
   直接变换控制点，点数不变、零额外开销；射影下三次贝塞尔变成**有理曲线、不再保形**，
   故先展平成折线、只对折线顶点做透视除法——射影保直线，顶点精确则整段精确。
   `prepare()` 只展平一次，逐帧复用 `base_polys`。
3. **消失线**：`w_v=0` 从折线段内部穿过时，该线段应映成两条不相连的射线。
   只查端点会连出一条横跨整屏的假直线，故按 `w` 变号断开子路径；
   `prepare()` 一次性 warning。消失线落在画面外时无此开销。

限制：3×3 是**二维射影**；射影分支每帧重建折线，
与 `transform()` 串联时点数会变；`apply_inverse()` 拒绝奇异矩阵；
`w_guard`（默认 `1e-3`）只钳制顶点，不能替代"把消失线移出画面"。
三维请用 `apply_matrix3d()` 或直接给 `apply_matrix()` 一个 4×4（见下节）。

## 齐次 4×4 与三维：多一步"投影"

`apply_matrix(obj, A)` 也接受 **4×4**：它把 3×3 当成"三维线性部分"，
走 `apply_matrix3d()` 的同一条路径。约定与二维一致，只是点变成 $(x,y,z,1)$：

```text
m = [ A  b ]     A = 3x3 线性部；b = 平移，位于第四列前三项
    [ w  1 ]     w = 射影部，w_v = w·(x,y,z) + 1
```

| 构造器 | 作用 |
|---|---|
| `homogeneous4_matrix(A, b, w)` | 通用，`m = [A b; w 1]` |
| `translation4_matrix(dx, dy, dz)` | 三维平移 |
| `affine4_matrix(A, b)` | 3×3 线性 + 平移 |
| `rotation4_matrix(axis, angle)` | 绕 `"x"` / `"y"` / `"z"` 或任意三维轴旋转（Rodrigues） |
| `projection4_matrix(n, v)` | 正交投影到法向 `n` 的平面，或到方向 `v` 的直线 |
| `perspective4_matrix(p, q, r)` | 三维射影，`w_v = 1 + p*x + q*y + r*z` |
| `rm_compose4(...)` | 按作用先后复合 |

```r
cam <- camera3d(eye = c(6, -8, 5), look_at = c(0, 0, 0),
                type = "ortho", zoom = 1.05)
sc  <- scene(); sc$set_camera(cam)
box <- cube3d_obj(side = 2, fill = "#58C4DD", opacity = 0.22)
b   <- basis3d_obj()
sc$add(box); sc$add(b); sc$add(axes3d_obj(3))
sc$play(create(box, run_time = 0.6))
sc$play(apply_matrix3d(box, affine4_matrix(matrix(c(2, .6, 0, 0, 1.5, 0, 0, .4, 2), 3))))
sc$play(apply_matrix3d(box, projection4_matrix(n = c(0, 0, 1))))   # 压成 xy 平面上的片
sc$play(rotate3d_group(box, axis = "z", angle = pi / 4))
```

要点：

1. **后端不变**。grid 后端只吃二维，所以三维投影发生在 `compile()` 里、绘制之前；
   装了相机才会触发，二维场景（教材前六段）走原路径、一字不动。
2. **`dim` 标记**。`state$dim` 默认 `2L`，三维图元是 `3L`。只有 `dim == 3` 的 state
   才被相机投影；文字、公式与 $x/y/z$ 标签留在屏幕空间，且给 `-Inf` 深度，
   按深度升序排序后**永远画在最上层**——否则标注会被透视拉歪、或被几何盖住。
3. **两条深度**。state 内部按子路径平均深度排序（解决同一物体内部前后关系），
   state 之间按整体平均深度排序（画家算法，远的先画）。`depth` 是沿视线方向的距离。
4. **投影后立刻改标 `dim = 2L`**，防止二次投影（`transform()` / morph 会把 state 传来传去）。
5. `project_point(cam, P)` 可以单独用：把某个三维点算成屏幕坐标，再把二维标签
   `move_to()` 过去（`dim = 2` 的对象用二维坐标）。

限制：三维射影同样是"每帧重建折线"；不支持 4×4 之外的维度（不做一般 $n$ 维）；
相机只做 look-at + 正交/透视，没有景深、雾化、光照与遮挡面剔除
（用半透明填充 + 按深度排序近似）；`near` 只做钳制与 warning，不做真裁剪。

## 时间轴语义（容易踩）

- `$add()` 只是把对象登记进场景，**不等于立刻可见**。若该对象的首个动画是
  `create()` / `fade_in()`（入场动画），从 `add()` 到动画起点这段时间不显示；
  `transform()` / `fade_out()` 不是入场动画，起点前显示源状态。
- `Transform(a, b)` 把 a 变成 b，**含位置**：b 要自己 `move_to()` 到期望位置。
- 同一个 `play()` 里若用 `succession()` 串起多个作用于同一对象的动画，后续动画
  **从前置动画的终态**出发，不是各自从初始状态起算（`apply_matrix(A)` 后接
  `apply_inverse(A)` 才能回到 $I$）。
- `$compile(t)` 是纯函数，可任意跳帧、重复渲染；`animation_group()` 的错峰偏移
  按每个叶子各自的绝对起止时间生效，不会被整段 `t1` 提前赋成终态。
- 帧求值只碰 `state`（纯数据：curves / path_id / style / opacity / polys），不碰 R6 对象。
  `polys` 是展平缓存，凡改 `curves` 必须同步。

## 回归验证

四套断言随仓库放在 `regression/`，从源码直跑，**不要求先装包**：

```bash
cd ROpenManim
Rscript regression/run-all.R          # 合计 172 PASS / 0 FAIL
```

| 脚本 | 条数 | 覆盖 |
|---|---|---|
| `regression/rm_assert.R` | 16 | 时间轴语义 |
| `regression/rm_p1_assert.R` | 40 | P1 图元 + 线性变换 |
| `regression/rm_homogeneous_assert.R` | 42 | 齐次 3x3 |
| `regression/rm_3d_assert.R` | 74 | 齐次 4x4 / 相机 / 三维 |

覆盖：入场前后可见性、`wait()` 后 add 的 birth、composite 错峰、`fade_out` 终态、
`transform` 末帧几何 == 目标公式且 != 源公式、末帧位置、4 张关键帧 md5 互异；
P1 侧另覆盖 23 个图元的构造与包围盒、等值线分支、`apply_matrix` 三点面积
（$1 \to 3 \to 6 = \det A$）、`succession(A, A^{-1})` 末态面积回到 1、
`rotate_group()` / `shift_group()` / `transform(vgroup)`、帧间差异；
齐次侧另覆盖 6 个构造器与代表元归一化、复合顺序、平移逐点等于 `shift_group`、
绕非原点旋转 bbox、正交投影面积归零、透视除法解析值、圆被折线重建、
curves 与 polys 逐点一致、消失线断开与有限性、`succession(M, M^{-1})` 复原；
三维侧另覆盖 4×4 归一化与 7 个构造器解析值、Rodrigues 绕轴旋转、
`projection4_matrix` 的秩与体积、三维透视除法、消失面断开、
`camera3d()` 正交/透视的解析投影值、`project_point()`、深度排序与 `dim` 穿透动画层、
二维路径逐点兼容、`succession(M3, M3^{-1})` 复原。

回归脚本的关键帧 PNG 写到 R 的临时目录（`tempdir()/rm_probe_frames/`），
只用于 md5 比对「动画确实在动」，不随仓库发布。

## 实际应用检验：线性代数实验手册第七章

配套教材第七章用六段必做动画演示面积塌陷、逆变换还原、Gram–Schmidt、
解集滑动、特征方向、二次型摆正；再用两段选做动画把矩阵升维
（齐次 3x3：平移不是线性变换、消失点；齐次 4x4 + 相机：体积 = $|\det|$、
秩 2 投影把立体压平）。该教材是独立项目，**不随本仓库发布**。

结论：最小闭环（文本 / 公式 / 时间轴 / mp4）在真实教材场景下够用，**但形状数量不是关键，
"整组图元被矩阵连续作用"才是**。因此本轮补齐 P1 图元与 `apply_matrix()` 动画层；
两者都由 `rm_p1_assert.R` 的数值断言守住，而不是靠"看动画觉得对"。教材侧同时守住
另一条纪律：动画不替代证明，每段后面都有 base R 实算。

升维这条路也验过了：3x3 与 4x4 是在**同一套时间轴**上加的，`succession()`、`rate_*`、
`transform()` 全部复用，2x2 的六段成片重生成后逐字节一致。
真正的增量只有两件事——射影必须先展平折线，三维必须先投影到屏幕。

## 已验证的性能（本机 R 4.6.0 / Windows，cairo 设备）

- 1080p 单帧 **55–58 ms**，720p 约 30 ms；`compile(t)` 2–10 ms（折线缓存命中后）
- `text()` 首次 0.25 s，`mathtex()` 首次 0.17 s、命中缓存 0.030 s
- 2.8 s / 30 fps / 1080p：84 帧渲染 4.9 s + 编码；四帧 md5 互不相同
- 教材八段动画：720p / 24 fps，必做六段 4.7–5.9 s、07 6.99 s / 169 帧、
  08 7.46 s / 180 帧；`animations/` 共 40 个文件约 1.4 MB（mp4 合计 685 KB）
- 齐次演示三段串联 4.1 s / 720p / 24 fps；射影分支预展平一次，逐帧只做矩阵乘法
- **三维明显更慢**：`08-3d-volume` 179 帧 720p 出片约 31–37 s（175–205 ms/帧），
  约为二维片段（30 ms/帧）的 5–6 倍。主因是半透明面填充与子路径数量（立方体
  6 面 + 12 棱 + 轴 + 向量），投影与排序的占比很小 —— 要提速先减面片，
  而不是优化相机。

## 实现坑（都踩过，按代价排序）

1. **`state$polys` 展平缓存不失效** → 每帧 PNG 的 md5 完全相同，视频"看起来没动"，
   且不报错。凡改 curves 处（trim / 仿射 / morph / 换目标 / 射影重建）必须同步缓存。
2. **入场哨兵 `intro_start = Inf` 不能直接跟 t 比** — `t < Inf` 恒真，会让所有
   *没有*入场动画的对象（坐标系、公式）全部消失，整帧空白。必须 `is.finite()` 后再判。
   这个 bug 还会连带让 `transform()` 的 `prepare()` 拿到全 NULL 状态，误退化成 crossfade。
3. 仿射约定 `v %*% t(M)` 时平移必须在 M 的**第三列**；放第三行会"静默不动"，
   所有 `move_to()` 失效，容易被误判成字形排版错。
4. `grid` 的 `default.units` 默认 `"npc"` 不是 `"native"` → 不显式写就整帧空白。
5. `.rm_style(style)` 若把 style 列表当 `...` 传入会变成 list-of-list，`fill` 静默
   保持 NA —— 所有图元只描边不填充。
6. `.rm_as_objects()` 必须递归到普通 list（`axes$parts`）、vgroup 的 `items`，
   否则箭头等被静默丢弃；`transform()` 两侧摊平后的对象数必须一致（单目标可广播）。
   写断言时 `.find_indices(list(group))` 找不到摊平后的 item，要传 `.rm_as_objects(obj)`。
7. `rsvg_raw()` 返回 (4,w,h)，`as.raster` 要 (h,w,4)，须 `aperm(c(3,2,1))`；
   `av_encode_video()` 要给 `vfilter = "format=yuv420p"`。
8. `system.time(for (i in 1:n) expr)` 里 expr 是 promise、只求值一次 —— 测帧耗时
   必须包成 `function()` 才准（早先"ragg 9 ms/帧"就是这么错的，真实 61 ms）。
9. **`succession()` 的链式动画必须从前置叶子的 `final` 取状态**；否则 `A → A^{-1}`
   的末态会变成 $A^{-1}$ 而不是 $I$，且不报错。`scene$play()` 用 `carried` 传递。
10. **morph 两侧子路径数不同会退化成 crossfade**（有 warning）。教材里 1→6 与 8→21
    子路径的两处公式切换，改成 `succession(fade_out(f1), fade_in(f2))` 并把 f2 显式
    `add()` 进场景，比硬 morph 更干净。
11. **Windows GBK locale**：某个教材目录的 `.Rprofile` 把 R 设成
    `Chinese_China.936`，`source()` 读本包 UTF-8 中文注释会报
    `unexpected end of input`。生成脚本开头须把 `LC_CTYPE` 改回 UTF-8；
    R6 源码注释里的上标字符（如 `A⁻¹`）也改成 ASCII `A^(-1)`。
12. **射影下三次贝塞尔不再保形**：直接变换控制点会得到错误的曲线（有理函数被当成
    多项式）。必须先展平折线、逐顶点做透视除法，再重建 curves / path_id / polys。
13. **齐次代表元不归一化，动画路径会随矩阵整体缩放漂移**：`A` 与 `3A` 是同一射影
    变换，但 `(1-f)I+fA` 不是。统一除到 `m[3,3]=1`。
14. **消失线会藏在折线段内部**：端点 `w` 同号也可能跨过 `w=0`，只查端点会画出
    横跨整屏的假直线；按 `w` 变号在交点两侧断开，且断点后那段必须补上原段终点，
    否则只剩一个点被 `.rm_curves_from_polys()` 丢掉。
15. **grid 后端只吃二维**，别想着"给后端加个 z"来解决三维：投影必须发生在
    `compile()` 里、绘制之前，后端永远只看到屏幕空间折线。装相机才触发投影，
    二维场景走原路径。
16. **`dim` 要穿透动画层，且只能投影一次**：`state` 默认 `dim = 2L`，三维图元标记为
    `3L`；`transform()` / morph 会复制 state，丢了 `dim` 就把三维几何当平面画；
    反过来 `.rm_project_state()` 必须立刻把 `dim` 改回 `2L`，否则同一帧被投两次，
    图形会缩成一小团。屏幕空间对象还要给 `-Inf` 深度才能固定在最上层。
17. **相机退化与近裁剪**：`up` 与视线平行时叉积为零，整幅退化成 NaN —— `camera3d()`
    直接报错而不是静默出坏帧；透视下点落到 `near` 之前会让 `k` 变负、屏幕坐标镜像
    跳变，`near` 只做钳制 + warning，不做真正的近裁剪。
18. **写断言时别冤枉实现**：`matrix(c(1, 0.5, 0, 1), 2, 2)` 是**按列**填充，
    `curves[[i]]` 的顶点顺序也不等于你脑子里的点序。三维断言第一次挂掉，查到最后
    是断言自己取错了顶点（取第二个而以为是第三个）。

## 已知未完成（按优先级）

1. **morph 质量**：当前是折线等点插值；两侧子路径数不同则退化为交叉淡入淡出。
   实测 11 子路径的 LaTeX 公式可正常 morph（x²→x³ 中间态是真实形变）。
   精确贝塞尔对齐留待 P2。
2. **后端能力**：只有矩形裁剪；cairo 后端后置；无 `Video` / `Image` / `Code` /
   gif / svg 导出。
3. **性能**：帧间并行未做；`Create` 每帧重新截断 + 展平（图元多时会成为瓶颈）；
   射影分支每帧重建折线，尚未做增量更新。
4. **变换维度**：已到 4×4 与三维（正交/透视相机 + 画家算法）。未做一般 $n$ 维、
   光照与遮挡面剔除、真正的近裁剪；相机不能做关键帧动画（只支持整段固定一台）；
   P5 的 3D 场景图（父子层级、相机轨道）未启动。

> 2026-11-13 暂停点的两项缺口（入场前可见性、transform 末帧）已修复并回归通过；
> P1 图元因教材第七章的实际需求已提前铺齐；`apply_matrix()` 已扩到 3×3 与 4×4，
> 三维能力已由教材选做 08 实际验证。

## 目录

```
ROpenManim/
  DESCRIPTION  NAMESPACE  README.md  .Rbuildignore
  man/                    9 个分组 Rd，覆盖 NAMESPACE 的 88 个导出
  R/geometry.R            贝塞尔、展平、弧长、截断、重采样、仿射、齐次/射影求值
  R/mobject.R             R6 图元 + 样式 + 绘制指令编译
  R/svgpath.R             最小 SVG path 解析器（M/L/H/V/C/S/Q/T/A/Z）
  R/text.R                systemfonts 字形轮廓 → 贝塞尔
  R/tex.R                 LaTeX → dvisvgm → 贝塞尔（含 md5 缓存）
  R/axes.R                坐标系与函数图像
  R/primitives.R          P1 的 23 个图元（网格 / 向量 / 等值线 / 直角标记 / 数轴 …）
  R/animation.R           rate 函数、create/fade/transform、组合（含 intro 语义）
  R/anim-linalg.R         齐次矩阵构造器 + 矩阵连续作用 / 逆 / 旋转 / 平移动画
  R/homogeneous3d.R       齐次 4x4 工具 + 三维动画 + 4x4 求值/分派
  R/primitives3d.R        12 个三维图元（立方体 / 平行六面体 / 轴 / 平面 / 曲面 …）
  R/camera.R              look-at 相机、正交/透视投影、深度、state 投影
  R/scene.R               场景 R6：时间轴段 + 纯函数 compile(t) + 相机与深度排序
  R/backend-grid.R        grid 后端（path / stroke）
  R/render.R              逐帧渲染 + av 编码
  regression/             四套断言 + run-all.R（172 PASS / 0 FAIL）；仅源码仓库可见
  docs/ARCHITECTURE.md    架构决策记录（ADR-002 随包发布版）
  tools/dump_sig.R        NAMESPACE → 签名清单（构建期用）
  tools/gen_man.py        签名清单 → man/*.Rd（构建期用）
```

> `regression/`、`docs/`、`tools/`、`dist/` 由 `.Rbuildignore` 排除，
> 不会打进安装包；它们只在 GitHub 仓库里供开发者查证。
