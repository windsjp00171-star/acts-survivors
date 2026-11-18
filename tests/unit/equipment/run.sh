#!/bin/bash
# 局外裝備測試。用暫存 APPDATA，不碰真實存檔。用法：tests/unit/equipment/run.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
G="${GODOT:-godot}"
if [ -n "${APPDATA:-}" ] && command -v cygpath >/dev/null 2>&1; then
  export APPDATA="$(cygpath -m "$(mktemp -d)")"
else
  export HOME="$(mktemp -d)" XDG_DATA_HOME="$(mktemp -d)"
fi
cd "$ROOT"
"$G" --headless --path . -s res://tests/unit/equipment/equipment_test.gd -- "$@" 2>&1 | grep -E "FAIL|RESULT|golden|ERROR"
exit "${PIPESTATUS[0]}"
