"""整理每局紀錄：看哪個流派（最高等級的同伴）撐得最久、勝率多少。

用法：python tools/runs_report.py [runs.json 路徑]
預設路徑（Godot 的 user:// 資料夾）：
  Windows: %APPDATA%/Godot/app_userdata/宣教之路/runs.json
  macOS:   ~/Library/Application Support/Godot/app_userdata/宣教之路/runs.json
  Linux:   ~/.local/share/godot/app_userdata/宣教之路/runs.json
"""
import json
import os
import sys
from collections import defaultdict

NAMES = {"silas": "詩歌流（西拉）", "apollos": "講道流（亞波羅）", "pri": "帳棚堡壘流（百基拉）",
         "tim": "差派流（提摩太）", "luke": "醫治流（路加）", "barn": "同心流（巴拿巴）"}


def default_path():
    if sys.platform.startswith("win"):
        base = os.path.join(os.environ.get("APPDATA", ""), "Godot")
    elif sys.platform == "darwin":
        base = os.path.expanduser("~/Library/Application Support/Godot")
    else:
        base = os.path.expanduser("~/.local/share/godot")
    return os.path.join(base, "app_userdata", "宣教之路", "runs.json")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_path()
    with open(path, encoding="utf-8") as f:
        runs = json.load(f)
    groups = defaultdict(list)
    for r in runs:
        party = r.get("party") or {}
        main_key = max(party, key=party.get) if party else "none"
        groups[main_key].append(r)
    print(f"共 {len(runs)} 局\n")
    print(f"{'流派':<16}{'局數':>4}{'勝率':>8}{'平均撐幾秒':>10}{'平均等級':>8}")
    for key, rs in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        wins = sum(1 for r in rs if r.get("won"))
        secs = sum(r.get("seconds", 0) for r in rs) / len(rs)
        lv = sum(r.get("level", 0) for r in rs) / len(rs)
        print(f"{NAMES.get(key, key):<16}{len(rs):>4}{wins / len(rs):>8.0%}{secs:>10.0f}{lv:>8.1f}")


if __name__ == "__main__":
    main()
