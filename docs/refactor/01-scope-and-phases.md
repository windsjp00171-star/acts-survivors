# 重構範圍與階段（2026-11-08 定案）

接續 [00-baseline-and-inventory.md](00-baseline-and-inventory.md)。分支 `refactor/studio`，不動 main。

## 範圍

| 領域 | 做什麼 | 驗收 |
|---|---|---|
| 程式 | 拆 `main.gd`（helper `RefCounted` + `g`），行為不變 | storysim、存檔測試 |
| 美術 | 程式內畫圖與色彩 token 化；素材集中載入；清未使用素材；UI 套件與版面；**重設視覺風格（史詩感）** | 結構部分逐像素不變；風格部分以新風格為準，由使用者逐畫面核可 |
| 音樂 | `sfx.gd` 播放與混音整理；`make_music.py`／`make_sounds.py` 資產管線整理；**重新作曲成史詩感，允許改 BPM** | 見下 |

### 美術範圍細項（2026-11-08 補充：使用者指定人物與關卡也要重構）

| 項目 | 程式端 | 素材端（`tools/`） |
|---|---|---|
| 人物 | `main.gd` 的 `_animate`、隊形與人物繪製；`camp.gd` 的人物 | `make_people.py`（218 行）、`make_people_src.py`（241 行）、`people_src/` 原圖 |
| 敵人 | 敵人繪製與特效 | `make_enemies.py` |
| 關卡 | `main.gd` 的「場景物件」段（766 行）、`_draw_ground_fx`、`_draw_air` | `make_terrain.py`（702 行）、`make_landmarks.py`（488 行）、`make_decals.py`（182 行） |
| 營地／標題／UI | `camp.gd`、`title.gd`、`base.gd`、`game_ui.gd`、`ui_kit.gd` | `make_camp.py`、`make_board.py`、`make_kit_icons.py` |
| 特效 | `_fx`、`_draw_*` 系列 | `make_vfx.py` |

結構階段（A）對以上每一項都要求逐像素不變；風格階段（B）才換樣子。

## 不動

- `arpg.gd`、`arpg.tscn`、`wip/0.51-classes-runes`。`arpg.gd` 的外觀因此**不會**跟著新風格改，是已知缺口。
- `save.gd` 的存檔格式與存檔碼全程向下相容。
- Android 簽章與匯出設定；金鑰不 commit、密碼只走環境變數。

## 硬限制（風格階段）

- 維持 640×360 像素風與現有縮放。
- 字型沿用 Noto Sans TC + Hebrew-Game（需涵蓋中文與希伯來文）。

## 階段

結構（不改外觀、不改聲音）一律先於風格。

| 階段 | 內容 | 狀態 |
|---|---|---|
| 0 | 4.7.2 升級、import、基準 | ✅ |
| 1 | 盤點 | ✅ |
| 2 | 存檔往返測試、黃金存檔碼 | ✅ |
| 2.5 | **視覺基準**：加 `--seed=`、固定幀率截圖腳本、基準截圖放 `production/qa/evidence/`；先驗證兩次跑出來是否逐像素相同，不同就改用容差並明講 | 進行中 |
| 3–4 | 拆 `main.gd` | |
| A | 美術結構：色彩／效果 token、`Art` 集中載入（快取、缺圖提示）、清未使用素材。**逐像素不變** | |
| M1 | `sfx.gd` 整理，行為與聲音不變 | |
| M2 | `make_music.py`／`make_sounds.py` 整理，重現輸出並比對 | |
| **關卡** | 風格提案（配色、氛圍、範例截圖；曲風、曲速、範例音檔）→ **使用者核可才進 B** | |
| B | 換風格：token、sprite、UI 套件（可改 `ui_kit.gd`，先確認 wip 分支現況）、重新作曲與音效；改 BPM 要同步重調同行合擊（`music_bpm`）判定並多跑一輪玩法測試 | |
| 5 | 清死碼、`config/features` 決定、CHANGELOG 收尾 | |

## 每步固定動作

parse check、storysim（隔離 APPDATA）、存檔往返測試、CHANGELOG、獨立 commit。美術步驟另加截圖比對；音樂步驟另加資產重現比對。

## 風險

- 音樂的 BPM 與同行合擊判定綁在一起（`main.gd` 的 `music_bpm`），改曲速會改玩法手感。
- 全域亂數沒有種子（main.gd 約 167 處 `randf`／`randi`／`shuffle`／`pick_random`），截圖要可重現必須先加種子。
- 風格是主觀的：無法自動驗收，必須由使用者逐畫面、逐曲核可。
- 本階段工作量大，建議分多個工作階段進行。
