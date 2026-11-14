## 输出：逐帧渲染 + 编码

## grDevices::png() 与 av::av_encode_video() 都要求输出文件的父目录已经存在。
## 教程的构建脚本自己建了 animations/，但读者在干净会话里照抄
## render(sc, "animations/x.mp4") 会在全部帧画完之后才被 av 拒绝。
## 这里统一兜住：嵌套目录也递归创建，创建不了就早失败、别白渲染。
.rm_prepare_output <- function(file) {
  d <- dirname(file)
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(d)) stop("无法创建输出目录：", d, call. = FALSE)
  }
  invisible(file)
}

## dur 由多个 run_time 浮点累加，例如 1.2 + 1.0 + 0.6 = 2.8000000000000003，
## 乘 30 得 84.000000000000014，ceiling() 就会多出一帧（85 而非 84）。
## 减一个远小于 1 帧的容差再取整。
.rm_n_frames <- function(dur, fps) {
  max(1L, as.integer(ceiling(dur * fps - 1e-9)))
}

.rm_quality <- function(quality = "h") {
  switch(as.character(quality),
    l = list(w = 854L, h = 480L, fps = 15),
    m = list(w = 1280L, h = 720L, fps = 30),
    h = list(w = 1920L, h = 1080L, fps = 60),
    k = list(w = 3840L, h = 2160L, fps = 60),
    stop("quality 只能是 l / m / h / k", call. = FALSE)
  )
}

.rm_open_device <- function(file, w, h) {
  ok <- capabilities("cairo")
  if (ok) {
    grDevices::png(file, width = w, height = h, units = "px", res = 72,
                   type = "cairo", bg = "transparent")
  } else {
    grDevices::png(file, width = w, height = h, units = "px", res = 72,
                   bg = "transparent")
  }
}

#' @export
render_frame <- function(sc, file, t = 0, quality = "h") {
  q <- .rm_quality(quality)
  .rm_prepare_output(file)
  .rm_open_device(file, q$w, q$h)
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  grid::grid.rect(gp = grid::gpar(fill = sc$background, col = NA))
  .rm_draw_ops(sc$compile(t), height_px = q$h, res = 72)
  invisible(file)
}

#' @export
last_frame <- function(sc, file, quality = "h") {
  render_frame(sc, file, t = max(0, sc$duration() - 1e-6), quality = quality)
}

#' @export
render <- function(sc, file = "manim.mp4", fps = NULL, quality = "h",
                   verbose = TRUE, keep_frames = FALSE) {
  q <- .rm_quality(quality)
  fps <- fps %||% q$fps
  dur <- sc$duration()
  if (dur <= 0) stop("场景时长为 0：先 play() 一些动画", call. = FALSE)
  ## 先检查输出目录：别等 84 帧都画完了才发现没地方写 mp4。
  .rm_prepare_output(file)
  n <- .rm_n_frames(dur, fps)
  dir <- tempfile("rm_frames_")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ## keep_frames = TRUE 时把逐帧 PNG 留下来（排查「某一帧画错了」很方便），
  ## 这时临时目录不能删，并把它报出来。
  on.exit(if (!isTRUE(keep_frames)) unlink(dir, recursive = TRUE, force = TRUE),
          add = TRUE)

  files <- file.path(dir, sprintf("f%05d.png", seq_len(n)))
  t0 <- Sys.time()
  for (i in seq_len(n)) {
    render_frame(sc, files[i], t = (i - 1) / fps, quality = quality)
    if (verbose && (i %% 15L == 0L || i == n)) {
      cat(sprintf("\r  渲染 %d/%d 帧（%.0f%%）", i, n, 100 * i / n))
    }
  }
  if (verbose) cat("\r", strrep(" ", 40), "\r", sep = "")
  tr <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  av::av_encode_video(files, output = file, framerate = fps,
                      vfilter = "format=yuv420p", verbose = FALSE)
  if (verbose) {
    cat(sprintf("  %d 帧 %.1fs（%.0f ms/帧）-> %s（%.2f MB）\n",
                n, tr, 1000 * tr / n, file, file.size(file) / 1024^2))
    if (isTRUE(keep_frames)) cat("  逐帧 PNG 留在：", dir, "\n")
  }
  invisible(file)
}
