# 交接：acts-survivors 重構與玩法開發（2026-11-08）

工作目錄：`C:\Users\user\Desktop\apps\acts-survivors`　分支：`refactor/studio`　HEAD：見 `git log -1`（本文件所在 commit 之前是 9e3ee45）　工作樹乾淨，尚未 push。
先讀：`docs/refactor/00` 到 `04` 五份文件（基準盤點、範圍與階段、風格方向、玩法方向、構築機制）。

## 這個專案是什麼

Godot 4.7.2（GL Compatibility）的使徒行傳背景 survivors-like，主程式 `scripts/main.gd`（9149 行）。
另有 `arpg.gd`（宣教之路 2 試作，**不動**）。使用者目前是**封閉測試**。

## 已完成（按 commit）

| Commit | 內容 |
|---|---|
| 51d9459 | 引擎升級 4.7.2，726 個 `.import` 重新 import |
| 9d3756a | `storysim.sh` 在 Windows 改用暫存 APPDATA |
| cd873df | 存檔往返測試與黃金存檔碼（`tests/unit/save/`） |
| a2f4228 | 視覺基準：`--seed=`、`tools/sim/shots.sh`、`shots_diff.py`、26 張基準截圖 |
| 827d6c2 / b4e8bd2 / 5b15583 | 拆 main.gd：`scripts/draw/px.gd`（靜態繪圖工具）、`scripts/draw/draw_fx.gd`（helper 持有 `g`）；main.gd 9985 → 9149 行 |
| c2c3ff8 / 98513f3 | 史詩感風格提案（配色、調色對比、示範曲），依使用者意見改版（保護膚色、提高飽和、拿掉光暈） |
| abb86c9 | **17 首關卡曲與 FEVER 換成史詩版**（`tools/make_music_epic.py`；半速對拍，`music_bpm` 與 main.gd 不動）；府城（fucheng）與營地、標題、劇情、結局四首維持原樣 |
| 53fd289 | **全螢幕調色層**（`scripts/grade.gd` 自動載入 + `scripts/draw/post_grade_epic.gdshader`）；arpg 場景自動排除；`--nograde` 可關；新基準 `production/qa/evidence/baseline-epic-grade/` |
| 5144a10 / 531db78 / 9e3ee45 | 玩法方向與構築機制提案（只有文件，沒改程式） |
| b54406c | 放寬存檔相容性規定（見下） |

## 約束（以這裡為準，已更新）

