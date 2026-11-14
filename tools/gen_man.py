# -*- coding: utf-8 -*-
"""从 NAMESPACE + 源码签名生成分组 Rd 文档（覆盖全部导出）。

用法：先由 tools/dump_sig.R 生成 _sig.tsv，再 `python tools/gen_man.py`。
分组是手工划的，签名与参数名从源码读取，避免文档与实现脱节。
"""
import io
import os
import re
import collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TSV = os.path.join(ROOT, "_sig.tsv")
MAN = os.path.join(ROOT, "man")

sig = {}
for ln in io.open(TSV, encoding="utf-8"):
    p = ln.rstrip("\n").split("\t")
    if len(p) >= 3:
        u = p[2]
        if u.endswith(" NULL"):
            u = u[:-5]
        prm = [x for x in (p[3].split(",") if len(p) > 3 else []) if x]
        sig[p[0]] = (p[1], u, prm)

groups = [
    ("scene", "场景与输出", ["scene", "render", "render_frame", "last_frame"],
     "场景是时间轴的容器：图元用 \\code{add()} 挂上去，动画用 \\code{play()} 排进去。",
     "帧不是逐步修改的状态，而是 \\code{compile(t)} 对时刻 \\code{t} 的纯函数求值——"
     "它返回一组绘制指令（\\code{stroke} / \\code{path}），后端只认这两个动词。"
     "因此可以跳帧、倒序渲染，结果完全一致。"
     "画布固定高 8 unit、宽高比 16:9；\\code{quality} 四档只改像素与帧率。",
     "s <- scene()\ns$add(circle_obj(r = 1))\nlength(s$compile(0))\ns$duration()"),

    ("constants", "画布常量", ["rm_frame_height", "rm_aspect"],
     "画布几何约定：帧高恒为 \\code{rm_frame_height} 个 unit，宽高比为 \\code{rm_aspect}。",
     "所以 16:9 画布的 x 范围约为 [-7.11, 7.11]、y 范围为 [-4, 4]。"
     "\\code{quality = \"m\"}（1280x720）时 1 unit = 90 px，屏幕原点在 (640, 360)。",
     "rm_frame_height\nrm_aspect\nrm_frame_height * rm_aspect   # 画布宽度（unit）"),

    ("mobjects", "二维图元与组合", None,
     "每个 \\code{*_obj()} 返回一个 \\code{rm_mobject}（R6 对象），可单独 \\code{add()} 进场景，"
     "也可用 \\code{vgroup()} 合成一组后整体变换。\\code{style} 参数统一接收"
     "\\code{list(stroke=, stroke_width=, fill=, alpha=)} 形式的样式。",
     "前 8 个是基础图元，其余是线性代数教材需要而补的 P1 图元（共 31 个）。"
     "三维图元见 \\code{?`three-d`}。",
     "g <- vgroup(circle_obj(r = 1), square_obj(side = 2))\ns <- scene()\ns$add(g)\nlength(s$compile(0))"),

    ("text-tex-axes", "文字、公式与坐标系", ["text", "mathtex", "axes"],
     "\\code{text()} 借 \\code{systemfonts} 把字形转成真正的贝塞尔轮廓，因此文字和公式"
     "是普通矢量图元，能被变换、淡入淡出与形变，不是贴上去的位图。",
     "中文必须显式给 \\code{family}（默认 \\code{\"sans\"} 会缺字形）。"
     "\\code{mathtex()} 需要本机 TeX 与 \\code{dvisvgm}，可选装 \\code{tinytex}；"
     "\\code{axes()} 构造坐标系，\\code{plot_fn()} / \\code{area_under_obj()} 依附于它。",
     "ax <- axes(xlim = c(-2, 2), ylim = c(-1, 1))\ns <- scene()\ns$add(ax)\nlength(s$compile(0))"),

    ("animation", "动画与时间曲线", None,
     "\\code{rate_*} 把 \\code{t} 从 [0, 1] 映射到 [0, 1]，决定缓动；"
     "\\code{create} / \\code{fade_in} / \\code{fade_out} / \\code{transform} 是四个叶子动画。",
     "\\code{animation_group()} 同步或错峰播放，\\code{succession()} 串行播放。"
     "注意：\\code{scene$play()} 每次只收一个动画，要同时播放多个请用"
     "\\code{animation_group(...)}；\\code{transform()} 要求两端子路径数一致，"
     "否则退化为交叉淡化或报错。",
     "s <- scene()\nsq <- square_obj(side = 2)\ns$add(sq)\ns$play(create(sq, run_time = 1))\ns$duration()\nrate_smooth(0.5)"),

    ("linalg2d", "齐次 3×3 与二维矩阵动画", None,
     "二维仿射与射影变换统一写成 3×3 齐次矩阵。\\code{apply_matrix()} 不插值形状，"
     "而是把 \\code{M(f) = (1-f)I + fA} 逐帧作用到整组图元的支持点。",
     "因此看到的是「同一个变换逐渐发生」，不是两幅静止形状的混合。"
     "\\code{rm_compose(m1, m2)} 是先 \\code{m1} 后 \\code{m2}。",
     "A <- translation_matrix(2, 0.5)\nA\nB <- rm_compose(affine_matrix(diag(2)), A)\nB"),

    ("linalg3d", "齐次 4×4 与三维矩阵动画", None,
     "三维版本：\\code{A} 是 3×3，\\code{b} / \\code{w} 各长 3。",
     "\\code{rotation4_matrix(axis, angle)} 的参数顺序是 \\strong{先轴后角}，"
     "务必用具名参数调用。\\code{rm_compose4(m1, m2)} 同样是先 \\code{m1} 后 \\code{m2}。"
     "\\code{apply_matrix3d()} 与二维同式 \\code{M(f) = (1-f)I + fA}。",
     "M <- homogeneous4_matrix(diag(3), b = c(2, 0, 0))\nM\nrotation4_matrix(axis = c(0, 0, 1), angle = pi/2)"),

    ("three-d", "相机与三维图元", None,
     "三维不是新引擎：\\code{dim = 3} 的状态在 \\code{compile()} 内被 \\code{.rm_project_state()}"
     "投影成二维，绘制前立刻把 \\code{dim} 改回 2 防止二次投影；文字与公式固定在最上层。",
     "\\code{camera3d()} 用 look-at 构造 \\code{f, r, u} 三轴；遮挡按画家算法（平均深度）排序。"
     "\\strong{坑}：\\code{project_point(cam, P)} 的第二参数按 \\strong{点集} 处理，"
     "传裸向量 \\code{c(1,2,3)} 会被当成 3 个点且不报错；单点必须写"
     "\\code{matrix(p, nrow = 1)}，批量用 \\code{pts[i, , drop = FALSE]}。",
     "cam <- camera3d(eye = c(6, -8, 5))\nP <- matrix(c(1, 2, 3), nrow = 1)\nproject_point(cam, P)\ns <- scene(camera = cam)\ns$add(cube3d_obj(side = 2))\nlength(s$compile(0))"),
]

