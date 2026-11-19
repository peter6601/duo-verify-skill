---
name: duo-verify
description: 功能或畫面寫完後，在 iPhone Duo 模擬器上自己跑一輪驗證：9 格矩陣（book、open 各 4 個旋轉方向＋closed 1 格，模擬器闔起時不旋轉），自動檢查按鈕有沒有落進狀態列、home indicator 區或橫跨折痕，實際點主要按鈕、比對截圖與預期、檢查切換時狀態有沒有保留，最後給「在這張矩陣內可以出貨／有問題／無法判斷」的結論。使用者說「duo-verify」「在 Duo 上驗一下」「Duo 上會不會有問題」時使用。
---

# /duo-verify：在 iPhone Duo 模擬器上驗證一個畫面

輸入（叫用時問清楚，缺的就問一次）：
1. **要驗的畫面**：怎麼從 app 首頁走到那裡（例如「首頁 → 設定 → 帳號」）。
2. **預期長相**：Figma frame 連結，或一兩句描述（哪些按鈕、什麼排法）。沒有就只做規則檢查，報告註明「未比對設計」。
3. **主要按鈕**：要實際點的按鈕 label，以及點了之後預期出現什麼。
4. **引擎**（選填）：讀元素和點擊用 `simpilot` 或 `rocketsim`。沒指定時，有 SimPilot 就用 SimPilot（見第 0 步第 3 條）。

工具都在這個 skill 的資料夾裡（下稱 `$H`，就是載入 skill 時顯示的 base directory）：

| 檔案 | 做什麼 |
|---|---|
| `scripts/duo_pose.sh <closed\|book\|open>` | 用 RocketSim 切姿態並讀回 hinge 確認，不符就重設，最多 3 次 |
| `scripts/duo_rotate.sh` | 點 Device Hub 的 Rotate Right 一次（RocketSim 沒有旋轉指令） |
| `scripts/duo_check.py <elements.json> --pose P [--baseline parent.json]` | 依實測 safe area 與折痕位置檢查元素座標；exit 1＝有 FAIL，2＝無法判斷 |
| `scripts/safe-xcodebuild.sh <參數>\|--check` | 這台機器有別的 xcodebuild 在跑就 exit 1、印出對方 PID 和指令；沒有才執行 |
| `scripts/devicehub_pose.sh "Closed\|Partially Open\|Open"` | 沒有 RocketSim 時，用 Device Hub 切姿態 |
| `probe/build.sh` | 探針 app：遇到 `duo_check.py` 不認得的畫面尺寸時，用它量 safe area |

