# 应用更新与发布

使用 Sparkle 2.10.0。运行期间默认每天检查一次；菜单栏和设置均有“检查更新”。用户确认后下载、验证签名、安装并重新启动。不自动下载或静默安装，不发送系统配置统计。用户可关闭自动检查，手动检查仍可用。0.2.2 及更早版本需要手动安装一次支持 Sparkle 的版本。

`config.json` 是版本号、递增构建号、公钥和更新地址的唯一来源。更新清单位于同一公开仓库的 `windowpeek-updates` 分支，路径 `windowpeek/appcast.xml`；安装包位于每个版本独立的 GitHub Release。不会误用仓库其他应用的 latest 下载链接。GitHub 网络可达性会影响检查和下载，后续可以同时迁移到可访问的 HTTPS 托管地址。

## 每次发版

1. 修改 `config.json` 的 `version` 和 `build`（构建号必须严格递增），编写 `Updates/<version>.md` 的用户说明。
2. Review、提交并推送到 GitHub 的 `main`。
3. 在 `WindowPeek` 目录执行：

```bash
python3 scripts/release.py --publish
```

这条命令自动运行核心测试与发布安全测试、构建并签名 DMG、Apple 公证与附票、生成并验证 EdDSA 更新签名、创建草稿 Release 和标签、上传安装包与校验文件、核对 GitHub 摘要、公开 Release，最后发布 appcast。任何中间步骤失败都不会提前推送新版更新提示。标签必须对应当前提交，已有不同内容的资产不会覆盖，更新清单通过文件 SHA 防止并发覆盖。

仅准备可审核产物（不创建 Release、不更新线上版本清单）：

```bash
python3 scripts/release.py
```

输出在 `dist/release-<version>/`。如果发布在上传或更新清单阶段中断，保持同一干净提交和产物，执行 `python3 scripts/release.py --publish --resume`。脚本验证提交、配置、文件摘要和签名后继续；不要重新打包并替换已经公开的同版本资产。准备时存在未提交修改的产物不能直接发布，需要提交后重新准备。

首次建立空清单可单独执行 `python3 scripts/release.py --init-feed`，不会发布新版本。发布命令也会自动初始化。

## 本机凭据

发布需要 Swift/Xcode 工具链、gh 登录、Developer ID Application 证书和钥匙串中名为 `windowpeek-notary` 的公证凭据。可通过 `--notary-profile` 指定其他公证配置。

Sparkle 私钥保存在 macOS 钥匙串，account 为 `local.windowpeek.app.sparkle`；仓库和应用仅包含公钥。首次配置工具：

```bash
swift package resolve
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account local.windowpeek.app.sparkle
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account local.windowpeek.app.sparkle -p
```

最后一条显示公钥，将其写入 `config.json` 的 `publicKey`。已有正式用户后不要重新生成另一把钥匙或随意修改公钥；换机时应安全迁移签名凭据。不要把私钥、证书或公证密码提交到仓库。

当前是**本机一条命令发版**，仍由维护者决定版本内容并发起命令；没有配置 push 后无人值守的 GitHub Actions。用户端检查和安装由 Sparkle 自动完成，无需手动维护 XML。Sparkle 许可证随应用打包在 `Contents/Resources/Sparkle-LICENSE.txt`。

## 验证

`python3 scripts/verify-updates.py` 使用独立 bundle ID、本机回环 HTTP 服务和临时测试应用，验证真实下载、签名校验、安装与重新启动，以及无更新、无效签名和请求失败时保留旧版本。不会修改已安装的 Window Peek，也不申请录屏或辅助功能权限。需先构建应用，首次运行签名工具可能需要在系统钥匙串弹窗中授权。`python3 -B scripts/UpdateCheck/test_release.py` 单独验证发布顺序、资产不可覆盖以及中断恢复，不访问网络。
