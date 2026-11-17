#!/bin/zsh
# 切 iPhone Duo 姿態並讀回確認。用法：./duo_pose.sh <closed|book|open> [UDID]
# 用 RocketSim CLI（不需要 Device Hub）；讀回的 hinge 狀態不符就重設，最多 3 次。
# 輸出一行：OK <pose> <hinge_state> <angle>，或 FAIL ...（exit 1）
P=$1
D=${2:-$(xcrun simctl list devices booted | grep "iPhone Duo" | grep -oE '[0-9A-F-]{36}' | head -1)}
case $P in closed) want=closed;; book) want=partiallyOpen;; open) want=openFlat;; *) echo "usage: $0 closed|book|open [UDID]"; exit 2;; esac
for try in 1 2 3; do
  rocketsim duo pose $P --udid $D >/dev/null 2>&1
  for i in {1..10}; do
    osascript -e 'delay 1'
    r=$(rocketsim duo hinge --udid $D 2>/dev/null | python3 -c "import json,sys
try:
  d=json.load(sys.stdin)['data'];print(d['hinge_state'],(-1 if d['hinge_angle_degrees'] is None else round(d['hinge_angle_degrees'],1)))
except Exception: print('none -1')")
    st=${r%% *}
    if [[ $st == $want ]]; then
      # angle must also settle (closing animation passes through partiallyOpen)
      osascript -e 'delay 2'
      echo "OK $P $r (try $try)"; exit 0
    fi
  done
done
echo "FAIL $P last=$r"; exit 1
