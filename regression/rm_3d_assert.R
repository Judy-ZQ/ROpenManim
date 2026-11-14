## ROpenManim 4x4 / 三维层回归断言
## 跑法：cd ROpenManim && env -u LC_ALL -u LANG Rscript regression/rm_3d_assert.R
## 本文件只读源码，不写任何教材资源。

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
src <- locate_src()
for (f in c("geometry.R", "mobject.R", "svgpath.R", "text.R", "tex.R", "axes.R",
            "primitives.R", "animation.R", "anim-linalg.R", "homogeneous3d.R",
            "primitives3d.R", "camera.R", "scene.R", "backend-grid.R", "render.R")) {
  source(file.path(src, f), encoding = "UTF-8")
}

pass <- 0L; fail <- 0L
ck <- function(label, ok) {
  if (isTRUE(ok)) { pass <<- pass + 1L; cat(sprintf("  PASS  %s\n", label)) }
  else            { fail <<- fail + 1L; cat(sprintf("  FAIL  %s\n", label)) }
}
near <- function(a, b, tol = 1e-6) {
  isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = tol))
}
finite_state <- function(s) {
  P <- do.call(rbind, s$polys)
  isTRUE(all(is.finite(P)))
}
bbox3 <- function(s) {
  P <- do.call(rbind, s$polys)
  c(xmin = min(P[, 1]), ymin = min(P[, 2]), zmin = min(P[, 3]),
    xmax = max(P[, 1]), ymax = max(P[, 2]), zmax = max(P[, 3]))
}
## 取某个对象（可以是 vgroup）在时刻 t 的第一个 state
one <- function(obj, anim, t) {
  sc <- scene()
  sc$add(obj)
  sc$play(anim)
  idx <- sc$.find_indices(.rm_as_objects(obj))
  list(sc = sc, st = sc$.state_at(idx[1L], t), idx = idx)
}
## 4x4 齐次矩阵作用到若干三维点，返回 N x 3
ap <- function(m, P) .rm4_homogeneous_xyz(as.matrix(P), m, w_guard = 1e-9)

cat("== 1. 4x4 齐次规范化与构造器 ==\n")
M0 <- homogeneous4_matrix(A = diag(3), b = c(1, 2, 3))
ck("归一化：m 与 3m 表示同一个变换",
   near(.rm4_as_homogeneous(M0), .rm4_as_homogeneous(3 * M0)))
ck("m[4,4]=0 被拒绝",
   inherits(try(.rm4_as_homogeneous(homogeneous4_matrix() * 0 +
                  diag(c(1, 1, 1, 0))), silent = TRUE), "try-error"))
ck("非 4x4 被拒绝",
   inherits(try(.rm4_as_homogeneous(diag(3)), silent = TRUE), "try-error"))
ck("平移解析值 (0,0,0) -> (1,2,3)",
   near(ap(translation4_matrix(1, 2, 3), rbind(c(0, 0, 0))), c(1, 2, 3)))
ck("平移不改变形状（两点差不变）",
   near(ap(translation4_matrix(1, 2, 3), rbind(c(0, 0, 0), c(1, 1, 1)))[2, ] -
        ap(translation4_matrix(1, 2, 3), rbind(c(0, 0, 0), c(1, 1, 1)))[1, ],
        c(1, 1, 1)))

Rz <- rotation4_matrix("z", pi / 2)
ck("绕 z 轴 90 度：(1,0,0) -> (0,1,0)",
   near(ap(Rz, rbind(c(1, 0, 0))), c(0, 1, 0)))
Rx <- rotation4_matrix("x", pi / 2)
ck("绕 x 轴 90 度：(0,1,0) -> (0,0,1)",
   near(ap(Rx, rbind(c(0, 1, 0))), c(0, 0, 1)))
u <- c(1, 1, 1) / sqrt(3)
Ra <- rotation4_matrix(u, 0.7)
A <- Ra[1:3, 1:3]
ck("绕任意轴的线性部正交", near(as.vector(t(A) %*% A), as.vector(diag(3))))
ck("绕任意轴 det R = 1", near(det(A), 1))
ck("轴向在旋转下不动", near(as.vector(A %*% u), u))
ck("绕任意轴是仿射（m[4,1:3]=0）", .rm4_is_affine(Ra))

Pn <- projection4_matrix(n = c(0, 0, 1))
ck("投到 xy 平面 = diag(1,1,0)", near(Pn[1:3, 1:3], diag(c(1, 1, 0))))
ck("平面投影秩 2 / det 0", near(det(Pn[1:3, 1:3]), 0) &&
     near(qr(Pn[1:3, 1:3])$rank, 2))
