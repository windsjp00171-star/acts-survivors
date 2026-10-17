# 宣教之路 Acts Survivors

以使徒行傳為背景的像素風生存 roguelite（類吸血鬼倖存者）。從五旬節的耶路撒冷出發，跟著彼得、司提反、腓利、保羅、約翰走過十五座城，一直走到拔摩海島；結局「第 29 章」走到台灣，走到今天的玩家。

世界觀：敵人都是黑暗的勢力（懼怕、謊言、自高、紛爭……），人從來不是敵人。每個黑暗的勢力背後都捆綁著一個人，爭戰是為了把人贏回來（弗 6:12、徒 26:18）。

做這款遊戲的心願：讓人在喜歡上遊戲的同時，也有機會認識這份信仰。

- 網頁版（手機、電腦都能玩）：https://windsjp00171-star.github.io/acts-survivors/
- itch.io（介紹、預告片、Windows 與 Android 下載）：https://emmark1989.itch.io/actsurvivors
- 試玩回饋表：https://form.jotform.com/262891694524065

## 怎麼玩

| 動作 | 鍵盤 | 觸控 |
| --- | --- | --- |
| 移動（攻擊自動） | WASD 或方向鍵 | 按住畫面下方拖曳 |
| 升級選卡 | 1～4 | 點卡片（亮起來才能點） |
| 重抽 | R | 按「重抽」 |
| 五旬節（同心合意滿了） | 空白鍵 | 按「五旬節」按鈕 |
| 暫停 | Esc 或 P | 右上角「Ⅱ」、返回鍵 |

**劇情模式**十五章照時間順序，系統一章一章開放（第 1 章只有招募與升級）。每章的目標：打倒 Boss 建立教會，並「從黑暗中贏回人」（帶尋找的人信主）。

**自由模式**在通過劇情後開放：自己選主角、組隊、組流派，挑戰信心等級（最高 15）與無盡模式。

**換裝置**：營地「日誌」頁 →「複製存檔碼」，到新裝置貼上 →「匯入」。

## 不會寫程式也能改

內容幾乎都寫在 `data/` 的 JSON 裡，改完存檔、重新執行就生效。每個檔案開頭的 `_說明` 欄位寫了每個欄位的意思。

| 檔案 | 內容 |
| --- | --- |
| `data/story.json` | 劇情十五章：關卡、主角、會遇到的同伴、各章難度倍率 |
| `data/stages.json` | 十五座城：地面與物件、關卡機制、Boss、進城與建立教會的對話、尋找的人、書信卡 |
| `data/game.json` | 局內：同伴與招式、流派與融合、敵人、菁英、Boss 招式、升級、新手提示 |
| `data/meta.json` | 局外：見證怎麼算、營地建設、解鎖商店、恩賜樹、見證錄、信心等級 |
| `data/talks.json` | 營地閒聊（一段可用 `after` 指定要先建立哪座城的教會才出現） |
| `data/bios.json` | 同伴生平（默契升級時解鎖） |
| `data/codex.json` | 圖鑑：敵人說明、信仰小辭典 |
| `data/events.json` | 旅程中的使徒行傳事件（自由模式） |
| `data/devlog.json` | 營地「日誌」頁的製作日誌（寫給玩家看） |

**給牧者審閱**：`python3 tools/make_review.py` 會把所有經文、對話、過場、結局整理成 `docs/審閱文字包.md`。

**寫對話的原則**：只寫當下發生的事、照時間順序，像真的人在說話；不要在句子後面掛經文出處；掃羅到徒 13:9 以後才叫保羅。

## 專案結構

| 路徑 | 內容 |
| --- | --- |
| `scenes/title.tscn`／`scripts/title.gd` | 標題畫面（第一個畫面）、開場、章節過場與結局（`INTRO`、`CUTS`） |
| `scenes/base.tscn`／`scripts/camp.gd` | 營地（走動、閒聊、設施） |
| `scripts/base.gd` | 營地的面板：出發、同伴、解鎖與建設、恩賜樹、見證錄、圖鑑、日誌 |
| `scenes/main.tscn`／`scripts/main.gd` | 一局遊戲（主程式） |
| `scripts/game_ui.gd` | 局內介面：血量、升級卡、寶箱、對話、結算 |
| `scripts/save.gd` | 存檔（自動載入，名稱 `Save`） |
| `scripts/sfx.gd` | 音效與分層音樂（自動載入，名稱 `Sfx`） |
| `scripts/ui_kit.gd` | 共用字型、顏色、按鈕 |
| `tools/make_*.py` | 用程式產生素材：配樂、音效、地面與物件、人物、敵人、字型 |
| `tools/release.sh` | 一鍵發版 |
| `tools/sim/` | 劇情難度模擬與測試存檔 |
| `CHANGELOG.md` | 更新紀錄（寫給維護的人看） |

