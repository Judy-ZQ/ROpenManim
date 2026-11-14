\name{ROpenManim-package}
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
