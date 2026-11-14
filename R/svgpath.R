## 最小 SVG 路径解析器：d 属性 -> 三次贝塞尔段
## 支持 M L H V C S Q T A Z（含相对命令）；够用来读 dvisvgm 的输出。

.rm_svg_tokens <- function(d) {
  pat <- "[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?"
  regmatches(d, gregexpr(pat, d, perl = TRUE))[[1]]
}

## 圆弧 -> 三次贝塞尔（SVG 规范 F.6 的实现）
.rm_arc_cubics <- function(p0, rx, ry, phi_deg, laf, sf, p1) {
  r <- sqrt(sum((p1 - p0)^2))
  if (rx == 0 || ry == 0) return(list(list(c1 = p0, c2 = p1, to = p1)))
  phi <- phi_deg * pi / 180
  dx2 <- (p0[1] - p1[1]) / 2; dy2 <- (p0[2] - p1[2]) / 2
  x1p <- cos(phi) * dx2 + sin(phi) * dy2
  y1p <- -sin(phi) * dx2 + cos(phi) * dy2
  rx <- abs(rx); ry <- abs(ry)
  lam <- x1p^2 / rx^2 + y1p^2 / ry^2
  if (lam > 1) { s <- sqrt(lam); rx <- rx * s; ry <- ry * s }
  den <- rx^2 * y1p^2 + ry^2 * x1p^2
  num <- rx^2 * ry^2 - den
  co <- if (den < 1e-15) 0 else sqrt(max(0, num / den))
  if (isTRUE(laf) == isTRUE(sf)) co <- -co
  cxp <- co * rx * y1p / ry
  cyp <- -co * ry * x1p / rx
  cx <- cos(phi) * cxp - sin(phi) * cyp + (p0[1] + p1[1]) / 2
  cy <- sin(phi) * cxp + cos(phi) * cyp + (p0[2] + p1[2]) / 2
  th1 <- atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
  th2 <- atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx)
  dth <- th2 - th1
  if (!isTRUE(sf) && dth > 0) dth <- dth - 2 * pi
  if (isTRUE(sf) && dth < 0) dth <- dth + 2 * pi
  n <- max(1L, ceiling(abs(dth) / (pi / 2)))
  delta <- dth / n
  k <- 4 / 3 * tan(delta / 4)
  ell <- function(t) c(cx + rx * cos(t) * cos(phi) - ry * sin(t) * sin(phi),
                       cy + rx * cos(t) * sin(phi) + ry * sin(t) * cos(phi))
  ell_d <- function(t) c(-rx * sin(t) * cos(phi) - ry * cos(t) * sin(phi),
                         -rx * sin(t) * sin(phi) + ry * cos(t) * cos(phi))
  out <- vector("list", n)
  t <- th1
  for (i in seq_len(n)) {
    t2 <- t + delta
    e0 <- ell(t); e1 <- ell(t2)
    out[[i]] <- list(c1 = e0 + k * ell_d(t), c2 = e1 - k * ell_d(t2), to = e1)
    t <- t2
  }
  out
}