Pv <- projection4_matrix(v = c(1, 2, 3))
ck("投到直线秩 1", near(qr(Pv[1:3, 1:3])$rank, 1))
ck("投影幂等 P^2 = P", near(Pv[1:3, 1:3] %*% Pv[1:3, 1:3], Pv[1:3, 1:3]))
ck("透视解析值 (2,0,0) -> 2/1.2",
   near(ap(perspective4_matrix(p = 0.1), rbind(c(2, 0, 0))), c(2 / 1.2, 0, 0)))
ck("透视不是仿射", !.rm4_is_affine(perspective4_matrix(p = 0.1)))

T <- translation4_matrix(1, 0, 0)
m_TR <- rm_compose4(T, Rz)
m_RT <- rm_compose4(Rz, T)
ck("复合顺序不可交换",
   !near(ap(m_TR, rbind(c(0, 0, 0))), ap(m_RT, rbind(c(0, 0, 0)))))
ck("先平移后旋转：(0,0,0) -> (0,1,0)",
   near(ap(m_TR, rbind(c(0, 0, 0))), c(0, 1, 0)))
ck("先旋转后平移：(0,0,0) -> (1,0,0)",
   near(ap(m_RT, rbind(c(0, 0, 0))), c(1, 0, 0)))

cat("\n== 2. 仿射动画路径（逐帧 / z 真的变了）==\n")
o2 <- cube3d_obj(side = 2)
z2 <- one(o2, apply_matrix(o2, translation4_matrix(0, 0, 3),
                           run_time = 1, rate = rate_linear), 0.5)
ck("apply_matrix() 自动分派 4x4", identical(z2$st$dim, 3L))
ck("f=0.5 的 z 位移 = 1.5",
   near(bbox3(z2$st)[3] - (-1), 1.5, 1e-5))
ck("仿射终态 z 位移 = 3",
   near(bbox3(one(o2, apply_matrix3d(o2, translation4_matrix(0, 0, 3),
                 run_time = 1, rate = rate_linear), 1)$st)[3] - (-1), 3, 1e-5))
ck("仿射路径点数不变",
   length(z2$st$curves) == length(.rm_state(.rm_as_objects(o2)[[1L]])$curves))
ck("仿射终态有限", finite_state(z2$st))
ck("dim 标记穿透动画层", identical(z2$st$dim, 3L))

## 绕非原点旋转：中心 (1,1,0) 应不动
o2b <- line3d_obj(c(1, 1, 0), c(2, 1, 0))
z2b <- one(o2b, rotate3d_group(o2b, "z", pi / 2, about = c(1, 1, 0),
                              run_time = 1, rate = rate_linear), 1)
ck("绕 (1,1,0) 旋转：旋转中心不动",
   near(z2b$st$polys[[1L]][1, 1:2], c(1, 1), 1e-5))
ck("绕 (1,1,0) 旋转：另一端 -> (1,2)",
   near(z2b$st$polys[[1L]][nrow(z2b$st$polys[[1L]]), 1:2], c(1, 2), 1e-5))

## shift3d_group 与 translation4_matrix 逐点等价
o2c <- line3d_obj(c(0, 0, 0), c(1, 1, 1))
sa <- one(o2c, shift3d_group(o2c, 1, 2, 3, run_time = 1,
                             rate = rate_linear), 1)$st
sb <- one(o2c, apply_matrix3d(o2c, translation4_matrix(1, 2, 3),
                              run_time = 1, rate = rate_linear), 1)$st
ck("shift3d_group 等于 translation4_matrix",
   near(do.call(rbind, sa$polys), do.call(rbind, sb$polys)))

cat("\n== 3. 逆变换与链式终态 ==\n")
Mi <- homogeneous4_matrix(A = matrix(c(2, 0, 0, 0, 3, 0, 0, 0, 1), 3, 3),
                          b = c(0.5, 0, 0))
o3 <- cube3d_obj()
sc3 <- scene(); sc3$add(o3)
sc3$play(succession(
  apply_matrix3d(o3, Mi, run_time = 1, rate = rate_linear),
  apply_inverse(o3, Mi, run_time = 1, rate = rate_linear)
))
idx3 <- sc3$.find_indices(.rm_as_objects(o3))[1L]
st3 <- sc3$.state_at(idx3, 2)
st30 <- sc3$.state_at(idx3, 0)
ck("succession(M, M^-1) 末态回到初态",
   near(do.call(rbind, st3$polys), do.call(rbind, st30$polys), 1e-5))
ck("apply_inverse() 对 4x4 可用", finite_state(st3))
ck("奇异 4x4 求逆被拒绝",
   inherits(try(apply_inverse3d(o3, projection4_matrix()), silent = TRUE),
            "try-error"))

