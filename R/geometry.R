## 几何内核：三次贝塞尔、展平、弧长、截断、重采样、仿射
## 约定：场景坐标单位为 Manim 的 "unit"；一帧高 8 unit，16:9 -> 宽 14.2222 unit。

`%||%` <- function(a, b) if (is.null(a)) b else a

#' @export
rm_frame_height <- 8
#' @export
rm_aspect <- 16 / 9

## ---- 点与直线 ---- 

## 点到直线 ab 的距离（向量化第二个参数以外）
.rm_dist_line <- function(p, a, b) {
  ab <- b - a
  den <- sqrt(sum(ab^2))
  if (den < 1e-12) return(sqrt(sum((p - a)^2)))
  abs(ab[1] * (p[2] - a[2]) - ab[2] * (p[1] - a[1])) / den
}

## ---- 三次贝塞尔 ---- 

.rm_cubic_at <- function(cv, t) {
  u <- 1 - t
  u^3 * cv[1, ] + 3 * u^2 * t * cv[2, ] + 3 * u * t^2 * cv[3, ] + t^3 * cv[4, ]
}

.rm_cubic_split <- function(cv, t = 0.5) {
  p0 <- cv[1, ]; p1 <- cv[2, ]; p2 <- cv[3, ]; p3 <- cv[4, ]
  a <- p0 + t * (p1 - p0)
  b <- p1 + t * (p2 - p1)
  c <- p2 + t * (p3 - p2)
  d <- a + t * (b - a)
  e <- b + t * (c - b)
  f <- d + t * (e - d)
  list(rbind(p0, a, d, f), rbind(f, e, c, p3))
}

## 自适应展平：按控制点到弦的距离判据细分
.rm_cubic_flatten <- function(cv, tol = 2e-3, depth = 0L) {
  d <- max(.rm_dist_line(cv[2, ], cv[1, ], cv[4, ]),
           .rm_dist_line(cv[3, ], cv[1, ], cv[4, ]))
  if (d <= tol || depth >= 10L) return(rbind(cv[1, ], cv[4, ]))
  sp <- .rm_cubic_split(cv, 0.5)
  rbind(.rm_cubic_flatten(sp[[1]], tol, depth + 1L),
        .rm_cubic_flatten(sp[[2]], tol, depth + 1L)[-1L, , drop = FALSE])
}

## 折线 <-> 曲线：每一段当成退化的三次贝塞尔（控制点按 1/3、2/3 放置）
.rm_line_curve <- function(p, q) {
  if (length(p) < 3L) p <- c(p[1], p[2], 0)
  if (length(q) < 3L) q <- c(q[1], q[2], 0)
  rbind(p, p + (q - p) / 3, p + 2 * (q - p) / 3, q)
}

## 由若干折线构造对象（每条折线是一个子路径）
.rm_curves_from_polys <- function(polys) {
  curves <- list(); pid <- integer(0)
  for (k in seq_along(polys)) {
    P <- polys[[k]]
    if (nrow(P) < 2L) next
    for (i in seq_len(nrow(P) - 1L)) {
      curves[[length(curves) + 1L]] <- .rm_line_curve(P[i, ], P[i + 1L, ])
      pid <- c(pid, k)
    }
  }
  list(curves = curves, path_id = pid)
}

## ---- 弧长与重采样 ---- 

.rm_cumlen <- function(P) {
  if (nrow(P) < 2L) return(c(0, 0))
  c(0, cumsum(sqrt(rowSums(diff(P)^2))))
}

## 按弧长等分重采样为 n 个点（n >= 2）
.rm_resample <- function(P, n) {
  if (nrow(P) < 2L) return(matrix(rep(P[1, ], n), ncol = 2, byrow = TRUE))
  s <- .rm_cumlen(P); L <- s[length(s)]
  if (L < 1e-12) return(matrix(rep(P[1, ], n), ncol = 2, byrow = TRUE))
  target <- seq(0, L, length.out = n)
  idx <- findInterval(target, s, all.inside = TRUE)
  idx <- pmin(idx, nrow(P) - 1L)
  w <- (target - s[idx]) / pmax(s[idx + 1L] - s[idx], 1e-12)
  P[idx, , drop = FALSE] + w * (P[idx + 1L, , drop = FALSE] - P[idx, , drop = FALSE])
}

