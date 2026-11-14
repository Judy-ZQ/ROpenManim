## 数学公式：LaTeX -> dvi -> dvisvgm -> SVG 路径 -> 贝塞尔对象
## 这样公式是可变形、可淡入的矢量对象，而不是贴图。

.rm_tex_ok <- function() {
  nzchar(Sys.which("latex")) && nzchar(Sys.which("dvisvgm"))
}

.rm_tex_cache_dir <- function() {
  root <- tryCatch(tools::R_user_dir("ROpenManim", "cache"), error = function(e) file.path(tempdir(), "ROpenManim"))
  d <- file.path(root, "tex")
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

#' @export
mathtex <- function(tex, size = 48, color = "#FFFFFF", preamble = NULL) {
  if (!.rm_tex_ok()) {
    stop("mathtex() 需要 LaTeX 与 dvisvgm（检查 Sys.which('latex') / Sys.which('dvisvgm')）", call. = FALSE)
  }
  src <- c(
    "\\documentclass[border=2pt]{standalone}",
    "\\usepackage{amsmath,amssymb}",
    if (!is.null(preamble)) preamble,
    "\\begin{document}",
    paste0("$\\displaystyle ", tex, "$"),
    "\\end{document}"
  )
  tmp <- tempfile(fileext = ".tex")
  writeLines(src, tmp, useBytes = TRUE)
  key <- unname(tools::md5sum(tmp))
  file.remove(tmp)

  dir <- file.path(.rm_tex_cache_dir(), key)
  svg <- file.path(dir, "m.svg")
  if (!file.exists(svg)) {
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    texf <- file.path(dir, "m.tex")
    writeLines(src, texf, useBytes = TRUE)
    old <- setwd(dir); on.exit(setwd(old), add = TRUE)
    log <- tryCatch(
      suppressWarnings(system2(Sys.which("latex"),
                               c("-interaction=nonstopmode", "-halt-on-error", "m.tex"),
                               stdout = TRUE, stderr = TRUE)),
      error = function(e) e
    )
    if (!file.exists("m.dvi")) {
      stop("LaTeX 编译失败：\n", paste(utils::tail(log, 15), collapse = "\n"), call. = FALSE)
    }
    system2(Sys.which("dvisvgm"),
            c("--no-fonts", "--exact", "--bbox=min", "-o", "m.svg", "m.dvi"),
            stdout = FALSE, stderr = FALSE)
    if (!file.exists(svg)) stop("dvisvgm 转换失败", call. = FALSE)
  }

  z <- .rm_svg_read(svg)
  if (!length(z$curves)) stop("mathtex(): SVG 里没有可用的路径", call. = FALSE)
  k <- 0.01 * size / 12        # 1bp -> 场景单位
  z$curves <- lapply(z$curves, function(cv) {
    cv[, 1] <- cv[, 1] * k
    cv[, 2] <- -cv[, 2] * k    # SVG 的 y 向下
    cv
  })
  o <- rm_mobject$new(z$curves, z$path_id,
                      list(stroke = NA_character_, fill = color), name = "mathtex")
  o$move_to(0, 0)
  o
}