# 自动补齐五个组的成员；二维图元必须排除 3d_obj
groups[2] = (groups[2][0], groups[2][1],
             [n for n in sig if (n.endswith("_obj") and not n.endswith("3d_obj"))
              or n in ("vgroup", "plot_fn")], *groups[2][3:])
groups[4] = (groups[4][0], groups[4][1],
             [n for n in sig if n.startswith("rate_")]
             + ["create", "fade_in", "fade_out", "transform",
                "animation_group", "succession"], *groups[4][3:])
groups[5] = (groups[5][0], groups[5][1],
             ["apply_matrix", "apply_inverse", "rotate_group", "shift_group",
              "homogeneous_matrix", "translation_matrix", "affine_matrix",
              "perspective_matrix", "projection_matrix", "rm_compose"], *groups[5][3:])
groups[6] = (groups[6][0], groups[6][1],
             ["homogeneous4_matrix", "translation4_matrix", "affine4_matrix",
              "rotation4_matrix", "projection4_matrix", "perspective4_matrix",
              "rm_compose4", "apply_matrix3d", "apply_inverse3d",
              "rotate3d_group", "shift3d_group"], *groups[6][3:])
groups[7] = (groups[7][0], groups[7][1],
             ["camera3d", "project_point"]
             + [n for n in sig if n.endswith("3d_obj")], *groups[7][3:])

all_members = [n for g in groups for n in g[2]]
dup = [k for k, v in collections.Counter(all_members).items() if v > 1]
assert not dup, dup
assert set(all_members) == set(sig), (set(sig) - set(all_members), set(all_members) - set(sig))
print("分组覆盖 %d/%d 导出" % (len(all_members), len(sig)))

