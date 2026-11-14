## 文本：把字符串变成真正的轮廓对象（可与其它图元互相 Transform）
## 依赖 systemfonts：shape_string 取字形与位置，glyph_outline 取轮廓多边形。
## 单位约定：1 排版点 = 0.01 场景单位（em 48pt -> 0.48 unit）。

.rm_cache <- new.env(parent = emptyenv())

#' @export
text <- function(str, size = 48, family = "sans", color = "#FFFFFF",
                 italic = FALSE, weight = "normal", tolerance = 0.05) {
  key <- paste(str, size, family, italic, weight, tolerance, sep = "\r")
  if (!is.null(.rm_cache[[key]])) {
    return(rm_mobject$new(.rm_cache[[key]]$curves, .rm_cache[[key]]$path_id,
                          list(stroke = NA_character_, fill = color), name = "text"))
  }
  font <- systemfonts::match_fonts(family = family, italic = italic, weight = weight)
  path <- font$path[1]
  fidx <- font$index[1]
  shap <- systemfonts::shape_string(str, family = family, size = size,
                                    italic = italic, weight = weight)$shape

  polys <- list(); cur <- NULL
  missing <- 0L
  for (i in seq_len(nrow(shap))) {
    gi <- as.integer(shap$index[i])
    if (is.na(gi)) next
    ch <- substr(str, min(i, nchar(str)), min(i, nchar(str)))
    if (grepl("^[[:space:]]$", ch)) next
    o <- systemfonts::glyph_outline(gi, path, index = fidx, size = size,
                                    tolerance = tolerance)
    if (!nrow(o)) { missing <- missing + 1L; next }
    o$x <- o$x + shap$x_offset[i]
    o$y <- o$y + (if (!is.null(shap$y_offset)) shap$y_offset[i] else 0)
    for (ct in unique(o$contour)) {
      P <- as.matrix(o[o$contour == ct, c("x", "y")])
      if (nrow(P) >= 3L) polys[[length(polys) + 1L]] <- P
    }
  }
  if (missing > 0) {
    warning(sprintf("%d 个字形没有轮廓（字体 %s 缺少该字符？可用 family= 指定中文字体）",
                    missing, family), call. = FALSE)
  }
  if (!length(polys)) stop("text(): 没有取到任何字形轮廓", call. = FALSE)

  z <- .rm_curves_from_polys(polys)
  z$curves <- lapply(z$curves, function(cv) { cv[, 1:2] <- cv[, 1:2] * 0.01; cv })
  .rm_cache[[key]] <- z
  o <- rm_mobject$new(z$curves, z$path_id,
                      list(stroke = NA_character_, fill = color), name = "text")
  o$move_to(0, 0)
  o
}
