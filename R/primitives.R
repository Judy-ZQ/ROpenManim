## P1 图元层：面向线性代数机理动画的 23 个新图元
## 已有 8 个：line / circle / rect / square / polygon / arrow / dot / vgroup
## 约定：所有图元都是「若干条三次贝塞尔子路径」，因此 apply_matrix() 能整体变换它们；
##       由多个独立笔画组成的图元返回 vgroup，scene$add() 会递归摊平。
## 单位：场景 unit（帧高 8）。颜色一律 hex，线宽为 1080p 下的像素。

## 由折线构造单个图元（closed=TRUE 时自动补回首点）
.rm_poly_mobject <- function(P, style = NULL, closed = FALSE, name = "poly") {
  P <- as.matrix(P)
  if (ncol(P) < 3L) P <- cbind(P, 0)
  if (closed && nrow(P) >= 2L && !all(P[nrow(P), 1:2] == P[1, 1:2])) {
    P <- rbind(P, P[1, , drop = FALSE])
  }
  z <- .rm_curves_from_polys(list(P))
  rm_mobject$new(z$curves, z$path_id, style, name = name)
}

.rm_stroke <- function(color, width = 4) list(stroke = color, stroke_width = width)
.rm_fill <- function(color, opacity = 0.35, stroke = NA_character_, width = 2) {
  list(fill = color, fill_opacity = opacity, stroke = stroke, stroke_width = width,
       rule = "winding")
}

## 把若干图元打包成 group（保持 vgroup 的 class）
.rm_group <- function(parts) do.call(vgroup, parts)

## ---- 1. 圆弧 / 2. 扇形 / 3. 椭圆 ----

#' @export
arc_obj <- function(center = c(0, 0), r = 1, start_angle = 0, angle = pi / 2,
                    color = "#FFFFFF", width = 4, n_seg = NULL, style = NULL) {
  n <- n_seg %||% max(12L, ceiling(abs(angle) / (pi / 48)))
  a <- seq(start_angle, start_angle + angle, length.out = n + 1L)
  P <- cbind(center[1] + r * cos(a), center[2] + r * sin(a))
  .rm_poly_mobject(P, style %||% .rm_stroke(color, width), FALSE, "arc")
}

#' @export
sector_obj <- function(center = c(0, 0), r = 1, start_angle = 0, angle = pi / 2,
                       fill = "#58C4DD", opacity = 0.35,
                       color = NA_character_, width = 2, n_seg = NULL) {
  n <- n_seg %||% max(12L, ceiling(abs(angle) / (pi / 48)))
  a <- seq(start_angle, start_angle + angle, length.out = n + 1L)
  P <- rbind(c(center[1], center[2]),
             cbind(center[1] + r * cos(a), center[2] + r * sin(a)),
             c(center[1], center[2]))
  .rm_poly_mobject(P, .rm_fill(fill, opacity, color, width), FALSE, "sector")
}

#' @export
ellipse_obj <- function(center = c(0, 0), rx = 1, ry = 0.6, angle = 0,
                        color = "#58C4DD", width = 4, n = 180, style = NULL) {
  t <- seq(0, 2 * pi, length.out = n)
  P <- cbind(rx * cos(t), ry * sin(t))
  R <- matrix(c(cos(angle), -sin(angle), sin(angle), cos(angle)), 2, 2, byrow = TRUE)
  P <- P %*% t(R)
  P[, 1] <- P[, 1] + center[1]; P[, 2] <- P[, 2] + center[2]
  .rm_poly_mobject(P, style %||% .rm_stroke(color, width), TRUE, "ellipse")
}

## ---- 4. 三角形 / 5. 花括号 / 6. 双箭头 ----

#' @export
triangle_obj <- function(p1, p2, p3, color = "#FFFFFF", width = 4,
                         fill = NULL, opacity = 0.3, style = NULL) {
  P <- rbind(p1, p2, p3)
  st <- style %||% (if (is.null(fill)) .rm_stroke(color, width)
                    else .rm_fill(fill, opacity, color, width))
  .rm_poly_mobject(P, st, TRUE, "triangle")
}

