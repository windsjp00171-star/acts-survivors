# 宣教之路

以使徒行傳為背景的 survivors-like roguelite。玩家操控保羅，同伴就是武器：他們群聚在保羅身邊自動攻擊，對抗懼怕、紛爭、謊言、沉睡這些想把隊伍打散的黑暗勢力。

目前有四座城（初代教會）：腓立比、帖撒羅尼迦、哥林多、以弗所，照保羅旅程的順序解鎖，通關就「建立教會」。一局約 12 分鐘，保羅用書信攻擊，升級三選一招募與強化同伴、收集聖靈果子與全副軍裝、用「肢體連結」把同伴的招式串成連鎖、同心合意滿了開五旬節 FEVER；第 6 分鐘起有菁英潮，第 10 分鐘各城的 Boss 出現，打倒就通關。保羅倒下就結束。

遊戲從安提阿營地開始：走到同伴身邊看他的生平，走到路標出發。營地會隨進度長出補給帳棚、見證牆等設施。每局結束帶回「見證」，在營地解鎖新同伴、果子、軍裝和隊伍位置；完成見證錄的目標會解鎖舊約人物（大衛、參孫、摩西、以利亞、約書亞）。常帶出門的同伴默契會升高，解鎖他的生平。

## 怎麼玩

**直接玩（Windows）**：下載 `宣教之路-windows.zip`，解壓縮後雙擊 `ActsSurvivors.exe`，不用安裝。Windows 跳出「已保護您的電腦」時按「其他資訊」→「仍要執行」。

**Android 手機**：下載 APK 到手機，點開安裝。第一次會問「是否允許安裝不明來源的應用程式」，允許後再按一次安裝。直式單手玩，按住畫面下方拖曳移動。

**用 Godot 開專案**：