cat("\n== 4. 射影路径与消失面断开 ==\n")
o4 <- line3d_obj(c(-3, 0, 0), c(3, 0, 0))
warn4 <- FALSE
z4 <- withCallingHandlers(
  one(o4, apply_matrix3d(o4, perspective4_matrix(p = 0.5),
                         run_time = 1, rate = rate_linear), 1),
  warning = function(w) { warn4 <<- TRUE; invokeRestart("muffleWarning") })
ck("消失面 x=-2 穿过线段时给出 warning", warn4)
ck("跨消失面的折线被拆成 2 条子路径",
   length(unique(z4$st$path_id)) == 2L)
ck("射影终态无 NaN / Inf", finite_state(z4$st))
ck("射影终态 dim 仍为 3", identical(z4$st$dim, 3L))
## 不跨越消失面时保持一条子路径
o4b <- line3d_obj(c(0, 0, 0), c(1, 1, 1))
z4b <- suppressWarnings(
  one(o4b, apply_matrix3d(o4b, perspective4_matrix(p = 0.1),
                          run_time = 1, rate = rate_linear), 1))
ck("未跨消失面时子路径数不变", length(unique(z4b$st$path_id)) == 1L)
ck("射影解析值 (1,1,1) -> 1/1.1",
   near(ap(perspective4_matrix(p = 0.1), rbind(c(1, 1, 1))),
        c(1 / 1.1, 1 / 1.1, 1 / 1.1)))
ck("curves 与 polys 逐点一致（射影）",
   near(do.call(rbind, lapply(.rm_flatten(z4b$st$curves, z4b$st$path_id),
                              function(P) P)),
        do.call(rbind, z4b$st$polys), 1e-5))

cat("\n== 5. 相机投影解析值 ==\n")
cam <- camera3d(eye = c(0, -10, 0), look_at = c(0, 0, 0),
                up = c(0, 0, 1), type = "ortho", zoom = 1)
p0 <- project_point(cam, rbind(c(0, 0, 0), c(1, 0, 0), c(0, 0, 1)))
ck("正交投影：原点 -> 屏幕原点", near(c(p0$x[1], p0$y[1]), c(0, 0)))
ck("正交投影：depth = |eye| = 10", near(p0$depth[1], 10))
ck("正交投影：+x -> (1,0)", near(c(p0$x[2], p0$y[2]), c(1, 0)))
ck("正交投影：+z -> (0,1)", near(c(p0$x[3], p0$y[3]), c(0, 1)))
ck("相机基向量正交归一",
   near(c(sum(cam$f^2), sum(cam$r^2), sum(cam$u^2)), c(1, 1, 1)) &&
     near(c(sum(cam$r * cam$u), sum(cam$r * cam$f), sum(cam$u * cam$f)), c(0, 0, 0)))
ck("up 与视线平行时报错",
   inherits(try(camera3d(eye = c(0, 0, 5), up = c(0, 0, 1)), silent = TRUE),
            "try-error"))
camps <- camera3d(eye = c(0, -10, 0), type = "persp", zoom = 1, focal = 10)
ps <- project_point(camps, rbind(c(0, 0, 0), c(0, -5, 0)))
ck("透视投影：目标平面上 k = 1", near(c(ps$x[1], ps$y[1]), c(0, 0)))
ck("透视投影：近处被放大（depth 5 -> k 2）", near(ps$depth[2], 5))
pnear <- project_point(camps, rbind(c(1, -5, 0)))
ck("透视投影：近处 x 放大到 2", near(pnear$x[1], 2))

cat("\n== 6. scene 集成：投影 / 深度排序 / 屏幕空间标注 ==\n")
far <- line3d_obj(c(-1, 3, 0), c(1, 3, 0), color = "#FF0000")
closer <- line3d_obj(c(-1, -3, 0), c(1, -3, 0), color = "#00FF00")
label2d <- line_obj(c(0, 0), c(1, 0), .rm_stroke("#FFFFFF", 3))
sc6 <- scene(camera = cam)
sc6$add(far); sc6$add(closer); sc6$add(label2d)
ops6 <- sc6$compile(0)
cols <- vapply(ops6, function(o) if (is.null(o$col)) "" else o$col, character(1))
ck("画家算法：远的对象先画", identical(cols[1], "#FF0000"))
ck("画家算法：近的对象后画", identical(cols[2], "#00FF00"))
ck("屏幕空间标注固定最上层", identical(cols[3], "#FFFFFF"))
ck("2D 标注坐标未被投影", near(ops6[[3L]]$x, c(0, 1)))
ck("3D 对象确实被投影（y 被压到 0）", near(ops6[[1L]]$y, c(0, 0), 1e-5))
ck("投影后 state 的 dim 变成 2（不二次投影）",
   identical(.rm_project_state(sc6$.state_at(1L, 0), cam)$dim, 2L))
