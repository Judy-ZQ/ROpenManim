\name{text-tex-axes}
\alias{text-tex-axes}
\alias{text}
\alias{mathtex}
\alias{axes}
\title{文字、公式与坐标系}
\description{\code{text()} 借 \code{systemfonts} 把字形转成真正的贝塞尔轮廓，因此文字和公式是普通矢量图元，能被变换、淡入淡出与形变，不是贴上去的位图。}
\usage{
text(str, size = 48, family = "sans", color = "#FFFFFF", italic = FALSE, weight = "normal", tolerance = 0.05)
mathtex(tex, size = 48, color = "#FFFFFF", preamble = NULL)
axes(xlim = c(0, 1), ylim = c(0, 1), width = 10, height = 6, x = 0, y = 0, color = "#FFFFFF", n_ticks = 5, tick_size = 0.14, label_size = 30, numbers = TRUE, arrows = TRUE, axis_labels = NULL)
}
\arguments{
  \item{arrows}{坐标轴是否带箭头。}
  \item{axis_labels}{两轴的名称。}
  \item{color}{描边颜色（十六进制）。}
  \item{family}{字体族；中文需显式指定。}
  \item{height}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{italic}{文字是否斜体。}
  \item{label_size}{标签字号。}
  \item{n_ticks}{坐标轴刻度数。}
  \item{numbers}{是否绘制刻度数字。}
  \item{preamble}{传给 LaTeX 的导言区。}
  \item{size}{字号或尺寸。}
  \item{str}{要绘制的字符串。}
  \item{tex}{LaTeX 公式源码。}
  \item{tick_size}{刻度线长度。}
  \item{tolerance}{贝塞尔展平容差。}
  \item{weight}{字重。}
  \item{width}{线宽（像素）。}
  \item{x}{x 坐标（或横坐标向量）。}
  \item{xlim}{x 范围 \code{c(min, max)}。}
  \item{y}{y 坐标（或纵坐标向量）。}
  \item{ylim}{y 范围 \code{c(min, max)}。}
}
\value{
本页各 \code{*_obj()} 返回 \code{rm_mobject}（R6 图元）；矩阵构造器返回数值矩阵；动画构造器返回可交给 \code{scene$play()} 的对象。
}
\details{中文必须显式给 \code{family}（默认 \code{"sans"} 会缺字形）。\code{mathtex()} 需要本机 TeX 与 \code{dvisvgm}，可选装 \code{tinytex}；\code{axes()} 构造坐标系，\code{plot_fn()} / \code{area_under_obj()} 依附于它。}
\examples{
ax <- axes(xlim = c(-2, 2), ylim = c(-1, 1))
s <- scene()
s$add(ax)
length(s$compile(0))
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
