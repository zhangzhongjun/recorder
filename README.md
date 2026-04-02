# Recorder — 会议实时字幕

一个 macOS 菜单栏应用，实时捕获系统声音（Zoom、飞书、腾讯会议等），并将语音转为文字展示在屏幕上的悬浮窗口中。

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 功能

- **系统音频捕获** — 使用 ScreenCaptureKit 捕获全局系统音频，无需虚拟声卡驱动
- **实时语音转写** — 使用 Apple Speech 框架，本地处理，支持中文 / 英文 / 自动检测
- **悬浮字幕窗口** — 半透明深色窗口，始终置顶，可拖拽、可调整大小
- **投屏不可见** — 窗口对屏幕录制和共享不可见（`sharingType = .none`），只有本人能看到字幕
- **渐变字幕样式** — 最新字幕更大更亮，旧字幕渐渐淡出
- **菜单栏驻留** — 无 Dock 图标，通过菜单栏图标控制显示/隐藏

## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon 或 Intel Mac

## 构建

需要安装 Swift（随 Xcode Command Line Tools 提供）：

```bash
xcode-select --install
```

```bash
# 构建 Recorder.app
make build

# 或直接构建并运行
make run

# 打包为可分发的 DMG
make dmg
```

## 首次运行权限

首次点击"开始"时需要授予两项权限：

| 权限 | 用途 |
|------|------|
| **语音识别** | 将音频转为文字 |
| **屏幕录制** | 捕获系统播放的声音 |

> 授予屏幕录制权限后，点击控制栏中的 **"已授权，重试"** 按钮即可，无需重启。
> 若出现"重启应用"按钮，点击后应用会自动重新启动。

## 使用方法

1. `make run` 启动应用，菜单栏出现波形图标
2. 悬浮窗口出现在屏幕底部中央
3. 点击 **"开始"** 按钮，授权后即开始转写
4. 支持中途切换语言（中文 / English / 自动）
5. 点击 **"停止"** 或关闭窗口结束

## 项目结构

```
Sources/Recorder/
├── main.swift                 # 入口，启动 NSApplication
├── AppDelegate.swift          # 菜单栏图标与窗口管理
├── OverlayWindowController.swift  # 悬浮窗口（sharingType = .none）
├── ContentView.swift          # SwiftUI 字幕界面
├── TranscriptionStore.swift   # 共享状态（ObservableObject）
├── RecorderViewModel.swift    # 权限流程 + 录制控制
├── AudioCaptureManager.swift  # ScreenCaptureKit 音频捕获
└── SpeechManager.swift        # Speech 框架实时识别
make_icon.py                   # 生成应用图标（纯 Python）
make_dmg_bg.py                 # 生成 DMG 背景图（纯 Python）
build.sh                       # 构建脚本
make_dmg.sh                    # DMG 打包脚本
```

## License

MIT