## ---- 对象层面的运算：展平、包围盒、截断 ---- 

.rm_flatten <- function(curves, path_id, tol = 2e-3) {
  if (!length(curves)) return(list())
  lapply(split(seq_along(curves), factor(path_id, levels = unique(path_id))), function(ii) {
    pts <- .rm_cubic_flatten(curves[[ii[1]]], tol)
    if (length(ii) > 1L) {
      for (j in ii[-1L]) pts <- rbind(pts, .rm_cubic_flatten(curves[[j]], tol)[-1L, , drop = FALSE])
    }
    pts
  })
}

.rm_bbox <- function(curves, path_id, tol = 2e-3) {
  polys <- .rm_flatten(curves, path_id, tol)
  if (!length(polys)) return(c(xmin = 0, ymin = 0, xmax = 0, ymax = 0))
  P <- do.call(rbind, polys)
  c(xmin = min(P[, 1]), ymin = min(P[, 2]), xmax = max(P[, 1]), ymax = max(P[, 2]))
}

## 按累计弧长截断（Create / DrawBorderThenFill 的内核）
.rm_trim <- function(curves, path_id, frac) {
  if (frac >= 1 - 1e-9) {
    return(list(curves = curves, path_id = path_id,
                polys = .rm_flatten(curves, path_id, tol = 1e-3)))
  }
  if (frac <= 1e-9) return(list(curves = list(), path_id = integer(0)))
  polys <- .rm_flatten(curves, path_id, tol = 1e-3)
  lens <- vapply(polys, function(P) { s <- .rm_cumlen(P); s[length(s)] }, numeric(1))
  total <- sum(lens)
  if (total < 1e-12) return(list(curves = list(), path_id = integer(0)))
  want <- frac * total
  out_p <- list(); acc <- 0
  for (k in seq_along(polys)) {
    if (acc >= want) break
    P <- polys[[k]]; L <- lens[k]
    if (acc + L <= want) {
      out_p[[length(out_p) + 1L]] <- P
      acc <- acc + L
    } else {
      r <- (want - acc) / L
      s <- .rm_cumlen(P); target <- r * s[length(s)]
      i <- max(1L, findInterval(target, s, all.inside = TRUE))
      i <- min(i, nrow(P) - 1L)
      w <- (target - s[i]) / max(s[i + 1L] - s[i], 1e-12)
      Pcut <- rbind(P[seq_len(i), , drop = FALSE], P[i, , drop = FALSE] + w * (P[i + 1L, , drop = FALSE] - P[i, , drop = FALSE]))
      out_p[[length(out_p) + 1L]] <- Pcut
      acc <- want
      break
    }
  }
  z <- .rm_curves_from_polys(out_p)
  z$polys <- out_p
  z
}

## ---- 仿射 ---- 

.rm_apply_affine <- function(curves, m) {
  lapply(curves, function(cv) {
    XY <- cbind(cv[, 1], cv[, 2], 1) %*% t(m)
    cbind(XY[, 1], XY[, 2], cv[, 3])
  })
}

.rm_rotate_m <- function(angle, about = c(0, 0)) {
  ca <- cos(angle); sa <- sin(angle)
  ## 约定：v %*% t(m)，平移分量在 m 的第三列
  tx <- about[1] - ca * about[1] + sa * about[2]
  ty <- about[2] - sa * about[1] - ca * about[2]
  matrix(c(ca, -sa, tx, sa, ca, ty, 0, 0, 1), nrow = 3, byrow = TRUE)
}

## ---- 齐次 / 射影 ----
## 约定：v = (x, y, 1)，变换写成 v %*% t(m)（等价于列向量 m %*% v）。
##   m = [ A  b ]     A = 2x2 线性部；b = 平移，位于 m 第三列的前两项
##       [ w  1 ]     w = 射影部，w_v = w[1]*x + w[2]*y + 1
## 射影变换下 (x', y') = (A(x,y) + b) / w_v。直线仍映成直线，但三次贝塞尔
## 不再保形（变成有理曲线），所以必须先展平成折线、只对折线顶点做透视除法：
## 折线段是直线，顶点精确则整段精确，不需要沿曲线再采样。

