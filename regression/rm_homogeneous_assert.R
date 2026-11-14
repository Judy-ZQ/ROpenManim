## ROpenManim 齐次 3x3 变换回归断言
## 覆盖：构造器 / 代表元归一化 / 复合顺序 / 平移 / 绕任意点旋转 /
##       正交投影 / 射影透视除法 / 消失线防护 / 链式逆还原 / 帧差异
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
near <- function(a, b, tol = 1e-6) {
  isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = tol))
}
bbox_state <- function(st) {
  P <- do.call(rbind, st$polys)
  c(min(P[, 1]), max(P[, 1]), min(P[, 2]), max(P[, 2]))
}
poly_area <- function(P) {
  x <- P[, 1]; y <- P[, 2]; n <- length(x)
  0.5 * abs(sum(x * c(y[-1], y[1]) - c(x[-1], x[1]) * y))
}
## 单对象场景 + 一个变换，取指定时刻的 state
one <- function(obj, anim, t) {
  sc <- scene(); sc$add(obj); sc$play(anim)
  ## group（如 grid_obj）会被 add() 摊平成多个 item，必须按摊平后的对象找下标
  idx <- sc$.find_indices(.rm_as_objects(obj))
  sts <- lapply(idx, function(i) sc$.state_at(i, t))
  st <- list(curves  = unlist(lapply(sts, `[[`, "curves"), recursive = FALSE),
             path_id = unlist(lapply(sts, `[[`, "path_id"), use.names = FALSE),
             polys   = unlist(lapply(sts, `[[`, "polys"), recursive = FALSE),
             style   = sts[[1L]]$style,
             opacity = sts[[1L]]$opacity)
  list(sc = sc, st = st, idx = idx, sts = sts)
}
finite_state <- function(st) {
  all(vapply(st$polys, function(P) all(is.finite(P[, 1:2])), logical(1)))
}

cat("== 1. 齐次矩阵构造器与代表元归一化 ==\n")
ck("homogeneous_matrix() 默认 = I3",
   near(homogeneous_matrix(), diag(3)))
T <- translation_matrix(2, -1)
ck("translation_matrix(2,-1) 平移在第三列",
   near(T, rbind(c(1, 0, 2), c(0, 1, -1), c(0, 0, 1))))
ck("affine_matrix(A,b) = [A b; 0 0 1]",
   near(affine_matrix(matrix(c(2, 0, 0, 3), 2, 2, byrow = TRUE), c(1, 1)),
        rbind(c(2, 0, 1), c(0, 3, 1), c(0, 0, 1))))
ck("perspective_matrix(0.15,-0.1) 第三行 = (0.15,-0.1,1)",
   near(perspective_matrix(0.15, -0.1)[3, ], c(0.15, -0.1, 1)))
P1 <- projection_matrix(c(1, 1))
ck("projection_matrix(1,1) = [[.5,.5],[.5,.5]]",
   near(P1, rbind(c(.5, .5, 0), c(.5, .5, 0), c(0, 0, 1))))
ck("正交投影幂等 P^2 = P", near(P1 %*% P1, P1))
ck("正交投影 det = 0（秩 1）", abs(det(P1)) < 1e-12)
M3 <- perspective_matrix(0.1, 0)
ck("代表元归一化：3*M 与 M 归一化后相同",
   near(.rm_as_homogeneous(3 * M3), .rm_as_homogeneous(M3)))
ck("2x2 自动提升为 3x3 仿射",
   near(.rm_as_homogeneous(matrix(c(2, 0, 0, 3), 2, 2)),
        rbind(c(2, 0, 0), c(0, 3, 0), c(0, 0, 1))))
ck("m[3,3]=0 被拒绝",
   inherits(try(.rm_as_homogeneous(rbind(c(1, 0, 0), c(0, 1, 0), c(0, 0, 0))),
                silent = TRUE), "try-error"))
ck("非 2x2 / 3x3 被拒绝",
   inherits(try(.rm_as_homogeneous(diag(4)), silent = TRUE), "try-error"))
R <- .rm_rotate_m(pi / 2)
ck("rm_compose(T,R) = R %*% T（先平移后旋转）",
   near(rm_compose(T, R), R %*% T))