argdoc = {
    "obj": "要变换或播放的图元 / 图元组。",
    "a": "形变起点图元。", "b": "平移向量（矩阵构造器中）或形变终点图元。",
    "A": "线性部分：2×2（三维为 3×3）矩阵。",
    "sc": "场景对象。", "t": "时刻（秒）；\\code{compile(t)} 对时刻求值。",
    "run_time": "动画时长（秒），默认 1（矩阵动画为 2）。",
    "rate": "缓动函数，如 \\code{rate_smooth}、\\code{rate_linear}。",
    "style": "样式列表 \\code{list(stroke=, stroke_width=, fill=, alpha=)}。",
    "color": "描边颜色（十六进制）。", "width": "线宽（像素）。", "fill": "填充颜色。",
    "opacity": "填充不透明度，0–1。", "r": "半径。",
    "x": "x 坐标（或横坐标向量）。", "y": "y 坐标（或纵坐标向量）。",
    "fun": "一元 / 二元函数，返回曲线点或曲面高度。",
    "p1": "第一个端点 / 顶点。", "p2": "第二个端点 / 顶点。", "p3": "第三个顶点。",
    "ax": "\\code{axes()} 构造的坐标系对象。",
    "from": "参数或区间起点。", "to": "参数或区间终点。",
    "n": "采样点数。", "nx": "x 方向网格数。", "ny": "y 方向网格数。",
    "xlim": "x 范围 \\code{c(min, max)}。", "ylim": "y 范围 \\code{c(min, max)}。",
    "step": "网格步长。", "cam": "\\code{camera3d()} 构造的相机。",
    "P": "点集矩阵，每行一个三维点。",
    "quality": "画质档 \\code{\"l\"} / \\code{\"m\"} / \\code{\"h\"} / \\code{\"k\"}，默认 \\code{\"h\"}。",
    "file": "输出文件路径。", "fps": "帧率；默认由 \\code{quality} 决定。",
    "verbose": "是否打印出片进度。", "keep_frames": "为 \\code{TRUE} 时保留逐帧 PNG 目录。",
    "v": "投影方向向量。", "n_seg": "弧线分段数。", "center": "中心点。",
    "axis": "旋转轴（字符串或长度 3 的向量）；\\code{rotation4_matrix()} 中它是第一个参数。",
    "angle": "旋转角（弧度）或弧 / 扇形的张角。", "about": "旋转中心。",
    "dx": "x 方向平移量。", "dy": "y 方向平移量。", "dz": "z 方向平移量。",
    "w": "射影行向量（长度 2 或 3）。", "lag_ratio": "组内错峰比例，0 表示完全同步。",
    "...": "传给下一层函数的额外参数，或 \\code{vgroup()} / \\code{animation_group()} 的可变对象。",
    "M": "矩阵；\\code{matrix_obj()} 中是要显示的数值矩阵。",
    "Q": "二次型矩阵。", "level": "等值线高度。", "size": "字号或尺寸。",
    "str": "要绘制的字符串。", "tex": "LaTeX 公式源码。",
    "family": "字体族；中文需显式指定。",
    "background": "画布背景色，\\code{\"transparent\"} 输出带 alpha 的 PNG。",
    "camera": "\\code{camera3d()} 相机；三维场景建议显式设置。",
    "side": "正方形 / 立方体边长。", "head": "箭头头部长度。",
    "closed": "是否闭合路径。", "flatten_tol": "贝塞尔展平容差。",
    "w_guard": "射影除法中 w 的安全阈值。",
    "pts": "顶点矩阵，每行一个点；\\code{closed = TRUE} 时首尾相连。",
    "vertex": "角的顶点。", "u": "第一个方向向量（直角标记 / 投影）。",
    "q": "三维线段的第二个端点。", "p": "一个点（二维或三维）。",
    "at": "标签所指向的锚点。", "offset": "标签相对锚点的偏移。",
    "shift": "淡入淡出时的位移量。", "preamble": "传给 LaTeX 的导言区。",
    "lim": "三维坐标轴的范围。", "z": "三维网格所在高度。",
    "extent": "等值线的绘制范围。", "baseline": "面积填充的基线高度。",
    "dash": "虚线段长度。", "gap": "虚线间隔长度。", "dashed": "是否画成虚线。",
    "label": "向量旁的标签文字。", "label_size": "标签字号。",
    "label_offset": "标签相对向量终点的偏移。", "origin": "起点 / 原点。",
    "dir": "刻度或标记的方向。", "near": "透视近裁剪距离。",
    "type": "\\code{\"ortho\"}（正交）或 \\code{\"persp\"}（透视）。",
    "zoom": "相机缩放系数。", "eye": "相机位置（世界坐标）。",
    "look_at": "相机注视点。", "up": "相机上方向，不能与视线平行。",
    "focal": "透视焦距，默认取相机到注视点的距离。",
    "n_ticks": "坐标轴刻度数。", "tick_size": "刻度线长度。",
    "label_size_extra": "（保留）", "numbers": "是否绘制刻度数字。",
    "arrows": "坐标轴是否带箭头。", "axis_labels": "两轴的名称。",
    "start_angle": "弧 / 扇形的起始角。", "rx": "椭圆横半轴。", "ry": "椭圆纵半轴。",
    "ext": "直线向两端延伸的长度。", "digits": "矩阵元素的小数位数。",
    "brackets": "矩阵是否带括号。", "leader": "标签是否带引出线。",
    "tolerance": "贝塞尔展平容差。", "italic": "文字是否斜体。",
    "weight": "字重。", "origin_color": "原点网格线颜色。",
    "origin_width": "原点网格线线宽。",
}