1. 下載 [Godot 4.4](https://godotengine.org/download)（標準版即可，免安裝）
2. 下載這個專案（綠色的 Code 按鈕 → Download ZIP，或用 git clone）
3. 打開 Godot，按「匯入」，選這個資料夾裡的 `project.godot`
4. 按右上角的 ▶（或 F5）開始玩

**操作**

| 動作 | 鍵盤 | 觸控／滑鼠 |
| --- | --- | --- |
| 移動 | WASD 或方向鍵 | 按住畫面下方拖曳 |
| 升級選卡 | 1／2／3 | 點卡片 |
| 重抽升級卡（要先解鎖） | R | 按「重抽」 |
| 五旬節 FEVER | 空白鍵（同心合意滿了） | 按「五旬節」按鈕 |
| 暫停 | Esc 或 P | 右上角「Ⅱ」、手機返回鍵 |
| 結束後再出發 | Enter 或空白鍵 | 按「再出發」或「回安提阿」 |

## 一起來改這個遊戲

同伴、技能、敵人、怪物數量曲線，全部寫在 [`data/game.json`](data/game.json)；局外成長在 [`data/meta.json`](data/meta.json)；同伴生平在 [`data/bios.json`](data/bios.json)。不會寫程式也能改：打開檔案改數字或文字，存檔後重新執行就生效。

- `companions`：同伴名單、名字、技能、流派
- `skills`：每種技能 Lv1 的數值（base）和 Lv2–5 的變化（levels）、升級卡說明（desc）；`engine` 可以借用現有招式的運作方式做出新角色
- `links`／`synergy`：肢體連結的種類與間隔、同工加成
- `tasks`：旅程任務
- `fever`：同心合意累積速度、FEVER 長度與效果
- `enemies`：四種敵人的血量、速度、打散隊伍的力道
- `waves.curve`：每個時間點場上要有多少怪
- `waves.scaling`／`waves.veteran`：敵人隨時間變強的倍率、老練敵人的出現機率
- `fruits`／`armor`／`evolutions`：果子、軍裝、進化條件與效果
- `elites`／`trials`／`elite_wave`：菁英、考驗型敵人與出現時間
- `boss`：Boss 出現時間、血量、各招式傷害

`meta.json` 裡有營地設施出現的條件、見證怎麼算、一開始解鎖哪些、基地能買什麼、見證錄目標、默契門檻。`bios.json` 的生平歡迎補充修正（請附經文出處）。

改出好玩的設定，歡迎開 Issue 或 Pull Request 分享。之後遊戲裡會有「使徒行傳第 29 章」的入口，讓玩家直接在遊戲中改寫。

## 專案結構

| 路徑 | 內容 |
| --- | --- |
| `data/game.json` | 所有局內遊戲數值 |
| `data/meta.json` | 局外成長：見證、解鎖、見證錄、默契 |
| `data/bios.json` | 同伴生平 |
| `data/stages.json` | 初代教會關卡（城市、Boss、書信卡） |
| `data/talks.json` | 營地對話 |
| `scripts/camp.gd` | 安提阿營地（遊戲開啟時的畫面） |
| `scripts/base.gd` | 營地裡的彈出面板（出發、同伴、解鎖、見證錄） |
| `scripts/save.gd` | 存檔（`profile.json`） |
| `scripts/main.gd` | 遊戲主程式 |
| `scripts/game_ui.gd` | 畫面介面（血量、升級卡、寶箱、失敗與通關畫面） |
| `scripts/ui_kit.gd` | 共用字型、顏色、按鈕 |
| `tools/runs_report.py` | 每局紀錄報表 |
| `scenes/base.tscn` | 營地（遊戲開啟時的畫面） |
| `scenes/main.tscn` | 一局遊戲 |
| `assets/sprites/` | 像素圖（目前由程式產生） |
| `docs/mockups/` | 美術風格樣稿（用瀏覽器打開） |

## 開發者：打包

`export_presets.cfg` 已設好 Windows 與 Linux。裝好 Godot 4.4.1 的 Export Templates 後：

```
godot --headless --path . --export-release "Windows Desktop" build/windows/ActsSurvivors.exe
```

Android：需要 Android SDK（apksigner）與 JDK，在 Godot 編輯器設定填好路徑。簽章金鑰用環境變數提供，不要寫進 `export_presets.cfg`：

```
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=金鑰路徑 GODOT_ANDROID_KEYSTORE_RELEASE_USER=acts GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=密碼 \
godot --headless --path . --export-release "Android" build/android/ActsSurvivors.apk
```

之後每次更新都必須用**同一把金鑰**簽，手機才能直接覆蓋安裝（保留存檔）。

## 開發者：自動測試

不用開視窗也能跑一段遊戲、印出狀態：

```
godot --headless --path . res://scenes/main.tscn -- --smoke
```

- `--t0=秒數`：直接跳到某個時間（例如 `--t0=590` 測 Boss）
- `--preset=strong`：全員出動、西拉滿級帶喜樂，開局附一個寶箱（測進化）
- `--preset=five`：接近實際的中後期隊伍（5 人 Lv4），拿來測難度曲線
- `--preset=ot`：五位舊約人物滿級
- `--preset=links`：預先接好一條三段的肢體連結
- `--stage=0~3`：選城市（0 腓立比、1 帖撒羅尼迦、2 哥林多、3 以弗所）
- `--preset=evo`：五位滿級並全部進化
- `--nofever`：不自動開五旬節（看一般狀態的畫面）
- `--light`：開五旬節時一定出現光的身影
- `--shot=路徑.png`：有顯示環境時存截圖（升級卡、FEVER、寶箱、Boss 預警、連鎖、失敗彩蛋各一張）

營地：`godot --path . res://scenes/base.tscn -- --shot=路徑.png` 會存營地、走近路標，以及出發、同伴、生平、解鎖、見證錄面板的截圖。加 `--resolution 450x900` 可以看直式（手機）排版。

## 平衡紀錄

每局結束會在本機存一筆紀錄（存活時間、等級、隊伍、果子、軍裝、最常被誰打散）。整理成報表：

```
python tools/runs_report.py
```

## 授權

尚未決定。