素材全部用程式產生，沒有外部素材的授權問題：

- `python3 tools/make_music.py [曲名…]`：配樂。關卡曲分三層（鼓、伴奏、旋律），遊戲裡依戰況調音量；全部重做約 20 分鐘。需要 numpy、scipy、ffmpeg。
- `python3 tools/make_sounds.py`：音效。
- `python3 tools/make_terrain.py`、`make_people.py`、`make_enemies.py`：地面、物件、人物、敵人的像素圖。
- `python3 tools/make_font.py`：遊戲字型。它只收遊戲裡用到的字，**文字改過就要重跑**，不然新字會變成方框。

## 發版

1. 在 `data/devlog.json` 最上面加一則（版本、日期、標題、給玩家看的說明）。
2. 在 `CHANGELOG.md` 的 `## [Unreleased]` 下面加 `## [版本] - 日期`。
3. 執行：

```
GODOT=godot執行檔 \
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=金鑰路徑 GODOT_ANDROID_KEYSTORE_RELEASE_USER=acts GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=密碼 \
tools/release.sh 0.28.3
```

腳本依序做這些事：版號 → 字型 → 匯入 → 檢查錯誤 → 提交 → 匯出網頁、Windows、Android → 網頁版換檔名（避免瀏覽器快取）→ 推到 GitHub Pages（`../acts-pages` 的 gh-pages 分支）→ 打包到 `build/dist`。

4. 到 itch.io 的編輯頁換上 `build/dist` 裡的三個檔案。

需要 Godot 4.4.1 與它的 Export Templates；Android 還要 Android SDK 與 JDK（在 Godot 編輯器設定裡填路徑）。**Android 每一版都要用同一把簽章金鑰**，玩家才能直接覆蓋安裝、保留存檔。金鑰不要放進專案（`.gitignore` 已擋）。

## 測試

```
# 跑一小段遊戲（不開視窗），印出結果
godot --headless --path . res://scenes/main.tscn -- --smoke --bot --stage=0 --frames=3000

# 劇情難度：用測試存檔讓機器人玩指定章節（章節 0 起算），每章 2 局
GODOT=godot tools/sim/storysim.sh mid 2 9 10 11
```

`main.tscn` 的測試參數：

- `--smoke --bot`：機器人自動玩（4 倍速）；`--frames=` 跑幾格
- `--stage=N`：自由模式第 N 座城；`--story=N`：劇情第 N 章（0 起算）
- `--t0=秒`：直接跳到某個時間
- `--preset=`：預設隊伍，例如 `five`、`evo`、`team:silas,tim`、`teamevo:silas,tim`
- `--anoint=paul:s_講道,s_詩歌`：主角一開始就裝上流派
- `--talk`：重看對話
- `--shot=路徑.png`：存各種畫面的截圖（要有顯示環境，例如 `xvfb-run`）
- `--perf`：每 300 格印出各部分花多少時間
- `--film`：錄影模式（機器人用正常速度），搭配 Godot 的 `--write-movie 檔名.avi`

標題、營地也支援 `--shot=`，會把開場、過場、結局、各面板都拍下來。加 `--resolution 720x1280` 可以看直式（手機）排版。

## 存檔

`user://profile.json`（Windows 在 `%APPDATA%\Godot\app_userdata\宣教之路`；網頁版存在瀏覽器裡）。

寫入時先寫到 `profile.json.tmp`，確認完整後才換上去，舊的那份存成 `profile_prev.json`；主檔壞了，讀檔時會自動改用這兩份。「從頭開始旅程」和「匯入存檔碼」之前，會先備份到 `profile_backup.json`。

## 授權

尚未決定。
