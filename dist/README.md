# 预构建安装包

| 文件 | 平台 | 安装方式 |
|---|---|---|
| `ROpenManim_0.0.3.zip` | **Windows**（R ≥ 4.2.0） | `install.packages("路径/ROpenManim_0.0.3.zip", repos = NULL, type = "win.binary")` |
| `ROpenManim_0.0.3.tar.gz` | 源码，任意平台 | `install.packages("路径/ROpenManim_0.0.3.tar.gz", repos = NULL, type = "source")` |

两者都由 R 4.6.0 / Windows x86-64 构建，包本身是纯 R（`NeedsCompilation: no`），
**不需要 Rtools**。Windows 用户也可以直接用
`remotes::install_github("Judy-ZQ/ROpenManim")` 装源码，同样不需要 Rtools。

构建与验收：

```bash
R CMD build ROpenManim
R CMD check --no-manual --no-build-vignettes ROpenManim_0.0.3.tar.gz
R CMD INSTALL --build --no-multiarch -l <临时库> ROpenManim_0.0.3.tar.gz
```

**目录里只保留当前版本 0.0.3**（旧版二进制已清理，需要 0.0.1 / 0.0.2 请到对应
Release 页下载）。0.0.3 在 0.0.2 的 9 个辅助导出（`COL` / `st()` / `fl()` /
`subpaths()` / `n_subpaths()` / `n_curves()` / `n_objects()` / `can_morph()` / `peek()`）
之上再加 6 个排字出图函数（`cjk_font()` / `lab()` / `tex()` / `ref_axes()` / `fig()` /
`frame_to()`），合计 103 个导出。教程里的示例因此可以直接抄进 `library(ROpenManim)`
会话——包括 `fig(sc, "intro-1b", t = 1.75)`。

`R CMD check` 只有 1 条 non-ASCII WARNING（源码里的中文注释与中文报错文本），
`install / load / Rd / examples` 全部 OK；帮助与示例在安装包里实测可用。
