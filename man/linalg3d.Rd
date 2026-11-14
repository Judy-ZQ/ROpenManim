\name{linalg3d}
\alias{linalg3d}
\alias{homogeneous4_matrix}
\alias{translation4_matrix}
\alias{affine4_matrix}
\alias{rotation4_matrix}
\alias{projection4_matrix}
\alias{perspective4_matrix}
\alias{rm_compose4}
\alias{apply_matrix3d}
\alias{apply_inverse3d}
\alias{rotate3d_group}
\alias{shift3d_group}
\title{齐次 4×4 与三维矩阵动画}
\description{三维版本：\code{A} 是 3×3，\code{b} / \code{w} 各长 3。}
\usage{
homogeneous4_matrix(A = diag(3), b = c(0, 0, 0), w = c(0, 0, 0))
translation4_matrix(dx = 0, dy = 0, dz = 0)
affine4_matrix(A, b = c(0, 0, 0))
rotation4_matrix(axis = "z", angle = 0)
projection4_matrix(n = c(0, 0, 1), v = NULL)
perspective4_matrix(p = 0, q = 0, r = 0, ...)
rm_compose4(...)
apply_matrix3d(obj, A, run_time = 2, rate = rate_smooth, flatten_tol = 0.001, w_guard = 0.001)
apply_inverse3d(obj, A, run_time = 2, rate = rate_smooth, ...)
rotate3d_group(obj, axis = "z", angle = pi/2, about = c(0, 0, 0), run_time = 1.5, rate = rate_smooth)
shift3d_group(obj, dx = 0, dy = 0, dz = 0, run_time = 1.5, rate = rate_smooth)
}
\arguments{
  \item{...}{传给下一层函数的额外参数，或 \code{vgroup()} / \code{animation_group()} 的可变对象。}
  \item{A}{线性部分：2×2（三维为 3×3）矩阵。}
  \item{about}{旋转中心。}
  \item{angle}{旋转角（弧度）或弧 / 扇形的张角。}
  \item{axis}{旋转轴（字符串或长度 3 的向量）；\code{rotation4_matrix()} 中它是第一个参数。}
  \item{b}{平移向量（矩阵构造器中）或形变终点图元。}
  \item{dx}{x 方向平移量。}
  \item{dy}{y 方向平移量。}
  \item{dz}{z 方向平移量。}
  \item{flatten_tol}{贝塞尔展平容差。}
  \item{n}{采样点数。}
  \item{obj}{要变换或播放的图元 / 图元组。}
  \item{p}{一个点（二维或三维）。}
  \item{q}{三维线段的第二个端点。}
  \item{r}{半径。}
  \item{rate}{缓动函数，如 \code{rate_smooth}、\code{rate_linear}。}
  \item{run_time}{动画时长（秒），默认 1（矩阵动画为 2）。}
  \item{v}{投影方向向量。}
  \item{w}{射影行向量（长度 2 或 3）。}
  \item{w_guard}{射影除法中 w 的安全阈值。}
}
\value{
本页各 \code{*_obj()} 返回 \code{rm_mobject}（R6 图元）；矩阵构造器返回数值矩阵；动画构造器返回可交给 \code{scene$play()} 的对象。
}
\details{\code{rotation4_matrix(axis, angle)} 的参数顺序是 \strong{先轴后角}，务必用具名参数调用。\code{rm_compose4(m1, m2)} 同样是先 \code{m1} 后 \code{m2}。\code{apply_matrix3d()} 与二维同式 \code{M(f) = (1-f)I + fA}。}
\examples{
M <- homogeneous4_matrix(diag(3), b = c(2, 0, 0))
M
rotation4_matrix(axis = c(0, 0, 1), angle = pi/2)
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