SimPilot 不在這個資料夾，是另外裝的 CLI（[https://github.com/peter6601/SimPilot](https://github.com/peter6601/SimPilot)，取代 `rocketsim elements`／`interact tap`／`duo pose`／`duo hinge`，沒有次數限制）：`SP=$(command -v simpilot)`。沒裝時不要自己裝，照第 0 步第 3 條改用 RocketSim；使用者想裝就給他那個 repo README 的「安裝」段。

## 0. 前置檢查（任一不過就停下來回報，不要硬跑）

1. **要 build 時，一律經過 `$H/scripts/safe-xcodebuild.sh`**：這台機器有別的 xcodebuild 在跑，它會 exit 1 並印出對方的 PID 和指令。exit 1 就停，把對方的 PID 和指令告訴使用者，不要 build、不要重試到通過。
   - 自己下 xcodebuild：`$H/scripts/safe-xcodebuild.sh <xcodebuild 參數>`，取代直接呼叫 `xcodebuild`。
   - 用 XcodeBuildMCP 或 Desktop 內建的 build：它們不經過這支腳本，先**單獨一個指令**跑 `$H/scripts/safe-xcodebuild.sh --check`，exit 0 才 build。
   - 只用已安裝的 app、不 build 時，別人的 xcodebuild 不影響，照常跑。
2. `xcrun simctl list devices booted | grep "iPhone Duo"` 拿 UDID（下稱 `$D`）。沒有就請使用者開一台。
3. **選讀元素的引擎**（下稱 `$ENG`）。使用者指定就照用；沒指定時 `[ -x "$SP" ]` 成立就用 SimPilot，否則用 RocketSim。
   - **SimPilot**：`"$SP" status` 回 `ok:true`。第一次 `elements` 會啟動 runner，約 15 秒，之後每次 0.4～0.9 秒。runner 本身就是一個 xcodebuild，跑著時會佔住 xcodebuild：
     - 回 `xcodebuild_busy`：別人的 xcodebuild 在跑，停下來把對方的 PID 和指令告訴使用者，不要重試。
     - 回 `runner_not_built`：先過第 1 條，再跑 `"$SP" runner build`。
     - 矩陣跑完、或接下來要 build 別的東西時，跑 `"$SP" stop` 讓出 xcodebuild（閒置 3 分鐘也會自己關）。
   - **RocketSim**：`rocketsim duo hinge --udid $D` 回 `ok:true`。回 `app_not_running` 就 `open -a RocketSim` 後重試。
   - RocketSim 回 `quota_exceeded`（免費版每日次數用完）時，有 SimPilot 就改用 SimPilot，並在報告註明。**不要想辦法繞過次數限制**。
   - 兩個都不能用：改走「看圖模式」：
     - Desktop：切姿態、旋轉、截圖用內建工具；CLI：切姿態用 Device Hub（`$H/scripts/devicehub_pose.sh`），截圖用 `xcrun simctl io $D screenshot --display=primary|primary-1`。
     - 跳過 `duo_check.py`，由 Claude 讀截圖判斷按鈕有沒有壓到狀態列、home indicator、折痕。
     - 報告第一行註明「看圖模式：未做座標檢查，精確度到不了 pt」。
4. 判斷執行環境，決定切姿態和旋轉用哪一套（見下方「兩種環境」）。CLI 環境的 Device Hub 視窗要開著（`pgrep DeviceHub`），而且選在這台 Duo 上：
   - 有 SimPilot：切姿態和旋轉都靠它。沒開就停下來請使用者打開 Device Hub。
   - 沒有 SimPilot：切姿態用 RocketSim，Device Hub 只用來旋轉；沒開就只跑旋轉 0，報告註明旋轉沒測。
5. 模擬器要登入的話，停下來請使用者用**測試帳號**登入。截圖會送到 Anthropic。

## 兩種環境

| 動作 | Claude Code Desktop（有內建 iOS Simulator 工具） | CLI |
|---|---|---|
| 切姿態 | Desktop 的 `duo_pose`，可設任意角度 | 有 SimPilot：`"$SP" duo pose closed\|book\|open --udid $D`（點 Device Hub 的按鈕，自己確認亮的那面、最多重試 3 次）；沒有：`$H/scripts/duo_pose.sh closed\|book\|open`（RocketSim）。兩者都只有三個固定姿態 |
| 旋轉 | Desktop 的 `rotate` | `$H/scripts/duo_rotate.sh`（Device Hub＋輔助使用權限） |
| 讀回 hinge | Desktop 的 `duo_hinge` | 有 SimPilot：`"$SP" duo hinge --udid $D`，**`hinge_angle_degrees` 一律是 null**，`hinge_state` 是推斷的（見下方說明）；沒有：`rocketsim duo hinge --udid $D` |
| 元素座標、點擊 | 依 `$ENG`，見下表 | 依 `$ENG`，見下表 |

| 動作 | SimPilot | RocketSim |
|---|---|---|
| 讀元素（下稱 `$EL`） | `"$SP" elements --udid $D` | `rocketsim elements --udid $D` |
| 點擊（下稱 `$TAP <label>`） | `"$SP" interact tap --label <label> --udid $D` | `rocketsim interact tap --label <label> --screen latest --udid $D` |
| 截圖 | `xcrun simctl io $D screenshot --display=primary`（外螢幕）或 `primary-1`（內螢幕），依 canvasSize 選 | `rocketsim screenshot --udid $D`，尺寸對不上再改用 simctl |
| 差異 | 不列被 sheet 蓋住的下層元素，元素數較少；tap 多回 `moved`（位置變了的 label）、`value_changed` | 會列被蓋住的元素，靠 `--baseline` 排除 |

兩個引擎的 JSON 格式相同，`duo_check.py` 都能讀；同一格的 FAIL／WARN 在 Xcode 27.2 實測逐格一致。Desktop 環境用 SimPilot 時，整輪不會呼叫任何 `rocketsim` 指令。

`simpilot duo hinge` 讀不到角度（模擬器外面沒有公開 API 讀得到），`hinge_state` 是這樣推斷的：亮外螢幕就是 `closed`；亮內螢幕時，靠 SimPilot 上次 `duo pose` 設的姿態分 `partiallyOpen`／`openFlat`，分不出來回 `unknown`。所以 CLI 用 SimPilot 時：
- 切姿態一律用 `"$SP" duo pose`，不要用 Device Hub 或其他方式手動切，否則 `hinge_state` 會是舊的推斷。
- 判斷是哪一面，以 `active_display`（outer／inner）和 `elements` 的 canvasSize 為準；報告裡的角度寫「無（SimPilot 讀不到）」，不要自己填數字。

**book 一定要測到內螢幕。** 轉軸有很大的遲滯：從 Closed 慢慢掀開，到約 150° 都還停在外螢幕；從 Open 慢慢關上，到約 25° 都還在內螢幕；從 Closed 一次跳到 84° 以上才會立刻換到內螢幕。所以 book 的做法是：
- Desktop：先切到 Open，再把角度設成 130°。
- CLI：`"$SP" duo pose book`（內部先切 Open 再切 Partially Open）或 `scripts/duo_pose.sh book`（RocketSim 是一次跳過去），都會到內螢幕。
- 兩邊都要看 `elements` 的 canvasSize 是不是 951×669 或 669×951。如果是 466×678，這一格就是「外螢幕半開」，記下來，不算 book。
- 要測「慢慢掀開時一直停在外螢幕」的情境，另外加一格「外螢幕半開」：Desktop 從 Closed 每次加 10° 掀到 120°。

## 1. Build 並開到目標畫面

- Build／安裝：先過第 0 步第 1 條。CLI 用 `safe-xcodebuild.sh` 或 XcodeBuildMCP `build_run_sim`（先 `session_show_defaults`）；Desktop app 用內建模擬器面板。scheme 用專案平常開發用的那個。
- 在**進入目標畫面前**，於上一層畫面拍 baseline：`$EL > $RUN/baseline.json`。RocketSim 會把被 fullScreenCover／sheet 蓋住的下層元素也列出來，`--baseline` 用來排除它們；SimPilot 不列，但照樣拍，兩個引擎的流程才一樣。如果已經在目標畫面裡，要離開才能拍：離開的動作會付費、送出資料或結束一段流程時，先問使用者，不要自己按。
- 走到目標畫面。操作用 `$TAP <label>`。

## 2. 跑矩陣

`$RUN` 用 `~/duo-verify-runs/<功能>_<日期>`（不要寫進專案 repo）。每一格：

```bash
# 切姿態、旋轉：依「兩種環境」那張表（CLI 用 scripts/duo_pose.sh／duo_rotate.sh，Desktop 用內建工具）
$EL > $RUN/<pose>_r<n>.json
# 截圖依 $ENG（見上表）。截圖要跟 canvasSize 對得上（×3），不對就是截到沒亮的那一面（全黑）：
#   外螢幕 xcrun simctl io $D screenshot --display=primary   $RUN/<pose>_r<n>.png
#   內螢幕 xcrun simctl io $D screenshot --display=primary-1 $RUN/<pose>_r<n>.png
python3 $H/scripts/duo_check.py $RUN/<pose>_r<n>.json --pose <pose> --baseline $RUN/baseline.json > $RUN/<pose>_r<n>.check.txt
```

姿態順序 closed → book → open，每個姿態旋轉 0–3。一個 shell 指令裡不要 `rm`；換新資料夾即可。

**closed 時模擬器不旋轉，r0–r3 記成同一格。** 闔起時按旋轉（Desktop 的 `rotate` 或 Device Hub 的 Rotate Right），devicectl 的裝置方向一直是 portrait、外螢幕一直是 rot0；同一個按鈕在 book／open 都轉得動（Xcode 27.2 實測，Desktop 和 CLI 都一樣）。所以：
- closed 只跑 r0，不用轉；矩陣表寫一列「closed r0–r3（模擬器闔起時不旋轉）」。
- 不要標成「無法判斷」或「旋轉失敗」，也不要重按。
- 報告的「沒測到」寫「外螢幕橫放：模擬器測不到」。

**每轉一次都要確認真的轉了，以及 app 有沒有跟著轉。** 轉完用 `xcrun devicectl device info displays --device $D` 讀亮著那一面（`active: true`）的 `currentOrientation`（rot0 直向、rot90／rot270 橫向、rot180 上下顛倒），再對照 `elements` 的 canvasSize。app 不支援的方向，裝置轉了、畫面停在 app 支援的方向。
- devicectl 是 rot180（上下顛倒）：canvasSize 和直向一樣都是 669×951 或 466×678，光看尺寸分不出 app 有沒有轉。跟直向那格的截圖比，一模一樣就是 app 不支援上下顛倒，這一格記「app 不支援此方向，畫面停在直向」，不重複判讀。
- devicectl 的方向變了，但 canvasSize 的長寬方向跟它對不上（例：rot90 卻還是 669×951）：同樣記「app 不支援此方向」。
- 外螢幕鎖直向的 app，四個方向的畫面都一樣，同樣在報告註明。
- devicectl 的方向也沒變：才是旋轉失敗，這一格標「無法判斷」（closed 除外，見上方）。不要以為是旋轉失敗就一直重按，先看 devicectl。

每一格另外做：
1. **讀截圖**（Read 圖檔）：文字有沒有被截斷、元件有沒有重疊、跟預期長相是否一致。
2. **點主要按鈕**：每個姿態至少旋轉 0 那一格點一輪。看 `$TAP` 回傳的 `screen_changed`／`appeared`（SimPilot 另有 `moved`：例如兩張卡片對調、元素沒增減只換了位置，就看這個），確認出現預期的東西，再關掉回到目標畫面。**換姿態前一定要先關掉打開的 sheet**：sheet 還開著時，下一個姿態點到的是 sheet 底下的按鈕，`interact` 一樣回 ok，結果不能信。
3. **狀態保留**：換姿態後目標畫面的關鍵元素（stableKey）還在，沒有被踢回首頁、分頁沒跳、輸入的文字還在。

整張矩陣跑完，`$ENG` 是 SimPilot 就跑 `"$SP" stop`，讓出 xcodebuild。

## 3. 判讀規則

- `FAIL`：可點元素（button、checkBox、slider 以外的控制項等）落進 safe area 外、超出螢幕，或在 book 姿態橫跨折痕。
- `WARN`：非互動元素（文字、圖）落進 safe area 外。看截圖判斷是否刻意（例如貼底的頁尾文字），在報告寫理由。
- 狀態列在畫面某一側，但 safe area 是整條：FAIL 的元素若沒有實際被時鐘、Wi-Fi 圖示蓋到，報告寫「侵入狀態列區域 N pt，未被遮擋」，交給使用者裁定，不要自己降級成通過。
- 折痕位置是推算的（畫面中線 ±10 pt），模擬器截圖畫不出折痕。
- `duo_check.py` 回 exit 2（畫面尺寸不認得）：用探針 app（`probe/build.sh`）在同一姿態量 safe area，加進 `INSETS` 表後重跑。
- 一格判不出來就標「無法判斷」並寫原因，不要略過。

## 4. 回報

1. 第一行結論，三選一，並寫出範圍和用了哪個引擎（SimPilot／RocketSim／看圖模式）：
   - 「在這張矩陣內，模擬器上沒有發現問題」
   - 「有 N 個問題」
   - 「有 N 格無法判斷」
   不要寫「Duo 上沒問題」：模擬器測不到真機手感、效能和實體折痕。
2. 矩陣表：姿態 × 旋轉，每格寫畫面尺寸、FAIL 數、WARN 數、按鈕可點、狀態保留。
3. 每個 FAIL：元素、位置、截圖檔名、一句影響。同一個元素在多格重複時合併成一條。
4. 沒測到的：CLI 只測得到固定的 book 姿態（用 SimPilot 時連角度都沒有），任意角度要用 Desktop；外螢幕橫放（closed 時模擬器不旋轉）；旋轉失敗的格；只點了旋轉 0 的按鈕。
5. 只測試，不改 code、不 commit。
6. **有 FAIL 時，最後一行建議交棒修正**（不要自己改）：
   - session 有 Xcode plugin 的 `app-resizability` skill（`xcode@claude-plugins-official`，由 `xcrun agent plugin` 匯出）時，建議交給它修。這類 FAIL 的根因多半在它處理的五類 API：`UIScreen.main`、`interfaceOrientation`、application lifecycle（沒改成 scene）、假設上下左右對稱或不會變動的 safe area、`userInterfaceIdiom`。交棒時附上 FAIL 清單（元素、姿態×旋轉、位置），讓它從這些畫面的 code 找起。
   - 沒有這個 skill：只列 FAIL，修法交給使用者。
   - 修完要重跑一次 duo-verify，至少重跑原本 FAIL 的那幾格，才算修好。

## 已知限制

- Safe area 表是 Xcode 27.2／iOS 27.2 的實測值；換 Xcode 版本要用探針 app 重量。
- 轉軸遲滯：亮哪一面、app 收到的 hinge 狀態，都取決於怎麼折過來，不只看角度。外螢幕亮著時 app 在 154° 還收到 `closed`。一律以讀回的畫面尺寸判斷是哪一面。
- `rocketsim screenshot` 依 hinge 判斷要截哪一面；用 Desktop 設角度造成「角度跟亮的那面不一致」時，可能截到全黑。截圖尺寸要對過。
- `duo_check.py` 遇到 book 但外螢幕亮著時，會跳過折痕檢查。
- CLI 環境有 SimPilot 時，整輪不會呼叫任何 `rocketsim` 指令。
- `simpilot duo pose` 回 `devicehub_wrong_device`（Device Hub 選的不是這台）、`devicehub_not_running` 或 `devicehub_click_failed`（多半是缺「輔助使用」權限）時，停下來告訴使用者，不要改去點別台。回 `pose_not_reached` 就把那個姿態的格標「無法判斷」。
- SimPilot 的 `moved` 只看 label 和位置：打開 sheet 時，被蓋住的元素和 sheet 裡的同名元素也會算進來。
- 旋轉依賴 Device Hub 視窗結構與「輔助使用」權限，Xcode 改版可能失效。
