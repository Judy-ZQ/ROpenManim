## 线性代数动画层：让「一组图元」被矩阵连续作用。
## Manim 的 Transform 只在两个静态形状之间插值，讲不了 A(t)=(1-t)I+tA 这种过程；
## 这里把变换矩阵本身当作动画参数，逐帧施加到 state 上（含展平缓存）。
## 注意：线性/射影变换会把字形也拉斜，因此只应对几何对象使用，
## 文字与公式请用 fade_in / transform。
##
## 矩阵约定：v = (x, y, 1)，变换写成 v %*% t(m)。
##   m = [ A  b ; w  1 ]，A 是 2x2 线性部，b 是平移（第三列前两项），
##   w 是射影部；w != 0 时 (x', y') = (A(x,y) + b) / (w . (x,y) + 1)。
## 接受两种输入：2x2 线性矩阵（自动提升为齐次）或 3x3 齐次矩阵。

## ---- 齐次矩阵的构造与规范化 ----

## 把 2x2 的 M 写成 3x3 齐次矩阵：x' = m[1,] . (x,y,1)，故前两行就是 M 的两行
.rm_linear_m <- function(M) {
  rbind(c(M[1, 1], M[1, 2], 0),
        c(M[2, 1], M[2, 2], 0),
        c(0, 0, 1))
}

## 输入规范化 + 齐次代表元归一化。
## 射影矩阵差一个非零标量倍表示同一个变换，但插值路径 M(f)=(1-f)I+f*A
## 依赖代表元；统一令 m[3,3]=1，路径才唯一、可复现。
.rm_as_homogeneous <- function(A) {
  m <- as.matrix(A)
  if (!is.numeric(m) || any(!is.finite(m))) {
    stop("apply_matrix(): 矩阵必须是有限数值", call. = FALSE)
  }
  d <- as.integer(dim(m))
  if (identical(d, c(2L, 2L))) {
    m <- .rm_linear_m(m)
  } else if (!identical(d, c(3L, 3L))) {
    stop("apply_matrix(): A 必须是 2x2 线性矩阵或 3x3 齐次矩阵", call. = FALSE)
  }
  k <- m[3, 3]
  if (abs(k) < 1e-9) {
    stop("apply_matrix(): 齐次矩阵 m[3,3] 不能为 0（原点会被映到无穷远）", call. = FALSE)
  }
  m / k
}

#' 通用齐次矩阵构造器：m = [A b; w 1]
#' @export
homogeneous_matrix <- function(A = diag(2), b = c(0, 0), w = c(0, 0)) {
  A <- as.matrix(A)
  b <- as.numeric(b); w <- as.numeric(w)
  if (nrow(A) != 2L || ncol(A) != 2L || length(b) != 2L || length(w) != 2L) {
    stop("homogeneous_matrix(): 需要 2x2 的 A 与长度 2 的 b / w", call. = FALSE)
  }
  rbind(c(A[1, 1], A[1, 2], b[1]),
        c(A[2, 1], A[2, 2], b[2]),
        c(w[1],    w[2],    1))
}

#' 平移：x' = x + dx, y' = y + dy
#' @export
translation_matrix <- function(dx = 0, dy = 0) {
  homogeneous_matrix(b = c(dx, dy))
}

#' 仿射：x' = A(x,y) + b
#' @export
affine_matrix <- function(A, b = c(0, 0)) {
  homogeneous_matrix(A = A, b = b)
}

#' 射影（透视）：w_v = 1 + p*x + q*y，可再叠加 A / b
#' @export
perspective_matrix <- function(p = 0, q = 0, ...) {
  homogeneous_matrix(w = c(p, q), ...)
}

#' 正交投影到 span(v)：P = v v^T / (v^T v)，秩 1、det = 0
#' @export
projection_matrix <- function(v) {
  v <- as.numeric(v)
  if (length(v) != 2L || sum(v^2) < 1e-12) {
    stop("projection_matrix(): v 必须是非零二维向量", call. = FALSE)
  }
  homogeneous_matrix(A = outer(v, v) / sum(v^2))
}

#' 按「作用先后」组合齐次矩阵：rm_compose(m1, m2) = 先 m1 后 m2。
#' v %*% t(m1) %*% t(m2) = v %*% t(m2 %*% m1)，故复合写成右乘累积。
#' @export
rm_compose <- function(...) {
  ms <- lapply(list(...), .rm_as_homogeneous)
  if (!length(ms)) return(diag(3))
  Reduce(function(acc, m) m %*% acc, ms[-1L], init = ms[[1L]])
}

## ---- 动画入口 ----