os.makedirs(MAN, exist_ok=True)
for fname, title, members, desc, details, examples in groups:
    lns = ["\\name{%s}" % fname]
    if fname not in members:
        lns.append("\\alias{%s}" % fname)
    lns += ["\\alias{%s}" % m for m in members]
    lns.append("\\title{%s}" % title)
    lns.append("\\description{%s}" % desc)
    lns.append("\\usage{")
    for m in members:
        kind, u, _prm = sig[m]
        lns.append(re.sub(r"\s+", " ", u).strip() if kind == "FN" else m)
    lns.append("}")
    ## 参数名直接来自 formals()，包含没有默认值的必填参数与 ...，
    ## 这样 R CMD check 的 "Undocumented arguments" 不会漏项。
    params = set()
    for m in members:
        params.update(sig[m][2])
    if params:
        lns.append("\\arguments{")
        for p in sorted(params):
            lns.append("  \\item{%s}{%s}" % (p, argdoc.get(
                p, "该参数的含义见本页 \\code{Usage} 与 \\code{Details}；同名参数在各函数间语义一致。")))
        lns.append("}")
    lns.append("\\value{")
    if fname == "constants":
        lns.append("数值常量：\\code{rm_frame_height = 8}，\\code{rm_aspect = 16/9}。")
    elif fname == "scene":
        lns.append("\\code{scene()} 返回 R6 场景；\\code{compile(t)} 返回绘制指令列表；"
                   "\\code{render()} / \\code{render_frame()} / \\code{last_frame()} 写出文件。")
    else:
        lns.append("本页各 \\code{*_obj()} 返回 \\code{rm_mobject}（R6 图元）；"
                   "矩阵构造器返回数值矩阵；动画构造器返回可交给 \\code{scene$play()} 的对象。")
    lns.append("}")
    lns.append("\\details{%s}" % details)
    lns.append("\\examples{")
    lns.append(examples)
    lns.append("}")
    lns.append("\\seealso{\\code{?ROpenManim-package} 与配套教程的 API 速查表。}")
    io.open(os.path.join(MAN, fname + ".Rd"), "w", encoding="utf-8").write("\n".join(lns) + "\n")

io.open(os.path.join(MAN, "ROpenManim-package.Rd"), "w", encoding="utf-8").write(r'''\name{ROpenManim-package}
\alias{ROpenManim-package}
\alias{ROpenManim}
\docType{package}
\title{ROpenManim：R 语言数学动画引擎}
\description{
Manim 的 R 侧实现。核心约定是\strong{帧 = 绘制指令列表}：\code{compile(t)}
把时刻 \code{t} 编译成一组 \code{path} / \code{stroke} 指令，默认后端用
\code{grid} 画到任意 R 图形设备，再由 \code{av} 编码成 mp4。
文字经 \code{systemfonts} 转成贝塞尔轮廓，公式经 \code{dvisvgm} 转成路径，
所以二者都是可被变换、淡入淡出与形变的矢量图元，而不是位图。
}
\details{
三层结构对应 Manim 的 Mobject / Animation / Scene：\code{*_obj()} 造图元，
\code{create()} 等造动画，\code{scene()} 排时间轴。\code{compile(t)} 是纯函数，
可跳帧、可倒序、帧间无累积漂移。

画布固定高 8 unit、宽高比 16:9。三维不是新引擎：\code{dim = 3} 的状态在
\code{compile()} 内先投影再绘制，文字与公式固定在最上层。

依赖：\code{R6}、\code{grid}、\code{systemfonts}、\code{av}。\code{mathtex()}
另需本机 TeX 与 \code{dvisvgm}（可选 \code{tinytex}）。
\strong{不需要编译}，Windows 用户无需 Rtools。
}
\value{载入后可用 88 个导出，按主题分见 \code{?scene}、\code{?mobjects}、
\code{?animation}、\code{?linalg2d}、\code{?linalg3d}、\code{?`three-d`}。}
\examples{
s <- scene()
s$add(circle_obj(r = 1))
length(s$compile(0))
}
\keyword{package}
''')
print("man/ 生成 %d 个 Rd" % len(os.listdir(MAN)))
