#!/usr/bin/env bash
#
# 本地双方案构建脚本（macOS + RootHide Theos）
# RootHide Theos 分支同时支持 rootless 与 roothide 两个 scheme，
# 与 .github/workflows/build.yml 的构建顺序完全一致。
#
# 安装 RootHide Theos：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/roothide/theos/master/bin/install-theos)"
#
# 用法：
#   ./build.sh            # 构建 rootless + roothide
#   ./build.sh rootless   # 只构建 rootless
#   ./build.sh roothide   # 只构建 roothide
#
set -euo pipefail

export THEOS="${THEOS:-$HOME/theos}"
export THEOS_MAKE_PATH="$THEOS/makefiles"
SCHEME="${1:-both}"

[ -f "$THEOS/makefiles/common.mk" ] || { echo "未找到 RootHide Theos：$THEOS"; exit 1; }

# 保存仓库里的 roothide 变体 control，退出时还原，避免污染工作区
cp control /tmp/themecore-control.roothide
restore_control() { cp /tmp/themecore-control.roothide control; }
trap restore_control EXIT

mkdir -p build

build_rootless() {
  echo "==> 构建 rootless（无 Pre-Depends，iphoneos-arm64）"
  cp control.rootless control
  make clean
  THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1
  local deb
  deb=$(find packages -maxdepth 1 -type f -name "*.deb" | head -n 1)
  cp "$deb" "build/ThemeCore-0.3-rootless.deb"
}

build_roothide() {
  echo "==> 构建 roothide（Pre-Depends rootless-compat，iphoneos-arm64e）"
  cp /tmp/themecore-control.roothide control
  make clean
  rm -rf packages
  THEOS_PACKAGE_SCHEME=roothide make package FINALPACKAGE=1
  local deb
  deb=$(find packages -maxdepth 1 -type f -name "*.deb" | head -n 1)
  cp "$deb" "build/ThemeCore-0.3-roothide.deb"
}

case "$SCHEME" in
  rootless) build_rootless ;;
  roothide) build_roothide ;;
  both)     build_rootless; build_roothide ;;
  *) echo "用法：$0 [rootless|roothide|both]" >&2; exit 1 ;;
esac

echo "全部完成。产物："
ls -la build/*.deb
