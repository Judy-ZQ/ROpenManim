\name{scene}
\alias{scene}
\alias{render}
\alias{render_frame}
\alias{last_frame}
\title{场景与输出}
\description{场景是时间轴的容器：图元用 \code{add()} 挂上去，动画用 \code{play()} 排进去。}
\usage{
scene(background = "#0E1116", width = NULL, height = NULL, camera = NULL)
render(sc, file = "manim.mp4", fps = NULL, quality = "h", verbose = TRUE, keep_frames = FALSE)
render_frame(sc, file, t = 0, quality = "h")
last_frame(sc, file, quality = "h")
}
\arguments{
  \item{background}{画布背景色，\code{"transparent"} 输出带 alpha 的 PNG。}
  \item{camera}{\code{camera3d()} 相机；三维场景建议显式设置。}
  \item{file}{输出文件路径。}
  \item{fps}{帧率；默认由 \code{quality} 决定。}
  \item{height}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{keep_frames}{为 \code{TRUE} 时保留逐帧 PNG 目录。}
  \item{quality}{画质档 \code{"l"} / \code{"m"} / \code{"h"} / \code{"k"}，默认 \code{"h"}。}
  \item{sc}{场景对象。}
  \item{t}{时刻（秒）；\code{compile(t)} 对时刻求值。}
  \item{verbose}{是否打印出片进度。}
  \item{width}{线宽（像素）。}
}
\value{
\code{scene()} 返回 R6 场景；\code{compile(t)} 返回绘制指令列表；\code{render()} / \code{render_frame()} / \code{last_frame()} 写出文件。
}
\details{帧不是逐步修改的状态，而是 \code{compile(t)} 对时刻 \code{t} 的纯函数求值——它返回一组绘制指令（\code{stroke} / \code{path}），后端只认这两个动词。因此可以跳帧、倒序渲染，结果完全一致。画布固定高 8 unit、宽高比 16:9；\code{quality} 四档只改像素与帧率。}
\examples{
s <- scene()
s$add(circle_obj(r = 1))
length(s$compile(0))
s$duration()
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
