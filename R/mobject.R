## 图元对象：R6 引用对象，内部只存三次贝塞尔段
## 一条对象 = curves（4x3 矩阵的列表，每段一条三次贝塞尔）+ path_id（每段所属子路径）

.rm_style <- function(style = NULL) {
  d <- list(stroke = "#FFFFFF", stroke_width = 4, stroke_opacity = 1,
            fill = NA_character_, fill_opacity = 1, rule = "winding")
  if (is.null(style)) return(d)
  if (!is.list(style) || is.null(names(style))) return(d)
  utils::modifyList(d, style)
}

#' @export
rm_mobject <- R6::R6Class(
  "rm_mobject",
  public = list(
    curves = NULL,
    path_id = NULL,
    style = NULL,
    opacity = 1,
    name = NULL,
    ## dim = 2 是屏幕空间的平面对象；dim = 3 是三维图元，
    ## 只有后者才会被 scene 的 camera 投影（文字/公式永远留在屏幕空间）。
    dim = 2L,

    initialize = function(curves = list(), path_id = NULL, style = NULL,
                          name = NULL, dim = 2L) {
      self$curves <- curves
      self$path_id <- path_id %||% rep(1L, length(curves))
      self$style <- .rm_style(style)
      self$name <- name
      self$dim <- as.integer(dim)
      invisible(self)
    },

    ## ---- 度量 ----
    n_paths = function() length(unique(self$path_id)),
    bbox = function() .rm_bbox(self$curves, self$path_id),
    width = function() { b <- self$bbox(); b[["xmax"]] - b[["xmin"]] },
    height = function() { b <- self$bbox(); b[["ymax"]] - b[["ymin"]] },
    center = function() {
      b <- self$bbox(); c((b[["xmin"]] + b[["xmax"]]) / 2, (b[["ymin"]] + b[["ymax"]]) / 2)
    },

    ## ---- 变换（原地，返回 invisible(self) 便于链式）----
    shift = function(dx = 0, dy = 0) {
      m <- matrix(c(1, 0, dx, 0, 1, dy, 0, 0, 1), nrow = 3, byrow = TRUE)
      self$curves <- .rm_apply_affine(self$curves, m)
      invisible(self)
    },
    move_to = function(x = 0, y = 0) {
      c0 <- self$center()
      self$shift(x - c0[1], y - c0[2])
    },
    scale = function(s = 1, about = c(0, 0)) {
      if (length(s) == 1L) s <- c(s, s)
      m <- matrix(c(s[1], 0, about[1] * (1 - s[1]),
                    0, s[2], about[2] * (1 - s[2]),
                    0, 0, 1), nrow = 3, byrow = TRUE)
      self$curves <- .rm_apply_affine(self$curves, m)
      invisible(self)
    },
    rotate = function(angle, about = c(0, 0)) {
      self$curves <- .rm_apply_affine(self$curves, .rm_rotate_m(angle, about))
      invisible(self)
    },
    flip = function(axis = "y") {
      m <- if (axis == "y") diag(c(-1, 1, 1)) else diag(c(1, -1, 1))
      self$curves <- .rm_apply_affine(self$curves, m)
      invisible(self)
    },

    ## ---- 样式 ---- 
    set_stroke = function(color = "#FFFFFF", width = 4, opacity = 1) {
      self$style$stroke <- color
      self$style$stroke_width <- width
      self$style$stroke_opacity <- opacity
      invisible(self)
    },
    set_fill = function(color = "#FFFFFF", opacity = 1) {
      self$style$fill <- color
      self$style$fill_opacity <- opacity
      invisible(self)
    },
    set_color = function(color) {
      if (identical(self$style$fill, NA_character_) || is.na(self$style$fill)) {
        self$style$stroke <- color
      } else {
        self$style$fill <- color
      }
      invisible(self)
    },
    set_opacity = function(o) { self$opacity <- o; invisible(self) },

    ## ---- 调试 ---- 
    print = function(...) {
      b <- self$bbox()
      cat(sprintf("<rm_mobject> %s  %d 条子路径, %d 段贝塞尔, bbox [%.2f, %.2f] x [%.2f, %.2f]\n",
                  self$name %||% "unnamed", self$n_paths(), length(self$curves),
                  b[["xmin"]], b[["xmax"]], b[["ymin"]], b[["ymax"]]))
      invisible(self)
    }
  )
)

## 场景里的"状态"：纯数据，渲染与动画都在这个层面做，不碰 R6 对象
.rm_state <- function(o) {
  list(curves = o$curves, path_id = o$path_id, style = o$style,
       opacity = o$opacity, dim = o$dim)
}