- 不動 main 分支；Android 金鑰絕不 commit、密碼只用環境變數。
- 不動 `arpg.gd`、`arpg.tscn`、`wip/0.51-classes-runes`（遠端分支 `origin/wip/0.51-classes-runes`，做 arpg 的職業與符文）。
- **存檔相容性已放寬**（2026-11-08 使用者指示：封閉測試中不必顧慮存檔向下相容）。可以直接改 `save.gd` 格式與存檔碼；改格式時用 `tests/unit/save/run.sh --gen` 重產黃金樣本，不要讓測試靜默失敗。已寫入跨階段記憶（`acts-survivors-save-compat-relaxed.md`）。「目前」兩字很重要：正式上線前要重新確認。
- 風格硬限制：640×360 像素風、字型 Noto Sans TC + Hebrew-Game。
- 智慧財產：玩法只參考機制，**不使用也不仿造暗黑、魔獸的名稱、美術、音效**；主題維持使徒行傳。
- 全域規則：commit 前更新 `CHANGELOG.md`（繁體中文，新內容放最上方的 `[Unreleased]`）；commit 訊息尾端加 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`。
- **同一時間只讓一個階段改這個資料夾**（曾有兩個階段同時改 `main.gd`，差點互相覆蓋）。

## 驗證指令（每個改動都要跑）

```bash
tests/unit/save/run.sh                                  # 要 RESULT PASS（b64 decode ERROR 是對壞存檔碼的預期負面案例）
GRADE_ARG=--nograde tools/sim/shots.sh <輸出資料夾>      # 結構重構：關掉調色，和舊基準逐像素比
python tools/sim/shots_diff.py production/qa/evidence/baseline-before-refactor <輸出資料夾>   # 要 PASS（26 張，0 張不同）
tools/sim/shots.sh <輸出資料夾>                          # 含調色；比對 baseline-epic-grade/
GODOT=godot tools/sim/storysim.sh fresh 2 0 1 2          # ch0/ch1/ch2 各 2 局全勝，0 個 SCRIPT ERROR
```
基準數值（storysim）：ch0 約 305–360 秒、ch1 約 310–345 秒、ch2 約 365–375 秒，等級約 20–26，擊殺約 3300–4400。偶有一局偏慢（曾見 419、432 秒），是隨機波動。
截圖一次約 10 秒（桌面會跳小視窗，跑時別操作）；storysim 約 8 分鐘，用背景執行。
玩法改動會**故意打破**這些基準，要先建立新基準（storysim 與截圖）。

## 已知陷阱（都踩過）

1. 腳本一律用隔離的暫存 `APPDATA`，不碰真實存檔。**不要 `unset APPDATA`**，也**不要在同一條命令裡先 `export APPDATA=臨時目錄` 再跑 Python**（Python 的套件在 `%APPDATA%\Python`，會找不到 PIL／numpy）。
2. `main.gd` 工作區是 **CRLF**、index 是 LF。用腳本改寫要保留 CRLF（Python 讀寫都用 `newline=''`，用 `\r\n` 切行）。
3. `godot --check-only -s main.gd` 會誤報 `Identifier not found: Save`（沒有自動載入），真正的 parse check 是啟動遊戲（跑 `shots.sh`）。
4. `-s` 腳本在 `_initialize` 時節點樹還沒啟動，要先 `await process_frame`。
5. Windows 的 Python 不認 `/c/...` 路徑，要用 `cygpath -m` 轉。
6. 換音訊或素材後要 `godot --headless --path . --import`，否則遊戲會讀舊的快取。
7. 專案內的文件資料夾若放圖片或音檔，要放 `.gdignore`（否則 Godot 會產生 `.import`）。新腳本的 `.uid` 要進版控。
8. 抽函式到 helper 時：自己的成員存取要補 `g.` 前綴；迴圈變數不能叫 `g`（會蓋掉 helper 的 `g`，已造成過一次錯誤）；Variant 型別用 `=` 不用 `:=`。
9. `bot_hz.png`、`bot_pause.png` 兩張截圖的提示橫幅區域（y 231–290）不穩定，`shots_diff.py` 已遮罩，原因沒查。
10. `shots_diff.py` 輸出用 UTF-8；Windows 主控台顯示中文可能亂碼，那只是顯示。

## 環境（本機已安裝）

- `scipy 1.18.1`（pip）與 `ffmpeg 9.0.2`（winget Gyan.FFmpeg，`C:\Users\user\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe`，bash 可直接呼叫）。使用者已授權安裝。
- Python 3.14，numpy 2.5.3，PIL 12.3。

## 待決定（使用者尚未明確回答）

1. **玩法開發順序**：已確認參考 D2 Survivors（同人作品，細節來自單一來源資料站、未驗證）與艾澤拉斯倖存者；對象是主遊戲，四個面向都要（裝備與掉寶、職業與天賦、戰鬥節奏、關卡與世界）。使用者最後要學的是 **D2 Survivors 的構築（build）機制**。
   `docs/refactor/04-build-mechanics.md` 提了六項：多段進化鏈、寶箱觸發進化、欄位上限、開局三選一、Boss 掉修飾、進化路線預覽。**預設從 1（多段進化）與 2（寶箱觸發）開始**，先做 2 到 3 條示範鏈；03 的裝備（稀有度＋詞綴）可排在其後。
2. 使用者**尚未實際玩過**新畫面（調色層）與新音樂，不滿意時：調色層可調 `post_grade_epic.gdshader` 的參數或 `--nograde`；音樂整個 commit（abb86c9）可還原。打擊層比旋律層低約 10 dB（原本約 4 dB），若覺得鼓不夠力可再加（`make_music_epic.py` 的 `PERC_BOOST`）。
3. 音樂檔案總量約 22.6 → 32 MB（曲子變兩倍長），網頁版載入變大；要不要縮短曲式。
4. 其餘舊問題：`%APPDATA%\Godot\app_userdata\宣教之路\runs.json` 內有 6 筆 2026-11-08 11:10–11:13 的模擬紀錄（第一次 storysim 路徑錯誤造成，**未經使用者同意不要動**）；`tools/sim/profiles/fresh.json` 其實是高進度存檔（是否改名）；存檔測試是否改用 gdUnit4；營地、標題、基地的截圖尚未納入基準；`24e246e`、`2631ba6` 兩個純文件 commit 沒更新 CHANGELOG；`project.godot` 的 `config/features` 仍是 `"4.4"`。

## 暫停或降級的工作

- 畫面素材逐章重畫（`tools/make_*.py`）：目前只靠調色層，素材本身沒重畫；使用者看過調色後再決定要不要做。
- main.gd 其餘拆分（職業／法術／天賦約 1400 行、劇情、Boss、敵人、寶箱）：**降為後台工作、不阻塞**。
- 營地、標題、劇情、結局四首音樂：本來就慢、已接近史詩感，建議不動。

## 下一步（預設）

1. 讀 `D.evolutions`（`data/game.json`）、`main.gd` 的 `_ready_evolutions`、`_evo_of`、`_evolve` 與「寶箱與進化」段。
2. 寫多段進化鏈與寶箱觸發的設計（資料加 `next`、進化後同伴從 1 級重新累積、需要新的果子）。
3. 實作 2 到 3 條示範鏈；建立新的 storysim 平衡基準與截圖基準；重產存檔黃金樣本。
4. 補聚焦式教學步驟（CLAUDE.md Rule 15：`data-tour`，教學文字繁體中文）。
5. 每步更新 CHANGELOG、獨立 commit。

## 本階段（交接前）的 token 使用

這個工作階段遠超使用者 `~/.claude/CLAUDE.md` 的上限（單次 4,000、單階段 30,000），所以交接到新階段。新階段請從乾淨的上下文開始，只讀必要的文件。

## Session Snapshot

📍 acts-survivors（refactor/studio）
上次做到：史詩版音樂與調色層上線並驗證（abb86c9、53fd289）；玩法與構築提案寫成文件（5144a10、9e3ee45）；存檔相容性放寬
目前狀態：可以運行；工作樹乾淨；storysim 6/6、存檔測試 PASS、`--nograde` 截圖 26/26 逐像素
卡點或未決定的事：見「待決定」
下一步：多段進化鏈與寶箱觸發的設計與實作（預設）
需要注意：見「已知陷阱」與「約束」
