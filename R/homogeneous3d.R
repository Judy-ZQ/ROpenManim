## 三维齐次变换层：4x4 矩阵作用于 (x, y, z, 1)。
## 与 3x3 齐次层完全平行，但独立实现，二维路径一字不动
## （教材六段动画的 2x2 / 3x3 行为必须逐点不变）。
##
## 约定：v = (x, y, z, 1)，变换写成 v %*% t(m)。
##   m = [ A  b ]     A = 3x3 线性部（列向量意义下的变换矩阵）
##       [ w  1 ]     b = 平移，位于 m 第四列的前三项
##                    w = 射影部，w_v = 1 + w . (x,y,z)
## 射影下 (x',y',z') = (A(x,y,z) + b) / w_v。
## 直线仍映成直线，但三次贝塞尔不再保形（变成有理曲线），
## 因此射影分支必须先把曲线展平成折线，只对折线顶点做透视除法。

## ---- 规范化 ----

.rm4_as_homogeneous <- function(A) {
  m <- as.matrix(A)
  if (!is.numeric(m) || any(!is.finite(m))) {
    stop("apply_matrix3d(): 矩阵必须是有限数值", call. = FALSE)
  }
  if (!identical(as.integer(dim(m)), c(4L, 4L))) {
    stop("apply_matrix3d(): A 必须是 4x4 齐次矩阵", call. = FALSE)
  }
  ## 齐次矩阵差一个非零标量倍表示同一个射影变换，但插值路径
  ## M(f)=(1-f)I+f*A 依赖代表元；统一令 m[4,4]=1，路径才唯一可复现。
  k <- m[4, 4]
  if (abs(k) < 1e-9) {
    stop("apply_matrix3d(): 齐次矩阵 m[4,4] 不能为 0（原点会被映到无穷远）",
         call. = FALSE)
  }
  m / k
}

.rm4_is_affine <- function(m, tol = 1e-9) {
  all(abs(m[4, 1:3]) < tol) && abs(m[4, 4] - 1) < tol
}

## 保证折线至少有三列；二维对象被误传进来时补 z=0，不越界
.rm4_xyz <- function(P) {
  P <- as.matrix(P)
  if (ncol(P) < 3L) {
    P <- cbind(P, matrix(0, nrow(P), 3L - ncol(P)))
  }
  P[, 1:3, drop = FALSE]
}

## ---- 仿射 / 射影两条求值路径 ----

.rm4_apply_affine <- function(curves, m) {
  lapply(curves, function(cv) {
    XYZ <- cbind(.rm4_xyz(cv), 1) %*% t(m)
    cbind(XYZ[, 1], XYZ[, 2], XYZ[, 3])
  })
}

.rm4_homogeneous_xyz <- function(P, m, w_guard = 1e-3) {
  H <- cbind(.rm4_xyz(P), 1) %*% t(m)
  w <- H[, 4]
  bad <- which(abs(w) < w_guard)
  if (length(bad)) w[bad] <- ifelse(w[bad] >= 0, 1, -1) * w_guard
  cbind(H[, 1] / w, H[, 2] / w, H[, 3] / w)
}

## 消失面 w_v=0 从折线段内部穿过时，射影把该线段映成两条不相连的射线。
## 只检测端点看不出来，会连出一条横跨整屏的假直线；按 w 变号把折线拆开。
.rm4_split_vanishing <- function(P, m, w_guard = 1e-3) {
  P <- .rm4_xyz(P)
  H <- cbind(P, 1) %*% t(m)
  w <- H[, 4]
  n <- nrow(P)
  if (n < 2L) return(list(P))
  out <- list(); cur <- P[1, , drop = FALSE]
  for (i in seq_len(n - 1L)) {
    wi <- w[i]; wj <- w[i + 1L]
    if (wi * wj < 0) {
      t0 <- wi / (wi - wj)
      dt <- min(t0, 1 - t0, w_guard / abs(wj - wi))
      d <- P[i + 1L, , drop = FALSE] - P[i, , drop = FALSE]
      Pa <- P[i, , drop = FALSE] + (t0 - dt) * d
      Pb <- P[i, , drop = FALSE] + (t0 + dt) * d
      cur <- rbind(cur, Pa)
      if (nrow(cur) >= 2L) out[[length(out) + 1L]] <- cur
      cur <- Pb
    }
    ## 无论是否跨越，该段终点都要补进当前子路径（否则断点后只剩一个点）
    cur <- rbind(cur, P[i + 1L, , drop = FALSE])
  }
  if (nrow(cur) >= 2L) out[[length(out) + 1L]] <- cur
  out
}