ck("复合顺序不可交换", !isTRUE(all.equal(rm_compose(T, R), rm_compose(R, T))))
ck("rm_compose 无参数返回 I3", near(rm_compose(), diag(3)))

cat("\n== 2. 平移（3x3 仿射，形状不变） ==\n")
sq <- unit_square_obj()
z <- one(sq, apply_matrix(sq, T, run_time = 1, rate = rate_linear), 1.2)
ck("translation_matrix(2,-1) 末态 bbox = [2,3]x[-1,0]",
   near(bbox_state(z$st), c(2, 3, -1, 0)))
ck("平移保持面积 = 1", near(poly_area(z$st$polys[[1]]), 1))
o_half <- unit_square_obj()
z5 <- one(o_half, apply_matrix(o_half, T, run_time = 1, rate = rate_linear), 0.5)
ck("f=0.5 平移量 = (1,-0.5)",
   near(bbox_state(z5$st), c(1, 2, -0.5, 0.5)))
ck("affine_matrix(diag(2), b) 与 translation_matrix 等价",
   near(affine_matrix(diag(2), c(2, -1)), T))
## shift_group 已委托给 translation_matrix，两个场景逐点比对
s_sh <- unit_square_obj(); s_hm <- unit_square_obj()
a <- one(s_sh, shift_group(s_sh, dx = 2, dy = -1, run_time = 1, rate = rate_linear), 1.2)
b <- one(s_hm, apply_matrix(s_hm, T, run_time = 1, rate = rate_linear), 1.2)
ck("shift_group 与 3x3 平移逐点一致",
   near(as.numeric(do.call(rbind, a$st$polys)),
        as.numeric(do.call(rbind, b$st$polys))))

cat("\n== 3. 绕任意点旋转（齐次平移部） ==\n")
o3 <- unit_square_obj()
z3 <- one(o3, rotate_group(o3, pi / 2, about = c(1, 1), run_time = 1,
                           rate = rate_linear), 1.2)
ck("绕 (1,1) 转 90° 后 bbox = [1,2]x[0,1]",
   near(bbox_state(z3$st), c(1, 2, 0, 1)))
ck("绕点旋转保持面积 = 1", near(poly_area(z3$st$polys[[1]]), 1))
o3b <- unit_square_obj()
z3b <- one(o3b, rotate_group(o3b, pi / 2, run_time = 1, rate = rate_linear), 1.2)
ck("about=(0,0) 与旧 2x2 行为一致（[-1,0]x[0,1]）",
   near(bbox_state(z3b$st), c(-1, 0, 0, 1)))

cat("\n== 4. 正交投影（教材意义的投影） ==\n")
o4 <- unit_square_obj()
z4 <- one(o4, apply_matrix(o4, projection_matrix(c(1, 0)), run_time = 1,
                           rate = rate_linear), 1.2)
ck("投影到 x 轴后 bbox 的 y 全为 0",
   near(bbox_state(z4$st), c(0, 1, 0, 0)))
ck("投影后面积 = 0", abs(poly_area(z4$st$polys[[1]])) < 1e-9)
ck("奇异投影的 apply_inverse 被拒绝",
   inherits(try(apply_inverse(o4, projection_matrix(c(1, 0))), silent = TRUE),
            "try-error"))

cat("\n== 5. 射影（透视除法） ==\n")
o5 <- unit_square_obj()
z5p <- one(o5, apply_matrix(o5, M3, run_time = 1, rate = rate_linear), 1.2)
## w = 1 + 0.1*x；(1,0) -> (1/1.1, 0)，(1,1) -> (1/1.1, 1/1.1)
ck("p=0.1 末态 (1,0) 落在 x=1/1.1（透视除法生效）",
   near(bbox_state(z5p$st)[2], 1 / 1.1))
ck("末态不是仿射（x_max 明显 < 1）", bbox_state(z5p$st)[2] < 0.95)
ck("末端 y 上界 = 1（x=0 一侧 w=1，未被压缩）",
   near(bbox_state(z5p$st)[4], 1))
ck("点 (1,1) 射影后 = (1/1.1, 1/1.1)",
   near(.rm_homogeneous_xy(rbind(c(1, 1)), M3)[1, ], c(1 / 1.1, 1 / 1.1)))
