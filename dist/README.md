# 预构建安装包

| 文件 | 平台 | 安装方式 |
|---|---|---|
| `ROpenManim_0.0.2.zip` | **Windows**（R ≥ 4.2.0） | `install.packages("路径/ROpenManim_0.0.2.zip", repos = NULL, type = "win.binary")` |
| `ROpenManim_0.0.2.tar.gz` | 源码，任意平台 | `install.packages("路径/ROpenManim_0.0.2.tar.gz", repos = NULL, type = "source")` |

两者都由 R 4.6.0 / Windows x86-64 构建，包本身是纯 R（`NeedsCompilation: no`），
**不需要 Rtools**。Windows 用户也可以直接用
`remotes::install_github("Judy-ZQ/ROpenManim")` 装源码，同样不需要 Rtools。

构建与验收：

```bash
R CMD build ROpenManim
R CMD check --no-manual --no-build-vignettes ROpenManim_0.0.2.tar.gz
R CMD INSTALL --build --no-multiarch -l <临时库> ROpenManim_0.0.2.tar.gz
```

**0.0.1 保留在同一目录**，仅供对照；新装请用 0.0.2——它把 `COL` / `st()` / `fl()` /
`subpaths()` / `n_subpaths()` / `n_curves()` / `n_objects()` / `can_morph()` / `peek()`
提升为正式导出（97 个），教程里的示例因此可以直接抄进 `library(ROpenManim)` 会话。

`R CMD check` 只有 1 条 non-ASCII WARNING（源码里的中文注释与中文报错文本），
`install / load / Rd / examples` 全部 OK；帮助与示例在安装包里实测可用。
