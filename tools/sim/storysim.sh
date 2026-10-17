#!/bin/bash
# 劇情難度模擬：讓機器人用某個測試存檔玩指定的章節，印出勝負、時間、受傷來源。
#
# 用法：tools/sim/storysim.sh <存檔> <每章幾局> <章節...>
#   存檔：tools/sim/profiles/ 裡的檔名（不含 .json）：fresh 新玩家、after_ch1 剛過第一章、mid 中期
#   章節：0 起算（0 五旬節、1 司提反、2 撒瑪利亞、3 大馬士革……14 拔摩海島）
#   例：tools/sim/storysim.sh mid 2 9 10 11
#
# 環境變數：GODOT（Godot 4.4 執行檔，預設 godot）、SIM_PAR（同時跑幾局，預設 2，看 CPU 數）
# 會暫時換掉本機的遊戲存檔，跑完自動換回原本的（同一台電腦正在玩遊戲時不要跑）。
# 一局大約 2～4 分鐘（機器人用 4 倍速）。結果的 won=true 是通關；DMG 是被什麼打傷。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="${GODOT:-godot}"
PAR="${SIM_PAR:-2}"
U="$HOME/.local/share/godot/app_userdata/宣教之路"
PROF="$ROOT/tools/sim/profiles/$1.json"
N=$2
shift 2
[ -f "$PROF" ] || { echo "找不到測試存檔：$PROF"; exit 1; }
mkdir -p "$U"
BAK="$(mktemp)"
HAD=0
if [ -f "$U/profile.json" ]; then cp "$U/profile.json" "$BAK"; HAD=1; fi
restore() {
  if [ $HAD -eq 1 ]; then cp "$BAK" "$U/profile.json"; else rm -f "$U/profile.json"; fi
  rm -f "$BAK" "$U/profile_prev.json" "$U/profile.json.tmp"
}
trap restore EXIT
OUTDIR="$(mktemp -d)"
cd "$ROOT"
for ch in "$@"; do
  cp "$PROF" "$U/profile.json"
  for i in $(seq "$N"); do
    (timeout 900 "$G" --headless --path . res://scenes/main.tscn -- --smoke --bot --story="$ch" --frames=40000 2>&1 \
      | grep -E "BOTRESULT|SCRIPT ERROR|DMG" | head -3 > "$OUTDIR/${ch}_$i.txt") &
    sleep 2
    while [ "$(jobs -rp | wc -l)" -ge "$PAR" ]; do sleep 1; done
  done
  wait
  echo "ch$ch: $(cat "$OUTDIR"/${ch}_*.txt | sed 's/BOTRESULT //' | tr '\n' '|')"
done
rm -rf "$OUTDIR"
