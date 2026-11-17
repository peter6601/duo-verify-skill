#!/bin/zsh
# 按 Device Hub 的 Rotate Right 一次（RocketSim 沒有旋轉指令）。需要終端機有「輔助使用」權限、Device Hub 視窗開著。
osascript -e 'tell application "System Events" to tell process "DeviceHub"
  set frontmost to true
  click (first button of group 3 of splitter group 1 of group 1 of splitter group 1 of group 1 of window 1 whose help is "Rotate Right")
end tell' -e 'delay 4' >/dev/null || { echo "FAIL rotate (Device Hub window?)"; exit 1; }
echo OK rotate