ck("射影结果无 NaN / Inf", finite_state(z5p$st))
o5b <- unit_square_obj()
z5m <- one(o5b, apply_matrix(o5b, M3, run_time = 1, rate = rate_linear), 0.5)
ck("f=0.5 时 w=1+0.05x，(1,0) 落在 1/1.05",
   near(bbox_state(z5m$st)[2], 1 / 1.05))
## 真贝塞尔对象：射影分支必须展平后重建，段数显著增加
circ <- circle_obj(0, 0, 1)
zc <- one(circ, apply_matrix(circ, M3, run_time = 1, rate = rate_linear), 1.2)
ck("圆的射影结果由折线重建（段数 > 原 4 段）",
   length(zc$st$curves) > 4L)
Pc <- do.call(rbind, .rm_flatten(zc$st$curves, zc$st$path_id, tol = 1e-3))
Pp <- do.call(rbind, zc$st$polys)
ck("射影 state 的 curves 与 polys 逐点一致",
   near(Pc[, 1:2], Pp[, 1:2], 1e-6))
## 平移 + 射影同时生效
Mboth <- perspective_matrix(0.1, 0, b = c(0, 1))
ob <- unit_square_obj()
zb <- one(ob, apply_matrix(ob, Mboth, run_time = 1, rate = rate_linear), 1.2)
ck("b 与 w 可同时生效（y 下界 = 1/1.1）", near(bbox_state(zb$st)[3], 1 / 1.1))

cat("\n== 6. 消失线防护与链式逆还原 ==\n")
warn_seen <- FALSE
og <- grid_obj(c(-2, 2), c(-2, 2), 1)
zg <- withCallingHandlers(
  one(og, apply_matrix(og, perspective_matrix(1, 0), run_time = 1,
                       rate = rate_linear), 1.2),
  warning = function(w) { warn_seen <<- TRUE; invokeRestart("muffleWarning") })
ck("消失线穿过图形时给出 warning", warn_seen)
ck("消失线附近仍不产生 NaN / Inf", finite_state(zg$st))
ck("跨消失线的折线被拆成更多子路径（10 -> >10）", length(zg$st$polys) > 10L)
## 射影的逆：单段
oi <- unit_square_obj()
zi <- one(oi, apply_inverse(oi, M3, run_time = 1, rate = rate_linear), 1.2)
ck("apply_inverse 对 3x3 射影可用", finite_state(zi$st))
ck("逆矩阵 w 部取负", near(.rm_as_homogeneous(solve(M3))[3, 1], -0.1))
## 链式：M 之后 M^(-1) 必须回到单位方格
sc6 <- scene(); sq6 <- unit_square_obj(); sc6$add(sq6)
sc6$play(succession(
  apply_matrix(sq6, M3, run_time = 1, rate = rate_linear),
  apply_inverse(sq6, M3, run_time = 1, rate = rate_linear)
))
i6 <- sc6$.find_indices(list(sq6))
st6 <- sc6$.state_at(i6, 2.5)
ck("succession(M, M^(-1)) 末态 bbox 复原",
   near(bbox_state(st6), c(0, 1, 0, 1), 1e-4))
ck("succession(M, M^(-1)) 末态面积复原", near(poly_area(st6$polys[[1]]), 1, 1e-4))

cat("\n== 7. 帧差异（动画确实在动） ==\n")
d <- normalizePath(file.path(tempdir(), "rm_probe_frames"), winslash = "/", mustWork = FALSE); dir.create(d, showWarnings = FALSE)
fs <- character(0)
for (tt in c(0.05, 0.35, 0.7, 1.05)) {
  f <- file.path(d, sprintf("hm_%.2f.png", tt))
  render_frame(zg$sc, f, t = tt, quality = "m"); fs <- c(fs, f)
}
h <- vapply(fs, function(f) unname(tools::md5sum(f)), character(1))
ck("射影动画四个时刻的帧互不相同", length(unique(h)) == 4L)

cat(sprintf("\n== %d PASS / %d FAIL ==\n", pass, fail))
if (fail > 0L) quit(status = 1L)
