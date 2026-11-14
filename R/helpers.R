## 公开辅助层：样式简写 + 对象结构窥视
##
## 为什么要有这一层：配套教程原先在 common/_setup.qmd 里自己维护了一份
## COL / st() / fl()，又用 .rm_state() / .rm_flatten() 重写了 n_subpaths() /
## peek() 等结构检查函数。于是「书里的代码」和「安装包里能用的代码」不是同一套：
## 用户 library(ROpenManim) 之后照抄 st(COL$cyan, 5) 会报「没有 st 这个函数」。
## 把这些能力收进包并正式导出，教程与安装包共用一份实现；白盒讲解里仍可
## 直接读 .rm_* 内部函数，但普通用户不需要碰它们。

## ---- 调色板（Manim 风格）----

COL <- list(
  bg     = "#0E1116",
  grid   = "#33404D",
  axis   = "#7D8590",
  dim    = "#5A6672",
  white  = "#FFFFFF",
  cyan   = "#58C4DD",
  green  = "#83C167",
  red    = "#FC6255",
  gold   = "#E8C547",
  purple = "#9A72C4"
)

## ---- 样式简写 ----
## st() = 只有描边；fl() = 填充（可再叠描边）。二者返回的 list 正是
## *_obj() 的 style 参数要的东西，等价于手写 list(stroke=, stroke_width=)。

#' @export
st <- function(color = COL$white, width = 4) {
  .rm_stroke(color, width)
}

#' @export
fl <- function(color = COL$cyan, opacity = 0.3,
               stroke = NA_character_, width = 2) {
  .rm_fill(color, opacity, stroke, width)
}

## ---- 结构窥视 ----
## 「帧 = 绘制指令列表」这条设计的好处是结构本身就是可检查的数据。
## 下面四个函数把教程里靠内部函数拼出来的查询变成正式 API。

#' @export
subpaths <- function(o) {
  if (inherits(o, "rm_mobject")) {
    s <- .rm_state(o)
    return(.rm_flatten(s$curves, s$path_id))
  }
  if (is.list(o)) return(unlist(lapply(o, subpaths), recursive = FALSE))
  list()
}

#' @export
n_subpaths <- function(o) length(subpaths(o))

#' @export
n_curves <- function(o) {
  if (inherits(o, "rm_mobject")) return(as.integer(length(.rm_state(o)$curves)))
  if (is.list(o)) return(as.integer(sum(vapply(o, n_curves, integer(1)))))
  0L
}

#' @export
n_objects <- function(o) length(.rm_as_objects(o))

#' @export
can_morph <- function(a, b) {
  A <- .rm_as_objects(a)
  B <- .rm_as_objects(b)
  ## morph 要求两侧摊平后各是一个对象，且子路径数一致；否则 transform()
  ## 会退化为交叉淡入淡出。
  if (length(A) != 1L || length(B) != 1L) return(FALSE)
  !is.null(.rm_align(.rm_state(A[[1L]]), .rm_state(B[[1L]])))
}

#' @export
peek <- function(o, label = NULL) {
  nm <- label %||% o$name %||% "<group>"
  P  <- subpaths(o)
  if (!length(P)) {
    cat(sprintf("%-14s 空对象\n", nm))
    return(invisible(o))
  }
  xs <- unlist(lapply(P, function(p) p[, 1]))
  ys <- unlist(lapply(P, function(p) p[, 2]))
  cat(sprintf("%-14s 子路径 %2d  曲线 %3d  点 %4d  bbox [%.2f, %.2f] x [%.2f, %.2f]\n",
              nm, length(P), n_curves(o),
              sum(vapply(P, nrow, integer(1))),
              min(xs), max(xs), min(ys), max(ys)))
  invisible(o)
}

## ---- 排字与出图包装 ----
## 每个例子都要做三件与动画内核无关的事：挑一个中文字体、把文字/公式放到
## 某个坐标、把当前帧变成一张图。这些包装原先只写在教程的 _setup.qmd 里，
## 于是读者把书里的 fig(sc, "x", t = 1.75) 抄进安装版就报「没有 fig 这个函数」。
## 收进包里之后，书里的示例才是真的可以直接跑。

## 字体探测有点贵（要枚举系统字体），结果缓存起来；lab() 的默认参数每次调用
## 都会求值一次，不缓存会拖慢整本书的渲染。
.rm_cjk_cache <- local({
  e <- new.env(parent = emptyenv())
  e$family <- NULL
  e
})

#' @export
cjk_font <- function() {
  if (!is.null(.rm_cjk_cache$family)) return(.rm_cjk_cache$family)
  cands <- c("Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
             "Source Han Sans SC", "SimHei", "SimSun")
  have <- tryCatch(unique(systemfonts::system_fonts()$family),
                   error = function(e) character(0))
  hit <- cands[cands %in% have]
  .rm_cjk_cache$family <- if (length(hit)) hit[[1L]] else "sans"
  .rm_cjk_cache$family
}

#' @export
lab <- function(str, x, y, size = 28, color = COL$white,
                family = cjk_font(), ...) {
  o <- text(str, size = size, color = color, family = family, ...)
  o$move_to(x, y)
  o
}

#' @export
tex <- function(s, x, y, size = 44, color = COL$white, ...) {
  o <- mathtex(s, size = size, color = color, ...)
  o$move_to(x, y)
  o
}

#' @export
ref_axes <- function(lim = 3.4, color = COL$dim, width = 2) {
  vgroup(line_obj(c(-lim, 0), c(lim, 0), st(color, width)),
         line_obj(c(0, -lim), c(0, lim), st(color, width)))
}

## knit 上下文里 fig() 要交一个 knitr 图对象；在控制台里则应该只留下文件、
## 返回路径。knitr 只是 Suggests，用 requireNamespace 软引用。
.rm_in_knit <- function() {
  isTRUE(requireNamespace("knitr", quietly = TRUE)) &&
    !is.null(tryCatch(knitr::current_input(), error = function(e) NULL))
}

#' @export
fig <- function(sc, name, t = NULL, quality = "m", dir = "figs") {
  f <- file.path(dir, paste0(name, ".png"))
  .rm_prepare_output(f)
  if (is.null(t)) last_frame(sc, f, quality = quality)
  else render_frame(sc, f, t = t, quality = quality)
  if (.rm_in_knit()) return(knitr::include_graphics(f))
  message("已写出 ", f, "（", format(file.size(f)), " 字节）")
  invisible(f)
}

#' @export
frame_to <- function(sc, name, t, quality = "m", dir = "figs") {
  f <- file.path(dir, paste0(name, ".png"))
  .rm_prepare_output(f)
  render_frame(sc, f, t = t, quality = quality)
  invisible(f)
}
