# 预构建安装包

| 文件 | 平台 | 安装方式 |
|---|---|---|
| `ROpenManim_0.0.4.zip` | **Windows**（R ≥ 4.2.0） | `install.packages("路径/ROpenManim_0.0.4.zip", repos = NULL, type = "win.binary")` |
| `ROpenManim_0.0.4.tar.gz` | 源码，任意平台 | `install.packages("路径/ROpenManim_0.0.4.tar.gz", repos = NULL, type = "source")` |

两者都由 R 4.6.0 / Windows x86-64 构建，包本身是纯 R（`NeedsCompilation: no`），
**不需要 Rtools**。Windows 用户也可以直接用
`remotes::install_github("Judy-ZQ/ROpenManim")` 装源码，同样不需要 Rtools。

构建与验收：

```bash
R CMD build ROpenManim
R CMD check --no-manual --no-build-vignettes ROpenManim_0.0.4.tar.gz
R CMD INSTALL --build --no-multiarch -l <临时库> ROpenManim_0.0.4.tar.gz
```

**目录里只保留当前版本 0.0.4**（旧版在各自 Release 页）。0.0.4 不新增导出
（仍是 103 个），修掉两处「照抄教程就炸」：`render()` / `render_frame()` /
`last_frame()` 自动创建输出文件的父目录；帧数按 `ceiling(duration*fps - 1e-9)`
计算，2.8 秒场景不再多渲一帧。0.0.2 收的 9 个辅助导出与 0.0.3 收的 6 个
排字出图函数都保留，因此 `fig(sc, "intro-1b", t = 1.75)` 与
`render(sc, "animations/first-scene.mp4")` 都能直接抄进 `library(ROpenManim)` 会话。

`R CMD check` 只有 1 条 non-ASCII WARNING（源码里的中文注释与中文报错文本），
`install / load / Rd / examples` 全部 OK；帮助与示例在安装包里实测可用。
