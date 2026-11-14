## ROpenManim P1 图元 + 线性变换动画回归断言
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
for (f in c("geometry.R", "mobject.R", "svgpath.R", "text.R", "tex.R", "axes.R",
            "primitives.R", "animation.R", "anim-linalg.R", "scene.R",
            "backend-grid.R", "render.R")) {
  source(file.path(root, f), encoding = "UTF-8")
}

pass <- 0L; fail <- 0L
ck <- function(label, ok) {
  if (isTRUE(ok)) { pass <<- pass + 1L; cat(sprintf("  PASS  %s\n", label)) }
  else            { fail <<- fail + 1L; cat(sprintf("  FAIL  %s\n", label)) }
}
near <- function(a, b, tol = 0.03) isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = tol))
bbox_of <- function(o) {
  parts <- .rm_as_objects(o)
  XY <- do.call(rbind, lapply(parts, function(p) {
    P <- do.call(rbind, .rm_flatten(p$curves, p$path_id)); P[, 1:2, drop = FALSE]
  }))
  c(min(XY[, 1]), max(XY[, 1]), min(XY[, 2]), max(XY[, 2]))
}
poly_area <- function(P) {
  x <- P[, 1]; y <- P[, 2]; n <- length(x)
  0.5 * abs(sum(x * c(y[-1], y[1]) - c(x[-1], x[1]) * y))
}

cat("== 1. 23 个新图元均可构造且几何非空 ==\n")
constructors <- list(
  arc_obj        = function() arc_obj(r = 1.5, angle = pi / 2),
  sector_obj     = function() sector_obj(r = 1.5, angle = pi / 3),
  ellipse_obj    = function() ellipse_obj(rx = 2, ry = 1),
  triangle_obj   = function() triangle_obj(c(0, 0), c(2, 0), c(1, 1.5)),
  brace_obj      = function() brace_obj(c(-1, 0), c(1, 0)),
  double_arrow_obj = function() double_arrow_obj(c(-1, 0), c(1, 0)),
  dashed_line_obj = function() dashed_line_obj(c(-1, 0), c(1, 1)),
  angle_obj      = function() angle_obj(c(0, 0), c(1, 0), c(0, 1)),
  right_angle_obj = function() right_angle_obj(c(0, 0), c(1, 0), c(0, 1)),
  number_line_obj = function() number_line_obj(c(-2, 2), at = -2:2),
  grid_obj       = function() grid_obj(c(-2, 2), c(-2, 2), step = 1),
  parametric_curve_obj = function() parametric_curve_obj(function(t) c(2 * cos(t), sin(t))),
  area_under_obj = function() area_under_obj(axes(c(0, 1), c(0, 1), 6, 4), function(x) x^2, 0, 1),
  polygon_fill_obj = function() polygon_fill_obj(rbind(c(0, 0), c(1, 0), c(0, 1))),
  vector_obj     = function() vector_obj(c(0, 0), c(1, 1), label = "v"),
  label_obj      = function() label_obj("A", c(0, 0)),
  matrix_obj     = function() matrix_obj(matrix(c(1, 2, 3, 4), 2, 2, byrow = TRUE)),
  cross_obj      = function() cross_obj(c(0.5, 0.5)),
  tick_obj       = function() tick_obj(c(0, 0)),
  span_line_obj  = function() span_line_obj(c(1, 0.5), ext = 3),
  quad_form_curve_obj = function() quad_form_curve_obj(diag(c(4, 1))),
  unit_square_obj = function() unit_square_obj(),
  basis_arrows_obj = function() basis_arrows_obj()
)
for (nm in names(constructors)) {
  o <- try(constructors[[nm]](), silent = TRUE)
  if (inherits(o, "try-error")) { ck(paste0("构造 ", nm), FALSE); next }
  parts <- .rm_as_objects(o)
  nonempty <- length(parts) > 0L && all(vapply(parts, function(p) length(p$curves) > 0L, logical(1)))
  bb <- try(bbox_of(o), silent = TRUE)
  ck(sprintf("构造 %-22s (%d 个对象)", nm, length(parts)),
     nonempty && !inherits(bb, "try-error") && all(is.finite(bb)))
}

cat("\n== 2. 关键图元的包围盒与手算值 ==\n")
ck("ellipse_obj(1,1,rx=2,ry=1) bbox",
   near(bbox_of(ellipse_obj(center = c(1, 1), rx = 2, ry = 1)), c(-1, 3, 0, 2), 0.02))
ck("unit_square_obj bbox = [0,1]x[0,1]",
   near(bbox_of(unit_square_obj()), c(0, 1, 0, 1), 1e-6))
ck("grid_obj(step=1, -2..2) 展开为 10 条线",
   length(.rm_as_objects(grid_obj(c(-2, 2), c(-2, 2), 1))) == 10L)
Q <- diag(c(4, 1))
ck("Q=diag(4,1) 的 x'Qx=1 是半轴 0.5/1 的椭圆",
   near(bbox_of(quad_form_curve_obj(Q)), c(-0.5, 0.5, -1, 1), 0.02))
Qi <- diag(c(4, -1))
ck("Q=diag(4,-1) 的等值线是双曲线两支",
   length(.rm_as_objects(quad_form_curve_obj(Qi))) == 2L)
Qr <- diag(c(4, 0))
ck("半正定 Q 的等值线是两条平行线",
   length(.rm_as_objects(quad_form_curve_obj(Qr))) == 2L)

