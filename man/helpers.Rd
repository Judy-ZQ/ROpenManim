\name{helpers}
\alias{helpers}
\alias{COL}
\alias{st}
\alias{fl}
\alias{subpaths}
\alias{n_subpaths}
\alias{n_curves}
\alias{n_objects}
\alias{can_morph}
\alias{peek}
\alias{cjk_font}
\alias{lab}
\alias{tex}
\alias{ref_axes}
\alias{fig}
\alias{frame_to}
\title{样式简写、结构窥视与排字出图}
\description{\code{COL} 是 Manim 风格调色板；\code{st()} / \code{fl()} 是 \code{style} 列表的简写（描边 / 填充），可直接传给任何 \code{*_obj()}。}
\usage{
COL
st(color = COL$white, width = 4)
fl(color = COL$cyan, opacity = 0.3, stroke = NA_character_, width = 2)
subpaths(o)
n_subpaths(o)
n_curves(o)
n_objects(o)
can_morph(a, b)
peek(o, label = NULL)
cjk_font()
lab(str, x, y, size = 28, color = COL$white, family = cjk_font(), ...)
tex(s, x, y, size = 44, color = COL$white, ...)
ref_axes(lim = 3.4, color = COL$dim, width = 2)
fig(sc, name, t = NULL, quality = "m", dir = "figs")
frame_to(sc, name, t, quality = "m", dir = "figs")
}
\arguments{
  \item{...}{传给下一层函数的额外参数，或 \code{vgroup()} / \code{animation_group()} 的可变对象。}
  \item{a}{形变起点图元。}
  \item{b}{平移向量（矩阵构造器中）或形变终点图元。}
  \item{color}{描边颜色（十六进制）。}
  \item{dir}{刻度或标记的方向。}
  \item{family}{字体族；中文需显式指定。}
  \item{label}{标签文字：向量图元指向量旁的标注，peek() 指打印时显示的名称。}
  \item{lim}{三维坐标轴的范围。}
  \item{name}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{o}{要检查 / 统计的图元或图元组。}
  \item{opacity}{填充不透明度，0–1。}
  \item{quality}{画质档 \code{"l"} / \code{"m"} / \code{"h"} / \code{"k"}，默认 \code{"h"}。}
  \item{s}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{sc}{场景对象。}
  \item{size}{字号或尺寸。}
  \item{str}{要绘制的字符串。}
  \item{stroke}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{t}{时刻（秒）；\code{compile(t)} 对时刻求值。}
  \item{width}{线宽（像素）。}
  \item{x}{x 坐标（或横坐标向量）。}
  \item{y}{y 坐标（或纵坐标向量）。}
}
\value{
\code{COL} 是颜色列表；\code{st()} / \code{fl()} 返回样式列表；\code{subpaths()} 返回折线矩阵列表，\code{n_subpaths()} / \code{n_curves()} / \code{n_objects()} 返回非负整数，\code{can_morph()} 返回逻辑标量，\code{peek()} 打印摘要并原样返回对象；\code{cjk_font()} 返回字体族名，\code{lab()} / \code{tex()} / \code{ref_axes()} 返回图元；\code{fig()} / \code{frame_to()} 写出 PNG 并返回文件路径（前者在 knit 上下文里改交 knitr 图对象）。
}
\details{后六个函数把「帧 = 绘制指令列表」的结构变成可查询的公开数据：\code{subpaths()} 返回展平后的折线，\code{n_subpaths()} 与 \code{n_curves()} 分别数子路径与贝塞尔段，\code{n_objects()} 数摊平后的图元个数，\code{can_morph(a, b)} 判断 \code{transform()} 会不会退化为交叉淡入淡出，\code{peek()} 一行打印形状、子路径数与包围盒。注意 \strong{对象数} 与 \strong{子路径数} 是两个不同的数：\code{arrow_obj()} 是 2 个对象、\code{text("O")} 可能有多个子路径。}
\examples{
o <- circle_obj(r = 1, style = st(COL$cyan, 5))
peek(o)
n_subpaths(o)
n_curves(o)
can_morph(o, square_obj(side = 2))

s <- scene(); s$add(lab("hi", 0, 1)); s$add(ref_axes())
fig(s, "demo", t = 0, quality = "l", dir = tempdir())
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
