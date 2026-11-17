# duo-verify

讓 Claude Code 在 **iPhone Duo 模擬器**上自己驗一個畫面的 skill。

功能寫完後打 `/duo-verify`，Claude 會：

- 把 Duo 切到 closed、book（半折）、open 三個姿態，每個姿態再旋轉 4 個方向
- 讀每個按鈕的座標，自動檢查有沒有壓到狀態列、home indicator 區，或橫跨折痕
- 實際點主要按鈕，確認有反應
- 換姿態後確認畫面狀態有保留
- 看截圖對照你給的預期長相
- 交一份「姿態 × 旋轉」的矩陣報告

結論只會說「在這張矩陣內，模擬器上有沒有問題」。真機的手感、效能、實體折痕，模擬器測不到。

## 需要的環境

| 項目 | 必要嗎 | 說明 |
|---|---|---|
| macOS ＋ Xcode 27.1 以上 | 必須 | 實測用 Xcode 27.2 |
| iOS 27.1 以上 runtime（含 iPhone Duo） | 必須 | |
| Claude Code（Desktop 或 CLI） | 擇一 | Desktop 可設任意角度；CLI 只有三個固定姿態 |
| [RocketSim](https://www.rocketsim.app/) | 自動判讀需要 | 讀按鈕座標、點擊；CLI 也靠它切姿態。免費版每天的次數有限 |
| Device Hub ＋ 終端機「輔助使用」權限 | CLI 旋轉才需要 | Desktop 不需要 |
| Python 3 | 必須 | 跑 `duo_check.py`，只用標準函式庫 |

沒有 RocketSim 也能跑，skill 會改走「看圖模式」：由 Claude 看截圖判斷，精確度到不了 pt，報告會註明。

## 安裝

```bash
git clone https://github.com/peter6601/duo-verify-skill.git
ln -s "$PWD/duo-verify-skill/duo-verify" ~/.claude/skills/duo-verify
```

## 使用

一次測一個畫面，不用另外寫腳本。叫用時給三句描述：

```text
/duo-verify
要驗的畫面：首頁 → 設定 → 帳號
預期長相：上方是大頭貼和名字，下面一排三個按鈕，最底下是登出鍵
主要按鈕：編輯（要打開編輯頁）、登出（要跳確認視窗）
```

- **要驗的畫面**：從 app 首頁怎麼走到那裡
- **預期長相**：一兩句描述，或 Figma 連結；沒給就只做規則檢查
- **主要按鈕**：要點的按鈕，加上點了應該發生什麼

模擬器上只登入**測試帳號**：截圖會傳給模型。

## 檔案

```
duo-verify/
├── SKILL.md                  skill 本體：流程、判讀規則、回報格式
├── scripts/
│   ├── duo_check.py          用實測 safe area 和折痕位置檢查元素座標
│   ├── duo_pose.sh           用 RocketSim 切姿態並讀回確認
│   ├── duo_rotate.sh         點 Device Hub 的 Rotate Right
│   ├── devicehub_pose.sh     沒有 RocketSim 時，用 Device Hub 切姿態
│   └── safe-xcodebuild.sh    有別的 xcodebuild 在跑就拒絕執行，避免搶同一個模擬器
└── probe/
    ├── main.swift            探針 app：在畫面上印出 safe area 與 hinge 狀態
    ├── Info.plist
    └── build.sh              編譯並安裝探針 app
```

## 實測值（Xcode 27.2／iOS 27.2）

| 畫面 | 尺寸（pt） | safe area（上／左／下／右） |
|---|---|---|
| 外螢幕直向 | 466×678 | 0／0／34／84 |
| 外螢幕橫向 | 678×466 | 0／0／34／84 或 0／84／34／0（看轉的方向） |
| 內螢幕橫向 | 951×669 | 0／0／34／84 |
| 內螢幕直向 | 669×951 | 82／0／34／0 |

換 Xcode 版本後，用探針 app 重量一次，更新 `duo_check.py` 的 `INSETS` 表。

## 已知限制

- 轉軸有遲滯：同一個角度，亮外螢幕還是內螢幕要看怎麼折過來。一律以畫面尺寸判斷。
- 折痕位置是推算的（畫面中線 ±10pt），模擬器截圖畫不出折痕。
- 旋轉依賴 Device Hub 的視窗結構，Xcode 改版可能失效。

## 授權

MIT，見 [LICENSE](LICENSE)。
