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
\title{样式简写与结构窥视}
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
}
\arguments{
  \item{a}{形变起点图元。}
  \item{b}{平移向量（矩阵构造器中）或形变终点图元。}
  \item{color}{描边颜色（十六进制）。}
  \item{label}{标签文字：向量图元指向量旁的标注，peek() 指打印时显示的名称。}
  \item{o}{要检查 / 统计的图元或图元组。}
  \item{opacity}{填充不透明度，0–1。}
  \item{stroke}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{width}{线宽（像素）。}
}
\value{
\code{COL} 是颜色列表；\code{st()} / \code{fl()} 返回样式列表；\code{subpaths()} 返回折线矩阵列表，\code{n_subpaths()} / \code{n_curves()} / \code{n_objects()} 返回非负整数，\code{can_morph()} 返回逻辑标量，\code{peek()} 打印摘要并原样返回对象。
}
\details{后六个函数把「帧 = 绘制指令列表」的结构变成可查询的公开数据：\code{subpaths()} 返回展平后的折线，\code{n_subpaths()} 与 \code{n_curves()} 分别数子路径与贝塞尔段，\code{n_objects()} 数摊平后的图元个数，\code{can_morph(a, b)} 判断 \code{transform()} 会不会退化为交叉淡入淡出，\code{peek()} 一行打印形状、子路径数与包围盒。注意 \strong{对象数} 与 \strong{子路径数} 是两个不同的数：\code{arrow_obj()} 是 2 个对象、\code{text("O")} 可能有多个子路径。}
\examples{
o <- circle_obj(r = 1, style = st(COL$cyan, 5))
peek(o)
n_subpaths(o)
n_curves(o)
can_morph(o, square_obj(side = 2))
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
