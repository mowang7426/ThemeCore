#!/usr/bin/env bash
#
# 本地双方案构建脚本（macOS + Theos）
#   - rootless：标准 Theos（默认 $HOME/theos，可用 THEOS 覆盖）
#   - roothide：roothide/Theos 分支（$HOME/theos-roothide，可用 THEOS_ROOTHIDE 覆盖）
#
# 用法：
#   ./build.sh            # 构建 rootless + roothide
#   ./build.sh rootless   # 只构建 rootless
#   ./build.sh roothide   # 只构建 roothide
#
set -euo pipefail

THEOS_ROOTLESS="${THEOS:-$HOME/theos}"
THEOS_ROOTHIDE="${THEOS_ROOTHIDE:-$HOME/theos-roothide}"
SCHEME="${1:-both}"

build_rootless() {
  echo "==> 构建 rootless（THEOS=$THEOS_ROOTLESS）"
  # 换成 rootless 变体 control（无 Pre-Depends，架构 iphoneos-arm64）
  mv control control.roothide
  cp control.rootless control
  THEOS="$THEOS_ROOTLESS" gmake clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
  mv control control.rootless
  mv control.roothide control
  echo "==> rootless 完成"
}

build_roothide() {
  [ -d "$THEOS_ROOTHIDE/sdks" ] || { echo "缺少 $THEOS_ROOTHIDE/sdks（roothide Theos 需安装 SDK）"; exit 1; }
  echo "==> 构建 roothide（THEOS=$THEOS_ROOTHIDE）"
  # 默认 control 即为 roothide 变体（Pre-Depends rootless-compat + iphoneos-arm64e）
  THEOS="$THEOS_ROOTHIDE" gmake clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
  echo "==> roothide 完成"
}

case "$SCHEME" in
  rootless) build_rootless ;;
  roothide) build_roothide ;;
  both)     build_rootless; build_roothide ;;
  *) echo "用法：$0 [rootless|roothide|both]" >&2; exit 1 ;;
esac

echo "全部完成。产物："
ls -la packages/*.deb
