"""把六棵恩賜樹排成一張「恩賜盤」（data/meta.json 的 gifts.board）。

用法：python3 tools/make_board.py
只在第一次搬家、或要重新排盤面時跑。它讀 gifts.trees（舊的六棵樹）＋下面的 EXTRA（新的基石、卡片節點、中央、橋），
寫出 gifts.board：nodes（每個節點的位置、效果、價錢）、links（哪兩個節點相連）、starts（每位主角的起點）。
盤面排好以後，要微調名字、數值、價錢，直接改 meta.json 的 gifts.board 就好（不用再跑這支）。
"""
import json
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
P = os.path.join(ROOT, "data", "meta.json")

ORDER = ["講道", "詩歌", "醫治", "守護", "差派", "門徒"]     # 順時針，從上面開始；相鄰的流派之間有橋
RING = 46                                                    # 每一圈相距幾個單位（畫面上的像素）

# 每個流派區的位置：(名字, 圈, 偏移 -1～1)
SMALL = [("A0", 2, 0.0), ("A1", 3, -0.45), ("A2", 3, 0.45), ("L1", 4, -0.75), ("R1", 4, 0.75),
         ("L2", 5, -0.8), ("M1", 5, -0.27), ("M2", 5, 0.27), ("R2", 5, 0.8)]
NOTABLE = [("N1", 4, -0.27), ("N2", 4, 0.27), ("N3", 6, -0.6), ("N4", 6, 0.0), ("N5", 6, 0.6), ("N6", 3.6, 0.0)]
KEY = [("K1", 7, -0.35), ("K2", 7, 0.35)]
LINKS = [("A0", "A1"), ("A0", "A2"), ("A1", "L1"), ("A1", "N1"), ("A2", "N2"), ("A2", "R1"), ("L1", "L2"), ("N1", "M1"),
         ("N2", "M2"), ("R1", "R2"), ("L2", "N3"), ("M1", "N3"), ("M1", "N4"), ("M2", "N4"), ("M2", "N5"), ("R2", "N5"),
         ("N3", "K1"), ("N4", "K1"), ("N4", "K2"), ("N5", "K2"), ("N1", "N6"), ("N2", "N6")]
COST_SMALL = {2: 15, 3: 20, 4: 25, 5: 30}

CARDS = {   # 卡片節點：這個流派的升級卡更常出現
    "講道": ("撒種", "可 4:14"), "詩歌": ("新歌", "詩 96:1"), "醫治": ("主的能力", "路 5:17"),
    "守護": ("謹守儆醒", "彼前 5:8"), "差派": ("請差遣我", "賽 6:8"), "門徒": ("來跟從我", "太 4:19"),
}
KEYSTONE = {   # 第二個基石：強大，但有代價
    "講道": ("得時不得時", "提後 4:2", "preach", "講道同伴傷害 +40%；但全隊攻擊速度 -15%"),
    "詩歌": ("半夜唱詩", "徒 16:25", "midnight", "主角血少於一半時，詩歌同伴傷害加倍；但主角血量 -15"),
    "醫治": ("以善勝惡", "羅 12:21", "overcome", "治療滿出來的部分，變成打向最近敵人的光；但治療量 -20%"),
    "守護": ("站立得穩", "弗 6:13", "stand", "護盾上限 +2；但主角移動 -10%"),
    "差派": ("兩個兩個", "可 6:7", "pairs", "隊伍人數（含主角）是偶數時全隊攻擊速度 +20%；奇數時 -10%"),
    "門徒": ("撒網", "路 5:4", "cast", "門徒同伴的範圍大一倍；但門徒同伴攻擊速度 -25%"),
}
CENTER = [   # 中央（安提阿）：全隊的小加成
    ("hub", "xp", 0.05, "差派的教會", "徒 13:3", "全隊經驗 +5%"),
    ("c0", "hp", 10, "剛強壯膽", "書 1:9", "主角血量 +10"),
    ("c1", "move", 0.04, "腳步穩妥", "詩 37:23", "移動速度 +4%"),
    ("c2", "revive", 0.12, "扶起來", "傳 4:10", "倒下的同伴早一點站起來 -12%"),
    ("c3", "guardcap", 1, "盾牌", "詩 3:3", "護盾上限 +1"),
    ("c4", "xp", 0.05, "長進", "彼後 3:18", "全隊經驗 +5%"),
    ("c5", "hp", 10, "堅忍", "雅 1:4", "主角血量 +10"),
]
STARTS = {"paul": "中央:hub", "stephen": "講道:A0", "peter": "門徒:A0", "john": "門徒:A1", "tim": "差派:A0",
          "philip": "差派:A2", "lydia": "守護:A0", "maxwell": "醫治:A0", "asaph": "詩歌:A0"}


def pos(sector, r, o):
    a = math.radians(-90 + sector * 60 + o * 26)
    return round(math.cos(a) * r * RING), round(math.sin(a) * r * RING)


def one_rank(desc, tag):
    d = desc.replace("／級", "").replace("%%", "%")
    return d.replace("%s", tag) if "%s" in d else d


