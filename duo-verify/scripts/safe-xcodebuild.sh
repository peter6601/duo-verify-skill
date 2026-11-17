#!/bin/zsh
# 只在這台機器沒有別的 xcodebuild 在跑時才執行 xcodebuild。
#
# 用法：
#   safe-xcodebuild.sh <xcodebuild 參數...>   沒有別人在跑就 exec xcodebuild，否則 exit 1
#   safe-xcodebuild.sh --check                只檢查：沒有別人在跑 exit 0，有就 exit 1
#
# 為什麼：模擬器（CoreSimulator）是整台機器共用的，兩個 xcodebuild 同時跑會互相拖慢、
# 卡在 Resolve Package Graph，或讓對方的測試逾時。把檢查和 build 寫在同一行
# （`ps ... | grep xcodebuild; xcodebuild ...`）擋不住，因為檢查的結果不會中止後面的指令。
# 這支腳本把「有人在跑就不執行」做成 exit code。
#
# 用 XcodeBuildMCP 或 Claude Code Desktop 內建的 build 時，它們不經過這支腳本：
# 先單獨跑一次 `safe-xcodebuild.sh --check`，exit 1 就不要 build。
#
# 限制：檢查和啟動之間仍有極短的空檔，兩邊同時啟動時可能都通過檢查。

others() {
  # 只認執行檔名稱是 xcodebuild 的行程；略過 XcodeBuildMCP 之類只是名字含 xcodebuild 的程式
  ps -axo pid=,etime=,args= | awk -v self=$$ '
    {
      exe = $3; n = split(exe, p, "/"); base = p[n]
      if (base == "xcodebuild" && $1 != self) print
    }'
}

found=$(others)
if [[ -n "$found" ]]; then
  echo "safe-xcodebuild: 這台機器已經有 xcodebuild 在跑，不執行。" >&2
  echo "PID  執行時間  指令" >&2
  print -r -- "$found" | cut -c1-240 >&2
  echo "等它結束，或確認可以中止它之後再跑。" >&2
  exit 1
fi

if [[ "$1" == "--check" ]]; then
  echo "safe-xcodebuild: 沒有別的 xcodebuild 在跑。"
  exit 0
fi

[[ $# -gt 0 ]] || { echo "用法：safe-xcodebuild.sh <xcodebuild 參數...> | --check" >&2; exit 2; }
exec xcrun xcodebuild "$@"