#' @export
brace_obj <- function(p1, p2, amplitude = 0.18, color = "#FFFFFF", width = 3,
                      n = 120, style = NULL) {
  v <- p2 - p1; L <- sqrt(sum(v^2))
  if (L < 1e-9) stop("brace_obj(): p1 与 p2 不能重合", call. = FALSE)
  if (!is.finite(amplitude) || amplitude == 0)
    return(line_obj(p1, p2, style %||% .rm_stroke(color, width)))
  u <- v / L; nr <- c(-u[2], u[1])
  ## 花括号 = 四个圆角：两端外翻的 1/4 圆 + 中间上翘的 1/4 圆（在中点对出尖角）。
  ## h 是波峰高度，按长度比例给：h = amplitude * L，所以长括号更鼓。
  h <- abs(amplitude) * L
  half <- L / 2
  r1 <- h                      # 端头圆角半径
  r2 <- 0.55 * h               # 中间尖角圆角半径
  if (half <= r1 + r2) {       # 括号太短：等比缩小，保证几何不自我交叉
    k <- half / (r1 + r2) * 0.98
    r1 <- r1 * k; r2 <- r2 * k; h <- r1
  }
  ## 左半边：s ∈ [0, half]，返回 (s, o) 两条等长向量，o 以 h 为单位
  th1 <- seq(pi, pi / 2, length.out = max(8L, n %/% 6))
  th2 <- seq(3 * pi / 2, 2 * pi, length.out = max(8L, n %/% 6))
  sL <- c(r1 + r1 * cos(th1), r1, half - r2, (half - r2) + r2 * cos(th2))
  oL <- c(r1 * sin(th1), h, h, h + r2 + r2 * sin(th2))
  keep <- c(TRUE, diff(sL) > 1e-9 | diff(oL) != 0)
  sL <- sL[keep]; oL <- oL[keep]
  s <- c(sL, rev(L - sL)); o <- c(oL, rev(oL))
  P <- cbind(p1[1] + s * u[1] + sign(amplitude) * o * nr[1],
             p1[2] + s * u[2] + sign(amplitude) * o * nr[2])
  .rm_poly_mobject(P, style %||% .rm_stroke(color, width), FALSE, "brace")
}

#' @export
double_arrow_obj <- function(p1, p2, color = "#FFFFFF", width = 4, head = 0.22) {
  .rm_group(list(
    arrow_obj(p1, p2, head = head, color = color, width = width),
    arrow_obj(p2, p1, head = head, color = color, width = width)
  ))
}

## ---- 7. 虚线 / 8. 角标记 / 9. 直角标记 ----

#' @export
dashed_line_obj <- function(p1, p2, dash = 0.16, gap = 0.12,
                            color = "#7D8590", width = 3) {
  v <- p2 - p1; L <- sqrt(sum(v^2))
  if (L < 1e-9) return(line_obj(p1, p1, .rm_stroke(color, width)))
  u <- v / L
  pos <- seq(0, L, by = dash + gap)
  .rm_group(lapply(pos, function(d) {
    line_obj(p1 + d * u, p1 + min(d + dash, L) * u, .rm_stroke(color, width))
  }))
}

#' @export
angle_obj <- function(vertex, p1, p2, r = 0.5, color = "#FFFFFF", width = 3) {
  a1 <- atan2(p1[2] - vertex[2], p1[1] - vertex[1])
  a2 <- atan2(p2[2] - vertex[2], p2[1] - vertex[1])
  da <- a2 - a1
  while (da > pi) da <- da - 2 * pi
  while (da < -pi) da <- da + 2 * pi
  arc_obj(vertex, r, a1, da, color = color, width = width)
}

#' @export
right_angle_obj <- function(vertex, u, v, size = 0.24,
                            color = "#FFFFFF", width = 3) {
  u <- u / sqrt(sum(u^2)); v <- v / sqrt(sum(v^2))
  P <- rbind(vertex + size * u, vertex + size * u + size * v, vertex + size * v)
  .rm_poly_mobject(P, .rm_stroke(color, width), FALSE, "right_angle")
}

## ---- 10. 数轴 / 11. 网格 ----

#' @export
number_line_obj <- function(xlim = c(-3, 3), y = 0, at = NULL, step = 1,
                            color = "#FFFFFF", width = 3,
                            label_size = 26, arrows = TRUE, tick_size = 0.12) {
  p1 <- c(xlim[1], y); p2 <- c(xlim[2], y)
  parts <- list(if (arrows) arrow_obj(p1, p2, head = 0.2, color = color, width = width)
                else line_obj(p1, p2, .rm_stroke(color, width)))
  vals <- at %||% seq(ceiling(xlim[1] / step) * step, xlim[2], by = step)
  for (v in vals) {
    p <- c(v, y)
    parts[[length(parts) + 1L]] <- line_obj(
      p + c(0, -tick_size), p + c(0, tick_size), .rm_stroke(color, 3))
    t <- text(format(v, trim = TRUE, scientific = FALSE), size = label_size, color = color)
    t$move_to(v, y - 0.34)
    parts[[length(parts) + 1L]] <- t
  }
  .rm_group(parts)
}

