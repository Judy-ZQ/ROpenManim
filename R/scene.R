## 场景：图元按 z 序排列；时间轴上记录"段"，每段是若干叶子动画 + 时间偏移。
## 帧的求值是纯函数 compile(t) —— 不依赖播放步进，因此可任意跳帧。

#' @export
rm_scene <- R6::R6Class(
  "rm_scene",
  public = list(
    items = NULL,
    segments = NULL,
    time = 0,
    background = "#0E1116",
    width = NULL,
    height = NULL,
    camera = NULL,

    initialize = function(background = "#0E1116", width = NULL, height = NULL,
                          camera = NULL) {
      self$items <- list()
      self$segments <- list()
      self$background <- background
      self$width <- width %||% (rm_frame_height * rm_aspect)
      self$height <- height %||% rm_frame_height
      self$camera <- camera
      invisible(self)
    },

    ## 设置/更换三维相机；传 NULL 可关掉投影（回到纯二维）
    set_camera = function(cam) {
      self$camera <- cam
      invisible(self)
    },

    ## 加入图元（组/坐标系会被摊平）
    add = function(obj) {
      objs <- .rm_as_objects(obj)
      for (o in objs) {
        st <- .rm_state(o)
        st$polys <- .rm_flatten(st$curves, st$path_id)   # 静止图元只展平一次
        self$items[[length(self$items) + 1L]] <- list(
          obj = o, base = st, birth = self$time
        )
      }
      invisible(self)
    },

    wait = function(d = 1) {
      self$time <- self$time + d
      invisible(self)
    },

    play = function(anim, run_time = NULL) {
      ## play() 只收一个动画。多给的那个会按位置落到 run_time 上，被静悄悄
      ## 吞掉（时长变成一个 list，算出来的时间全是垃圾）。这里直接拦住。
      if (!is.null(run_time) &&
          (!is.numeric(run_time) || length(run_time) != 1L)) {
        stop("play() 只支持一个动画；要同时播放多个请用 animation_group(...)",
             call. = FALSE)
      }
      if (!is.null(run_time)) anim$run_time <- run_time
      leaves <- .rm_expand(anim)
      prepared <- list()
      ## 同一个 play() 内若有多个叶子接连作用于同一对象（succession / 链式
      ## apply_matrix），后面的叶子必须从前面叶子的终态出发；否则第二个变换
      ## 会错误地从 play 开始时的原始状态起算（例如 A 之后再 A^(-1) 回不到 I）。
      carried <- list()
      for (lf in leaves) {
        idx <- self$.find_indices(lf$anim$objects)
        if (!length(idx)) {
          warning("play(): 有动画目标不在场景里，已跳过", call. = FALSE)
          next
        }
        states <- lapply(idx, function(i) {
          k <- as.character(i)
          if (!is.null(carried[[k]])) carried[[k]] else self$.state_at(i, self$time)
        })
        a <- .rm_anim_prepare(lf$anim, states)
        for (j in seq_along(idx)) carried[[as.character(idx[j])]] <- a$final[[j]]
        ## 记录叶子的绝对起止时间（含 composite 的错峰偏移），
        ## 避免用整段 t1 判断时把还没结束的叶子提前赋成终态。
        prepared[[length(prepared) + 1L]] <- list(
          idx = idx, offset = lf$offset, anim = a,
          t0 = self$time + lf$offset,
          t1 = self$time + lf$offset + a$run_time
        )
      }
      if (!length(prepared)) return(invisible(self))
      t0 <- self$time
      t1 <- t0 + .rm_anim_time(anim)
      self$segments[[length(self$segments) + 1L]] <- list(t0 = t0, t1 = t1, leaves = prepared)
      self$time <- t1
      invisible(self)
    },

    duration = function() self$time,

    compile = function(t = self$time) {
      ops <- list(); depths <- numeric(0)
      for (i in seq_along(self$items)) {
        st <- self$.state_at(i, t)
        if (is.null(st)) next
        ## 屏幕空间对象（文字/公式/参考轴）不投影，且固定最上层：
        ## 给 -Inf 的深度，按 -depth 升序排时它落在最后绘制。
        d <- -Inf
        if (!is.null(self$camera) && identical(as.integer(st$dim), 3L)) {
          st <- .rm_project_state(st, self$camera)
          d <- if (is.finite(st$depth)) st$depth else 0
        }
        o <- .rm_ops(st)
        if (length(o)) {
          ops <- c(ops, o)
          depths <- c(depths, rep(d, length(o)))
        }
      }
      ## 画家算法：depth 大（远）的先画；第二关键字保证同深度稳定保序。
      if (!is.null(self$camera) && length(ops) > 1L) {
        ops <- ops[order(-depths, seq_along(depths))]
      }
      ops
    },

    ## 内部：按引用找到图元在场景里的下标
    .find_indices = function(objs) {
      which(vapply(self$items, function(it) {
        any(vapply(objs, function(o) identical(it$obj, o), logical(1)))
      }, logical(1)))
    },

    ## 内部：某个图元在时刻 t 的状态
    .state_at = function(i, t) {
      it <- self$items[[i]]
      if (t < it$birth) return(NULL)

      ## 收集该图元参与的全部叶子动画（声明顺序即时间顺序）
      mine <- list()
      for (seg in self$segments) {
        for (lf in seg$leaves) {
          p <- match(i, lf$idx)
          if (is.na(p)) next
          mine[[length(mine) + 1L]] <- list(
            anim = lf$anim, p = p, t0 = lf$t0, t1 = lf$t1
          )
        }
      }

      ## 入场动画（create / fade_in）开始前：对象还没进画面。
      ## 这一步必须在 play() 之外做，因为 add() 与 play() 之间可以隔任意多段。
      intro_start <- Inf
      for (z in mine) {
        if (isTRUE(z$anim$intro)) intro_start <- min(intro_start, z$t0)
      }
      ## 没有入场动画的对象 intro_start 仍是 Inf，不能拿它跟 t 比
      if (is.finite(intro_start) && t < intro_start) return(NULL)

      st <- it$base
      for (z in mine) {
        if (t >= z$t1) {
          st <- z$anim$final[[z$p]]
        } else if (t >= z$t0) {
          st <- .rm_anim_sample(z$anim, t - z$t0)[[z$p]]
        }
      }
      st
    }
  )
)

#' @export
scene <- function(background = "#0E1116", width = NULL, height = NULL,
                  camera = NULL) {
  rm_scene$new(background = background, width = width, height = height,
               camera = camera)
}
