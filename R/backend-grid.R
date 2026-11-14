## 渲染后端（grid）：把绘制指令画到当前设备上
## 只实现 path / stroke 两个动词；后续 cairo / OpenGL / manim-emit 后端实现同一接口即可。

.rm_draw_ops <- function(ops, height_px = 1080, res = 72) {
  if (!length(ops)) return(invisible(NULL))
  px_per_unit <- height_px / rm_frame_height
  hw <- rm_frame_height * rm_aspect / 2
  hh <- rm_frame_height / 2

  grid::pushViewport(grid::viewport(
    xscale = c(-hw, hw), yscale = c(-hh, hh), clip = "off"
  ))
  on.exit(grid::popViewport(), add = TRUE)

  for (op in ops) {
    if (identical(op$op, "path")) {
      grid::grid.draw(grid::pathGrob(
        op$x, op$y, id = op$id, rule = op$rule,
        default.units = "native",
        gp = grid::gpar(fill = grDevices::adjustcolor(op$fill, alpha.f = op$alpha),
                        col = NA)
      ))
    } else if (identical(op$op, "stroke")) {
      ## 线宽以"1080p 下的像素"为单位；lwd 的单位是 1/96 英寸
      lwd <- op$width * (height_px / 1080) * 96 / res
      grid::grid.draw(grid::polylineGrob(
        op$x, op$y, default.units = "native",
        gp = grid::gpar(col = grDevices::adjustcolor(op$col, alpha.f = op$alpha),
                        lwd = lwd, lineend = "round", linejoin = "round")
      ))
    }
  }
  invisible(NULL)
}
