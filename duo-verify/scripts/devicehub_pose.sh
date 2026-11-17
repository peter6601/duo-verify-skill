#!/bin/zsh
# 沒有 RocketSim 時的備案：點 Device Hub 的姿態按鈕切 Duo 姿態。
# 用法：./devicehub_pose.sh "Closed|Partially Open|Open"
# 需要終端機有「輔助使用」權限、Device Hub 視窗開著。切換偶爾會被吞掉，切完要用截圖尺寸確認。
osascript -e "tell application \"System Events\" to tell process \"DeviceHub\"
  set frontmost to true
  click (first button of group 3 of splitter group 1 of group 1 of splitter group 1 of group 1 of window 1 whose help is \"$1\")
end tell" -e 'delay 8' >/dev/null || { echo "FAIL $1 (Device Hub window?)"; exit 1; }
echo "OK $1"
