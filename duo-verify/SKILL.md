---
name: duo-verify
description: 功能或畫面寫完後，在 iPhone Duo 模擬器上自己跑一輪驗證：三個姿態（closed／book／open）× 四個旋轉方向，自動檢查按鈕有沒有落進狀態列、home indicator 區或橫跨折痕，實際點主要按鈕、比對截圖與預期、檢查切換時狀態有沒有保留，最後給「在這張矩陣內可以出貨／有問題／無法判斷」的結論。使用者說「duo-verify」「在 Duo 上驗一下」「Duo 上會不會有問題」時使用。
---

# /duo-verify：在 iPhone Duo 模擬器上驗證一個畫面

輸入（叫用時問清楚，缺的就問一次）：
1. **要驗的畫面**：怎麼從 app 首頁走到那裡（例如「首頁 → 設定 → 帳號」）。
2. **預期長相**：Figma frame 連結，或一兩句描述（哪些按鈕、什麼排法）。沒有就只做規則檢查，報告註明「未比對設計」。
3. **主要按鈕**：要實際點的按鈕 label，以及點了之後預期出現什麼。

工具都在這個 skill 的資料夾裡（下稱 `$H`，就是載入 skill 時顯示的 base directory）：

| 檔案 | 做什麼 |
|---|---|
| `scripts/duo_pose.sh <closed\|book\|open>` | 用 RocketSim 切姿態並讀回 hinge 確認，不符就重設，最多 3 次 |
| `scripts/duo_rotate.sh` | 點 Device Hub 的 Rotate Right 一次（RocketSim 沒有旋轉指令） |
| `scripts/duo_check.py <elements.json> --pose P [--baseline parent.json]` | 依實測 safe area 與折痕位置檢查元素座標；exit 1＝有 FAIL，2＝無法判斷 |
| `scripts/devicehub_pose.sh "Closed\|Partially Open\|Open"` | 沒有 RocketSim 時，用 Device Hub 切姿態 |
| `probe/build.sh` | 探針 app：遇到 `duo_check.py` 不認得的畫面尺寸時，用它量 safe area |

## 0. 前置檢查（任一不過就停下來回報，不要硬跑）

1. **要 build 時**，先用**單獨一個指令**跑 `ps -eo pid=,etime=,command= | grep "[x]codebuild" | grep -v mcp`。有輸出就停，告訴使用者誰在跑，不要 build。不要把這個檢查和 build 寫在同一行：檢查的結果擋不住後面的指令。只用已安裝的 app、不 build 時，別人的 xcodebuild 不影響，照常跑。
2. `xcrun simctl list devices booted | grep "iPhone Duo"` 拿 UDID（下稱 `$D`）。沒有就請使用者開一台。
3. `rocketsim duo hinge --udid $D` 回 `ok:true`。回 `app_not_running` 就 `open -a RocketSim` 後重試。
   - 回 `quota_exceeded`（免費版每日次數用完）或沒裝 RocketSim：**不要想辦法繞過次數限制**。改走「看圖模式」：
     - Desktop：切姿態、旋轉、截圖用內建工具；CLI：切姿態用 Device Hub（`$H/scripts/devicehub_pose.sh`），截圖用 `xcrun simctl io $D screenshot --display=primary|primary-1`。
     - 跳過 `duo_check.py`，由 Claude 讀截圖判斷按鈕有沒有壓到狀態列、home indicator、折痕。
     - 報告第一行註明「看圖模式：未做座標檢查，精確度到不了 pt」。
4. 判斷執行環境，決定切姿態和旋轉用哪一套（見下方「兩種環境」）。CLI 環境要旋轉時，Device Hub 視窗要開著（`pgrep DeviceHub`）；沒開就只跑旋轉 0，報告註明旋轉沒測。
5. 模擬器要登入的話，停下來請使用者用**測試帳號**登入。截圖會送到 Anthropic。

## 兩種環境

| 動作 | Claude Code Desktop（有內建 iOS Simulator 工具） | CLI |
|---|---|---|
| 切姿態 | Desktop 的 `duo_pose`，可設任意角度 | `$H/scripts/duo_pose.sh closed\|book\|open`（RocketSim，只有三個固定姿態） |
| 旋轉 | Desktop 的 `rotate` | `$H/scripts/duo_rotate.sh`（Device Hub＋輔助使用權限） |
| 讀回 hinge | 兩邊都用 `rocketsim duo hinge --udid $D` |
| 元素座標、點擊 | 兩邊都用 `rocketsim elements`／`rocketsim interact` |

**book 一定要測到內螢幕。** 轉軸有很大的遲滯：從 Closed 慢慢掀開，到約 150° 都還停在外螢幕；從 Open 慢慢關上，到約 25° 都還在內螢幕；從 Closed 一次跳到 84° 以上才會立刻換到內螢幕。所以 book 的做法是：
- Desktop：先切到 Open，再把角度設成 130°。
- CLI：`scripts/duo_pose.sh book`（RocketSim 是一次跳過去，會到內螢幕）。
- 兩邊都要看 `elements` 的 canvasSize 是不是 951×669 或 669×951。如果是 466×678，這一格就是「外螢幕半開」，記下來，不算 book。
- 要測「慢慢掀開時一直停在外螢幕」的情境，另外加一格「外螢幕半開」：Desktop 從 Closed 每次加 10° 掀到 120°。

