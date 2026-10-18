"""技能盤點：每位同伴單獨上場（Lv4，不選分支／分支一／分支二各跑一次），印出出手次數、傷害、以及場上真的發生的效果。

用法：GODOT=godot執行檔 python3 tools/sim/skillcheck.py [同伴 key …]
  不寫 key 就全部跑。結果另存 tools/sim/skillcheck_result.txt。
會暫時換掉本機的遊戲存檔（用 tools/sim/profiles/mid.json），跑完換回來。
看結果時：說明寫「暈眩」就要看到「暈眩」、寫「回血」就要看到「回血」，出手次數不能是 0。
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
G = os.environ.get("GODOT", "godot")
PAR = int(os.environ.get("SIM_PAR", "2"))
U = os.path.expanduser("~/.local/share/godot/app_userdata/宣教之路")
FRAMES = int(os.environ.get("FRAMES", "1500"))
T0 = os.environ.get("T0", "")   # 從第幾秒開始（敵人比較硬，效果比較不會被一擊打散而看不到）

game = json.load(open(os.path.join(ROOT, "data/game.json"), encoding="utf-8"))
comps = [c for c in game["companions"] if c.get("skill")]
keys = sys.argv[1:] or [c["key"] for c in comps]


def run(key, branch):
    args = [G, "--headless", "--path", ROOT, "res://scenes/main.tscn", "--", "--smoke", "--bot", "--stage=7",
            "--preset=team:%s" % key, "--frames=%d" % FRAMES] + (["--t0=%s" % T0] if T0 else [])
    if branch is not None:
        args.append("--branch=%s:%d" % (key, branch))
    args.append("--only=%s" % key)
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=600).stdout
    except subprocess.TimeoutExpired:
        return key, branch, "逾時", "", ""
    dealt = re.search(r'"%s": "([^"]*)"' % key, out)
    fx = re.search(r"^FX (.*)$", out, re.M)
    err = "；".join(sorted(set(re.findall(r"SCRIPT ERROR: (.*)", out))))[:200]
    return key, branch, dealt.group(1) if dealt else "沒上場", fx.group(1) if fx else "", err


def main():
    os.makedirs(U, exist_ok=True)
    bak = tempfile.mktemp()
    had = os.path.exists(os.path.join(U, "profile.json"))
    if had:
        shutil.copy(os.path.join(U, "profile.json"), bak)
    shutil.copy(os.path.join(ROOT, "tools/sim/profiles/mid.json"), os.path.join(U, "profile.json"))
    jobs = []
    for k in keys:
        c = next(c for c in comps if c["key"] == k)
        n = len(game["skills"][c["skill"]].get("branches", []))
        jobs += [(k, None)] + [(k, i) for i in range(n)]
    lines = []
    try:
        with ThreadPoolExecutor(PAR) as ex:
            for key, branch, dealt, fx, err in ex.map(lambda j: run(*j), jobs):
                c = next(c for c in comps if c["key"] == key)
                sk = game["skills"][c["skill"]]
                bname = "—" if branch is None else sk["branches"][branch]["name"]
                line = "%s（%s）｜%s｜傷害/出手 %s｜%s%s" % (c["name"], key, bname, dealt, fx, ("｜錯誤 " + err) if err else "")
                print(line, flush=True)
                lines.append(line)
    finally:
        if had:
            shutil.copy(bak, os.path.join(U, "profile.json"))
    open(os.path.join(ROOT, "tools/sim/skillcheck_result.txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
