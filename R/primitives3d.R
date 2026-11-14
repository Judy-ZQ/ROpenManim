## 三维图元层（P5 的第一批）：curves 的第三列存真实 z，dim = 3L。
## 与二维图元一样是「若干条三次贝塞尔子路径」，因此 4x4 齐次变换能整体作用；
## 多笔画图元返回 vgroup，scene$add() 会递归摊平，每条笔画独立参与深度排序。
## 单位仍是场景 unit（帧高 8）；相机投影在 compile() 里做，图元本身不知道相机。

## 保证一个点是长度 3 的数值向量
.rm3_pt <- function(p) {
  p <- as.numeric(p)
  if (length(p) < 3L) p <- c(p, rep(0, 3L - length(p)))
  p[1:3]
}

.rm3_cross <- function(a, b) {
  c(a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1])
}

## 由 N x 3 折线构造一个三维图元
.rm3_poly <- function(P, style = NULL, closed = FALSE, name = "poly3d") {
  P <- as.matrix(P)
  if (ncol(P) < 3L) P <- cbind(P, matrix(0, nrow(P), 3L - ncol(P)))
  P <- P[, 1:3, drop = FALSE]
  if (closed && nrow(P) >= 2L && !all(P[nrow(P), ] == P[1, ])) {
    P <- rbind(P, P[1, , drop = FALSE])
  }
  z <- .rm_curves_from_polys(list(P))
  rm_mobject$new(z$curves, z$path_id, style, name = name, dim = 3L)
}

.rm3_group <- function(parts) do.call(vgroup, parts)

## ---- 1. 线段 / 2. 折线 ----

#' @export
line3d_obj <- function(p, q, color = "#FFFFFF", width = 3, style = NULL) {
  .rm3_poly(rbind(.rm3_pt(p), .rm3_pt(q)),
            style %||% .rm_stroke(color, width), FALSE, "line3d")
}

#' @export
polyline3d_obj <- function(P, color = "#FFFFFF", width = 3, closed = FALSE,
                           style = NULL) {
  P <- as.matrix(P)
  if (ncol(P) < 3L) P <- cbind(P, matrix(0, nrow(P), 3L - ncol(P)))
  .rm3_poly(P[, 1:3, drop = FALSE], style %||% .rm_stroke(color, width),
            closed, "polyline3d")
}

## ---- 3. 盒状线框（立方体 / 平行六面体共用）----
## 12 条棱各是一个独立对象，便于画家算法按棱的深度分别排序；
## fill 非空时再补 6 个半透明面（用于把体积「看」出来）。
.rm3_box <- function(C, color, width, fill, opacity, name) {
  ## C: 8 x 3，行按二进制 (a,b,c) 排列：C[1 + a + 2*b + 4*c, ]
  E <- rbind(c(1, 2), c(2, 4), c(4, 3), c(3, 1),      # z = 0 面
             c(5, 6), c(6, 8), c(8, 7), c(7, 5),      # z = 1 面
             c(1, 5), c(2, 6), c(3, 7), c(4, 8))      # 竖棱
  parts <- lapply(seq_len(nrow(E)), function(i) {
    line3d_obj(C[E[i, 1], ], C[E[i, 2], ], color = color, width = width)
  })
  if (!is.null(fill)) {
    faces <- list(c(1, 2, 4, 3), c(5, 6, 8, 7),
                  c(1, 2, 6, 5), c(3, 4, 8, 7),
                  c(1, 3, 7, 5), c(2, 4, 8, 6))
    st <- .rm_fill(fill, opacity, NA_character_, 2)
    for (f in faces) {
      parts[[length(parts) + 1L]] <- .rm3_poly(C[f, , drop = FALSE],
                                               st, TRUE, "box_face")
    }
  }
  for (p in parts) p$name <- name
  .rm3_group(parts)
}

#' 单位立方体（棱长 side，中心 center）
#' @export
cube3d_obj <- function(side = 2, center = c(0, 0, 0),
                       color = "#58C4DD", width = 4,
                       fill = NULL, opacity = 0.22) {
  h <- side / 2
  a <- seq(-h, h, length.out = 2L)
  G <- expand.grid(a, a, a)                 # 列顺序：x 变化最快
  C <- as.matrix(G) + matrix(.rm3_pt(center), nrow(G), 3, byrow = TRUE)
  ## expand.grid 的行序是 (x,y,z) 字典序，正好对应 (a,b,c) 二进制
  .rm3_box(C, color, width, fill, opacity, "cube3d")
}

#' 由三列向量张成的平行六面体：体积 = |det(v1,v2,v3)|
#' @export
parallelepiped3d_obj <- function(v1 = c(1, 0, 0), v2 = c(0, 1, 0),
                                 v3 = c(0, 0, 1), origin = c(0, 0, 0),
                                 color = "#58C4DD", width = 4,
                                 fill = NULL, opacity = 0.22) {
  v1 <- .rm3_pt(v1); v2 <- .rm3_pt(v2); v3 <- .rm3_pt(v3)
  o <- .rm3_pt(origin)
  G <- expand.grid(0:1, 0:1, 0:1)
  C <- t(apply(G, 1, function(abc) {
    o + as.numeric(abc[1]) * v1 + as.numeric(abc[2]) * v2 + as.numeric(abc[3]) * v3
  }))
  .rm3_box(C, color, width, fill, opacity, "parallelepiped3d")
}

## ---- 4. 三维坐标轴 ----

