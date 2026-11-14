## 一键跑五套回归断言（源码直跑，不要求先安装包）。
## cd ROpenManim && env -u LC_ALL -u LANG Rscript regression/run-all.R
Sys.setenv(LC_CTYPE = "Chinese (Simplified)_China.utf8")
a <- commandArgs(trailingOnly = FALSE)
hit <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
here <- if (length(hit)) normalizePath(dirname(hit[1]), winslash = "/") else "regression"

files <- c("rm_assert.R", "rm_p1_assert.R", "rm_homogeneous_assert.R",
           "rm_3d_assert.R", "rm_helpers_assert.R")
tot_pass <- 0L; tot_fail <- 0L
for (f in files) {
  cat("\n===== ", f, " =====\n", sep = "")
  out <- system2(file.path(R.home("bin"), "Rscript"),
                 c("--vanilla", shQuote(file.path(here, f))),
                 stdout = TRUE, stderr = TRUE)
  cat(paste(grep("PASS|FAIL|==|md5|--", out, value = TRUE), collapse = "\n"), "\n")
  tail_line <- tail(grep("== .* PASS / .* FAIL ==", out, value = TRUE), 1L)
  m <- regmatches(tail_line, regexec("== ([0-9]+) PASS / ([0-9]+) FAIL ==", tail_line))[[1]]
  if (length(m) == 3L) {
    tot_pass <- tot_pass + as.integer(m[2]); tot_fail <- tot_fail + as.integer(m[3])
  } else {
    cat("  !! 该套脚本未返回汇总行：\n", paste(tail(out, 8), collapse = "\n"), "\n")
    tot_fail <- tot_fail + 1L
  }
}
cat(sprintf("\n==== 合计：%d PASS / %d FAIL ====\n", tot_pass, tot_fail))
if (tot_fail > 0L) quit(status = 1L)
