#!/bin/bash
# 一鍵發版：版號 → 字型 → 匯入 → 檢查 → 提交 → 匯出三平台 → 網頁版換檔名 → 推到 GitHub Pages → 打包。
#
# 用法：tools/release.sh <版本>      例：tools/release.sh 0.28.1
#
# 發版前要先寫好（腳本會檢查，沒寫就停下來）：
#   - data/devlog.json 最上面一則的 version 是這個版本（玩家在「日誌」頁看到的）
#   - CHANGELOG.md 有「## [這個版本]」那一段（給維護的人看的）
#
# 環境變數：
#   GODOT       Godot 4.4 執行檔（預設 godot）
#   PAGES_DIR   GitHub Pages 的資料夾（gh-pages 分支，預設 ../acts-pages）；不存在就跳過網頁版上線
#   DIST_DIR    打包好的檔案放哪裡（預設 build/dist）
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH／_USER／_PASSWORD   Android 簽章（沒設就跳過 APK）
#   COMMIT_TRAILER   附在提交訊息最後的文字（選填）
#   SKIP_PUSH=1      只做本機，不推到 GitHub
set -euo pipefail
VER="${1:?用法：tools/release.sh <版本>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
G="${GODOT:-godot}"
PAGES="${PAGES_DIR:-$ROOT/../acts-pages}"
DIST="${DIST_DIR:-$ROOT/build/dist}"
say() { printf '\n== %s\n' "$*"; }

say "檢查製作日誌與更新紀錄"
TOP=$(python3 -c "import json;print(json.load(open('data/devlog.json',encoding='utf-8'))['entries'][0]['version'])")
[ "$TOP" = "$VER" ] || { echo "data/devlog.json 最上面一則是 $TOP，不是 $VER：先寫好製作日誌"; exit 1; }
grep -q "^## \[$VER\]" CHANGELOG.md || { echo "CHANGELOG.md 沒有「## [$VER]」：先寫好更新紀錄"; exit 1; }
TITLE=$(python3 -c "import json;print(json.load(open('data/devlog.json',encoding='utf-8'))['entries'][0]['title'])")

say "版號：$VER"
CODE=$(grep -o 'version/code=[0-9]*' export_presets.cfg | cut -d= -f2)
OLDVER=$(grep -o 'version/name="[^"]*"' export_presets.cfg | cut -d'"' -f2)
if [ "$OLDVER" != "$VER" ]; then
  CODE=$((CODE + 1))
  sed -i "s/version\/code=[0-9]*/version\/code=$CODE/; s/version\/name=\"[^\"]*\"/version\/name=\"$VER\"/" export_presets.cfg
fi
echo "Android versionCode=$CODE"

say "字型（只收用得到的字）與資源匯入"
python3 tools/make_font.py > /dev/null
timeout 600 "$G" --headless --path . --import > /dev/null 2>&1 || true

say "檢查：標題、營地、一小段戰鬥有沒有錯誤"
LOG="$(mktemp)"
U="$HOME/.local/share/godot/app_userdata/宣教之路"
BAK="$(mktemp)"; HAD=0
[ -f "$U/profile.json" ] && { cp "$U/profile.json" "$BAK"; HAD=1; }
mkdir -p "$U"; cp tools/sim/profiles/mid.json "$U/profile.json"
timeout 120 "$G" --headless --path . --quit-after 200 >> "$LOG" 2>&1 || true
timeout 120 "$G" --headless --path . res://scenes/base.tscn --quit-after 200 >> "$LOG" 2>&1 || true
timeout 300 "$G" --headless --path . res://scenes/main.tscn -- --smoke --bot --stage=0 --frames=3000 >> "$LOG" 2>&1 || true
if [ $HAD -eq 1 ]; then cp "$BAK" "$U/profile.json"; else rm -f "$U/profile.json"; fi
rm -f "$BAK"
if grep -E "SCRIPT ERROR|Parse Error" "$LOG"; then echo "有錯誤，停止發版"; exit 1; fi
rm -f "$LOG"
echo "沒有錯誤"

say "提交"
git add -A
if ! git diff --cached --quiet; then
  MSG="$VER：$TITLE"
  [ -n "${COMMIT_TRAILER:-}" ] && MSG="$MSG

$COMMIT_TRAILER"
  git commit -q -m "$MSG"
fi
[ "${SKIP_PUSH:-0}" = "1" ] || git push -q
git log --oneline -1

say "匯出：網頁版、Windows"
mkdir -p build/web build/windows build/android "$DIST"
timeout 600 "$G" --headless --path . --export-release "Web" build/web/index.html > /dev/null 2>&1
timeout 600 "$G" --headless --path . --export-release "Windows Desktop" build/windows/ActsSurvivors.exe > /dev/null 2>&1
python3 tools/web_cachebust.py   # index.pck → index-<版本>.pck（舊的會刪掉）

APK=0
if [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
  say "匯出：Android（簽章）"
  timeout 600 "$G" --headless --path . --export-release "Android" build/android/ActsSurvivors.apk > /dev/null 2>&1 && APK=1
else
  say "沒有設定 Android 簽章，跳過 APK"
fi

if [ -d "$PAGES/.git" ]; then
  say "網頁版上線（GitHub Pages）"
  ( cd "$PAGES"
    for old in index-*.pck; do
      [ -e "$old" ] && [ "$old" != "index-$VER.pck" ] && git rm -q "$old"
    done
    cp "$ROOT"/build/web/* .
    git add -A
    git diff --cached --quiet || git commit -q -m "網頁版 $VER"
    [ "${SKIP_PUSH:-0}" = "1" ] || git push -q origin gh-pages
    git log --oneline -1 )
else
  say "找不到 $PAGES，跳過網頁版上線"
fi

say "打包到 $DIST"
( cd build/web && zip -qr "$DIST/acts-survivors-web-$VER.zip" . )
( cd build/windows && zip -qr "$DIST/acts-survivors-windows-$VER.zip" . )
[ $APK -eq 1 ] && cp build/android/ActsSurvivors.apk "$DIST/acts-survivors-$VER.apk"
ls -la "$DIST" | grep "$VER"
say "完成：$VER"