## 把一个纯数据 state 用 4x4 齐次矩阵作用。
## base_polys 是 prepare 阶段预先展平好的折线，逐帧复用，避免重复细分。
.rm4_apply_homogeneous_state <- function(s, m, base_polys = NULL,
                                          flatten_tol = 1e-3, w_guard = 1e-3) {
  if (.rm4_is_affine(m)) {
    ## 快路径：仿射与贝塞尔的凸组合可交换，直接变换控制点，点数不变
    s$curves <- .rm4_apply_affine(s$curves, m)
    if (!is.null(s$polys)) {
      s$polys <- lapply(s$polys, function(P) {
        H <- cbind(.rm4_xyz(P), 1) %*% t(m)
        cbind(H[, 1], H[, 2], H[, 3])
      })
    }
    return(s)
  }
  ## 射影路径：由展平折线的顶点重建，curves / path_id / polys 三者必须同步
  bp <- if (is.null(base_polys)) {
    lapply(.rm_flatten(s$curves, s$path_id, flatten_tol), .rm4_xyz)
  } else {
    lapply(base_polys, .rm4_xyz)
  }
  out_p <- unlist(lapply(bp, function(P) {
    lapply(.rm4_split_vanishing(P, m, w_guard), function(S) {
      .rm4_homogeneous_xyz(S, m, w_guard)
    })
  }), recursive = FALSE)
  z <- .rm_curves_from_polys(out_p)
  s$curves <- z$curves
  s$path_id <- z$path_id
  s$polys <- out_p
  s
}

## ---- 4x4 齐次矩阵构造器 ----

#' 通用 4x4 齐次矩阵：m = [A b; w 1]
#' @export
homogeneous4_matrix <- function(A = diag(3), b = c(0, 0, 0), w = c(0, 0, 0)) {
  A <- as.matrix(A); b <- as.numeric(b); w <- as.numeric(w)
  if (nrow(A) != 3L || ncol(A) != 3L || length(b) != 3L || length(w) != 3L) {
    stop("homogeneous4_matrix(): 需要 3x3 的 A 与长度 3 的 b / w", call. = FALSE)
  }
  rbind(c(A[1, ], b[1]),
        c(A[2, ], b[2]),
        c(A[3, ], b[3]),
        c(w,       1))
}

#' 平移：x' = x + dx, y' = y + dy, z' = z + dz
#' @export
translation4_matrix <- function(dx = 0, dy = 0, dz = 0) {
  homogeneous4_matrix(b = c(dx, dy, dz))
}

#' 仿射：v' = A v + b
#' @export
affine4_matrix <- function(A, b = c(0, 0, 0)) {
  homogeneous4_matrix(A = A, b = b)
}

#' 绕任意轴旋转（Rodrigues）。axis 可取 "x"/"y"/"z" 或任意三维向量。
#' 线性部是列向量意义下的旋转矩阵 R；因为约定是 v %*% t(m)，
#' 而 (v %*% t(m))_j = sum_k m[j,k] v_k = (m v)_j，故 m 左上角直接放 R。
#' @export
rotation4_matrix <- function(axis = "z", angle = 0) {
  u <- if (is.character(axis) && length(axis) == 1L) {
    switch(tolower(axis),
           x = c(1, 0, 0), y = c(0, 1, 0), z = c(0, 0, 1),
           stop("rotation4_matrix(): axis 只能是 x / y / z 或三维向量",
                call. = FALSE))
  } else {
    as.numeric(axis)
  }
  if (length(u) != 3L || any(!is.finite(u)) || sum(u^2) < 1e-12) {
    stop("rotation4_matrix(): axis 必须是非零三维向量", call. = FALSE)
  }
  u <- u / sqrt(sum(u^2))
  ca <- cos(angle); sa <- sin(angle)
  ## K v = u x v
  K <- matrix(c(0, -u[3], u[2],
                u[3], 0, -u[1],
                -u[2], u[1], 0), 3, 3, byrow = TRUE)
  R <- ca * diag(3) + (1 - ca) * outer(u, u) + sa * K
  homogeneous4_matrix(A = R)
}

#' 正交投影：给 n（法向）投到过原点的平面 n^perp（秩 2），
#' 给 v（方向）投到直线 span(v)（秩 1）。两者都可作为 4x4 齐次矩阵动画。
#' @export
projection4_matrix <- function(n = c(0, 0, 1), v = NULL) {
  if (!is.null(v)) {
    v <- as.numeric(v)
    if (length(v) != 3L || sum(v^2) < 1e-12) {
      stop("projection4_matrix(): v 必须是非零三维向量", call. = FALSE)
    }
    P <- outer(v, v) / sum(v^2)
  } else {
    n <- as.numeric(n)
    if (length(n) != 3L || sum(n^2) < 1e-12) {
      stop("projection4_matrix(): n 必须是非零三维向量", call. = FALSE)
    }
    P <- diag(3) - outer(n, n) / sum(n^2)
  }
  homogeneous4_matrix(A = P)
}

#' 三维射影：w_v = 1 + p*x + q*y + r*z，可再叠加 A / b
#' @export
perspective4_matrix <- function(p = 0, q = 0, r = 0, ...) {
  homogeneous4_matrix(w = c(p, q, r), ...)
}

