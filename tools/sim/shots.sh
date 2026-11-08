#!/bin/bash
# 固定場景截圖（視覺基準）。要有顯示環境（Windows 桌面會跳出小視窗，約幾十秒）。
#
# 用法：tools/sim/shots.sh <輸出資料夾> [存檔，預設 fresh]
# 固定：亂數種子 --seed=1、固定幀率 --fixed-fps 60、視窗 640x360、暫存 APPDATA（不碰真實存檔）。
# 關閉史詩調色（結構重構的逐像素基準用）：GRADE_ARG=--nograde tools/sim/shots.sh <資料夾>
# 比對兩次輸出：python tools/sim/shots_diff.py <資料夾A> <資料夾B>
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="${GODOT:-godot}"
OUT="$(cd "$(dirname "${1:?用法：shots.sh <輸出資料夾> [存檔]}")" 2>/dev/null && pwd)/$(basename "$1")"
PROF="$ROOT/tools/sim/profiles/${2:-fresh}.json"
[ -f "$PROF" ] || { echo "找不到測試存檔：$PROF"; exit 1; }
mkdir -p "$OUT"
if [ -n "${APPDATA:-}" ] && command -v cygpath >/dev/null 2>&1; then
  ISO="$(cygpath -m "$(mktemp -d)")"
  export APPDATA="$ISO"
  U="$ISO/Godot/app_userdata/宣教之路"
  OUTARG="$(cygpath -m "$OUT")"
else
  ISO="$(mktemp -d)"
  export HOME="$ISO" XDG_DATA_HOME="$ISO"
  U="$ISO/godot/app_userdata/宣教之路"
  OUTARG="$OUT"
fi
mkdir -p "$U"
cd "$ROOT"
run() {   # 名稱 遊戲參數...
  local name=$1; shift
  cp "$PROF" "$U/profile.json"
  rm -f "$U/runs.json"
  timeout 180 "$G" --path . --fixed-fps 60 --resolution 640x360 --windowed --position 0,0 \
    res://scenes/main.tscn -- --smoke --seed=1 --shot="$OUTARG/$name.png" ${GRADE_ARG:-} "$@" 2>&1 \
    | grep -E "SCRIPT ERROR|ERROR:" | head -3
}
run ch0 --story=0 --frames=80
run ch1 --story=1 --frames=80
run free0 --stage=0 --frames=60
run free3 --stage=3 --frames=60
run fx --stage=0 --frames=40 --fxtest
run bot --stage=0 --bot --frames=900
rm -rf "$ISO"
ls "$OUT"