#' 逐帧把 M(f) = (1-f)I + f*A 作用到整组图元
#' @export
apply_matrix <- function(obj, A, run_time = 2, rate = rate_smooth,
                         flatten_tol = 1e-3, w_guard = 1e-3) {
  ## 4x4 交给三维齐次层；下面的 2x2 / 3x3 路径保持原样，逐点不变。
  if (identical(as.integer(dim(as.matrix(A))), c(4L, 4L))) {
    return(apply_matrix3d(obj, A, run_time, rate, flatten_tol, w_guard))
  }
  m <- .rm_as_homogeneous(A)
  ## 插值路径上只要有一帧是奇异的，那一帧的图形就会塌掉（整组缩成一点/一条线）。
  ## 仿射路径也会：A = -I（旋转 180°）在 f = 0.5 处 M = 0。所以两条路都要查，
  ## 只是说法不同——射影路径是「不连续」，仿射路径是「塌缩」。
  fs <- seq(0, 1, length.out = 21)
  ds <- vapply(fs, function(f) det((1 - f) * diag(3) + f * m), numeric(1))
  if (any(abs(ds) < 1e-8)) {
    if (.rm_is_affine_m(m)) {
      warning(sprintf(paste("apply_matrix(): 插值路径在 f≈%.2f 处经过奇异矩阵，",
                            "那一帧图形会塌缩成一点或一条线"),
                      fs[which.min(abs(ds))]), call. = FALSE)
    } else {
      warning("apply_matrix(): 插值路径经过奇异齐次矩阵，画面可能不连续", call. = FALSE)
    }
  }
  .rm_new_anim("matrix", .rm_as_objects(obj), run_time, rate,
               intro = FALSE, matrix = m,
               flatten_tol = flatten_tol, w_guard = w_guard)
}

#' 逆变换（2x2 或 3x3 齐次均可）
#' @export
apply_inverse <- function(obj, A, run_time = 2, rate = rate_smooth, ...) {
  if (identical(as.integer(dim(as.matrix(A))), c(4L, 4L))) {
    return(apply_inverse3d(obj, A, run_time, rate, ...))
  }
  m <- .rm_as_homogeneous(A)
  if (abs(det(m)) < 1e-9) {
    stop("apply_inverse(): 矩阵奇异，不存在逆变换", call. = FALSE)
  }
  apply_matrix(obj, solve(m), run_time, rate, ...)
}

#' 绕任意点旋转（about 非零时用到齐次平移部）
#' @export
rotate_group <- function(obj, angle, about = c(0, 0), run_time = 1.5,
                         rate = rate_smooth) {
  apply_matrix(obj, .rm_rotate_m(angle, about), run_time, rate)
}

#' 纯平移的糖：等价于 apply_matrix(obj, translation_matrix(dx, dy))
#' @export
shift_group <- function(obj, dx = 0, dy = 0, run_time = 1.5,
                        rate = rate_smooth) {
  apply_matrix(obj, translation_matrix(dx, dy), run_time, rate)
}

## ---- prepare / sample ----

.rm_anim_prepare.rm_anim_matrix <- function(a, states) {
  a$states <- states
  a$affine <- .rm_is_affine_m(a$matrix)
  if (!a$affine) {
    ## 射影路径每帧都要重建折线，展平只做一次
    a$base_polys <- lapply(states, function(s) {
      .rm_flatten(s$curves, s$path_id, a$flatten_tol)
    })
    ## 逐条子路径检查 w：既看顶点是否贴近消失线，也看线段是否跨过它
    infos <- unlist(lapply(a$base_polys, function(polys) {
      lapply(polys, function(P) (cbind(P[, 1], P[, 2], 1) %*% t(a$matrix))[, 3])
    }), recursive = FALSE)
    wmin <- if (length(infos)) min(vapply(infos, function(w) min(abs(w)), numeric(1))) else Inf
    ncross <- if (length(infos)) {
      sum(vapply(infos, function(w) {
        if (length(w) < 2L) return(0)
        sum(w[-length(w)] * w[-1L] < 0)
      }, numeric(1)))
    } else 0
    if (wmin < a$w_guard || ncross > 0) {
      warning(sprintf("apply_matrix(): 消失线穿过图形（%d 条线段跨越），已断开子路径；建议减小 w 或把消失线移出画面",
                      as.integer(ncross)), call. = FALSE)
    }
    a$final <- Map(function(s, bp) {
      .rm_apply_homogeneous_state(s, a$matrix, bp, a$flatten_tol, a$w_guard)
    }, states, a$base_polys)
  } else {
    a$final <- lapply(states, function(s) .rm_apply_homogeneous_state(s, a$matrix))
  }
  a
}

.rm_anim_sample.rm_anim_matrix <- function(a, tau) {
  f <- .rm_alpha(tau, a$run_time, a$rate)
  ## a$matrix 已归一化到 m[3,3]=1，故 M(f)[3,3] 恒为 1
  m <- (1 - f) * diag(3) + f * a$matrix
  if (a$affine) {
    lapply(a$states, function(s) .rm_apply_homogeneous_state(s, m))
  } else {
    Map(function(s, bp) {
      .rm_apply_homogeneous_state(s, m, bp, a$flatten_tol, a$w_guard)
    }, a$states, a$base_polys)
  }
}
