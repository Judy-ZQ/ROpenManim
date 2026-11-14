## 从源码导出全部 NAMESPACE 导出的真实签名，供 tools/gen_man.py 生成 Rd。
## 跑法：cd ROpenManim && env -u LC_ALL -u LANG Rscript tools/dump_sig.R
## 输出：_sig.tsv（构建期中间产物，已列入 .Rbuildignore / .gitignore）

Sys.setenv(LC_CTYPE = "Chinese (Simplified)_China.utf8")

## 三级回退定位脚本所在目录，避免依赖当前工作目录
locate_script <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  hit <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(hit)) return(normalizePath(dirname(hit[1]), winslash = "/"))
  for (fr in sys.frames()) {
    of <- get0("ofile", envir = fr, inherits = FALSE)
    if (is.character(of) && length(of) == 1L)
      return(normalizePath(dirname(of), winslash = "/"))
  }
  if (dir.exists("tools")) return(normalizePath("tools", winslash = "/"))
  stop("定位不到 tools/ 目录，请在包根目录下运行")
}

root <- normalizePath(file.path(locate_script(), ".."), winslash = "/")
suppressPackageStartupMessages(library(grid))

files <- c("geometry.R", "mobject.R", "svgpath.R", "text.R", "tex.R", "axes.R",
           "primitives.R", "animation.R", "anim-linalg.R", "homogeneous3d.R",
           "primitives3d.R", "camera.R", "scene.R", "backend-grid.R", "render.R",
           "helpers.R")
for (f in files) source(file.path(root, "R", f), encoding = "UTF-8")

ns <- readLines(file.path(root, "NAMESPACE"), encoding = "UTF-8")
ex <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))

lines <- vapply(ex, function(n) {
  o <- get(n, inherits = TRUE)
  if (is.function(o)) {
    u <- paste(deparse(args(o)), collapse = " ")
    u <- sub("^function ", paste0(n, ""), u)   # function (...) -> name(...)
    u <- sub(" NULL$", "", u)                   # args() 末尾的 NULL
    u <- gsub("[\r\n\t]", " ", u)
    ## 第 4 列给 Rd 的 \arguments 用：直接从 formals() 取，
    ## 比从 usage 文本里正则猜要准（必填参数没有 "="，正则会漏）。
    paste0(n, "\tFN\t", u, "\t", paste(names(formals(o)), collapse = ","))
  } else {
    paste0(n, "\tDATA\t", as.character(o[1]), "\t")
  }
}, "")

writeLines(lines, file.path(root, "_sig.tsv"), useBytes = TRUE)
cat("dump", length(lines), "signatures ->", file.path(root, "_sig.tsv"), "\n")