def main():
    m = json.load(open(P, encoding="utf-8"))
    G = m["gifts"]
    nodes, links = [], []

    def add(nid, tag, kind, size, xy, name, ref, desc, cost, extra=None):
        nd = {"id": nid, "tag": tag, "kind": kind, "size": size, "x": xy[0], "y": xy[1], "name": name, "ref": ref, "desc": desc, "cost": cost}
        nd.update(extra or {})
        nodes.append(nd)

    for i, (nid, kind, per, name, ref, desc) in enumerate(CENTER):
        xy = (0, 0) if nid == "hub" else pos(i - 1, 1, 0)
        add("中央:" + nid, "中央", kind, 1 if nid != "hub" else 2, xy, name, ref, desc, 0 if nid == "hub" else 20, {"per": per})
        if nid != "hub":
            links.append(["中央:hub", "中央:" + nid])
    for si, tag in enumerate(ORDER):
        tr = G["trees"][tag]
        basic, notable, key = [], [], []
        for k, nd in enumerate(tr["nodes"]):
            nm, rf = tr["names"][k], tr["refs"][k]
            if nd["id"] == "rule_key":
                key.append((nd, nm, rf))
            elif nd["kind"] == "mod" or int(nd["max"]) == 1:
                notable.append((nd, nm, rf))
            else:
                basic.append([nd, nm, rf, int(nd["max"])])
        # 小節點：輪流從每一種基本加成拿一級
        picks = []
        while len(picks) < len(SMALL) and any(b[3] > 0 for b in basic):
            for b in basic:
                if b[3] > 0 and len(picks) < len(SMALL):
                    picks.append(b[:3])
                    b[3] -= 1
        for (slot, r, o), (nd, nm, rf) in zip(SMALL, picks):
            ex = {k: nd[k] for k in ("per", "stat", "add", "mul") if k in nd}
            add("%s:%s" % (tag, slot), tag, nd["kind"], 1, pos(si, r, o), nm, rf, one_rank(nd["desc"], tag), COST_SMALL[r], ex)
        cname, cref = CARDS[tag]
        notable.append(({"kind": "cards", "per": 0.15, "desc": "升級卡更常出現%s的卡（+15%%）" % tag, "max": 1}, cname, cref))
        for (slot, r, o), (nd, nm, rf) in zip(NOTABLE, notable):
            ex = {k: nd[k] for k in ("per", "stat", "add", "mul", "mod") if k in nd}
            add("%s:%s" % (tag, slot), tag, nd["kind"], 2, pos(si, r, o), nm, rf, one_rank(nd["desc"], tag), 60 if r < 5 else 90, ex)
        used = {s for s, _, _ in NOTABLE[:len(notable)]}
        nd, nm, rf = key[0]
        add("%s:K1" % tag, tag, "mod", 3, pos(si, *KEY[0][1:]), nm, rf, one_rank(nd["desc"], tag), 200, {"per": 1, "mod": nd["mod"]})
        kn, kr, ks, kd = KEYSTONE[tag]
        add("%s:K2" % tag, tag, "keystone", 3, pos(si, *KEY[1][1:]), kn, kr, kd, 200, {"ks": ks})
        for a, b in LINKS:
            if (a.startswith("N") and a not in used) or (b.startswith("N") and b not in used):
                continue
            links.append(["%s:%s" % (tag, a), "%s:%s" % (tag, b)])
        links.append(["中央:c%d" % si if si < 6 else "", "%s:A0" % tag])
        # 橋：這一區的 R2 和下一區的 L2 中間
        nxt = ORDER[(si + 1) % 6]
        bid = "橋:%s%s" % (tag, nxt)
        add(bid, "橋", "bridge", 2, pos(si, 5.4, 1.15), "同心合意", "腓 2:2", "%s和%s的同伴傷害 +6%%" % (tag, nxt), 40, {"per": 0.06, "tags": [tag, nxt]})
        links.append(["%s:R2" % tag, bid])
        links.append([bid, "%s:L2" % nxt])
    # 中央六格依序連到六個流派區的入口（c0 → 講道 … c5 → 門徒），中央六格之間也連成一圈
    for i in range(6):
        links.append(["中央:c%d" % i, "中央:c%d" % ((i + 1) % 6)])
    G["board"] = {
        "_說明": "恩賜盤：nodes 是每個節點（id 是「流派:位置」，x、y 是盤面上的位置，size 1 小節點／2 經文節點／3 基石，cost 是學會要幾個餅，"
                 "kind 是效果種類，per 是數值）；links 是相連的兩個節點；starts 是每位主角的起點（免費、一定點上）。"
                 "學會：要跟已經學會的節點（或任何一位主角的起點）相連。裝上：每位主角一套，要從他的起點連過去，總數不超過 loadout 算出來的點數。",
        "order": ORDER, "nodes": nodes, "links": links, "starts": STARTS,
    }
    # 只把 board 這一塊插進 gifts 裡（其他地方的排版不動）；一個節點一行，好讀好改
    B = G["board"]
    txt = ['"board": {', '    "_說明": %s,' % json.dumps(B["_說明"], ensure_ascii=False),
           '    "order": %s,' % json.dumps(ORDER, ensure_ascii=False), '    "starts": %s,' % json.dumps(STARTS, ensure_ascii=False), '    "nodes": [']
    txt += ['      %s%s' % (json.dumps(nd, ensure_ascii=False), "," if k < len(nodes) - 1 else "") for k, nd in enumerate(nodes)]
    txt += ['    ],', '    "links": [']
    txt += ['      %s%s' % (json.dumps(l, ensure_ascii=False), "," if k < len(links) - 1 else "") for k, l in enumerate(links)]
    txt += ['    ]', '  },']
    raw = open(P, encoding="utf-8").read()
    if '"board": {' in raw:
        raise SystemExit("meta.json 已經有 board 了：要重排請先刪掉 gifts.board")
    i = raw.index('"gifts": {') + len('"gifts": {')
    raw = raw[:i] + "\n    " + "\n    ".join(txt) + raw[i:]
    json.loads(raw)
    open(P, "w", encoding="utf-8").write(raw)
    print(len(nodes), "nodes", len(links), "links")


if __name__ == "__main__":
    main()