#' @export
vgroup <- function(...) {
  structure(list(...), class = c("rm_group", "list"))
}

.rm_is_group <- function(x) inherits(x, "rm_group")

## ---- 图元构造 ---- 

#' @export
line_obj <- function(p1, p2, style = NULL) {
  rm_mobject$new(list(.rm_line_curve(p1, p2)), 1L, style, name = "line")
}

#' @export
polygon_obj <- function(pts, closed = TRUE, style = NULL) {
  if (closed) pts <- rbind(pts, pts[1, , drop = FALSE])
  z <- .rm_curves_from_polys(list(pts))
  rm_mobject$new(z$curves, z$path_id, style, name = "polygon")
}

#' @export
circle_obj <- function(x = 0, y = 0, r = 1, style = NULL) {
  k <- 4 / 3 * (sqrt(2) - 1)
  a <- seq(0, 2 * pi, length.out = 5L)
  curves <- vector("list", 4L)
  for (i in 1:4) {
    p0 <- c(x + r * cos(a[i]), y + r * sin(a[i]), 0)
    p3 <- c(x + r * cos(a[i + 1L]), y + r * sin(a[i + 1L]), 0)
    p1 <- p0 + k * r * c(-sin(a[i]), cos(a[i]), 0)
    p2 <- p3 - k * r * c(-sin(a[i + 1L]), cos(a[i + 1L]), 0)
    curves[[i]] <- rbind(p0, p1, p2, p3)
  }
  rm_mobject$new(curves, rep(1L, 4L), style, name = "circle")
}

#' @export
rect_obj <- function(w = 2, h = 1, x = 0, y = 0, style = NULL) {
  pts <- cbind(c(x - w / 2, x + w / 2, x + w / 2, x - w / 2),
               c(y - h / 2, y - h / 2, y + h / 2, y + h / 2))
  polygon_obj(pts, TRUE, style)
}

#' @export
square_obj <- function(side = 2, x = 0, y = 0, style = NULL) {
  rect_obj(side, side, x, y, style)
}

#' @export
dot_obj <- function(x = 0, y = 0, r = 0.08, color = "#FFFFFF") {
  o <- circle_obj(x, y, r, list(stroke = NA_character_, fill = color))
  o$name <- "dot"
  o
}

#' @export
arrow_obj <- function(p1, p2, head = 0.22, color = "#FFFFFF", width = 4, style = NULL) {
  d <- p2 - p1
  L <- sqrt(sum(d^2))
  if (L < 1e-9) return(dot_obj(p1[1], p1[2], r = width / 200, color = color))
  u <- d / L
  n <- c(-u[2], u[1])
  base <- p2 - head * u
  tri <- rbind(p2, base + (head * 0.45) * n, base - (head * 0.45) * n)
  body <- line_obj(p1, base * 0.995 + p2 * 0.005,
                   style = style %||% list(stroke = color, stroke_width = width))
  tip <- polygon_obj(tri, TRUE, list(stroke = NA_character_, fill = color))
  structure(list(body, tip), class = c("rm_group", "list"))
}

## ---- 绘图指令构造（IRT）---- 

## 把一个状态编译成绘制指令：填充走 path，描边走 polyline
## state$polys 是展平结果的缓存（静止图元只算一次）；几何一变就要置 NULL。
.rm_ops <- function(state, tol = 2e-3) {
  ops <- list()
  st <- state$style
  if (!length(state$curves)) return(ops)
  polys <- state$polys
  if (is.null(polys)) polys <- .rm_flatten(state$curves, state$path_id, tol)
  if (!length(polys)) return(ops)

  if (!is.null(st$fill) && !is.na(st$fill) && (st$fill_opacity * state$opacity) > 0) {
    id <- rep(seq_along(polys), vapply(polys, nrow, integer(1)))
    XY <- do.call(rbind, polys)
    ops[[length(ops) + 1L]] <- list(
      op = "path", x = XY[, 1], y = XY[, 2], id = id,
      fill = st$fill,
      alpha = st$fill_opacity * state$opacity,
      rule = st$rule %||% "winding"
    )
  }
  if (!is.null(st$stroke) && !is.na(st$stroke) && st$stroke_width > 0 &&
      (st$stroke_opacity * state$opacity) > 0) {
    for (k in seq_along(polys)) {
      P <- polys[[k]]
      ops[[length(ops) + 1L]] <- list(
        op = "stroke", x = P[, 1], y = P[, 2],
        col = st$stroke, width = st$stroke_width,
        alpha = st$stroke_opacity * state$opacity
      )
    }
  }
  ops
}
