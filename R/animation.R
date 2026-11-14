## 动画：动画对象 = 纯数据 + 三个方法（prepare / sample / final）
## 全部按"局部时间 tau"求值，因此可以跳帧、可重复渲染、可组合。

#' @export
rate_linear <- function(t) t
#' @export
rate_smooth <- function(t) t * t * (3 - 2 * t)
#' @export
rate_smoothstep <- function(t) t * t * (3 - 2 * t)
#' @export
rate_double_smooth <- function(t) rate_smooth(rate_smooth(t))
#' @export
rate_rush_into <- function(t) t * t
#' @export
rate_rush_from <- function(t) 1 - (1 - t)^2
#' @export
rate_there_and_back <- function(t) if (t < 0.5) 2 * t else 2 - 2 * t

.rm_clamp01 <- function(x) min(1, max(0, x))
.rm_alpha <- function(tau, run_time, rate) rate(.rm_clamp01(tau / run_time))

## 把一个对象/组展开成对象列表（递归摊平：组、坐标系）
.rm_as_objects <- function(x) {
  if (inherits(x, "rm_axes")) return(.rm_as_objects(x$parts))
  if (R6::is.R6(x)) return(list(x))
  if (is.list(x)) return(unlist(lapply(x, .rm_as_objects), recursive = FALSE))
  list(x)
}

## intro = TRUE 表示「入场动画」：该动画开始之前，目标对象不在画面里。
## Manim 的 Create / FadeIn 会隐式把对象加进场景；ROpenManim 要求先 add()，
## 因此必须由场景层把 add() 到 play() 之间那一段压成不可见，否则对象会提前亮相。
.rm_new_anim <- function(kind, objects, run_time, rate, intro = FALSE, ...) {
  structure(c(list(kind = kind, objects = objects, run_time = run_time, rate = rate,
                   intro = intro),
              list(...)),
            class = c(paste0("rm_anim_", kind), "rm_animation"))
}

.rm_anim_prepare <- function(a, states) UseMethod(".rm_anim_prepare")
.rm_anim_sample <- function(a, tau) UseMethod(".rm_anim_sample")

## ---- Create ---- 
#' @export
create <- function(obj, run_time = 1, rate = rate_smooth) {
  .rm_new_anim("create", .rm_as_objects(obj), run_time, rate, intro = TRUE)
}
.rm_anim_prepare.rm_anim_create <- function(a, states) {
  a$states <- states
  a$final <- states
  a
}
.rm_anim_sample.rm_anim_create <- function(a, tau) {
  f <- .rm_alpha(tau, a$run_time, a$rate)
  lapply(a$states, function(s) {
    z <- .rm_trim(s$curves, s$path_id, f)
    s$curves <- z$curves; s$path_id <- z$path_id
    s$polys <- z$polys        # 截断时已经算过折线，直接复用
    s
  })
}

## ---- FadeIn / FadeOut ---- 
#' @export
fade_in <- function(obj, run_time = 1, rate = rate_smooth, shift = 0) {
  .rm_new_anim("fade", .rm_as_objects(obj), run_time, rate,
               intro = TRUE, dir = 1, shift = shift)
}
#' @export
fade_out <- function(obj, run_time = 1, rate = rate_smooth, shift = 0) {
  .rm_new_anim("fade", .rm_as_objects(obj), run_time, rate, dir = -1, shift = shift)
}
.rm_anim_prepare.rm_anim_fade <- function(a, states) {
  a$states <- states
  a$final <- lapply(states, function(s) {
    s$opacity <- s$opacity * (if (a$dir > 0) 1 else 0)
    s
  })
  a
}
.rm_anim_sample.rm_anim_fade <- function(a, tau) {
  f <- .rm_alpha(tau, a$run_time, a$rate)
  op <- if (a$dir > 0) f else 1 - f
  lapply(a$states, function(s) {
    if (a$shift != 0) {
      ## 入场：从偏移处回到本位；出场：从本位移到偏移处
      dy <- (if (a$dir > 0) 1 - f else f) * a$shift
      s$curves <- .rm_apply_affine(s$curves, matrix(
        c(1, 0, 0, 0, 1, dy, 0, 0, 1), nrow = 3, byrow = TRUE))
      ## 位移是刚体变换，折线缓存跟着平移即可，不必重算
      if (!is.null(s$polys)) s$polys <- lapply(s$polys, function(P) { P[, 2] <- P[, 2] + dy; P })
    }
    s$opacity <- s$opacity * op
    s
  })
}