#' @export
grid_obj <- function(xlim = c(-4, 4), ylim = c(-3, 3), step = 1,
                     color = "#3D4653", width = 2, origin_color = NULL,
                     origin_width = 3) {
  parts <- list()
  xs <- seq(xlim[1], xlim[2], by = step)
  ys <- seq(ylim[1], ylim[2], by = step)
  for (x in xs) {
    cl <- if (!is.null(origin_color) && abs(x) < 1e-9) origin_color else color
    wd <- if (!is.null(origin_color) && abs(x) < 1e-9) origin_width else width
    parts[[length(parts) + 1L]] <-
      line_obj(c(x, ylim[1]), c(x, ylim[2]), .rm_stroke(cl, wd))
  }
  for (y in ys) {
    cl <- if (!is.null(origin_color) && abs(y) < 1e-9) origin_color else color
    wd <- if (!is.null(origin_color) && abs(y) < 1e-9) origin_width else width
    parts[[length(parts) + 1L]] <-
      line_obj(c(xlim[1], y), c(xlim[2], y), .rm_stroke(cl, wd))
  }
  .rm_group(parts)
}

## ---- 12. 参数曲线 / 13. 曲线下方面积 / 14. 填充多边形 ----

#' @export
parametric_curve_obj <- function(fun, from = 0, to = 2 * pi, n = 200,
                                 color = "#58C4DD", width = 4,
                                 closed = FALSE, style = NULL) {
  tt <- seq(from, to, length.out = n)
  P <- t(vapply(tt, function(s) as.numeric(fun(s)), numeric(2)))
  .rm_poly_mobject(P, style %||% .rm_stroke(color, width), closed, "param_curve")
}

#' @export
area_under_obj <- function(ax, fun, from = ax$xlim[1], to = ax$xlim[2],
                           n = 200, baseline = 0, fill = "#58C4DD",
                           opacity = 0.3) {
  xv <- seq(from, to, length.out = n)
  yv <- fun(xv)
  ok <- is.finite(yv)
  P <- rbind(ax$c2p(from, baseline)[1, ], ax$c2p(xv[ok], yv[ok]),
             ax$c2p(to, baseline)[1, ])
  .rm_poly_mobject(P, .rm_fill(fill, opacity), TRUE, "area_under")
}

#' @export
polygon_fill_obj <- function(pts, fill = "#58C4DD", opacity = 0.35,
                             color = NA_character_, width = 2) {
  .rm_poly_mobject(pts, .rm_fill(fill, opacity, color, width), TRUE, "filled_polygon")
}

## ---- 15. 带标签向量 / 16. 引线标签 / 17. 矩阵框 ----

#' @export
vector_obj <- function(from = c(0, 0), to = c(1, 0), color = "#58C4DD",
                       width = 5, head = 0.22, label = NULL,
                       label_size = 30, label_offset = 0.28, family = "sans") {
  parts <- list(arrow_obj(from, to, head = head, color = color, width = width))
  if (!is.null(label)) {
    t <- text(label, size = label_size, color = color, family = family)
    mid <- (from + to) / 2
    v <- to - from; nr <- c(-v[2], v[1]); L <- sqrt(sum(nr^2))
    if (L > 1e-9) nr <- nr / L
    t$move_to(mid[1] + label_offset * nr[1], mid[2] + label_offset * nr[2])
    parts[[length(parts) + 1L]] <- t
  }
  .rm_group(parts)
}

#' @export
label_obj <- function(str, at, offset = c(0.8, 0.6), size = 30,
                      color = "#FFFFFF", leader = TRUE, width = 2,
                      family = "sans") {
  p <- at + offset
  t <- text(str, size = size, color = color, family = family)
  t$move_to(p[1], p[2])
  parts <- list(t)
  if (leader) {
    parts[[2L]] <- line_obj(at, p - sign(offset) * 0.18, .rm_stroke(color, width))
  }
  .rm_group(parts)
}

#' @export
matrix_obj <- function(M, x = 0, y = 0, cell_w = 0.78, cell_h = 0.62,
                       color = "#FFFFFF", size = 30, brackets = TRUE,
                       width = 3, digits = 3) {
  M <- as.matrix(M)
  nr <- nrow(M); nc <- ncol(M)
  W <- nc * cell_w; H <- nr * cell_h
  parts <- list()
  fmt <- function(v) {
    s <- format(round(v, digits), trim = TRUE, scientific = FALSE)
    if (identical(s, "0")) "0" else s
  }
  for (i in seq_len(nr)) for (j in seq_len(nc)) {
    t <- text(fmt(M[i, j]), size = size, color = color)
    t$move_to(x - W / 2 + (j - 0.5) * cell_w, y + H / 2 - (i - 0.5) * cell_h)
    parts[[length(parts) + 1L]] <- t
  }
  if (brackets) {
    h <- H / 2 + 0.08
    for (sx in c(-1, 1)) {
      bx <- x + sx * (W / 2 + 0.12)
      parts[[length(parts) + 1L]] <- line_obj(c(bx, y - h), c(bx, y + h),
                                              .rm_stroke(color, width))
      parts[[length(parts) + 1L]] <- line_obj(
        c(bx, y + h), c(bx - sx * 0.12, y + h), .rm_stroke(color, width))
      parts[[length(parts) + 1L]] <- line_obj(
        c(bx, y - h), c(bx - sx * 0.12, y - h), .rm_stroke(color, width))
    }
  }
  .rm_group(parts)
}

