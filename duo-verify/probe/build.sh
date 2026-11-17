#!/bin/zsh
# 編譯並安裝探針 app（HingeProbe）到 iPhone Duo 模擬器。
# 用法：./build.sh [UDID]（省略則自動找已開機的 iPhone Duo）
# 需要 Xcode 27.1 以上（xcode-select 指向的版本，或用 DEVELOPER_DIR 覆蓋）。
set -e
cd "$(dirname "$0")"
D=${1:-$(xcrun simctl list devices booted | grep "iPhone Duo" | grep -oE '[0-9A-F-]{36}' | head -1)}
[ -n "$D" ] || { echo "找不到已開機的 iPhone Duo 模擬器"; exit 1; }
mkdir -p HingeProbe.app && cp Info.plist HingeProbe.app/Info.plist
xcrun -sdk iphonesimulator swiftc -parse-as-library -target arm64-apple-ios27.1-simulator main.swift -o HingeProbe.app/HingeProbe
codesign -f -s - HingeProbe.app
xcrun simctl install "$D" HingeProbe.app && xcrun simctl launch "$D" local.probe.hinge
echo "讀數也寫在 app container 的 Documents/probe.log：xcrun simctl get_app_container $D local.probe.hinge data"