sc6$set_camera(NULL)
ops6b <- sc6$compile(0)
ck("set_camera(NULL) 回到纯二维",
   near(ops6b[[1L]]$y, c(3, 3)) && length(ops6b) == 3L)
sc6$set_camera(cam)
ck("恢复相机后重新生效", near(sc6$compile(0)[[1L]]$y, c(0, 0), 1e-5))

cat("\n== 7. 三维图元构造 ==\n")
cube <- .rm_as_objects(cube3d_obj(side = 2))
ck("cube3d_obj 有 12 条棱", length(cube) == 12L)
ck("cube 所有部件 dim=3", all(vapply(cube, function(o) identical(o$dim, 3L), logical(1))))
vv <- list(v1 = c(2, 0, 0), v2 = c(0, 3, 0), v3 = c(0, 0, 1.5))
pp <- .rm_as_objects(parallelepiped3d_obj(vv$v1, vv$v2, vv$v3))
got <- unique(round(do.call(rbind, lapply(pp, function(o) {
  o$curves[[1L]][c(1L, 4L), 1:3, drop = FALSE]
})), 6))
G <- expand.grid(0:1, 0:1, 0:1)
want <- unique(round(t(apply(G, 1, function(a) {
  as.numeric(a[1]) * vv$v1 + as.numeric(a[2]) * vv$v2 + as.numeric(a[3]) * vv$v3
})), 6))
key <- function(M) paste(apply(M, 1, function(r) paste(r, collapse = ",")),
                         collapse = "|", sep = "")
ck("平行六面体 8 个角点正确", identical(sort(strsplit(key(got), "\\|")[[1L]]),
                                     sort(strsplit(key(want), "\\|")[[1L]])))
ck("体积 = |det(v1,v2,v3)| = 9",
   near(abs(det(cbind(vv$v1, vv$v2, vv$v3))), 9))
facets <- .rm_as_objects(cube3d_obj(fill = "#58C4DD"))
ck("cube3d_obj 带填充时 6 个面 + 12 条棱", length(facets) == 18L)
for (nm in c("axes3d", "grid3d", "plane3d", "vector3d", "basis3d",
             "point3d", "surface3d")) {
  obj <- switch(nm,
    axes3d = axes3d_obj(lim = 2),
    grid3d = grid3d_obj(c(-1, 1), c(-1, 1), step = 1),
    plane3d = plane3d_obj(size = 1, step = 1),
    vector3d = vector3d_obj(c(0, 0, 0), c(1, 1, 1)),
    basis3d = basis3d_obj(),
    point3d = point3d_obj(c(1, 2, 3)),
    surface3d = surface3d_obj(function(x, y) x^2 + y^2,
                              c(-1, 1), c(-1, 1), nx = 5, ny = 5))
  parts <- .rm_as_objects(obj)
  ck(sprintf("%s 可构造且部件均为 dim=3", nm),
     length(parts) > 0L &&
       all(vapply(parts, function(o) identical(o$dim, 3L), logical(1))))
}
ck("surface3d_obj 网格线数 = nx+ny",
   length(.rm_as_objects(surface3d_obj(function(x, y) x^2 + y^2,
                                      c(-1, 1), c(-1, 1), nx = 5, ny = 7))) == 12L)

cat("\n== 8. 二维兼容性（旧行为不变）==\n")
sq <- unit_square_obj()
ck("二维图元 dim=2", identical(sq$dim, 2L))
A2 <- matrix(c(1, 0.5, 0, 1), 2, 2)
z8 <- one(sq, apply_matrix(sq, A2, run_time = 1, rate = rate_linear), 1)
ck("2x2 变换后 dim 仍为 2", identical(z8$st$dim, 2L))
P0 <- rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1))
ck("2x2 变换逐点等于 P0 %*% t(A)",
   near(as.vector(z8$st$polys[[1L]][1:4, 1:2]),
        as.vector(P0 %*% t(A2)), 1e-5))
sc8 <- scene()
sc8$add(sq)
ck("无相机时 compile 走原路径", length(sc8$compile(0)) >= 1L)
ck("二维场景不调用投影函数", identical(sc8$.state_at(1L, 0)$dim, 2L))

cat(sprintf("\n== %d PASS / %d FAIL ==\n", pass, fail))
if (fail > 0L) quit(status = 1L)
