# main.gd 重構：基準與盤點

分支 `refactor/studio`。引擎 Godot 4.7.2。

## 範圍

- 範圍內：把 `scripts/main.gd`（9985 行）依職責拆成小檔，每檔目標 ≤800 行。玩家看得到的行為不變。
- 不動：`arpg.gd`、`arpg.tscn`、`ui_kit.gd`、`wip/0.51-classes-runes`、Android 簽章與匯出設定。
- `save.gd` 的存檔格式與存檔碼全程向下相容；`save.gd` 本身不改。

## 基準（`GODOT=godot tools/sim/storysim.sh fresh 2 0 1 2`，隔離 APPDATA）

| 章 | 勝 | 秒數 | 等級 | 擊殺 | 隊友 |
|---|---|---|---|---|---|
| 0 五旬節 | ✅ ✅ | 319 / 311 | 24 / 22 | 3531 / 3442 | 4 / 4 |
| 1 司提反 | ✅ ✅ | 324 / 309 | 21 / 21 | 3622 / 3336 | 3 / 3 |
| 2 撒瑪利亞 | ✅ ✅ | 373 / 367 | 24 / 25 | 4129 / 4083 | 2 / 2 |

模擬有隨機性，受傷量每局差很大。比對只看勝負、時間、等級、擊殺的大趨勢。

## main.gd 結構

- 一個 `Node2D` 掛 340 個 var/const、303 個函式；內部沒有 signal 或 group。
- 對外只有兩處：`base.gd` 用 `change_scene_to_file` 切到 main 場景、`Save.resume`。其他檔案不呼叫 main。
- main 對 `Save` 的用量最多的是 `Save.data`、`Save.run_config`、`Save.up_value`。

| 段落（註解標題） | 行數 | 函式數 |
|---|---|---|
| 畫面 | 2350 | 65 |
| 主迴圈 | 753 | 7 |
| 場景物件 | 766 | 20 |
| 劇情對話與帶人信主 | 725 | 15 |
| 同伴等級 | 689 | 31 |
| 流派規則 | 681 | 33 |
| 敵人 | 552 | 23 |
| Boss | 553 | 17 |
| 新的攻擊方式 | 427 | 7 |
| 寶箱與進化 | 394 | 16 |

「畫面」段名不副實，實際含三塊：繪圖（`_render`、`_draw_air`、`_draw_ground_fx`、`_pline`/`_pring` 等）、職業／法術／天賦（`_kit_*`、`_class_*`、`_tal_*`，`_kit_cast` 約 450 行）、一般工具（`_aoe`、`_line_hit`、`_densest`、`_team_heal`）。

## 拆法

每個系統一支 `RefCounted` 腳本，持有 `g`（指向 main），狀態暫時留在 main。順序由低風險到高風險：

1. 純繪圖輔助
2. `_draw_air`、`_draw_ground_fx`、`_draw_schools`
3. 一般工具
4. 職業／法術／天賦
5. 劇情、場景物件、Boss、敵人、寶箱
6. 主迴圈最後，或不拆

## 每步固定動作

parse check、storysim（fresh 2 局 ch0–2）、存檔往返測試、CHANGELOG、獨立 commit。

## 已知注意事項

- `wip/0.51-classes-runes` 沒有改 `main.gd`，拆 main 不會與它衝突。
- `project.godot` 的 `config/features` 仍是 `"4.4"`，留到最後階段獨立處理。
- `tools/sim/profiles/fresh.json` 其實是高進度存檔（24 場、witness 18757），名稱容易誤導。