## 1. Build 並開到目標畫面

- Build／安裝：CLI 用 XcodeBuildMCP `build_run_sim`（先 `session_show_defaults`）；Desktop app 用內建模擬器面板。scheme 用專案平常開發用的那個。
- 在**進入目標畫面前**，於上一層畫面拍 baseline：`rocketsim elements --udid $D > $RUN/baseline.json`。RocketSim 會把被 fullScreenCover／sheet 蓋住的下層元素也列出來，`--baseline` 用來排除它們。如果已經在目標畫面裡，要離開才能拍：離開的動作會付費、送出資料或結束一段流程時，先問使用者，不要自己按。
- 走到目標畫面。操作用 `rocketsim interact tap --label ... --screen latest --udid $D`。

## 2. 跑矩陣

`$RUN` 用 `~/duo-verify-runs/<功能>_<日期>`（不要寫進專案 repo）。每一格：

```bash
# 切姿態、旋轉：依「兩種環境」那張表（CLI 用 scripts/duo_pose.sh／duo_rotate.sh，Desktop 用內建工具）
rocketsim elements --udid $D > $RUN/<pose>_r<n>.json
rocketsim screenshot --udid $D > $RUN/<pose>_r<n>.png
# 截圖要跟 canvasSize 對得上（×3）。不對就是截到沒亮的那一面（全黑），改用：
#   外螢幕 xcrun simctl io $D screenshot --display=primary   <檔名>
#   內螢幕 xcrun simctl io $D screenshot --display=primary-1 <檔名>
python3 $H/scripts/duo_check.py $RUN/<pose>_r<n>.json --pose <pose> --baseline $RUN/baseline.json > $RUN/<pose>_r<n>.check.txt
```

姿態順序 closed → book → open，每個姿態旋轉 0–3。一個 shell 指令裡不要 `rm`；換新資料夾即可。

每一格另外做：
1. **讀截圖**（Read 圖檔）：文字有沒有被截斷、元件有沒有重疊、跟預期長相是否一致。
2. **點主要按鈕**：每個姿態至少旋轉 0 那一格點一輪。看 `interact` 回傳的 `screen_changed`／`appeared`，確認出現預期的東西，再關掉回到目標畫面。**換姿態前一定要先關掉打開的 sheet**：sheet 還開著時，下一個姿態點到的是 sheet 底下的按鈕，`interact` 一樣回 ok，結果不能信。
3. **狀態保留**：換姿態後目標畫面的關鍵元素（stableKey）還在，沒有被踢回首頁、分頁沒跳、輸入的文字還在。

## 3. 判讀規則

- `FAIL`：可點元素（button、checkBox、slider 以外的控制項等）落進 safe area 外、超出螢幕，或在 book 姿態橫跨折痕。
- `WARN`：非互動元素（文字、圖）落進 safe area 外。看截圖判斷是否刻意（例如貼底的頁尾文字），在報告寫理由。
- 狀態列在畫面某一側，但 safe area 是整條：FAIL 的元素若沒有實際被時鐘、Wi-Fi 圖示蓋到，報告寫「侵入狀態列區域 N pt，未被遮擋」，交給使用者裁定，不要自己降級成通過。
- 折痕位置是推算的（畫面中線 ±10 pt），模擬器截圖畫不出折痕。
- `duo_check.py` 回 exit 2（畫面尺寸不認得）：用探針 app（`probe/build.sh`）在同一姿態量 safe area，加進 `INSETS` 表後重跑。
- 一格判不出來就標「無法判斷」並寫原因，不要略過。

## 4. 回報

1. 第一行結論，三選一，並寫出範圍：
   - 「在這張矩陣內，模擬器上沒有發現問題」
   - 「有 N 個問題」
   - 「有 N 格無法判斷」
   不要寫「Duo 上沒問題」：模擬器測不到真機手感、效能和實體折痕。
2. 矩陣表：姿態 × 旋轉，每格寫畫面尺寸、FAIL 數、WARN 數、按鈕可點、狀態保留。
3. 每個 FAIL：元素、位置、截圖檔名、一句影響。同一個元素在多格重複時合併成一條。
4. 沒測到的：CLI 只測得到 RocketSim 的固定 book 角度，任意角度要用 Desktop；旋轉失敗的格；只點了旋轉 0 的按鈕。
5. 只測試，不改 code、不 commit。

## 已知限制

- Safe area 表是 Xcode 27.2／iOS 27.2 的實測值；換 Xcode 版本要用探針 app 重量。
- 轉軸遲滯：亮哪一面、app 收到的 hinge 狀態，都取決於怎麼折過來，不只看角度。外螢幕亮著時 app 在 154° 還收到 `closed`。一律以讀回的畫面尺寸判斷是哪一面。
- `rocketsim screenshot` 依 hinge 判斷要截哪一面；用 Desktop 設角度造成「角度跟亮的那面不一致」時，可能截到全黑。截圖尺寸要對過。
- `duo_check.py` 遇到 book 但外螢幕亮著時，會跳過折痕檢查。
- 旋轉依賴 Device Hub 視窗結構與「輔助使用」權限，Xcode 改版可能失效。