## ---- 18. 叉号 / 19. 刻度 / 20. 张成直线 ----

#' @export
cross_obj <- function(p, size = 0.15, color = "#FC6255", width = 3) {
  .rm_group(list(
    line_obj(p + c(-size, -size), p + c(size, size), .rm_stroke(color, width)),
    line_obj(p + c(-size, size), p + c(size, -size), .rm_stroke(color, width))
  ))
}

#' @export
tick_obj <- function(p, dir = c(0, 1), size = 0.18, color = "#FFFFFF", width = 3) {
  d <- dir / sqrt(sum(dir^2))
  line_obj(p - size * d / 2, p + size * d / 2, .rm_stroke(color, width))
}

#' @export
span_line_obj <- function(v, ext = 6, color = "#7D8590", width = 3,
                          dashed = TRUE, dash = 0.2) {
  n <- sqrt(sum(v^2))
  if (n < 1e-9) stop("span_line_obj(): v 不能是零向量", call. = FALSE)
  u <- v / n
  p1 <- -ext * u; p2 <- ext * u
  if (dashed) dashed_line_obj(p1, p2, dash = dash, gap = dash * 0.7,
                              color = color, width = width)
  else line_obj(p1, p2, .rm_stroke(color, width))
}

## ---- 21. 二次型等值线 x'Qx = level（椭圆 / 双曲线 / 平行线）----

#' @export
quad_form_curve_obj <- function(Q, level = 1, color = "#58C4DD", width = 5,
                                n = 240, extent = 6, style = NULL) {
  Q <- as.matrix(Q)
  e <- eigen(Q, symmetric = TRUE)
  lam <- e$values; R <- e$vectors
  st <- style %||% .rm_stroke(color, width)
  back <- function(P) {
    Z <- P %*% t(R)
    cbind(Z[, 1], Z[, 2])
  }
  parts <- list()
  if (all(lam > 1e-9)) {                       ## 椭圆
    t <- seq(0, 2 * pi, length.out = n)
    parts[[1L]] <- .rm_poly_mobject(
      back(cbind(sqrt(level / lam[1]) * cos(t), sqrt(level / lam[2]) * sin(t))),
      st, TRUE, "level_ellipse")
  } else if (lam[1] > 1e-9 && lam[2] < -1e-9) {  ## 双曲线两支
    T <- min(extent, 2.2)
    t <- seq(-T, T, length.out = n)
    for (s in c(1, -1)) {
      parts[[length(parts) + 1L]] <- .rm_poly_mobject(
        back(cbind(s * sqrt(level / lam[1]) * cosh(t),
                   sqrt(level / abs(lam[2])) * sinh(t))),
        st, FALSE, "level_hyperbola")
    }
  } else if (lam[1] > 1e-9 && abs(lam[2]) <= 1e-9) {  ## 两条平行线
    u0 <- sqrt(level / lam[1])
    for (s in c(1, -1)) {
      v <- seq(-extent, extent, length.out = 100)
      parts[[length(parts) + 1L]] <- .rm_poly_mobject(
        back(cbind(rep(s * u0, length(v)), v)), st, FALSE, "level_parallel")
    }
  } else {
    stop("quad_form_curve_obj(): 该 Q 在 level>0 时没有实等值线", call. = FALSE)
  }
  if (length(parts) == 1L) parts[[1L]] else .rm_group(parts)
}

## ---- 22. 单位方格（行列式面积用） / 23. 基向量组 ----

#' @export
unit_square_obj <- function(origin = c(0, 0), fill = "#58C4DD", opacity = 0.30,
                            color = "#58C4DD", width = 4) {
  P <- rbind(origin, origin + c(1, 0), origin + c(1, 1), origin + c(0, 1))
  .rm_poly_mobject(P, .rm_fill(fill, opacity, color, width), TRUE, "unit_square")
}

#' @export
basis_arrows_obj <- function(e1 = c(1, 0), e2 = c(0, 1),
                             color1 = "#FC6255", color2 = "#83C167",
                             labels = c("e1", "e2"), width = 5, head = 0.2) {
  .rm_group(list(
    vector_obj(c(0, 0), e1, color = color1, width = width,
               head = head, label = labels[1]),
    vector_obj(c(0, 0), e2, color = color2, width = width,
               head = head, label = labels[2])
  ))
}