## ---- Transform ---- 
#' @export
## 两侧都摊平成对象列表后一一对应；b 可以是 vgroup（例如整支箭头），
## 也不再要求两侧对象数相同——单个目标会广播到源对象的每一个部件。
transform <- function(a, b, run_time = 1, rate = rate_smooth) {
  objs_a <- .rm_as_objects(a)
  targets <- lapply(.rm_as_objects(b), .rm_state)
  if (length(targets) == 1L) targets <- rep(targets, length(objs_a))
  if (length(targets) != length(objs_a)) {
    stop("transform(): 两侧摊平后的对象数不一致", call. = FALSE)
  }
  .rm_new_anim("transform", objs_a, run_time, rate,
               targets = targets, target = targets[[1L]])  # target 兼容旧读取
}
.rm_anim_prepare.rm_anim_transform <- function(anim, states) {
  anim$states <- states
  anim$pairs <- Map(function(s0, tg) .rm_align(s0, tg), states, anim$targets)
  anim$mode <- if (all(vapply(anim$pairs, function(p) !is.null(p), logical(1)))) "morph" else "dissolve"
  if (identical(anim$mode, "dissolve")) {
    warning("transform(): 两侧子路径数不一致，本次退化为交叉淡入淡出（v1 限制）", call. = FALSE)
  }
  anim$target_polys <- lapply(anim$targets, function(tg) .rm_flatten(tg$curves, tg$path_id))
  anim$final <- Map(function(s, tg, tp) {
    s$curves <- tg$curves
    s$path_id <- tg$path_id
    s$style <- tg$style
    s$polys <- tp
    s
  }, states, anim$targets, anim$target_polys)
  anim
}
.rm_anim_sample.rm_anim_transform <- function(anim, tau) {
  f <- .rm_alpha(tau, anim$run_time, anim$rate)
  n <- length(anim$states)
  if (identical(anim$mode, "dissolve")) {
    early <- f < 0.5
    return(lapply(seq_len(n), function(i) {
      s <- anim$states[[i]]; tg <- anim$targets[[i]]
      s$opacity <- s$opacity * if (early) (1 - 2 * f) else (2 * f - 1)
      if (!early) {
        s$curves <- tg$curves
        s$path_id <- tg$path_id
        s$polys <- anim$target_polys[[i]]
        s$style <- tg$style      # 换形状也要换样式，否则后半段用源色画目标形
      }
      s
    }))
  }
  lapply(seq_len(n), function(i) {
    .rm_morph(anim$states[[i]], anim$pairs[[i]], anim$targets[[i]], f)
  })
}

## 两个状态对齐成等点数折线（要求子路径数一致）
##
## 只把点数对齐是不够的：两条闭合路径的**起点**若落在不同位置（方的起点在下左角、
## 圆的起点在正右方），逐点插值会让中间帧朝圆心塌陷——方变圆会缩成一小团。
## 所以这里还要在循环意义下挑一个最佳起点，并统一绕向。
.rm_align <- function(sa, sb) {
  pa <- .rm_flatten(sa$curves, sa$path_id)
  pb <- .rm_flatten(sb$curves, sb$path_id)
  if (!length(pa) || length(pa) != length(pb)) return(NULL)
  lapply(seq_along(pa), function(k) {
    n <- max(nrow(pa[[k]]), nrow(pb[[k]]), 24L)
    A <- .rm_resample(pa[[k]], n)
    B <- .rm_resample(pb[[k]], n)
    list(a = A, b = .rm_match_start(A, B))
  })
}

