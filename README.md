# 27banner animation

iOS 15–17 SpringBoard 通知横幅动画的独立重建项目。维护与包署名：**Ning**。
原 GlassSuiteX 行为来源和许可说明保留在 [NOTICE.md](NOTICE.md)。不嵌入或加载原插件。

## 当前源码版本 0.5

保留横幅进出场动画、`动画弹性`和`转场时长`，新增`停留时长`倍率：只调整 SpringBoard 的通知 dismiss timer，不改变进出场动画；横幅正常收起完成后在时间下方短暂显示视频对应的短横线，随后按代次票据自动清除。短横线不处理通知数据，也不拦截交互。开启“减弱动态效果”时，横幅动画回退原生。

- `Sources/NB27Motion.h`：曲线、弹性、转场与 dismiss 延迟倍率模型。
- `Sources/NB27Banner.m`：横幅转场、原生 dismiss timer 钩子及生命周期接线。
- `Sources/NB27Compact.*`：状态栏时间锚点和收起后短横线。

目标系统上的实际 timer 单位和 UI 外观仍需设备验证；不支持的 timer ABI 不会安装相应钩子。

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
