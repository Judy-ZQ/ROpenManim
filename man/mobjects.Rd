\name{mobjects}
\alias{mobjects}
\alias{vgroup}
\alias{line_obj}
\alias{circle_obj}
\alias{square_obj}
\alias{rect_obj}
\alias{polygon_obj}
\alias{arrow_obj}
\alias{dot_obj}
\alias{plot_fn}
\alias{arc_obj}
\alias{sector_obj}
\alias{ellipse_obj}
\alias{triangle_obj}
\alias{brace_obj}
\alias{double_arrow_obj}
\alias{dashed_line_obj}
\alias{angle_obj}
\alias{right_angle_obj}
\alias{number_line_obj}
\alias{grid_obj}
\alias{parametric_curve_obj}
\alias{area_under_obj}
\alias{polygon_fill_obj}
\alias{vector_obj}
\alias{label_obj}
\alias{matrix_obj}
\alias{cross_obj}
\alias{tick_obj}
\alias{span_line_obj}
\alias{quad_form_curve_obj}
\alias{unit_square_obj}
\alias{basis_arrows_obj}
\title{二维图元与组合}
\description{每个 \code{*_obj()} 返回一个 \code{rm_mobject}（R6 对象），可单独 \code{add()} 进场景，也可用 \code{vgroup()} 合成一组后整体变换。\code{style} 参数统一接收\code{list(stroke=, stroke_width=, fill=, alpha=)} 形式的样式。}
\usage{
vgroup(...)
line_obj(p1, p2, style = NULL)
circle_obj(x = 0, y = 0, r = 1, style = NULL)
square_obj(side = 2, x = 0, y = 0, style = NULL)
rect_obj(w = 2, h = 1, x = 0, y = 0, style = NULL)
polygon_obj(pts, closed = TRUE, style = NULL)
arrow_obj(p1, p2, head = 0.22, color = "#FFFFFF", width = 4, style = NULL)
dot_obj(x = 0, y = 0, r = 0.08, color = "#FFFFFF")
plot_fn(ax, fun, from = ax$xlim[1], to = ax$xlim[2], n = 300, color = "#58C4DD", width = 5, style = NULL)
arc_obj(center = c(0, 0), r = 1, start_angle = 0, angle = pi/2, color = "#FFFFFF", width = 4, n_seg = NULL, style = NULL)
sector_obj(center = c(0, 0), r = 1, start_angle = 0, angle = pi/2, fill = "#58C4DD", opacity = 0.35, color = NA_character_, width = 2, n_seg = NULL)
ellipse_obj(center = c(0, 0), rx = 1, ry = 0.6, angle = 0, color = "#58C4DD", width = 4, n = 180, style = NULL)
triangle_obj(p1, p2, p3, color = "#FFFFFF", width = 4, fill = NULL, opacity = 0.3, style = NULL)
brace_obj(p1, p2, amplitude = 0.18, color = "#FFFFFF", width = 3, n = 120, style = NULL)
double_arrow_obj(p1, p2, color = "#FFFFFF", width = 4, head = 0.22)
dashed_line_obj(p1, p2, dash = 0.16, gap = 0.12, color = "#7D8590", width = 3)
angle_obj(vertex, p1, p2, r = 0.5, color = "#FFFFFF", width = 3)
right_angle_obj(vertex, u, v, size = 0.24, color = "#FFFFFF", width = 3)
number_line_obj(xlim = c(-3, 3), y = 0, at = NULL, step = 1, color = "#FFFFFF", width = 3, label_size = 26, arrows = TRUE, tick_size = 0.12)
grid_obj(xlim = c(-4, 4), ylim = c(-3, 3), step = 1, color = "#3D4653", width = 2, origin_color = NULL, origin_width = 3)
parametric_curve_obj(fun, from = 0, to = 2 * pi, n = 200, color = "#58C4DD", width = 4, closed = FALSE, style = NULL)
area_under_obj(ax, fun, from = ax$xlim[1], to = ax$xlim[2], n = 200, baseline = 0, fill = "#58C4DD", opacity = 0.3)
polygon_fill_obj(pts, fill = "#58C4DD", opacity = 0.35, color = NA_character_, width = 2)
vector_obj(from = c(0, 0), to = c(1, 0), color = "#58C4DD", width = 5, head = 0.22, label = NULL, label_size = 30, label_offset = 0.28, family = "sans")
label_obj(str, at, offset = c(0.8, 0.6), size = 30, color = "#FFFFFF", leader = TRUE, width = 2, family = "sans")
matrix_obj(M, x = 0, y = 0, cell_w = 0.78, cell_h = 0.62, color = "#FFFFFF", size = 30, brackets = TRUE, width = 3, digits = 3)
cross_obj(p, size = 0.15, color = "#FC6255", width = 3)
tick_obj(p, dir = c(0, 1), size = 0.18, color = "#FFFFFF", width = 3)
span_line_obj(v, ext = 6, color = "#7D8590", width = 3, dashed = TRUE, dash = 0.2)
quad_form_curve_obj(Q, level = 1, color = "#58C4DD", width = 5, n = 240, extent = 6, style = NULL)
unit_square_obj(origin = c(0, 0), fill = "#58C4DD", opacity = 0.3, color = "#58C4DD", width = 4)
basis_arrows_obj(e1 = c(1, 0), e2 = c(0, 1), color1 = "#FC6255", color2 = "#83C167", labels = c("e1", "e2"), width = 5, head = 0.2)
}
\arguments{
  \item{...}{传给下一层函数的额外参数，或 \code{vgroup()} / \code{animation_group()} 的可变对象。}
  \item{M}{矩阵；\code{matrix_obj()} 中是要显示的数值矩阵。}
  \item{Q}{二次型矩阵。}
  \item{amplitude}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{angle}{旋转角（弧度）或弧 / 扇形的张角。}
  \item{arrows}{坐标轴是否带箭头。}
  \item{at}{标签所指向的锚点。}
  \item{ax}{\code{axes()} 构造的坐标系对象。}
  \item{baseline}{面积填充的基线高度。}
  \item{brackets}{矩阵是否带括号。}
  \item{cell_h}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{cell_w}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{center}{中心点。}
  \item{closed}{是否闭合路径。}
  \item{color}{描边颜色（十六进制）。}
  \item{color1}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{color2}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{dash}{虚线段长度。}
  \item{dashed}{是否画成虚线。}
  \item{digits}{矩阵元素的小数位数。}
  \item{dir}{刻度或标记的方向。}
  \item{e1}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{e2}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{ext}{直线向两端延伸的长度。}
  \item{extent}{等值线的绘制范围。}
  \item{family}{字体族；中文需显式指定。}
  \item{fill}{填充颜色。}
  \item{from}{参数或区间起点。}
  \item{fun}{一元 / 二元函数，返回曲线点或曲面高度。}
  \item{gap}{虚线间隔长度。}
  \item{h}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{head}{箭头头部长度。}
  \item{label}{向量旁的标签文字。}
  \item{label_offset}{标签相对向量终点的偏移。}
  \item{label_size}{标签字号。}
  \item{labels}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{leader}{标签是否带引出线。}
  \item{level}{等值线高度。}
  \item{n}{采样点数。}
  \item{n_seg}{弧线分段数。}
  \item{offset}{标签相对锚点的偏移。}
  \item{opacity}{填充不透明度，0–1。}
  \item{origin}{起点 / 原点。}
  \item{origin_color}{原点网格线颜色。}
  \item{origin_width}{原点网格线线宽。}
  \item{p}{一个点（二维或三维）。}
  \item{p1}{第一个端点 / 顶点。}
  \item{p2}{第二个端点 / 顶点。}
  \item{p3}{第三个顶点。}
  \item{pts}{顶点矩阵，每行一个点；\code{closed = TRUE} 时首尾相连。}
  \item{r}{半径。}
  \item{rx}{椭圆横半轴。}
  \item{ry}{椭圆纵半轴。}
  \item{side}{正方形 / 立方体边长。}
  \item{size}{字号或尺寸。}
  \item{start_angle}{弧 / 扇形的起始角。}
  \item{step}{网格步长。}
  \item{str}{要绘制的字符串。}
  \item{style}{样式列表 \code{list(stroke=, stroke_width=, fill=, alpha=)}。}
  \item{tick_size}{刻度线长度。}
  \item{to}{参数或区间终点。}
  \item{u}{第一个方向向量（直角标记 / 投影）。}
  \item{v}{投影方向向量。}
  \item{vertex}{角的顶点。}
  \item{w}{射影行向量（长度 2 或 3）。}
  \item{width}{线宽（像素）。}
  \item{x}{x 坐标（或横坐标向量）。}
  \item{xlim}{x 范围 \code{c(min, max)}。}
  \item{y}{y 坐标（或纵坐标向量）。}
  \item{ylim}{y 范围 \code{c(min, max)}。}
}
\value{
本页各 \code{*_obj()} 返回 \code{rm_mobject}（R6 图元）；矩阵构造器返回数值矩阵；动画构造器返回可交给 \code{scene$play()} 的对象。
}
\details{前 8 个是基础图元，其余是线性代数教材需要而补的 P1 图元（共 31 个）。三维图元见 \code{?`three-d`}。}
\examples{
g <- vgroup(circle_obj(r = 1), square_obj(side = 2))
s <- scene()
s$add(g)
length(s$compile(0))
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
