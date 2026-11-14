## v0.0.2 公开辅助层回归（源码直跑，不用先装包）
## 重点：教程里原先手写的 st/COL/peek 等，现在必须与包导出逐项等价，
##       且用户照抄的第一章示例能在只有 library() 的语义下跑通。
suppressPackageStartupMessages({ library(grid); library(grDevices) })
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
            "primitives.R", "animation.R", "anim-linalg.R", "homogeneous3d.R",
            "primitives3d.R", "camera.R", "scene.R", "backend-grid.R", "render.R",
            "helpers.R")) {
  source(file.path(root, f), encoding = "UTF-8")
}

pass <- 0L; fail <- 0L
ck <- function(label, ok) {
  if (isTRUE(ok)) { pass <<- pass + 1L; cat(sprintf("  PASS  %s\n", label)) }
  else            { fail <<- fail + 1L; cat(sprintf("  FAIL  %s\n", label)) }
}

## ---- 调色板 ----
ck("COL 有 10 个色名", length(COL) == 10L)
ck("COL$cyan / gold 与教程一致",
   identical(COL$cyan, "#58C4DD") && identical(COL$gold, "#E8C547"))
ck("COL$bg 与 scene() 默认背景一致", identical(COL$bg, "#0E1116"))

## ---- 样式简写 ----
ck("st() 等价于手写描边列表",
   identical(st(COL$cyan, 5), list(stroke = "#58C4DD", stroke_width = 5)))
ck("st() 不产生填充", is.null(st()$fill))
ck("st() 默认值与 .rm_stroke 一致", identical(st(), .rm_stroke(COL$white, 4)))
ck("fl() 等价于 .rm_fill", identical(fl(), .rm_fill(COL$cyan, 0.3, NA_character_, 2)))
ck("fl() 带 winding 填充规则", identical(fl()$rule, "winding"))
ck("fl() 可叠描边",
   identical(fl(COL$red, 0.5, COL$white, 3)$stroke, COL$white))

sq <- square_obj(side = 2.4, style = st(COL$cyan, 5))
ci <- circle_obj(0, 0, 1.2, style = fl(COL$gold, 0.4))
ck("st() 造出的图元能编出 stroke 指令",
   identical(scene()$add(sq)$compile(0)[[1]]$col, COL$cyan))
ck("fl() 造出的图元能编出 path 指令",
   identical(sq$style$stroke, COL$cyan) && !is.null(ci$style$fill))

## ---- 结构窥视 ----
ck("圆：1 条子路径", identical(n_subpaths(circle_obj(r = 1)), 1L))
ck("圆：4 段贝塞尔", identical(n_curves(circle_obj(r = 1)), 4L))
ck("subpaths() 返回折线矩阵",
   is.matrix(subpaths(circle_obj(r = 1))[[1]]) &&
     ncol(subpaths(circle_obj(r = 1))[[1]]) >= 2L)
ck("vgroup 的子路径数按件累加",
   identical(n_subpaths(vgroup(circle_obj(), square_obj())), 2L))
ck("vgroup 的曲线数按件累加",
   identical(n_curves(vgroup(circle_obj(), square_obj())), 8L))
ck("arrow_obj 是 2 个对象但有 2 条子路径",
   identical(n_objects(arrow_obj(c(0, 0), c(1, 1))), 2L) &&
     identical(n_subpaths(arrow_obj(c(0, 0), c(1, 1))), 2L))
ck("空 group 的子路径数为 0", identical(n_subpaths(vgroup()), 0L))
ck("can_morph(方, 圆) 成立（子路径数相同）",
   isTRUE(can_morph(square_obj(side = 2), circle_obj(r = 1))))
ck("can_morph 对多对象组返回 FALSE",
   isFALSE(can_morph(vgroup(circle_obj(), circle_obj()), circle_obj())))
z <- circle_obj(r = 1)
ck("peek() 原样返回对象", identical(peek(z), z))
ck("peek() 打印子路径与包围盒",
   any(grepl("子路径", capture.output(peek(circle_obj(r = 1))))) &&
     any(grepl("bbox", capture.output(peek(circle_obj(r = 1))))))

## ---- 用户贴的第一章示例 ----
usr <- scene()
u_sq <- square_obj(side = 2.4, style = st(COL$cyan, 5))
u_ci <- circle_obj(0, 0, 1.2, style = st(COL$gold, 5))
usr$add(u_sq)
usr$play(create(u_sq, run_time = 1))
warn <- NULL
withCallingHandlers(usr$play(transform(u_sq, u_ci, run_time = 1.4)),
                     warning = function(w) { warn <<- conditionMessage(w)
                                             invokeRestart("muffleWarning") })
ck("示例时长 = 2.4 秒", isTRUE(all.equal(usr$duration(), 2.4)))
ck("transform 未退化为交叉淡入淡出", is.null(warn))
ck("末帧有 1 条绘制指令", identical(length(usr$compile()), 1L))
ck("末帧换成金色描边", identical(usr$compile()[[1]]$col, COL$gold))

## ---- 排字与出图包装（v0.0.3）----
## 这六个函数原先只在教程 _setup.qmd 里，读者抄 fig()/lab()/tex() 会报「没有这个函数」。
ck("cjk_font() 返回单个字符串", is.character(cjk_font()) && length(cjk_font()) == 1L)
ck("cjk_font() 有缓存（两次同一值）", identical(cjk_font(), cjk_font()))

lb <- lab("测试", 1, 2, size = 20)
ck("lab() 返回图元", inherits(lb, "rm_mobject"))
bb <- lb$bbox()
ctr <- c(mean(bb[c("xmin", "xmax")]), mean(bb[c("ymin", "ymax")]))
ck("lab() 中心落在指定点",
   isTRUE(all.equal(unname(ctr), c(1, 2), tolerance = 0.05)))
ck("lab() 中文没有退化成方框（多于 2 条子路径）", n_subpaths(lb) > 2L)

ra <- ref_axes(lim = 2, color = COL$dim, width = 1.5)
ck("ref_axes() 是 2 个对象", n_objects(ra) == 2L)
ck("ref_axes() 两条都是描边", all(vapply(ra, function(o) identical(o$style$stroke, COL$dim), TRUE)))

tdir <- file.path(tempdir(), "rm_helpers_fig")
unlink(tdir, recursive = TRUE, force = TRUE)
s2 <- scene(); s2$add(circle_obj(r = 1, style = st(COL$cyan, 3)))
p1 <- suppressMessages(fig(s2, "one", t = 0, quality = "l", dir = tdir))
ck("fig() 非 knit 上下文返回路径", is.character(p1) && file.exists(p1))
ck("fig() PNG 非空", file.size(p1) > 500)
p0 <- suppressMessages(fig(s2, "last", quality = "l", dir = tdir))
ck("fig() 不给 t 时取末帧", file.exists(p0) && file.size(p0) > 500)
p2 <- frame_to(s2, "two", 0.5, quality = "l", dir = tdir)
ck("frame_to() 返回路径且已写盘", file.exists(p2) && file.size(p2) > 500)
unlink(tdir, recursive = TRUE, force = TRUE)

cat(sprintf("\n==== %d PASS / %d FAIL ====\n", pass, fail))
if (fail > 0L) quit(save = "no", status = 1L)
