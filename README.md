# duo-verify

**中文** | [English](README.en.md)

讓 Claude Code 在 **iPhone Duo 模擬器**上，自己幫你驗一個畫面。

相關：[SimPilot](https://github.com/peter6601/SimPilot)：讀按鈕位置、點按鈕、切 Duo 姿態的工具，這個 skill 預設用它。

## 目的

- iPhone Duo 是折疊機：有外螢幕、內螢幕，中間有折痕。
- 同一個畫面，要在不同姿態、不同方向都正常。
- 一般 iPhone 測不出 Duo 的問題：Duo 的狀態列在側邊，還多了折痕。
- 手動一格一格折、一格一格看，很花時間，也容易漏。
- 這個 skill 讓 Claude 自動跑完，交回一張問題清單。

## 可以得到什麼

功能寫完後打 `/duo-verify`，Claude 會：

- 把 Duo 切到 closed（闔起）、book（半折）、open（攤開）。
- book、open 各轉 4 個方向，closed 1 格，共 9 格。
- 讀每顆按鈕的位置，算它有沒有壓到狀態列、底部橫條或折痕。
- 實際點你指定的按鈕，確認有反應。
- 換姿態後，確認畫面還在、沒被踢回首頁。
- 看截圖，對照你描述的樣子。

最後交一份報告：

- 第一行就是結論：沒問題、有幾個問題，或有幾格無法判斷。
- 一張 9 格表：每格的畫面尺寸、FAIL 數、WARN 數。
- 每個問題：哪顆按鈕、在哪、對應的截圖。
- 截圖和資料存在 `~/duo-verify-runs/`，不會寫進你的專案。

報告只說「模擬器上這 9 格有沒有問題」。真機手感、效能、實體折痕，模擬器測不到。

## 需要準備什麼

| 項目 | 要不要 | 用途 |
|---|---|---|
| Mac ＋ Xcode 27.1 以上 | 必須 | 實測用 Xcode 27.2 |
| iOS 27.1 以上的模擬器 | 必須 | 才開得出 iPhone Duo |
| Claude Code | 必須 | Mac app 或終端機 CLI 都可以 |
| Python 3 | 必須 | 跑檢查腳本 |
| [SimPilot](https://github.com/peter6601/SimPilot) | 建議 | 讀按鈕位置、點按鈕；CLI 也靠它切姿態 |
| [RocketSim](https://www.rocketsim.app/) | 替代 | 沒裝 SimPilot 時用；免費版每天有次數限制 |
| Device Hub ＋「輔助使用」權限 | 只有 CLI | 在終端機切姿態、轉方向 |
| 測試帳號 | 必須 | 截圖會傳給 Claude |

- SimPilot 和 RocketSim 都沒裝，也能跑。
- 這時改成 Claude 看截圖判斷，精確度比較低，報告會註明。

## 安裝

1. 裝 skill：

   ```bash
   git clone https://github.com/peter6601/duo-verify-skill.git
   ln -s "$PWD/duo-verify-skill/duo-verify" ~/.claude/skills/duo-verify
   ```

2. 裝 SimPilot（建議）：

   ```bash
   brew install xcodegen
   git clone https://github.com/peter6601/SimPilot.git
   cd SimPilot
   scripts/make-app.sh
   build/simpilot runner build
   ln -s "$PWD/build/simpilot" /usr/local/bin/simpilot
   ```

- 裝一次，之後任何專案都能用 `/duo-verify`。
- SimPilot 要放在 PATH 上，skill 才找得到它。
- SimPilot clone 下來的資料夾要留著。細節見 [SimPilot 的 README](https://github.com/peter6601/SimPilot#安裝)。

## 怎麼執行

1. 開一台 iPhone Duo 模擬器，登入測試帳號。
2. 把要測的 app 打開。
3. 用終端機跑的話，打開 Device Hub，選到這台 Duo。
4. 在 Claude Code 打 `/duo-verify`，給三句描述：

```text
/duo-verify
要驗的畫面：首頁 → 設定 → 帳號
預期長相：上方是大頭貼和名字，下面一排三個按鈕，最底下是登出鍵
主要按鈕：編輯（要打開編輯頁）、登出（要跳確認視窗）
```

- **要驗的畫面**：從首頁怎麼走到那裡。
- **預期長相**：一兩句話，或 Figma 連結。沒給就只做規則檢查。
- **主要按鈕**：要點哪些按鈕，點了應該發生什麼。
- **引擎**（選填）：`simpilot` 或 `rocketsim`。沒寫就優先用 SimPilot。

5. 等報告。先看第一行和 FAIL 清單，有 FAIL 就修完再跑。

## 報告怎麼看

- **FAIL**：按鈕壓到狀態列、底部橫條、超出畫面，或橫跨折痕。要修。
- **WARN**：文字或圖片壓到邊。Claude 會看截圖判斷是不是刻意的。
- **交給你判斷**：按鈕在狀態列區域，但沒被時鐘或 Wi-Fi 圖示蓋到。
- **無法判斷**：姿態沒切到、截圖全黑。報告會寫原因。

duo-verify 只測試，不改 code。有 FAIL 時，如果你裝了 Xcode 匯出的 plugin（`xcode@claude-plugins-official`），報告會建議交給它的 `app-resizability` skill 修。這類問題多半出在 `UIScreen.main`、`interfaceOrientation`、safe area 的假設這幾類 API。修完再跑一次 duo-verify 確認。

## Mac app 和 CLI 差在哪

| | Mac app（Claude Code Desktop） | CLI（終端機） |
|---|---|---|
| 切姿態 | 內建，可以設任意角度 | 只有三個固定姿態，經 Device Hub |
| 轉方向 | 內建按鈕 | Device Hub 的 Rotate Right |
| 看畫面 | 對話旁邊即時看 | 看截圖檔 |
| 要先開 | Desktop v4.29.0 以上 | Device Hub，選到這台 Duo |

- 兩邊跑同一個 `/duo-verify`，結果一樣。
- 要測特定角度、想邊看邊測，用 Mac app。
- 要重複跑同一套、習慣終端機，用 CLI。

## SimPilot 和 RocketSim

- 兩個都能讀按鈕位置、點按鈕，輸出格式一樣。
- 同一個畫面實測 9 格，兩邊找到的問題完全一樣。

| | SimPilot | RocketSim |
|---|---|---|
| 取得 | [GitHub](https://github.com/peter6601/SimPilot)，免費、開源 | [rocketsim.app](https://www.rocketsim.app/)，付費，有免費版 |
| 次數限制 | 沒有 | 免費版每天有限 |
| 同名按鈕 | 只點看得到的那顆 | 可能點錯 |
| 點完之後 | 會說哪些東西換了位置 | 只說畫面有沒有變 |
| 讀姿態角度 | 讀不到，只知道是哪個姿態 | 讀得到 |

- SimPilot 跑著時會佔住 xcodebuild。
- 跑完 skill 會自動關掉它；閒置 3 分鐘也會自己關。

## 已知限制

- 只能測模擬器，不能測實機。
- 折痕位置是推算的：畫面中線左右各 10pt。
- 闔起時模擬器不會旋轉，外螢幕橫放測不到。
- 轉軸有遲滯：同一個角度，亮哪一面要看怎麼折過來。所以一律看畫面尺寸判斷。
- 轉方向靠 Device Hub 的視窗結構，Xcode 改版可能失效。
- 實測值只對 Xcode 27.2，換版本要重量（見下方）。

## 實測值（Xcode 27.2／iOS 27.2）

| 畫面 | 尺寸（pt） | safe area（上／左／下／右） |
|---|---|---|
| 外螢幕直向 | 466×678 | 0／0／34／84 |
| 內螢幕橫向 | 951×669 | 0／0／34／84 |
| 內螢幕直向 | 669×951 | 82／0／34／0 |

- 沒有外螢幕橫向：闔起時模擬器不旋轉。
- 換 Xcode 版本後，用探針 app 重量，更新 `duo_check.py` 的 `INSETS` 表。

## 檔案

```
duo-verify/
├── SKILL.md                  skill 本體：流程、判讀規則、報告格式
├── scripts/
│   ├── duo_check.py          用實測 safe area 和折痕位置檢查按鈕座標
│   ├── duo_pose.sh           用 RocketSim 切姿態並確認
│   ├── duo_rotate.sh         點 Device Hub 的 Rotate Right
│   ├── devicehub_pose.sh     沒有 RocketSim 時，用 Device Hub 切姿態
│   └── safe-xcodebuild.sh    別的 xcodebuild 在跑時拒絕執行，避免搶模擬器
└── probe/
    ├── main.swift            探針 app：在畫面上印出 safe area 和姿態
    ├── Info.plist
    └── build.sh              編譯並安裝探針 app
```

## 授權

MIT，見 [LICENSE](LICENSE)。
