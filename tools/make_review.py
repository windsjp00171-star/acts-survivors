"""牧者審閱文字包：把遊戲裡的經文、對話、過場、信仰說明整理成一份 Markdown。

用法：python3 tools/make_review.py   → docs/審閱文字包.md
文字改過就重跑一次，再交給審閱的人。
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "審閱文字包.md"


def load(name):
    return json.loads((ROOT / "data" / f"{name}.json").read_text(encoding="utf-8"))


game, meta, stages, story, talks, bios, codex, events = (
    load(n) for n in ["game", "meta", "stages", "story", "talks", "bios", "codex", "events"])

# 說話的人 key → 名字
NAMES = {"": "旁白", "paul": "保羅", "jesus": "耶穌"}
for c in game["companions"]:
    NAMES[c["key"]] = c["name"]
for c in game["leaders"]:
    NAMES.setdefault(c["key"], c.get("name", c["key"]))
NAMES.update({"saul": "掃羅", "ananias": "亞拿尼亞", "disciple": "門徒", "aq": "亞居拉"})

out = []
w = out.append


def lines(rows, default_paul="保羅"):
    for r in rows:
        who = r[2] if len(r) > 2 and r[2] else NAMES.get(r[0], r[0])
        if r[0] == "paul" and not (len(r) > 2 and r[2]):
            who = default_paul
        text = str(r[1]).replace("\n", " ")
        w(f"- **{who}**：{text}" if r[0] else f"- （旁白）{text}")


def cut_lines(src, const):
    """從 title.gd 抓 INTRO 或 CUTS 的旁白。"""
    return re.findall(r'"text": "((?:[^"\\]|\\.)*)"', const)


title_gd = (ROOT / "scripts" / "title.gd").read_text(encoding="utf-8")
intro_src = title_gd.split("const INTRO := [", 1)[1].split("\n]\n", 1)[0]
cuts_src = title_gd.split("const CUTS := {", 1)[1].split("\n}\n", 1)[0]
cuts = {}
for m in re.finditer(r'"(\w+)": \[(.*?)\n\t\],', cuts_src, re.S):
    cuts[m.group(1)] = [t.replace("\\n", " ") for t in cut_lines(None, m.group(2))]

w("# 宣教之路：牧者審閱文字包")
w("")
w("這份文件收錄遊戲裡所有跟聖經、信仰有關的文字：開場、十五章的劇情與對話、章節過場、結局（台灣宣教史）、同伴生平與閒聊、信仰小辭典，以及卡片、事件上引用的經文。")
w("")
w("**想請您幫忙看的地方**")
w("")
w("1. 有沒有跟聖經記載不合、或容易讓人誤會的地方")
w("2. 神學上的說法是否妥當（特別是「信仰小辭典」與結局）")
w("3. 經文出處標錯的地方")
w("4. 台灣宣教史的年代、人名、事蹟是否正確")
w("")
w("遊戲的世界觀：敵人都是黑暗的勢力（懼怕、謊言、自高、紛爭……），人從來不是敵人。每個黑暗的勢力背後都捆綁著一個人，爭戰是為了把人贏回來（弗 6:12、徒 26:18）。")
w("")
w("經文依和合本。對話是為了遊戲改寫的口語，原則是只寫當下發生的事、照時間順序。有意見直接寫在旁邊或留言即可。")
w("")

# 一、開場
w("## 一、開場（第一次打開遊戲）")
w("")
for t in cut_lines(None, intro_src):
    w(f"- {t}")
w("")

# 二、十五章
w("## 二、劇情十五章")
w("")
st_by = {s["id"]: s for s in stages["stages"]}
after_cut = {"stephen": "stephen", "damascus": "damascus", "rome": "rome", "patmos": "patmos"}
for i, ch in enumerate(story["chapters"]):
    s = st_by[ch["stage"]]
    w(f"### 第 {i + 1} 章　{ch['title']}（{s.get('ref', '')}）")
    w("")
    paul_name = "掃羅" if ch["stage"] in ("stephen", "damascus") else "保羅"
    lead = paul_name if ch["leader"] == "paul" else NAMES.get(ch["leader"], ch["leader"])
    cast = "、".join(NAMES.get(k, k) for k in ch.get("cast", []))
    info = f"主角：{lead}。會遇到的同伴：{cast or '（無）'}。"
    if s.get("church"):
        info += f"建立的教會：{s['church']}。"
    w(info)
    w("")
    if s.get("intro"):
        w(f"**選關畫面的一句話**：{s['intro']}")
        w("")
    if s.get("story"):
        w(f"**故事簡介**：{s['story']}")
        w("")
    if s.get("talk_in"):
        w("**進城的對話**")
        w("")
        lines(s["talk_in"], paul_name)
        w("")
    if s.get("talk_ananias"):
        w("**亞拿尼亞來到時的對話**")
        w("")
        lines(s["talk_ananias"], paul_name)
        w("")
    hz = s.get("hazard", {})
    if hz.get("text"):
        w(f"**關卡機制的提示**：{hz['text']}")
        w("")
    if s.get("seekers"):
        w("**尋找的人**（玩家陪他走一段，他就信主跟著你）")
        w("")
        for sk in s["seekers"]:
            w(f"- {sk['name']}（{sk.get('ref', '')}）：「{sk.get('line', '')}」")
        w("")
    b = s.get("boss", {})
    if b:
        w(f"**Boss**：{b.get('name', '')}。打倒後的話：「{b.get('win_text', '')}」（{b.get('win_ref', '')}）")
        w("")
    if s.get("talk_out"):
        w("**建立教會後的對話**")
        w("")
        lines(s["talk_out"], paul_name)
        w("")
    if s.get("church_notes"):
        w("**教會長大後的近況**")
        w("")
        for n in s["church_notes"]:
            w(f"- {n[0]}（{n[1]}）")
        w("")
    ep = s.get("epistle")
    if ep:
        w(f"**書信卡**：{ep.get('name', '')}——{ep.get('desc', '')}")
        w("")
    if ch["stage"] in cuts:
        title = "結局「第 29 章」" if ch["stage"] == "patmos" else "通過後的過場"
        w(f"**{title}**")
        w("")
        for t in cuts[ch["stage"]]:
            w(f"- {t}")
        w("")

# 三、同伴
w("## 三、同伴")
w("")
w("### 同伴生平（默契升級時解鎖）")
w("")
for k, v in bios.items():
    if k.startswith("_") or not isinstance(v, list):
        continue
    w(f"#### {NAMES.get(k, k)}")
    w("")
    for e in v:
        w(f"- **{e.get('title', '')}**（{e.get('ref', '')}）：{e.get('text', '')}")
    w("")
w("### 營地閒聊")
w("")
w("括號裡是要先建立哪座城的教會，這段閒聊才會出現。")
w("")
cname = {s["id"]: s.get("church", s["name"]) for s in stages["stages"]}
for k, v in talks["talks"].items():
    w(f"#### {NAMES.get(k, k)}")
    w("")
    for seg in v:
        if isinstance(seg, dict):
            w(f"（{cname.get(seg.get('after'), seg.get('after', ''))}以後）")
            w("")
            lines(seg["lines"])
        else:
            lines(seg)
        w("")

# 四、信仰小辭典
w("## 四、信仰小辭典（圖鑑）")
w("")
for x in codex["words"]:
    w(f"- **{x['name']}**（{x.get('ref', '')}）：{x['text']}")
w("")
w("### 黑暗的勢力（敵人）")
w("")
for x in codex["enemies"]:
    w(f"- **{x['name']}**：{x.get('what', '')}　經文：「{x.get('verse', '')}」（{x.get('ref', '')}）")
w("")

# 五、旅程事件
w("## 五、旅程中的事件（自由模式）")
w("")
for e in events["events"]:
    ch = "；".join(f"{c['label']}（{c.get('desc', '')}）" for c in e.get("choices", []))
    w(f"- **{e['title']}**（{e.get('ref', '')}）：{e.get('text', '')}　選項：{ch}")
w("")

# 六、其他引用經文的地方：自動收集所有有 ref 的項目
w("## 六、卡片、流派、成就等引用經文的地方")
w("")
w("這部分是遊戲系統的名稱與效果說明，經文多半是取名字的由來，請主要看名字與出處是否搭配得宜。")
w("")
REF = re.compile(r"[（(][^（）()]*\d+[:：]\d+[^（）()]*[）)]")
seen = set()


def walk(node, path):
    if isinstance(node, dict):
        if "ref" in node and isinstance(node["ref"], str) and node.get("name") or node.get("title"):
            if "ref" in node:
                name = node.get("name") or node.get("title")
                desc = node.get("story") or node.get("desc") or node.get("text") or node.get("verse") or ""
                if isinstance(desc, list):
                    desc = desc[0]
                key = (name, node["ref"])
                if key not in seen:
                    seen.add(key)
                    w(f"- **{name}**（{node['ref']}）{('：' + desc) if desc else ''}")
        for k, v in node.items():
            if not k.startswith("_"):
                walk(v, path)
    elif isinstance(node, list):
        for v in node:
            walk(v, path)
    elif isinstance(node, str) and REF.search(node) and node not in seen:
        seen.add(node)
        w(f"- {node}")


SECTIONS = [
    (game, ["schools", "fusions", "evolutions", "bonds", "relics", "callings", "armor", "armor_sets",
            "fruits", "links", "elites", "fever", "tips"], "局內"),
    (meta, ["faith", "achievements", "buildings", "gifts", "shop"], "局外"),
]
LABEL = {"schools": "流派", "fusions": "流派融合", "evolutions": "進化", "bonds": "默契技", "relics": "信物",
         "callings": "呼召", "armor": "軍裝", "armor_sets": "軍裝套組", "fruits": "果子", "links": "肢體連結",
         "elites": "菁英", "fever": "五旬節", "tips": "提示", "faith": "信心等級", "achievements": "見證錄",
         "buildings": "營地建設", "gifts": "恩賜樹", "shop": "解鎖"}
for data, keys, _ in SECTIONS:
    for k in keys:
        if k in data:
            n0 = len(out)
            w(f"### {LABEL.get(k, k)}")
            w("")
            n1 = len(out)
            walk(data[k], LABEL.get(k, k))
            if len(out) == n1:
                del out[n0:]
            else:
                w("")

# 遊戲中直接寫在程式裡的經文
w("### 寫在程式裡的提示")
w("")
for f in ["main.gd", "base.gd", "game_ui.gd", "camp.gd"]:
    for m in re.finditer(r'"([^"\n]*[（(][^"\n]*\d+:\d+[^"\n]*[）)][^"\n]*)"', (ROOT / "scripts" / f).read_text(encoding="utf-8")):
        t = m.group(1)
        if t not in seen:
            seen.add(t)
            w(f"- {t}")
w("")

OUT.parent.mkdir(exist_ok=True)
OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
print(OUT, len(out), "行", sum(len(x) for x in out), "字")
