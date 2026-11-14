## 相机与投影：三维图元在 compile() 里被投到二维屏幕坐标，后端不变。
## 这一步是「显示手段」，不是线性代数结论：透视缩放来自相机，不来自矩阵。
## 相机采用标准 look-at：f = 前，r = 右，u = 上；depth = 沿 f 的距离，
## 数值越大越远，画家算法按 depth 降序绘制（远的先画）。
##
## 文字 / 公式 / 参考轴是 dim = 2 的屏幕空间对象，不参与投影，
## 且固定排在最上层，避免被三维几何盖住或被透视拉歪。

.rm_cam_xyz <- function(P) {
  P <- as.matrix(P)
  if (ncol(P) < 3L) P <- cbind(P, matrix(0, nrow(P), 3L - ncol(P)))
  P[, 1:3, drop = FALSE]
}

.rm_cam_cross <- function(a, b) {
  c(a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1])
}

#' 创建一台三维相机。
#' eye / look_at / up 是世界坐标；zoom 是 unit 每世界单位的缩放；
#' type = "persp" 时按 focal / depth 做透视除法，focal 默认取相机到目标的距离
#' （于是 look_at 处的缩放恰为 zoom）。offset 把整幅三维画面在屏幕上平移。
#' @export
camera3d <- function(eye = c(6, -8, 5), look_at = c(0, 0, 0),
                     up = c(0, 0, 1), zoom = 1,
                     type = c("ortho", "persp"), focal = NULL,
                     near = 0.2, offset = c(0, 0)) {
  type <- match.arg(type)
  eye <- as.numeric(eye); look_at <- as.numeric(look_at)
  up <- as.numeric(up); offset <- as.numeric(offset)
  if (length(eye) != 3L || length(look_at) != 3L || length(up) != 3L ||
      length(offset) != 2L) {
    stop("camera3d(): eye / look_at / up 需为三维点，offset 需为二维点",
         call. = FALSE)
  }
  f <- look_at - eye
  nf <- sqrt(sum(f^2))
  if (nf < 1e-9) stop("camera3d(): eye 与 look_at 不能重合", call. = FALSE)
  f <- f / nf
  r <- .rm_cam_cross(f, up)
  nr <- sqrt(sum(r^2))
  if (nr < 1e-9) stop("camera3d(): up 与视线方向平行", call. = FALSE)
  r <- r / nr
  u <- .rm_cam_cross(r, f)
  structure(list(eye = eye, look_at = look_at, up = up,
                 f = f, r = r, u = u,
                 zoom = as.numeric(zoom), type = type,
                 focal = if (is.null(focal)) nf else as.numeric(focal),
                 near = as.numeric(near), offset = offset),
            class = "rm_camera")
}

#' 把三维点投到屏幕：返回 list(x, y, depth)，x/y 是场景 unit 坐标。
#' 可用于把二维文字标签贴到某个三维点上（构图时算一次即可）。
#' @export
project_point <- function(cam, P) {
  if (!inherits(cam, "rm_camera")) {
    stop("project_point(): cam 必须是 camera3d() 的结果", call. = FALSE)
  }
  XYZ <- .rm_cam_xyz(P)
  d <- sweep(XYZ, 2, cam$eye, "-")
  cx <- as.vector(d %*% cam$r)
  cy <- as.vector(d %*% cam$u)
  cz <- as.vector(d %*% cam$f)
  if (identical(cam$type, "persp") && any(cz < cam$near)) {
    warning("project_point(): 有点落到了相机后方或近裁剪面之前，已钳制",
            call. = FALSE)
  }
  k <- if (identical(cam$type, "persp")) {
    cam$focal / pmax(cz, cam$near)
  } else {
    rep(1, length(cz))
  }
  list(x = cam$zoom * k * cx + cam$offset[1],
       y = cam$zoom * k * cy + cam$offset[2],
       depth = cz)
}

#' 把一个三维 state 投影成屏幕空间 state。
## 每条子路径按自身平均深度排序（对象内部的前后关系），
## 整个 state 的平均深度交给 scene 做对象间排序。
.rm_project_state <- function(s, cam) {
  polys <- s$polys
  if (is.null(polys)) polys <- .rm_flatten(s$curves, s$path_id)
  if (!length(polys)) {
    s$depth <- 0
    s$dim <- 2L
    return(s)
  }
  out <- lapply(polys, function(P) {
    pr <- project_point(cam, P)
    list(P = cbind(pr$x, pr$y, 0), d = mean(pr$depth))
  })
  ds <- vapply(out, `[[`, numeric(1), "d")
  out_p <- lapply(out[order(-ds)], `[[`, "P")
  z <- .rm_curves_from_polys(out_p)
  s$curves <- z$curves
  s$path_id <- z$path_id
  s$polys <- out_p
  s$depth <- mean(ds)
  s$dim <- 2L           # 投影后已是屏幕空间，禁止二次投影
  s
}