## 主解析：返回 list(curves, path_id)，坐标为 SVG 用户单位（y 向下）
.rm_svg_path <- function(d) {
  if (is.null(d) || is.na(d) || !nzchar(d)) return(list(curves = list(), path_id = integer(0)))
  tk <- .rm_svg_tokens(d)
  i <- 1L; n <- length(tk)
  curves <- list(); pid <- integer(0)
  path <- 0L
  cur <- c(0, 0); start <- c(0, 0); prev_c2 <- NULL
  last_cmd <- ""

  num <- function() { v <- as.numeric(tk[i]); i <<- i + 1L; v }
  is_cmd <- function(s) grepl("^[A-Za-z]$", s)
  add3 <- function(c1, c2, to) {
    curves[[length(curves) + 1L]] <<- rbind(c(cur, 0), c(c1, 0), c(c2, 0), c(to, 0))
    pid <<- c(pid, path)
    prev_c2 <<- c2
    cur <<- to
  }
  addline <- function(to) add3(cur, to, to)

  while (i <= n) {
    if (is_cmd(tk[i])) { cmd <- tk[i]; i <- i + 1L } else if (last_cmd == "M") cmd <- "L" else if (last_cmd == "m") cmd <- "l" else cmd <- last_cmd
    rel <- cmd %in% c("m", "l", "h", "v", "c", "s", "q", "t", "a")
    C <- toupper(cmd)

    if (C == "M") {
      p <- c(num(), num()); if (rel) p <- cur + p
      cur <- p; start <- p; path <- path + 1L
      prev_c2 <- NULL
      last_cmd <- cmd
      next
    }
    if (C == "Z") {
      if (sum(abs(cur - start)) > 1e-12) addline(start)
      cur <- start; prev_c2 <- NULL
      last_cmd <- cmd
      next
    }
    if (C == "L") {
      p <- c(num(), num()); if (rel) p <- cur + p
      addline(p)
    } else if (C == "H") {
      v <- num(); p <- c(if (rel) cur[1] + v else v, cur[2]); addline(p)
    } else if (C == "V") {
      v <- num(); p <- c(cur[1], if (rel) cur[2] + v else v); addline(p)
    } else if (C == "C") {
      c1 <- c(num(), num()); c2 <- c(num(), num()); p <- c(num(), num())
      if (rel) { c1 <- cur + c1; c2 <- cur + c2; p <- cur + p }
      add3(c1, c2, p)
    } else if (C == "S") {
      c2 <- c(num(), num()); p <- c(num(), num())
      if (rel) { c2 <- cur + c2; p <- cur + p }
      c1 <- if (is.null(prev_c2)) cur else 2 * cur - prev_c2
      add3(c1, c2, p)
    } else if (C %in% c("Q", "T")) {
      if (C == "Q") {
        q <- c(num(), num()); p <- c(num(), num())
        if (rel) { q <- cur + q; p <- cur + p }
      } else {
        p <- c(num(), num()); if (rel) p <- cur + p
        q <- if (is.null(prev_c2)) cur else 2 * cur - prev_c2
      }
      add3(cur + 2 / 3 * (q - cur), p + 2 / 3 * (q - p), p)
    } else if (C == "A") {
      rx <- num(); ry <- num(); rot <- num(); laf <- num(); sf <- num()
      p <- c(num(), num()); if (rel) p <- cur + p
      segs <- .rm_arc_cubics(cur, rx, ry, rot, laf != 0, sf != 0, p)
      for (s in segs) add3(s$c1, s$c2, s$to)
    } else {
      stop("unsupported SVG path command: ", cmd)
    }
    last_cmd <- cmd
  }
  list(curves = curves, path_id = pid)
}

## 读 dvisvgm 生成的 SVG：<defs> 里的 path + 正文的 <use>/<rect>
.rm_svg_read <- function(file) {
  txt <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  defs <- list()
  m <- gregexpr("<path\\s+id='([^']+)'\\s+d='([^']*)'", txt, perl = TRUE)
  if (m[[1]][1] != -1) {
    hits <- regmatches(txt, m)[[1]]
    for (h in hits) {
      id <- sub(".*id='([^']+)'.*", "\\1", h)
      d <- sub(".*d='([^']*)'.*", "\\1", h)
      defs[[id]] <- d
    }
  }
  body <- sub("(?s).*</defs>", "", txt, perl = TRUE)
  body <- sub("(?s)<defs>.*", "", body, perl = TRUE)

  curves <- list(); pid <- integer(0); path <- 0L
  push <- function(z, dx = 0, dy = 0) {
    if (!length(z$curves)) return(invisible(NULL))
    for (cv in z$curves) {
      cv[, 1] <- cv[, 1] + dx
      cv[, 2] <- cv[, 2] + dy
      curves[[length(curves) + 1L]] <<- cv
      pid <<- c(pid, path)
    }
    invisible(NULL)
  }
  elems <- regmatches(body, gregexpr("<(use|rect)[^>]*>", body, perl = TRUE))[[1]]
  for (e in elems) {
    path <- path + 1L
    if (grepl("^<use", e)) {
      id <- sub(".*(?:xlink:)?href='#([^']+)'.*", "\\1", e, perl = TRUE)
      x <- as.numeric(sub(".*\\sx='([^']*)'.*", "\\1", e))
      y <- as.numeric(sub(".*\\sy='([^']*)'.*", "\\1", e))
      if (is.na(x)) x <- 0
      if (is.na(y)) y <- 0
      if (!is.null(defs[[id]])) push(.rm_svg_path(defs[[id]]), x, y)
    } else {
      gx <- function(k) as.numeric(sub(paste0(".*\\s", k, "='([^']*)'.*"), "\\1", e))
      x <- gx("x"); y <- gx("y"); w <- gx("width"); h <- gx("height")
      if (any(is.na(c(x, y, w, h)))) next
      P <- cbind(c(x, x + w, x + w, x), c(y, y, y + h, y + h))
      push(.rm_curves_from_polys(list(rbind(P, P[1, ]))))
    }
  }
  list(curves = curves, path_id = pid)
}
