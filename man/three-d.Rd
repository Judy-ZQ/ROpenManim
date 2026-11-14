\name{three-d}
\alias{three-d}
\alias{camera3d}
\alias{project_point}
\alias{line3d_obj}
\alias{polyline3d_obj}
\alias{cube3d_obj}
\alias{parallelepiped3d_obj}
\alias{axes3d_obj}
\alias{grid3d_obj}
\alias{plane3d_obj}
\alias{vector3d_obj}
\alias{basis3d_obj}
\alias{point3d_obj}
\alias{surface3d_obj}
\title{相机与三维图元}
\description{三维不是新引擎：\code{dim = 3} 的状态在 \code{compile()} 内被 \code{.rm_project_state()}投影成二维，绘制前立刻把 \code{dim} 改回 2 防止二次投影；文字与公式固定在最上层。}
\usage{
camera3d(eye = c(6, -8, 5), look_at = c(0, 0, 0), up = c(0, 0, 1), zoom = 1, type = c("ortho", "persp"), focal = NULL, near = 0.2, offset = c(0, 0))
project_point(cam, P)
line3d_obj(p, q, color = "#FFFFFF", width = 3, style = NULL)
polyline3d_obj(P, color = "#FFFFFF", width = 3, closed = FALSE, style = NULL)
cube3d_obj(side = 2, center = c(0, 0, 0), color = "#58C4DD", width = 4, fill = NULL, opacity = 0.22)
parallelepiped3d_obj(v1 = c(1, 0, 0), v2 = c(0, 1, 0), v3 = c(0, 0, 1), origin = c(0, 0, 0), color = "#58C4DD", width = 4, fill = NULL, opacity = 0.22)
axes3d_obj(lim = 3, color1 = "#FC6255", color2 = "#83C167", color3 = "#58C4DD", width = 3, head = 0.24)
grid3d_obj(xlim = c(-3, 3), ylim = c(-3, 3), step = 1, z = 0, color = "#33404D", width = 2)
plane3d_obj(n = c(0, 0, 1), size = 3, step = 1, color = "#7D8590", width = 2)
vector3d_obj(from = c(0, 0, 0), to = c(1, 0, 0), color = "#FFFFFF", width = 4, head = 0.24)
basis3d_obj(v1 = c(1, 0, 0), v2 = c(0, 1, 0), v3 = c(0, 0, 1), color1 = "#FC6255", color2 = "#83C167", color3 = "#58C4DD", width = 5, head = 0.22)
point3d_obj(p = c(0, 0, 0), r = 0.1, color = "#E8C547", width = 3)
surface3d_obj(fun, xlim = c(-2, 2), ylim = c(-2, 2), nx = 13, ny = 13, color = "#58C4DD", width = 2)
}
\arguments{
  \item{P}{点集矩阵，每行一个三维点。}
  \item{cam}{\code{camera3d()} 构造的相机。}
  \item{center}{中心点。}
  \item{closed}{是否闭合路径。}
  \item{color}{描边颜色（十六进制）。}
  \item{color1}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{color2}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{color3}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{eye}{相机位置（世界坐标）。}
  \item{fill}{填充颜色。}
  \item{focal}{透视焦距，默认取相机到注视点的距离。}
  \item{from}{参数或区间起点。}
  \item{fun}{一元 / 二元函数，返回曲线点或曲面高度。}
  \item{head}{箭头头部长度。}
  \item{lim}{三维坐标轴的范围。}
  \item{look_at}{相机注视点。}
  \item{n}{采样点数。}
  \item{near}{透视近裁剪距离。}
  \item{nx}{x 方向网格数。}
  \item{ny}{y 方向网格数。}
  \item{offset}{标签相对锚点的偏移。}
  \item{opacity}{填充不透明度，0–1。}
  \item{origin}{起点 / 原点。}
  \item{p}{一个点（二维或三维）。}
  \item{q}{三维线段的第二个端点。}
  \item{r}{半径。}
  \item{side}{正方形 / 立方体边长。}
  \item{size}{字号或尺寸。}
  \item{step}{网格步长。}
  \item{style}{样式列表 \code{list(stroke=, stroke_width=, fill=, alpha=)}。}
  \item{to}{参数或区间终点。}
  \item{type}{\code{"ortho"}（正交）或 \code{"persp"}（透视）。}
  \item{up}{相机上方向，不能与视线平行。}
  \item{v1}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{v2}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{v3}{该参数的含义见本页 \code{Usage} 与 \code{Details}；同名参数在各函数间语义一致。}
  \item{width}{线宽（像素）。}
  \item{xlim}{x 范围 \code{c(min, max)}。}
  \item{ylim}{y 范围 \code{c(min, max)}。}
  \item{z}{三维网格所在高度。}
  \item{zoom}{相机缩放系数。}
}
\value{
本页各 \code{*_obj()} 返回 \code{rm_mobject}（R6 图元）；矩阵构造器返回数值矩阵；动画构造器返回可交给 \code{scene$play()} 的对象。
}
\details{\code{camera3d()} 用 look-at 构造 \code{f, r, u} 三轴；遮挡按画家算法（平均深度）排序。\strong{坑}：\code{project_point(cam, P)} 的第二参数按 \strong{点集} 处理，传裸向量 \code{c(1,2,3)} 会被当成 3 个点且不报错；单点必须写\code{matrix(p, nrow = 1)}，批量用 \code{pts[i, , drop = FALSE]}。}
\examples{
cam <- camera3d(eye = c(6, -8, 5))
P <- matrix(c(1, 2, 3), nrow = 1)
project_point(cam, P)
s <- scene(camera = cam)
s$add(cube3d_obj(side = 2))
length(s$compile(0))
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
