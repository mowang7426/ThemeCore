# ThemeCore（独立重写版）

轻量化 iOS 桌面图标主题插件（Tweak）的**原始实现重写工程**。
功能与原 ThemeCore 0.3 对齐：修改图标与图标阴影、覆盖主屏/文件夹/资源库/通知/分享面板/Widget，
支持 Anemone/Iconomatic 兼容主题格式，时钟、日历图标可动态渲染。

> 说明：本工程是根据对已提供 .deb 包的行为观察（公开 API 选择器、目录结构、偏好键）**重新编写**的
> 独立实现，不是对原二进制的反编译拷贝。仅用于学习与个人使用。

## 功能

- 图标替换：SpringBoard 主屏、文件夹、App 资源库、Widget、通知横幅、分享面板（AirDrop）、图标服务代理
- 图标阴影：`Effects/Shadow` 蒙版 + modern 投影
- 动态时钟图标：主题表盘/指针按当前时间绘制
- 动态日历图标：主题日历底图 + 当前日期数字（支持主题自定义字体/颜色/偏移）
- 主题格式：兼容 Anemone（IconBundles / Bundles / Effects）与现代（modern）两种布局
- 设置面板：启用开关、主题选择（启用/禁用/激活/分组）、一键刷新图标、越狱源页脚
- 双打包方案：rootless（Dopamine / palera1n）与 roothide（Bootstrap）均可编译
- rootless 支持：内置 `/var/jb` 与 `.jbroot-*` 探测（与 postinst 逻辑一致），无需额外依赖，iOS 15.0+

## 编译（GitHub Actions，推荐）

仓库内置 `.github/workflows/build.yml`，在 Actions 页手动 Run workflow（`workflow_dispatch`）即自动构建两个 deb。
单个 job 顺序构建：先 rootless，再 roothide，**两个 scheme 都用 RootHide Theos 分支**（该分支同时支持 rootless/roothide）。

| Scheme | 命令 | 包架构 | 安装位置 | 说明 |
|---|---|---|---|---|
| rootless | `THEOS_PACKAGE_SCHEME=rootless make package` | iphoneos-arm64 | /var/jb | Dopamine / palera1n，无 Pre-Depends |
| roothide | `THEOS_PACKAGE_SCHEME=roothide make package` | iphoneos-arm64e | jbroot（bind mount 到根路径） | 带 `Pre-Depends: rootless-compat (>= 0.9)` |

产物在 Actions 页的 Artifacts（`ThemeCore-0.3`）里下载：
`ThemeCore-0.3-rootless.deb` 与 `ThemeCore-0.3-roothide.deb`。

要点：
- 必须用 **macOS runner（macos-14）**：arm64e 新 ABI 依赖 Xcode 的 ld64（未开源，Linux 编不了 arm64e）；
- 工作流用 `git clone` 安装 RootHide Theos，再 sparse clone `theos/sdks` 的 `iPhoneOS16.5.sdk`（部署目标 iOS 15.0）；
- 两个方案使用不同 control：构建 rootless 前换成 `control.rootless`（无 Pre-Depends），构建 roothide 前还原 `control`（带 rootless-compat）；
- 最后用 `dpkg-deb` 校验主 dylib、设置面板 bundle、PreferenceLoader 入口都在包里，并核对 Pre-Depends 差异。

## 编译（本地 macOS）

只需安装一份 RootHide Theos（同时支持两个 scheme）+ iOS SDK：

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/roothide/theos/master/bin/install-theos)"
```

然后：

```sh
# 双方案一起构建（产物在 build/）
./build.sh
# 或单独构建
./build.sh rootless
./build.sh roothide
```

手动等价命令：

```sh
# rootless
cp control.rootless control
THEOS_PACKAGE_SCHEME=rootless make clean package FINALPACKAGE=1

# roothide（还原带 Pre-Depends 的 control）
cp /tmp/themecore-control.roothide control
THEOS_PACKAGE_SCHEME=roothide make clean package FINALPACKAGE=1
```

## 在设备上安装（roothide，iPhone 14 Pro Max）

1. 下载 `ThemeCore-0.3-roothide.deb`（Actions Artifacts）；
2. 打开 roothide Bootstrap 的 Sileo/Zebra，用文件管理器（如 Filza）或 Sileo 的「本地安装」导入 deb；
3. 首次安装会同时装上 `rootless-compat`（roothide 默认源已提供）；
4. 安装完成后，把主题放进 `/Library/Themes/*.theme`（设备上看到的根路径；物理上在 jbroot 下）；
5. 设置 → ThemeCore 里启用插件并选择主题，点「刷新图标」，SpringBoard 会重载图标。

> 若注入 SpringBoard 不生效，在 Bootstrap App 里确认 SpringBoard 的注入开关已打开
> （roothide 默认部分系统进程不注入，需手动启用）。

## 主题目录规范

用户把主题放进 `/Library/Themes/*.theme`，一个主题包结构如下（Anemone 兼容 + modern 扩展）：

```
MyTheme.theme/
├── Info.plist                  # PackageName（显示名）、modern（1/0）
├── IconBundles/
│   ├── com.apple.mobilemail.png        # 图标：<bundle-id>.png
│   ├── com.apple.mobilemail-large.png  # 大尺寸变体（-large）
│   └── clock.background.png            # 时钟表盘
├── Bundles/
│   └── com.apple.mobiletimer/
│       ├── ClockIconHourHand.png
│       ├── ClockIconMinuteHand.png
│       ├── ClockIconSecondHand.png
│       └── ClockIconRedDot.png
└── Effects/
    ├── Shadow/                          # 阴影蒙版（<bundle-id>.png / Shadow.png）
    ├── AnemoneEffects/                  # 叠加特效（modern）
    └── Iconomatic/                      # 传统叠加特效
```

时钟素材键：`clock.background` / `ClockIconBackgroundSquare`、`ClockIconHourHand`、`ClockIconMinuteHand`、
`ClockIconSecondHand`、`ClockIconRedDot`（秒针端圆点）、`ClockIconBlackDot`（中心圆点）。
日历数字布局参数放在 `Info.plist`：`CalendarIconDateSettings`（FontName/FontSize/FontWeight/TextColor/TextXoffset/TextYoffset）、
`CalendarIconDaySettings`。

偏好存储：`/var/mobile/Library/Preferences/com.susudear.themecore.plist`
（`Enabled`、`ActiveTheme`、`EnabledThemes`）。

## 工程结构

```
.github/workflows/build.yml     GitHub Actions 双方案编译
control / control.rootless      两种打包方案的包元数据
ThemeCore.xm                    主 Tweak：全链路 hooks
TCThemeStore.h/.m               主题扫描、合并、编译产物、缓存
TCClockResource.h/.m            动态时钟渲染
TCCalendarResource.h/.m         动态日历渲染
TCShadowLayer.h/.m              图标阴影层
TCIconImageBox.h/.m             图标服务图像盒（iconservicesagent）
ThemeCorePrefs/                 设置面板（Root/ThemeList 控制器、模型、资源）
layout/                         打包布局（PreferenceLoader 入口等）
Makefile / postinst / postrm / ThemeCore.plist
build.sh                        本地双方案构建脚本
```

## 已知限制

- 各 iOS 版本的私有 API 方法签名可能有差异，个别 hook（如 iconservicesagent 侧）需要按目标系统微调；
- 本项目在 Linux 环境编写，无法在此编译/真机验证；请用 GitHub Actions 或本地 Theos 构建并在设备上测试。
