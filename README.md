# Mac Tools

个人 macOS 工具合集，每个工具独立存放源码、使用说明与构建脚本。

| 工具 | 用途 | 系统要求 |
| --- | --- | --- |
| [Window Peek](WindowPeek/README.md) | 长按修饰键预览当前应用的窗口，按编号或方向键选择，松开切换 | macOS 14+ |

安装包见 [Window Peek 最新发布版](https://github.com/erjin-zhi/mac-tools/releases/latest)。提供 Apple Silicon 版 DMG 和 SHA-256 校验文件。

## 构建 Window Peek

需要安装 Xcode Command Line Tools，并提供 Swift 5.10 或更新版本。

```bash
cd WindowPeek
swift test
./scripts/build-app.sh --install
open "$HOME/Applications/Window Peek.app"
```

首次使用需要授予辅助功能和屏幕录制权限，详见 [Window Peek 使用说明](WindowPeek/README.md)。

构建缓存、应用安装包与本机文件不纳入源码版本管理。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。