#' 三条带箭头的坐标轴（x 红 / y 绿 / z 蓝）
#' @export
axes3d_obj <- function(lim = 3, color1 = "#FC6255", color2 = "#83C167",
                       color3 = "#58C4DD", width = 3, head = 0.24) {
  .rm3_group(list(
    vector3d_obj(c(0, 0, 0), c(lim, 0, 0), color = color1,
                 width = width, head = head),
    vector3d_obj(c(0, 0, 0), c(0, lim, 0), color = color2,
                 width = width, head = head),
    vector3d_obj(c(0, 0, 0), c(0, 0, lim), color = color3,
                 width = width, head = head)
  ))
}

## ---- 5. xy 平面网格 ----

#' z = z 平面上的网格（3D 里可被 4x4 变换整体压斜）
#' @export
grid3d_obj <- function(xlim = c(-3, 3), ylim = c(-3, 3), step = 1, z = 0,
                       color = "#33404D", width = 2) {
  xs <- seq(xlim[1], xlim[2], by = step)
  ys <- seq(ylim[1], ylim[2], by = step)
  parts <- c(
    lapply(xs, function(x) line3d_obj(c(x, ylim[1], z), c(x, ylim[2], z),
                                      color = color, width = width)),
    lapply(ys, function(y) line3d_obj(c(xlim[1], y, z), c(xlim[2], y, z),
                                      color = color, width = width))
  )
  .rm3_group(parts)
}

## ---- 6. 过原点、法向 n 的平面片 ----

#' 平面 n . x = 0 上的一片网格（秩 2 投影的像空间）
#' @export
plane3d_obj <- function(n = c(0, 0, 1), size = 3, step = 1,
                        color = "#7D8590", width = 2) {
  n <- .rm3_pt(n); n <- n / sqrt(sum(n^2))
  tmp <- if (abs(n[3]) < 0.9) c(0, 0, 1) else c(1, 0, 0)
  u <- .rm3_cross(n, tmp); u <- u / sqrt(sum(u^2))
  w <- .rm3_cross(n, u)
  at <- seq(-size, size, by = step)
  parts <- c(
    lapply(at, function(s) line3d_obj(-size * u + s * w, size * u + s * w,
                                      color = color, width = width)),
    lapply(at, function(s) line3d_obj(-size * w + s * u, size * w + s * u,
                                      color = color, width = width))
  )
  .rm3_group(parts)
}

## ---- 7. 三维箭头 ----

#' 杆 + 四棱锥线框的三维箭头
#' @export
vector3d_obj <- function(from = c(0, 0, 0), to = c(1, 0, 0),
                         color = "#FFFFFF", width = 4, head = 0.24) {
  p <- .rm3_pt(from); q <- .rm3_pt(to)
  d <- q - p; L <- sqrt(sum(d^2))
  if (L < 1e-9) return(point3d_obj(p, r = 0.06, color = color))
  u <- d / L
  tmp <- if (abs(u[3]) < 0.9) c(0, 0, 1) else c(1, 0, 0)
  n1 <- .rm3_cross(u, tmp); n1 <- n1 / sqrt(sum(n1^2))
  n2 <- .rm3_cross(u, n1)
  base <- q - min(head, L * 0.5) * u
  h <- min(head, L * 0.5)
  rim <- rbind(base + h * 0.42 * n1, base - h * 0.42 * n1,
               base + h * 0.42 * n2, base - h * 0.42 * n2)
  parts <- list(line3d_obj(p, base, color = color, width = width))
  for (i in 1:4) {
    parts[[length(parts) + 1L]] <- line3d_obj(q, rim[i, ],
                                              color = color, width = width)
  }
  .rm3_group(parts)
}

## ---- 8. 三维基向量组 ----

#' @export
basis3d_obj <- function(v1 = c(1, 0, 0), v2 = c(0, 1, 0), v3 = c(0, 0, 1),
                        color1 = "#FC6255", color2 = "#83C167",
                        color3 = "#58C4DD", width = 5, head = 0.22) {
  .rm3_group(list(
    vector3d_obj(c(0, 0, 0), v1, color = color1, width = width, head = head),
    vector3d_obj(c(0, 0, 0), v2, color = color2, width = width, head = head),
    vector3d_obj(c(0, 0, 0), v3, color = color3, width = width, head = head)
  ))
}

## ---- 9. 三维点标记（三条正交直径线）----

#' @export
point3d_obj <- function(p = c(0, 0, 0), r = 0.10, color = "#E8C547",
                        width = 3) {
  p <- .rm3_pt(p)
  .rm3_group(list(
    line3d_obj(p - c(r, 0, 0), p + c(r, 0, 0), color = color, width = width),
    line3d_obj(p - c(0, r, 0), p + c(0, r, 0), color = color, width = width),
    line3d_obj(p - c(0, 0, r), p + c(0, 0, r), color = color, width = width)
  ))
}

## ---- 10. 参数曲面 z = fun(x, y) 的网格 ----

#' 二次型曲面 z = x'Qx 之类；fun 接受等长 x / y 向量，返回等长 z 向量
#' @export
surface3d_obj <- function(fun, xlim = c(-2, 2), ylim = c(-2, 2),
                          nx = 13, ny = 13, color = "#58C4DD", width = 2) {
  xs <- seq(xlim[1], xlim[2], length.out = nx)
  ys <- seq(ylim[1], ylim[2], length.out = ny)
  zfun <- function(x, y) as.numeric(fun(x, y))
  parts <- list()
  for (y in ys) {
    parts[[length(parts) + 1L]] <-
      polyline3d_obj(cbind(xs, rep(y, length(xs)), zfun(xs, rep(y, length(xs)))),
                     color = color, width = width)
  }
  for (x in xs) {
    parts[[length(parts) + 1L]] <-
      polyline3d_obj(cbind(rep(x, length(ys)), ys, zfun(rep(x, length(ys)), ys)),
                     color = color, width = width)
  }
  .rm3_group(parts)
}
