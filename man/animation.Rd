\name{animation}
\alias{animation}
\alias{rate_smooth}
\alias{rate_linear}
\alias{rate_rush_into}
\alias{rate_rush_from}
\alias{rate_there_and_back}
\alias{rate_smoothstep}
\alias{rate_double_smooth}
\alias{create}
\alias{fade_in}
\alias{fade_out}
\alias{transform}
\alias{animation_group}
\alias{succession}
\title{动画与时间曲线}
\description{\code{rate_*} 把 \code{t} 从 [0, 1] 映射到 [0, 1]，决定缓动；\code{create} / \code{fade_in} / \code{fade_out} / \code{transform} 是四个叶子动画。}
\usage{
rate_smooth(t)
rate_linear(t)
rate_rush_into(t)
rate_rush_from(t)
rate_there_and_back(t)
rate_smoothstep(t)
rate_double_smooth(t)
create(obj, run_time = 1, rate = rate_smooth)
fade_in(obj, run_time = 1, rate = rate_smooth, shift = 0)
fade_out(obj, run_time = 1, rate = rate_smooth, shift = 0)
transform(a, b, run_time = 1, rate = rate_smooth)
animation_group(..., lag_ratio = 0.5, run_time = NULL, rate = rate_smooth)
succession(..., run_time = NULL)
}
\arguments{
  \item{...}{传给下一层函数的额外参数，或 \code{vgroup()} / \code{animation_group()} 的可变对象。}
  \item{a}{形变起点图元。}
  \item{b}{平移向量（矩阵构造器中）或形变终点图元。}
  \item{lag_ratio}{组内错峰比例，0 表示完全同步。}
  \item{obj}{要变换或播放的图元 / 图元组。}
  \item{rate}{缓动函数，如 \code{rate_smooth}、\code{rate_linear}。}
  \item{run_time}{动画时长（秒），默认 1（矩阵动画为 2）。}
  \item{shift}{淡入淡出时的位移量。}
  \item{t}{时刻（秒）；\code{compile(t)} 对时刻求值。}
}
\value{
本页各 \code{*_obj()} 返回 \code{rm_mobject}（R6 图元）；矩阵构造器返回数值矩阵；动画构造器返回可交给 \code{scene$play()} 的对象。
}
\details{\code{animation_group()} 同步或错峰播放，\code{succession()} 串行播放。注意：\code{scene$play()} 每次只收一个动画，要同时播放多个请用\code{animation_group(...)}；\code{transform()} 要求两端子路径数一致，否则退化为交叉淡化或报错。}
\examples{
s <- scene()
sq <- square_obj(side = 2)
s$add(sq)
s$play(create(sq, run_time = 1))
s$duration()
rate_smooth(0.5)
}
\seealso{\code{?ROpenManim-package} 与配套教程的 API 速查表。}