.rm_is_affine_m <- function(m, tol = 1e-9) {
  abs(m[3, 1]) < tol && abs(m[3, 2]) < tol && abs(m[3, 3] - 1) < tol
}

## 逐点齐次变换 + 透视除法；消失线附近按符号钳制，避免 Inf / NaN 打穿后端
.rm_homogeneous_xy <- function(XY, m, w_guard = 1e-3) {
  H <- cbind(XY[, 1], XY[, 2], 1) %*% t(m)
  w <- H[, 3]
  bad <- which(abs(w) < w_guard)
  if (length(bad)) w[bad] <- ifelse(w[bad] >= 0, 1, -1) * w_guard
  cbind(H[, 1] / w, H[, 2] / w)
}

## 消失线 w_v=0 从折线段内部穿过时，射影把这一条线段映成两条不相连的射线。
## 只检测端点看不出来，会连出一条横跨整屏的假直线；这里在交点两侧各留一个点，
## 把折线拆成独立子路径（backend 按 path_id 分开描边/填充）。
.rm_split_vanishing <- function(P, m, w_guard = 1e-3) {
  H <- cbind(P[, 1], P[, 2], 1) %*% t(m)
  w <- H[, 3]
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
    ## 无论是否跨越，该段的终点都要补进当前子路径（否则断点后的第二段只剩一个点）
    cur <- rbind(cur, P[i + 1L, , drop = FALSE])
  }
  if (nrow(cur) >= 2L) out[[length(out) + 1L]] <- cur
  out
}

## 把一个纯数据 state 用 3x3 齐次矩阵作用。
## base_polys 是 prepare 阶段预先展平好的折线，逐帧复用，避免重复细分。
.rm_apply_homogeneous_state <- function(s, m, base_polys = NULL,
                                        flatten_tol = 1e-3, w_guard = 1e-3) {
  if (.rm_is_affine_m(m)) {
    ## 快路径：仿射与贝塞尔的凸组合可交换，直接变换控制点即可，点数不变
    s$curves <- .rm_apply_affine(s$curves, m)
    if (!is.null(s$polys)) {
      s$polys <- lapply(s$polys, function(P) {
        XY <- cbind(P[, 1], P[, 2], 1) %*% t(m)
        Q <- P
        Q[, 1] <- XY[, 1]; Q[, 2] <- XY[, 2]
        Q
      })
    }
    return(s)
  }
  ## 射影路径：由展平折线的顶点重建，curves / path_id / polys 三者必须同步
  bp <- if (is.null(base_polys)) {
    .rm_flatten(s$curves, s$path_id, flatten_tol)
  } else {
    base_polys
  }
  out_p <- unlist(lapply(bp, function(P) {
    lapply(.rm_split_vanishing(P, m, w_guard), function(S) {
      XY <- .rm_homogeneous_xy(S[, 1:2, drop = FALSE], m, w_guard)
      if (ncol(S) >= 3L) {
        Q <- S
        Q[, 1] <- XY[, 1]; Q[, 2] <- XY[, 2]
        Q
      } else {
        cbind(XY[, 1], XY[, 2])
      }
    })
  }), recursive = FALSE)
  z <- .rm_curves_from_polys(out_p)
  s$curves <- z$curves
  s$path_id <- z$path_id
  s$polys <- out_p
  s
}

## ---- 颜色 ---- 

.rm_is_colour <- function(x) is.character(x) && length(x) == 1L

## 两个 hex 颜色线性插值（用于 Transform 的颜色过渡）
.rm_colour_lerp <- function(a, b, t) {
  if (is.na(a) || is.na(b)) return(if (t < 0.5) a else b)
  ca <- grDevices::col2rgb(a) / 255
  cb <- grDevices::col2rgb(b) / 255
  grDevices::rgb(ca[1] + t * (cb[1] - ca[1]),
                 ca[2] + t * (cb[2] - ca[2]),
                 ca[3] + t * (cb[3] - ca[3]))
}