cat("\n== 3. apply_matrix：M(f)=(1-f)I+fA 三点几何 ==\n")
A <- matrix(c(2, 0, 0, 3), 2, 2, byrow = TRUE)
sc <- scene(); sq <- unit_square_obj(); sc$add(sq)
sc$play(apply_matrix(sq, A, run_time = 1, rate = rate_linear))
idx <- sc$.find_indices(list(sq))
state_polys <- function(s, t) sc$.state_at(s, t)$polys[[1]]
a0 <- poly_area(state_polys(idx, 0))
a5 <- poly_area(state_polys(idx, 0.5))
a1 <- poly_area(state_polys(idx, 1))
cat(sprintf("  面积 f=0/0.5/1: %.3f / %.3f / %.3f（手算 1 / 3 / 6）\n", a0, a5, a1))
ck("f=0 面积 = 1",              near(a0, 1, 1e-6))
ck("f=0.5 面积 = 3 (M=diag(1.5,2))", near(a5, 3, 1e-6))
ck("f=1 面积 = 6 = det(A)",     near(a1, 6, 1e-6))
b1 <- apply(state_polys(idx, 1), 2, range)
ck("f=1 bbox = [0,2]x[0,3]",   near(c(b1[1, 1], b1[2, 1], b1[1, 2], b1[2, 2]), c(0, 2, 0, 3), 1e-6))

cat("\n== 4. 链式变换：A 之后 A⁻¹ 必须回到原状 ==\n")
sc2 <- scene(); sq2 <- unit_square_obj(); sc2$add(sq2)
sc2$play(succession(
  apply_matrix(sq2, A, run_time = 1, rate = rate_linear),
  apply_inverse(sq2, A, run_time = 1, rate = rate_linear)
))
i2 <- sc2$.find_indices(list(sq2))
P_end <- sc2$.state_at(i2, 2.5)$polys[[1]]
cat(sprintf("  末态面积 %.3f（期望 1.000）\n", poly_area(P_end)))
ck("succession(A, A⁻¹) 末态面积 = 1", near(poly_area(P_end), 1, 1e-6))
ck("succession(A, A⁻¹) 末态 bbox 复原",
   near(apply(P_end[, 1:2, drop = FALSE], 2, range),
        matrix(c(0, 1, 0, 1), 2, 2), 1e-6))

cat("\n== 5. rotate_group 与帧差异 ==\n")
sc3 <- scene(); sq3 <- unit_square_obj(); sc3$add(sq3)
sc3$play(rotate_group(sq3, pi / 2, run_time = 1, rate = rate_linear))
i3 <- sc3$.find_indices(list(sq3))
P3 <- sc3$.state_at(i3, 1.2)$polys[[1]]
r3 <- apply(P3, 2, range)
ck("逆时针 90° 后单位方格落在 [-1,0]x[0,1]",
   near(c(r3[1, 1], r3[2, 1], r3[1, 2], r3[2, 2]), c(-1, 0, 0, 1), 1e-6))

d <- normalizePath(file.path(tempdir(), "rm_probe_frames"), winslash = "/", mustWork = FALSE); dir.create(d, showWarnings = FALSE)
fs <- character(0)
for (tt in c(0.05, 0.35, 0.7, 1.05)) {
  f <- file.path(d, sprintf("p1_%.2f.png", tt))
  render_frame(sc, f, t = tt, quality = "m"); fs <- c(fs, f)
}
h <- vapply(fs, function(f) unname(tools::md5sum(f)), character(1))
ck("apply_matrix 四个时刻的帧互不相同", length(unique(h)) == 4L)

cat("\n== 6. transform(vgroup) 与 shift_group ==\n")
u <- vector_obj(c(0, 0), c(2, 0.5), color = "#58C4DD")
v <- vector_obj(c(0, 0), c(0.4, 1.9), color = "#83C167")
s4 <- scene(); s4$add(u)
s4$play(transform(u, v, run_time = 1, rate = rate_linear))
i4 <- s4$.find_indices(.rm_as_objects(u))   # group 会被摊平成多个 item
sig_state <- function(s, t) {
  P <- do.call(rbind, unlist(lapply(i4, function(k) s$.state_at(k, t)$polys),
                             recursive = FALSE))
  c(sum(P[, 1]), sum(P[, 2]), nrow(P))
}
sig_v <- local({
  parts <- .rm_as_objects(v)
  P <- do.call(rbind, unlist(lapply(parts, function(p) .rm_flatten(p$curves, p$path_id)),
                             recursive = FALSE))
  c(sum(P[, 1]), sum(P[, 2]), nrow(P))
})
ck("transform() 接受 vgroup 且末态 == 目标箭头", near(sig_state(s4, 1.2), sig_v, 1e-6))
ck("vgroup morph 中间态几何非空",
   all(vapply(i4, function(k) length(s4$.state_at(k, 0.5)$polys) > 0L, logical(1))))

s5 <- scene(); d5 <- dot_obj(0, 0, r = 0.2); s5$add(d5)
s5$play(shift_group(d5, dx = 2, dy = 1, run_time = 1, rate = rate_linear))
i5 <- s5$.find_indices(list(d5))
P5 <- do.call(rbind, s5$.state_at(i5, 1.2)$polys)
ck("shift_group 末态圆心落在 (2,1)",
   near(c(mean(range(P5[, 1])), mean(range(P5[, 2]))), c(2, 1), 1e-6))

cat(sprintf("\n== %d PASS / %d FAIL ==\n", pass, fail))
if (fail > 0L) quit(status = 1L)