## 让 B 的起点与绕向尽量贴合 A：闭合路径在循环意义下穷举起点（正反两个方向），
## 开放路径只比较正反。代价是 O(n^2) 的向量运算，n 通常只有几十到几百。
.rm_match_start <- function(A, B) {
  n <- nrow(A)
  if (n < 3L) return(B)
  closedA <- sqrt(sum((A[1, ] - A[n, ])^2)) < 1e-6
  closedB <- sqrt(sum((B[1, ] - B[n, ])^2)) < 1e-6
  if (!closedA || !closedB) {
    d1 <- sum((A - B)^2)
    Br <- B[n:1, , drop = FALSE]
    return(if (sum((A - Br)^2) < d1) Br else B)
  }
  A0 <- A[-n, , drop = FALSE]
  B0 <- B[-n, , drop = FALSE]
  m <- nrow(A0)
  best_d <- Inf; best <- B0
  for (rev in c(FALSE, TRUE)) {
    C <- if (rev) B0[m:1, , drop = FALSE] else B0
    for (s in seq_len(m) - 1L) {
      Cs <- if (s == 0L) C else C[c((s + 1L):m, seq_len(s)), , drop = FALSE]
      d <- sum((A0 - Cs)^2)
      if (d < best_d) { best_d <- d; best <- Cs }
    }
  }
  rbind(best, best[1L, , drop = FALSE])
}

.rm_morph <- function(s0, pairs, target, f) {
  polys <- lapply(pairs, function(p) p$a + f * (p$b - p$a))
  z <- .rm_curves_from_polys(polys)
  s0$curves <- z$curves
  s0$path_id <- z$path_id
  s0$polys <- polys        # 插值出来的折线本身就是展平结果
  if (length(target$style$stroke) == 1L && !is.na(target$style$stroke) &&
      length(s0$style$stroke) == 1L && !is.na(s0$style$stroke)) {
    s0$style$stroke <- .rm_colour_lerp(s0$style$stroke, target$style$stroke, f)
  }
  if (length(target$style$fill) == 1L && !is.na(target$style$fill) &&
      length(s0$style$fill) == 1L && !is.na(s0$style$fill)) {
    s0$style$fill <- .rm_colour_lerp(s0$style$fill, target$style$fill, f)
  }
  s0
}

## ---- 组合：在场景层展开成"叶子动画 + 时间偏移" ---- 
#' @export
animation_group <- function(..., lag_ratio = 0.5, run_time = NULL, rate = rate_smooth) {
  leaves <- list(...)
  n <- length(leaves)
  if (is.null(run_time)) {
    d <- max(vapply(leaves, `[[`, numeric(1), "run_time"))
  } else {
    d <- run_time / (1 + (n - 1) * lag_ratio)
    ## 给了总时长就必须把「每片多长」写回叶子：叶子只占 d，
    ## 否则它仍按自己的 run_time 跑，整段会在声明结束时刻还没画完。
    for (k in seq_along(leaves)) leaves[[k]]$run_time <- d
  }
  rt <- d * (1 + (n - 1) * lag_ratio)
  structure(list(leaves = leaves, lag_ratio = lag_ratio, run_time = rt, kind = "group",
                 starts = (seq_len(n) - 1) * lag_ratio * d, dur = d),
            class = "rm_anim_composite")
}

#' @export
succession <- function(..., run_time = NULL) {
  leaves <- list(...)
  d <- vapply(leaves, `[[`, numeric(1), "run_time")
  structure(list(leaves = leaves, kind = "succ", starts = c(0, cumsum(d)[-length(d)]),
                 dur = d, run_time = sum(d)),
            class = "rm_anim_composite")
}

## 展开成 list(anim=, offset=)
.rm_expand <- function(a, offset = 0) {
  if (!inherits(a, "rm_anim_composite")) return(list(list(anim = a, offset = offset)))
  out <- list()
  for (i in seq_along(a$leaves)) {
    out <- c(out, .rm_expand(a$leaves[[i]], offset + a$starts[i]))
  }
  out
}

.rm_anim_time <- function(a) if (inherits(a, "rm_anim_composite")) a$run_time else a$run_time
