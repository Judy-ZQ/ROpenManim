\name{linalg2d}
\alias{linalg2d}
\alias{apply_matrix}
\alias{apply_inverse}
\alias{rotate_group}
\alias{shift_group}
\alias{homogeneous_matrix}
\alias{translation_matrix}
\alias{affine_matrix}
\alias{perspective_matrix}
\alias{projection_matrix}
\alias{rm_compose}
\title{齐次 3×3 与二维矩阵动画}
\description{二维仿射与射影变换统一写成 3×3 齐次矩阵。\code{apply_matrix()} 不插值形状，而是把 \code{M(f) = (1-f)I + fA} 逐帧作用到整组图元的支持点。}
\usage{
apply_matrix(obj, A, run_time = 2, rate = rate_smooth, flatten_tol = 0.001, w_guard = 0.001)
apply_inverse(obj, A, run_time = 2, rate = rate_smooth, ...)
rotate_group(obj, angle, about = c(0, 0), run_time = 1.5, rate = rate_smooth)
shift_group(obj, dx = 0, dy = 0, run_time = 1.5, rate = rate_smooth)
homogeneous_matrix(A = diag(2), b = c(0, 0), w = c(0, 0))
translation_matrix(dx = 0, dy = 0)
affine_matrix(A, b = c(0, 0))
perspective_matrix(p = 0, q = 0, ...)
projection_matrix(v)
rm_compose(...)
}
\arguments{
  \item{...}{传给下一层函数的额外参数，或 \code{vgroup()} / \code{animation_group()} 的可变对象。}
  \item{A}{线性部分：2×2（三维为 3×3）矩阵。}
  \item{about}{旋转中心。}
  \item{angle}{旋转角（弧度）或弧 / 扇形的张角。}
  \item{b}{平移向量（矩阵构造器中）或形变终点图元。}
  \item{dx}{x 方向平移量。}
  \item{dy}{y 方向平移量。}
  \item{flatten_tol}{贝塞尔展平容差。}
  \item{obj}{要变换或播放的图元 / 图元组。}
  \item{p}{一个点（二维或三维）。}
  \item{q}{三维线段的第二个端点。}
  \item{rate}{缓动函数，如 \code{rate_smooth}、\code{rate_linear}。}
  \item{run_time}{动画时长（秒），默认 1（矩阵动画为 2）。}
  \item{v}{投影方向向量。}
  \item{w}{射影行向量（长度 2 或 3）。}
  \item{w_guard}{射影除法中 w 的安全阈值。}
}
\value{
本页各 \code{*_obj()} 返回 \code{rm_mobject}（R6 图元）；矩阵构造器返回数值矩阵；动画构造器返回可交给 \code{scene$play()} 的对象。
}
\details{因此看到的是「同一个变换逐渐发生」，不是两幅静止形状的混合。\code{rm_compose(m1, m2)} 是先 \code{m1} 后 \code{m2}。}
\examples{
A <- translation_matrix(2, 0.5)
A
B <- rm_compose(affine_matrix(diag(2)), A)
B
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
