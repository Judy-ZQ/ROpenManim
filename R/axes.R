## 坐标系：axes() 产出轴线、刻度、刻度标签，并提供数据坐标 -> 场景坐标的映射

#' @export
rm_axes <- R6::R6Class(
  "rm_axes",
  public = list(
    xlim = NULL, ylim = NULL, width = NULL, height = NULL, origin = NULL,
    parts = NULL,
    initialize = function(xlim, ylim, width, height, origin, parts) {
      self$xlim <- xlim; self$ylim <- ylim
      self$width <- width; self$height <- height
      self$origin <- origin; self$parts <- parts
    },
    c2p = function(xv, yv = 0) {
      xs <- self$origin[1] + (xv - self$xlim[1]) / diff(self$xlim) * self$width - self$width / 2
      ys <- self$origin[2] + (yv - self$ylim[1]) / diff(self$ylim) * self$height - self$height / 2
      cbind(xs, ys)
    },
    print = function(...) {
      cat(sprintf("<rm_axes> x [%g, %g]  y [%g, %g]  %g x %g unit\n",
                  self$xlim[1], self$xlim[2], self$ylim[1], self$ylim[2],
                  self$width, self$height))
      invisible(self)
    }
  )
)

#' @export
axes <- function(xlim = c(0, 1), ylim = c(0, 1), width = 10, height = 6,
                 x = 0, y = 0, color = "#FFFFFF", n_ticks = 5,
                 tick_size = 0.14, label_size = 30, numbers = TRUE,
                 arrows = TRUE, axis_labels = NULL) {
  parts <- list()
  ax0 <- if (xlim[1] <= 0 && xlim[2] >= 0) 0 else xlim[1]
  ay0 <- if (ylim[1] <= 0 && ylim[2] >= 0) 0 else ylim[1]
  ax <- rm_axes$new(xlim, ylim, width, height, c(x, y), list())
  p <- function(xv, yv) ax$c2p(xv, yv)[1, ]

  xa <- p(xlim[1], ay0); xb <- p(xlim[2], ay0)
  ya <- p(ax0, ylim[1]); yb <- p(ax0, ylim[2])

  if (arrows) {
    parts <- c(parts, list(arrow_obj(xa, xb, color = color)),
               list(arrow_obj(ya, yb, color = color)))
  } else {
    parts <- c(parts, list(line_obj(xa, xb, list(stroke = color, stroke_width = 4))),
               list(line_obj(ya, yb, list(stroke = color, stroke_width = 4))))
  }

  tick <- function(v, vertical = FALSE) {
    pt <- if (vertical) p(v, ay0) else p(ax0, v)
    d <- if (vertical) c(0, tick_size) else c(tick_size, 0)
    line_obj(pt - d, pt + d, list(stroke = color, stroke_width = 3))
  }
  xs <- if (n_ticks > 1) seq(xlim[1], xlim[2], length.out = n_ticks) else xlim
  ys <- if (n_ticks > 1) seq(ylim[1], ylim[2], length.out = n_ticks) else ylim
  parts <- c(parts, lapply(xs, tick, vertical = TRUE), lapply(ys, tick, vertical = FALSE))

  if (numbers) {
    fmt <- function(v) {
      s <- format(v, trim = TRUE, scientific = FALSE)
      if (nchar(s) > 6) format(v, digits = 2) else s
    }
    for (v in xs) {
      t <- text(fmt(v), size = label_size, color = color)
      ## 数字 0 正好被纵轴一切两半；纵轴在框内部时把它往左挪半个字宽
      inside <- ax0 > xlim[1] + 1e-9 && ax0 < xlim[2] - 1e-9
      dx <- if (inside && abs(v - ax0) < 1e-9) -0.24 else 0
      t$move_to(p(v, ay0)[1] + dx, p(v, ay0)[2] - 0.32)
      parts <- c(parts, list(t))
    }
    for (v in ys) {
      if (abs(v) < 1e-9) next
      t <- text(fmt(v), size = label_size, color = color)
      t$move_to(p(ax0, v)[1] - 0.38, p(ax0, v)[2])
      parts <- c(parts, list(t))
    }
  }

  if (!is.null(axis_labels)) {
    tl <- text(axis_labels[1], size = label_size + 8, color = color)
    tl$move_to(xb[1] + 0.45, xb[2] - 0.1)
    parts <- c(parts, list(tl))
    if (length(axis_labels) > 1) {
      ty <- text(axis_labels[2], size = label_size + 8, color = color)
      ## 放在箭头右侧：左边是刻度数字（(ax0 - 0.38, ylim[2])），右侧才是空的
      ty$move_to(yb[1] + 0.34, yb[2] + 0.08)
      parts <- c(parts, list(ty))
    }
  }

  ax$parts <- parts
  ax
}

#' @export
plot_fn <- function(ax, fun, from = ax$xlim[1], to = ax$xlim[2], n = 300,
                    color = "#58C4DD", width = 5, style = NULL) {
  xv <- seq(from, to, length.out = max(2L, n))
  yv <- fun(xv)
  ok <- is.finite(yv)
  P <- ax$c2p(xv[ok], yv[ok])
  polygon_obj(P, closed = FALSE,
              style = style %||% list(stroke = color, stroke_width = width))
}
