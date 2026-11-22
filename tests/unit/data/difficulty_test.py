"""難度資料檢查：python tests/unit/data/difficulty_test.py
守住三件事：Boss 的傷害一章比一章痛、Boss 三階段的資料齊全、天賦盤的割草基石在戰鬥裡真的有寫效果。
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def load(name: str) -> dict:
    return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))


game, story, meta = load("game.json"), load("story.json"), load("meta.json")
stages = {s["id"]: s for s in load("stages.json")["stages"]}
boss = game["boss"]

n = len(boss["phases"]) + 1
for key in ("phase_warn", "phase_rest", "chase"):
    assert len(boss[key]) == n, f"{key} 要有 {n} 個值（每階段一個）"
assert boss["chase"] == sorted(boss["chase"]), "越後面的階段追擊要越多，不然站著不動也過得了"

power = [
    max(boss["power_min"], stages[c["stage"]]["dmg_mult"] * story["dmg_mult"] * c.get("dmg_mult", 1.0) * boss["power_scale"])
    * c.get("boss_dmg", 1.0)
    for c in story["chapters"]
]
for i in range(1, len(power)):
    assert power[i] >= power[i - 1] - 0.02, f"第 {i} 章的 Boss（{power[i]:.2f}）比前一章（{power[i - 1]:.2f}）輕，難度沒有往上走"

main = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
body = main[main.index("func _mow_kill"):main.index("func _kill(")]
linked = {x for pair in meta["gifts"]["board"]["links"] for x in pair}
mow = [x for x in meta["gifts"]["board"]["nodes"] if x["kind"] == "mow"]
assert len(mow) == 6, "六個流派各一顆割草基石"
for x in mow:
    assert f'"{x["do"]}":' in body, f'{x["id"]} 的效果 {x["do"]} 沒有寫在 _mow_kill'
    assert x["id"] in linked, f'{x["id"]} 沒有連到盤面，永遠學不到'
print("PASS", [round(p, 2) for p in power])
