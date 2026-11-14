\name{constants}
\alias{constants}
\alias{rm_frame_height}
\alias{rm_aspect}
\title{画布常量}
\description{画布几何约定：帧高恒为 \code{rm_frame_height} 个 unit，宽高比为 \code{rm_aspect}。}
\usage{
rm_frame_height
rm_aspect
}
\value{
数值常量：\code{rm_frame_height = 8}，\code{rm_aspect = 16/9}。
}
\details{所以 16:9 画布的 x 范围约为 [-7.11, 7.11]、y 范围为 [-4, 4]。\code{quality = "m"}（1280x720）时 1 unit = 90 px，屏幕原点在 (640, 360)。}
\examples{
rm_frame_height
rm_aspect
rm_frame_height * rm_aspect   # 画布宽度（unit）
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
