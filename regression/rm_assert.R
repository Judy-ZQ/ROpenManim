## ROpenManim v0.0.1 时间轴回归断言（源码直跑，不用先装包）
## 重点：入场动画之前的可见性、composite 错峰、transform 末态、帧间确有变化
suppressPackageStartupMessages({ library(grid); library(grDevices) })
## 从源码仓库定位 R/ 目录（不要求先安装包）。
## 跑法：cd ROpenManim && env -u LC_ALL -u LANG Rscript regression/run-all.R
locate_src <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  hit <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(hit)) {
    base <- normalizePath(file.path(dirname(hit[1]), ".."), winslash = "/")
    if (dir.exists(file.path(base, "R"))) return(file.path(base, "R"))
  }
  if (dir.exists("R")) return(normalizePath("R", winslash = "/"))
  stop("找不到 R/ 目录，请在包根目录或 regression/ 下运行")
}
root <- locate_src()
for (f in c("geometry.R", "mobject.R", "svgpath.R", "text.R", "tex.R",
            "axes.R", "animation.R", "scene.R", "backend-grid.R", "render.R")) {
  source(file.path(root, f), encoding = "UTF-8")
}

pass <- 0L; fail <- 0L
ck <- function(label, ok) {
  if (isTRUE(ok)) { pass <<- pass + 1L; cat(sprintf("  PASS  %s\n", label)) }
  else            { fail <<- fail + 1L; cat(sprintf("  FAIL  %s\n", label)) }
}

ax  <- axes(c(0, 3), c(0, 3), width = 8, height = 5, x = -2.4, y = -0.8,
            axis_labels = c("x", "y"))
sc  <- scene(); sc$add(ax)
p   <- plot_fn(ax, function(x) x^2, 0, 1.8, color = "#58C4DD"); sc$add(p)
lab <- text("vector morph", size = 40, color = "#83C167"); lab$move_to(3.0, 3.1); sc$add(lab)
mt  <- mathtex("\\int_0^1 x^2\\,dx = \\frac{1}{3}"); mt$move_to(2.6, 1.7); sc$add(mt)
## Transform 只把 a 变成 b，含位置：目标必须自己定位（与 Manim 一致）
mt2 <- mathtex("\\int_0^1 x^3\\,dx = \\frac{1}{4}"); mt2$move_to(2.6, 1.7)

sc$play(create(p, run_time = 1.2))
sc$play(fade_in(lab, run_time = 0.6, shift = -0.3))
sc$play(transform(mt, mt2, run_time = 1.0))

ip <- sc$.find_indices(list(p))
il <- sc$.find_indices(list(lab))
im <- sc$.find_indices(list(mt))
cat(sprintf("下标 p=%s lab=%s mt=%s ｜时长 %.1fs ｜items %d\n",
            ip, il, im, sc$duration(), length(sc$items)))

nops <- function(i, t) {
  st <- sc$.state_at(i, t)
  if (is.null(st)) return(0L)
  length(.rm_ops(st))
}
cat("\n-- 各对象绘制指令数（0 = 画面上不可见）--\n")
for (tt in c(0, 0.3, 0.6, 1.2, 1.5, 1.8, 2.2, 2.8, 2.81)) {
  cat(sprintf("  t=%-5.2f  p=%3d  lab=%3d  mt=%3d\n", tt,
              nops(ip, tt), nops(il, tt), nops(im, tt)))
}

sig <- function(i, t) {
  st <- sc$.state_at(i, t)
  if (is.null(st) || !length(st$polys)) return(NULL)
  XY <- do.call(rbind, st$polys)
  c(sum(XY[, 1]), sum(XY[, 2]), nrow(XY))
}
sig_target <- local({
  P <- .rm_flatten(mt2$curves, mt2$path_id); XY <- do.call(rbind, P)
  c(sum(XY[, 1]), sum(XY[, 2]), nrow(XY))
})

cat("\n-- 断言 --\n")
ck("fade_in 起点前（t=0.6）标签完全不可见", nops(il, 0.6) == 0L)
ck("fade_in 进行中（t=1.5）标签可见",       nops(il, 1.5) > 0L)
ck("fade_in 结束后（t=1.9）标签可见",       nops(il, 1.9) > 0L)
ck("transform 起点前（t=0.6）源公式可见",   nops(im, 0.6) > 0L)
ck("transform 进行中（t=2.2）公式可见",     nops(im, 2.2) > 0L)
ck("create 进行中（t=0.6）抛物线部分可见",  nops(ip, 0.6) > 0L)
ck("create 结束后（t=1.3）抛物线完整",      nops(ip, 1.3) > 0L)
ck("末帧几何等于目标公式（x^3 = 1/4）",
   isTRUE(all.equal(sig(im, 2.8), sig_target, tolerance = 1e-6)))
ck("末帧几何不同于源公式（缓存确已失效）",
   !isTRUE(all.equal(sig(im, 2.8), sig(im, 0.6), tolerance = 1e-6)))
ck("末帧位置保持在 (2.6, 1.7) 附近",
   abs(sig(im, 2.8)[1] / sig(im, 2.8)[3] - 2.6) < 0.5)

## fade_out / birth / composite 错峰：另开一个小场景
s2 <- scene()
a <- text("A", size = 40); a$move_to(-2, 0); s2$add(a)
b <- text("B", size = 40); b$move_to(2, 0)
s2$play(fade_in(a, run_time = 0.4)); s2$wait(0.2)
s2$add(b)                                    # birth = 0.6
## 让 b 成为错峰里「后启动」的叶子：starts = c(0, 0.3)，故 b 的叶子从 0.9 开始
s2$play(animation_group(fade_out(a, run_time = 0.6), create(b, run_time = 0.6),
                        lag_ratio = 0.5))
ia <- s2$.find_indices(list(a)); ib <- s2$.find_indices(list(b))
n2 <- function(i, t) { st <- s2$.state_at(i, t); if (is.null(st)) 0L else length(.rm_ops(st)) }
ck("wait() 之后 add 的对象在 birth 前不可见", n2(ib, 0.3) == 0L)
ck("fade_out 结束后对象不可见",               n2(ia, 1.5) == 0L)
ck("composite 错峰中后启动的叶子尚未入场",    n2(ib, 0.65) == 0L)
ck("composite 错峰叶子到点后确实入场",        n2(ib, 1.0) > 0L)
ck("fade_in 与 fade_out 之间的静止段可见",    n2(ia, 0.5) > 0L)

cat("\n-- 帧差异 --\n")
d <- normalizePath(file.path(tempdir(), "rm_probe_frames"), winslash = "/", mustWork = FALSE)
dir.create(d, showWarnings = FALSE)
ts <- c(0.6, 1.5, 2.2, 2.8)
fs <- character(0)
for (tt in ts) {
  f <- file.path(d, sprintf("as_%.1f.png", tt))
  render_frame(sc, f, t = tt, quality = "m")
  fs <- c(fs, f)
}
h <- vapply(fs, function(f) unname(tools::md5sum(f)), character(1))
cat(sprintf("  md5: %s\n", paste(substr(h, 1, 8), collapse = " ")))
ck("4 张关键帧互不相同（动画确实在动）", length(unique(h)) == 4L)

cat(sprintf("\n== %d PASS / %d FAIL ==\n", pass, fail))
if (fail > 0L) quit(status = 1L)
