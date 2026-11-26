# 27banner animation

iOS 15–17 SpringBoard 通知横幅动画的独立重建项目。维护与包署名：**Ning**。
原 GlassSuiteX 行为来源和许可说明保留在 [NOTICE.md](NOTICE.md)。不嵌入或加载原插件。

## 当前源码版本 0.3

以用户提供的视频为参考：左侧紧凑通知 → 展开横幅 → 正常收起 → 时间下方保留短横线。
不提供自定义弹性滑块，不修改原生通知图标、材质、点击、长按内容或消息数据。

- `Sources/NB27Motion.h`：静态重建的四通道关键节点与插值。
- `Sources/NB27ReferenceMotion.h`：实际时间区域锚点、非中心 anchor 与回收轨迹。
- `Sources/NB27Banner.m`：原生过渡与退出/取消生命周期接入，独立 once/ABI 校验。
- `Sources/NB27Compact.*`：不接管触摸的短横线，单次代次票据；未知状态时隐藏。
- `Docs/video-reference.md`：视频证据、尚未展示的行为和验证边界。

**0.3 是锚点采集修复候选，不代表真机视觉已验证。** 必须在目标 iOS 17.2.1 设备安装后同机录屏逐帧对比；未知锁屏状态、不支持的布局、减弱动态效果或原插件同功能同时开启时回退，而不更改通知链。

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
