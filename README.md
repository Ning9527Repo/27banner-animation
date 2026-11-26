# 27banner animation

iOS 15–17 SpringBoard 通知横幅动画的独立重建项目。维护与包署名：**Ning**。
原 GlassSuiteX 行为来源和许可说明保留在 [NOTICE.md](NOTICE.md)。不嵌入或加载原插件。

## 当前源码版本 0.4

从初始横幅动画基线恢复，仅新增两个设置：`动画弹性`（0–2，默认 1）和转场时长倍率（0.5–2，默认 1）。默认曲线、入场时长和设置说明保持原行为；开启“减弱动态效果”时回退系统原生动画。通知停留时长没有加入。

- `Sources/NB27Motion.h`：四通道曲线、弹性过冲与转场时长映射。
- `Sources/NB27Banner.m`：基线横幅转场与受 ABI 校验的系统转场时长适配。

原生 iOS 17.2.1 设备的视觉表现仍需实际安装录屏确认。

## 本地预检

```sh
python3 tools/check_source.py
python3 tools/check_syntax.py --sdk /path/to/iPhoneOS16.5.sdk
```

第一项运行实际生产函数的 C 测试与资源/打包 fixture。第二项只做双架构 Objective-C
严格语法检查，不链接、不签名、不触发 Actions，也不安装或自动注销设备。

## 获准后手动构建

GitHub Actions 仅 `workflow_dispatch`，提交源码不会自动构建。每次构建另需明确许可。
在 macOS/Xcode 手动构建双版本：

```sh
python3 tools/build.py --arch both
```

产物为 arm64 普通无根版（`var/jb/`）和真正 arm64e RootHide 版（subtype
`0x80000002`）；主库与设置库均独立编译签名校验，附 `out/verification.json`。
本项目不运行安装、注入、注销、软件源发布或任何 CI 自动重试。
