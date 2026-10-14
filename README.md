# 宣教之路

以使徒行傳為背景的 survivors-like roguelite。玩家操控保羅，同伴就是武器：他們群聚在保羅身邊自動攻擊，對抗懼怕、紛爭、謊言、沉睡這些想把隊伍打散的黑暗勢力。

目前是原型「腓立比」這一座城：約 12 分鐘一局，升級三選一招募與強化同伴、收集聖靈果子與全副軍裝、同心合意滿了開五旬節 FEVER；第 6 分鐘起有菁英潮，第 10 分鐘 Boss「捆鎖」出現，打倒就通關。保羅倒下就結束。

## 怎麼玩

**直接玩（Windows）**：下載 `宣教之路-windows.zip`，解壓縮後雙擊 `宣教之路.exe`，不用安裝。Windows 跳出「已保護您的電腦」時按「其他資訊」→「仍要執行」。

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
| 五旬節 FEVER | 空白鍵（同心合意滿了） | 按「五旬節」按鈕 |
| 失敗後再出發 | Enter 或空白鍵 | 按「再出發」 |

## 一起來改這個遊戲

同伴、技能、敵人、怪物數量曲線，全部寫在 [`data/game.json`](data/game.json)。不會寫程式也能改：打開這個檔案改數字，存檔後重新執行就生效。

- `companions`：同伴名單、名字、技能、站位
- `skills`：每種技能 Lv1 的數值（base）和 Lv2–5 的變化（levels）、升級卡說明（desc）
- `start_party`：開局帶哪些同伴
- `fever`：同心合意累積速度、FEVER 長度與效果
- `enemies`：四種敵人的血量、速度、打散隊伍的力道
- `waves.curve`：每個時間點場上要有多少怪
- `fruits`／`armor`／`evolutions`：果子、軍裝、進化條件
- `elites`／`trials`／`elite_wave`：菁英、考驗型敵人與出現時間
- `boss`：Boss 出現時間、血量、各招式傷害

改出好玩的設定，歡迎開 Issue 或 Pull Request 分享。之後遊戲裡會有「使徒行傳第 29 章」的入口，讓玩家直接在遊戲中改寫。

## 專案結構

| 路徑 | 內容 |
| --- | --- |
| `data/game.json` | 所有遊戲數值 |
| `scripts/main.gd` | 遊戲主程式 |
| `scripts/game_ui.gd` | 畫面介面（血量、升級卡、寶箱、失敗與通關畫面） |
| `tools/runs_report.py` | 每局紀錄報表 |
| `scenes/main.tscn` | 主場景 |
| `assets/sprites/` | 像素圖（目前由程式產生） |
| `docs/mockups/` | 美術風格樣稿（用瀏覽器打開） |

## 開發者：打包

`export_presets.cfg` 已設好 Windows 與 Linux。裝好 Godot 4.4.1 的 Export Templates 後：

```
godot --headless --path . --export-release "Windows Desktop" build/windows/宣教之路.exe
```

## 開發者：自動測試

不用開視窗也能跑一段遊戲、印出狀態：

```
godot --headless --path . -- --smoke
```

- `--t0=秒數`：直接跳到某個時間（例如 `--t0=590` 測 Boss）
- `--preset=strong`：滿編隊伍、西拉滿級帶喜樂，開局附一個寶箱（測進化）
- `--shot=路徑.png`：有顯示環境時存截圖（升級卡、FEVER、寶箱、Boss 預警、失敗彩蛋各一張）

## 平衡紀錄

每局結束會在本機存一筆紀錄（存活時間、等級、隊伍、果子、軍裝、最常被誰打散）。整理成報表：

```
python tools/runs_report.py
```

## 授權

尚未決定。