#' 按「作用先后」组合 4x4 齐次矩阵：rm_compose4(m1, m2) = 先 m1 后 m2。
#' @export
rm_compose4 <- function(...) {
  ms <- lapply(list(...), .rm4_as_homogeneous)
  if (!length(ms)) return(diag(4))
  Reduce(function(acc, m) m %*% acc, ms[-1L], init = ms[[1L]])
}

## ---- 动画入口 ----

#' 逐帧把 M(f) = (1-f)I + f*A 作用到三维图元组（A 为 4x4 齐次矩阵）
#' @export
apply_matrix3d <- function(obj, A, run_time = 2, rate = rate_smooth,
                           flatten_tol = 1e-3, w_guard = 1e-3) {
  m <- .rm4_as_homogeneous(A)
  if (!.rm4_is_affine(m)) {
    fs <- seq(0, 1, length.out = 21)
    ds <- vapply(fs, function(f) det((1 - f) * diag(4) + f * m), numeric(1))
    if (any(abs(ds) < 1e-8)) {
      warning("apply_matrix3d(): 插值路径经过奇异齐次矩阵，画面可能不连续",
              call. = FALSE)
    }
  }
  .rm_new_anim("matrix3d", .rm_as_objects(obj), run_time, rate,
               intro = FALSE, matrix = m,
               flatten_tol = flatten_tol, w_guard = w_guard)
}

#' 逆变换（4x4 齐次）
#' @export
apply_inverse3d <- function(obj, A, run_time = 2, rate = rate_smooth, ...) {
  m <- .rm4_as_homogeneous(A)
  if (abs(det(m)) < 1e-9) {
    stop("apply_inverse3d(): 矩阵奇异，不存在逆变换", call. = FALSE)
  }
  apply_matrix3d(obj, solve(m), run_time, rate, ...)
}

#' 绕任意点、任意轴旋转（about 非零时用到齐次平移部）
#' @export
rotate3d_group <- function(obj, axis = "z", angle = pi / 2,
                           about = c(0, 0, 0), run_time = 1.5,
                           rate = rate_smooth) {
  if (length(about) != 3L) {
    stop("rotate3d_group(): about 必须是三维点", call. = FALSE)
  }
  m <- rm_compose4(
    translation4_matrix(-about[1], -about[2], -about[3]),
    rotation4_matrix(axis, angle),
    translation4_matrix(about[1], about[2], about[3])
  )
  apply_matrix3d(obj, m, run_time, rate)
}

#' 三维平移的糖
#' @export
shift3d_group <- function(obj, dx = 0, dy = 0, dz = 0, run_time = 1.5,
                          rate = rate_smooth) {
  apply_matrix3d(obj, translation4_matrix(dx, dy, dz), run_time, rate)
}

## ---- prepare / sample（S3 分派到 rm_anim_matrix3d）----

.rm_anim_prepare.rm_anim_matrix3d <- function(a, states) {
  a$states <- states
  a$affine <- .rm4_is_affine(a$matrix)
  if (!a$affine) {
    ## 射影路径每帧都要重建折线，展平只做一次
    a$base_polys <- lapply(states, function(s) {
      lapply(.rm_flatten(s$curves, s$path_id, a$flatten_tol), .rm4_xyz)
    })
    infos <- unlist(lapply(a$base_polys, function(polys) {
      lapply(polys, function(P) (cbind(P, 1) %*% t(a$matrix))[, 4])
    }), recursive = FALSE)
    wmin <- if (length(infos)) {
      min(vapply(infos, function(w) min(abs(w)), numeric(1)))
    } else Inf
    ncross <- if (length(infos)) {
      sum(vapply(infos, function(w) {
        if (length(w) < 2L) return(0)
        sum(w[-length(w)] * w[-1L] < 0)
      }, numeric(1)))
    } else 0
    if (wmin < a$w_guard || ncross > 0) {
      warning(sprintf("apply_matrix3d(): 消失面穿过图形（%d 条线段跨越），已断开子路径；建议减小 w 或把消失面移出画面",
                      as.integer(ncross)), call. = FALSE)
    }
    a$final <- Map(function(s, bp) {
      .rm4_apply_homogeneous_state(s, a$matrix, bp, a$flatten_tol, a$w_guard)
    }, states, a$base_polys)
  } else {
    a$final <- lapply(states, function(s) .rm4_apply_homogeneous_state(s, a$matrix))
  }
  a
}

.rm_anim_sample.rm_anim_matrix3d <- function(a, tau) {
  f <- .rm_alpha(tau, a$run_time, a$rate)
  ## a$matrix 已归一化到 m[4,4]=1，故 M(f)[4,4] 恒为 1
  m <- (1 - f) * diag(4) + f * a$matrix
  if (a$affine) {
    lapply(a$states, function(s) .rm4_apply_homogeneous_state(s, m))
  } else {
    Map(function(s, bp) {
      .rm4_apply_homogeneous_state(s, m, bp, a$flatten_tol, a$w_guard)
    }, a$states, a$base_polys)
  }
}
