"""史詩感關卡曲：沿用 make_music.py 每首曲子自己的主題、調式、聖詩與地區配器，只換曲式、速度與配器。

做法：把 make_music.battle 換成 epic_battle，再照原本的 SONGS 清單逐首產生，所以各章的旋律與辨識度不變。
速度：取遊戲 BPM（data/game.json 的 music_bpm）的一半（半速）。遊戲的重拍（每 4 個遊戲拍）因此剛好落在
音樂的第 1、3 拍，同行合擊與「詩歌」流派的節拍判定完全不變，不用改 main.gd 或 game.json。
三層（perc、harm、top）照舊，sfx.gd 的強度混音（set_intensity）不用改。
用法：python tools/make_music_epic.py <輸出資料夾> [曲名 ...]    （只處理 battle 系的關卡曲與 fever；
camp、title、story、ending 不是 battle 系，另外處理）需要 numpy、scipy、ffmpeg。
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_music as mm  # noqa: E402

GAME_JSON = os.path.join(os.path.dirname(__file__), "..", "data", "game.json")
# 力度走勢（各段的音量倍率）：弱起 → 主題 → 銅管與合唱 → 聖詩（收一點）→ 高潮 → 收尾回到弱起，循環才接得上
ARC = {"intro": 0.35, "A": 0.55, "B": 0.85, "C": 0.55, "A2": 1.0, "end": 0.4}
PERC_BOOST = 1.6   # +4 dB：半速後鼓點稀疏、RMS 偏低，史詩感要靠定音鼓與太鼓撐住（現有曲子打擊層比旋律層只低 3.5–5.6 dB）
current = {"name": ""}


def _region(region: str) -> dict:
    return {"judea": dict(arp=mm.harp, brass=mm.shofar),
            "levant": dict(arp=mm.oud, brass=mm.ney),
            "greek": dict(arp=mm.kithara, brass=mm.brass),
            "rome": dict(arp=mm.kithara, brass=mm.brass),
            "sea": dict(arp=mm.harp, brass=mm.brass),
            "vision": dict(arp=mm.bell, brass=mm.brass)}[region]


def epic_battle(root, mode, bpm, prog, motif, answer, lead=mm.aulos, taiko_a=None, taiko_b=None,
                frame=None, extra=None, quote="theme", region="greek"):
    """與 make_music.battle 同樣的參數與曲式（前奏 2 → A 8 → B 8 → C 聖詩或主題 → A' 8），可循環。"""
    want = json.load(open(GAME_JSON, encoding="utf-8")).get("music_bpm", {}).get(current["name"])
    assert want is None or abs(want - bpm) < 1e-6, f"{current['name']}：曲子 BPM {bpm} 和 game.json 的 {want} 不同，會破壞對拍"
    R = _region(region)
    if lead is mm.aulos and region in ("levant", "judea"):
        lead = mm.ney
    big = "D" if region == "levant" else "B"
    q = mm.HYMNS.get(quote, mm.THEME)
    minor_q = quote in mm.MINOR_HYMNS
    c_bars = int(np.ceil(mm.beats(q) / 4)) + 1
    A, B, C = 2, 10, 18
    A2 = C + c_bars
    total = A2 + 8
    tr = mm.Track(bpm=bpm / 2.0, bars=total)         # 半速：一個音樂拍 = 兩個遊戲拍
    chord = lambda bar: prog[bar % len(prog)]  # noqa: E731
    rel = mm.REL_MAJOR[mode]
    use_hymn = quote in mm.HYMNS and not minor_q
    c_prog = [rel, rel + 3, rel + 4, rel] if use_hymn else prog
    cchord = (lambda bar: c_prog[(bar - C) // 2 % len(c_prog)]) if use_hymn else chord  # noqa: E731
    in_c = lambda bar: C <= bar < A2  # noqa: E731
    beat = tr.beat

    # ---- 打擊：重拍落在第 1、3 拍（對上遊戲重拍）；C 段只剩定音鼓；段落交接放定音鼓滾奏 ----
    tr.layer = "perc"
    for bar in range(total):
        b = bar * 4
        if in_c(bar):
            if bar % 2 == 0:
                tr.put(b, mm.timp(0.8), 0.9, mm.taiko, "perc")
            continue
        if bar >= A:
            for t, v in ((0, 1.0), (2, 0.85)):
                tr.hit(b + t, big, v * (0.9 + 0.1 * mm.RNG.random()))
            if bar >= B:
                for t in (1, 3):
                    tr.hit(b + t, big, 0.4)
        if bar in (0, 1, B - 1, C - 1, total - 1) or (A2 - 1 == bar):
            tr.put(b, mm.timp(1.0), 1.0, mm.taiko, "perc")

    # ---- 低音與伴奏：大提琴長音、弦樂鋪底、地區樂器慢琶音 ----
    tr.layer = "harm"
    for bar in range(A, total):
        c = cchord(bar)
        b = bar * 4
        soft = 0.8 if in_c(bar) else 0.6
        if not in_c(bar) or bar % 2 == 0:
            span = 8.2 if in_c(bar) else 4.2
            tr.note(mm.cello, b, mm.hz(mm.deg(root - 24, mode, c)), beat * span, 1.0)
            for d in (c, c + 2, c + 4):
                tr.note(mm.strings, b, mm.hz(mm.deg(root - 12, mode, d)), beat * span, soft)
        if not in_c(bar):
            for i, d in enumerate([0, 4, 2, 4]):
                tr.note(R["arp"], b + i, mm.hz(mm.deg(root, mode, c + d)), beat * 1.3, 0.8, 0.5)

    # ---- 旋律、銅管、合唱 ----
    tr.layer = "top"
    for bar in list(range(B, C)) + list(range(A2, total)):
        c = chord(bar)
        for d in ((c, c + 4) if R["brass"] is mm.shofar else (c, c + 2, c + 4)):
            tr.note(R["brass"], bar * 4, mm.hz(mm.deg(root - 12, mode, d)), beat * 4.2, 0.8)
        for d in (c, c + 2, c + 4):
            tr.note(mm.choir, bar * 4, mm.hz(mm.deg(root, mode, d)), beat * 4.2, 0.5 if bar < C else 0.65)
    pos = tr.melody(lead, root, mode, motif, A * 4)
    tr.melody(lead, root, mode, answer, pos)
    pos = tr.melody(lead, root, mode, motif, B * 4, octave=1)
    tr.melody(R["arp"], root, mode, motif, B * 4, 0.7)
    tr.melody(R["brass"], root - 12, mode, answer, pos, 0.8)
    q_root, q_mode = (root, mode) if (minor_q or quote not in mm.HYMNS) else (mm.deg(root, mode, rel), "rast")
    q_inst = mm.aulos if lead is not mm.aulos or quote in mm.HYMNS else mm.kithara
    tr.melody(q_inst, q_root, q_mode, q, C * 4 + 2, 0.95)
    tr.melody(mm.choir, q_root - 12, q_mode, list(q), C * 4 + 2, 0.55, legato=1.0)
    tr.melody(mm.strings, q_root - 12, q_mode, list(q), C * 4 + 2, 0.5, legato=1.0)
    pos = tr.melody(lead, root, mode, motif, A2 * 4, octave=1)
    tr.melody(R["brass"], root - 12, mode, motif, A2 * 4, 0.9)
    tr.melody(lead, root, mode, answer, pos)
    if extra:
        extra(tr, total, in_c)

    out = tr.render({"perc": 0.8, "harm": 1.3, "top": 1.8})
    # 力度包絡（逐小節倍率，中間內插）；頭尾都回到弱起的力度，循環才不會突然變大聲
    marks = [(0, ARC["intro"]), (A, ARC["A"]), (B, ARC["B"]), (C, ARC["C"]), (A2, ARC["A2"]),
             (total - 2, ARC["A2"] * 0.9), (total, ARC["end"])]
    n = out["top"].shape[1]
    bar_len = tr.length / total
    env = np.interp(np.arange(n), [m[0] * bar_len for m in marks], [m[1] for m in marks])
    return {k: v * env * (PERC_BOOST if k == "perc" else 1.0) for k, v in out.items()}


def main(out_dir: str, only: list) -> None:
    os.makedirs(out_dir, exist_ok=True)
    mm.battle = epic_battle           # 各曲的函式用模組全域的 battle，這樣就換掉了
    mm.OUT = out_dir
    for name, fn, stems in mm.SONGS:
        if name in ("camp", "title", "story", "ending"):
            continue                   # 不是 battle 系
        if only and name not in only:
            continue
        current["name"] = name
        mm.save(name, fn(), stems)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
