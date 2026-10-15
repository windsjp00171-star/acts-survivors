"""產生遊戲配樂：希臘羅馬史詩風（全部用程式合成，沒有外部素材）。

用法：python tools/make_music.py   （需要 numpy 和 ffmpeg）
輸出：assets/audio/music_*.ogg，每首都可以無縫循環。

樂器：阿洛斯雙管（aulos）、基薩拉琴（kithara）、羅馬銅管、戰鼓、框鼓、弦樂斷奏、低音、合唱；
使徒行傳的城市（腓立比、帖撒羅尼迦、哥林多、以弗所）都是希臘羅馬城市，所以用古希臘調式，不用帶增二度的希賈茲（太像埃及）。
每首曲子寫成「調式＋旋律（音階級數）＋鼓的節奏型」，想改旋律就改下面的 score。
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RNG = np.random.default_rng(11)

# 調式（相對主音的半音）
MODES = {
    "rast":     [0, 2, 4, 5, 7, 9, 11],    # 大調（不用四分之一音的簡化）
    "dorian":   [0, 2, 3, 5, 7, 9, 10],
    "aeolian":  [0, 2, 3, 5, 7, 8, 10],    # 自然小調
    "phrygian": [0, 1, 3, 5, 7, 8, 10],    # 弗里吉亞（古希臘調式，沒有增二度）
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
}


def ta(sec):
    return np.arange(int(SR * sec)) / SR


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def deg(root, mode, d):
    """音階級數 → MIDI（可以超過 7 或小於 0，自動跨八度）"""
    sc = MODES[mode]
    o, i = divmod(d, len(sc))
    return root + 12 * o + sc[i]


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


NOISE = RNG.standard_normal(SR * 2)
NOISE_LP = lowpass(NOISE, 0.08)
NOISE_HP = NOISE - lowpass(NOISE, 0.35)


# ---------- 樂器 ----------
def choir(f, sec, vel=1.0):
    """合唱「啊」：多個微微走音的聲音，加上母音共振峰"""
    t = ta(sec)
    y = np.zeros_like(t)
    for dt in (-0.6, 0.0, 0.5, 1.1):
        ff = f + dt
        vib = 1 + 0.004 * np.sin(2 * np.pi * (4.8 + dt) * t)
        ph = 2 * np.pi * np.cumsum(ff * vib) / SR
        for k in range(1, 10):
            fk = ff * k
            w = np.exp(-((fk - 750) / 220) ** 2) + 0.7 * np.exp(-((fk - 1150) / 260) ** 2) + 0.15 / k
            y += w * np.sin(k * ph)
    env = np.clip(t / 0.35, 0, 1) * np.clip((sec - t) / 0.4, 0, 1)
    return y / 4 * env * vel * 0.25


def drone(f, sec):
    """持續低音：主音＋五度，很輕的濾波鋸齒波"""
    t = ta(sec)
    saw = sum(np.sin(2 * np.pi * f * k * t) / k for k in range(1, 8))
    fifth = sum(np.sin(2 * np.pi * f * 1.5 * k * t) / k for k in range(1, 5))
    swell = 0.85 + 0.15 * np.sin(2 * np.pi * t / sec)
    return (saw + 0.5 * fifth) * swell * 0.06


def doum(vel=1.0):
    t = ta(0.35)
    f = 70 + 90 * np.exp(-t * 25)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * vel * 0.9


def tek(vel=1.0):
    t = ta(0.07)
    n = NOISE_HP[: len(t)]
    ring = np.sin(2 * np.pi * 2400 * t) * 0.3
    return (n + ring) * np.exp(-t * 70) * vel * 0.45


def ka(vel=1.0):
    return tek(vel * 0.55)


def daf(vel=1.0):
    """框鼓：低沉的一下＋鈴片"""
    t = ta(0.4)
    low = np.sin(2 * np.pi * (85 + 40 * np.exp(-t * 20)) * t) * np.exp(-t * 7)
    jingle = NOISE_HP[: len(t)] * np.exp(-t * 14) * 0.25
    return (low + jingle) * vel * 0.6


def clap(vel=1.0):
    t = ta(0.12)
    n = NOISE[: len(t)] - lowpass(NOISE[: len(t)], 0.2)
    env = np.exp(-t * 35) + 0.5 * np.exp(-np.abs(t - 0.012) * 300)
    return n * env * vel * 0.35


# ---------- 編曲 ----------
class Track:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.beat = 60.0 / bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.length = int(SR * self.beat * beats_per_bar * bars)
        self.buf = np.zeros(self.length + SR * 4)   # 多留尾巴，最後折回開頭

    def put(self, at_beat, sound, gain=1.0):
        s = int(at_beat * self.beat * SR)
        n = min(len(sound), len(self.buf) - s)
        if n > 0:
            self.buf[s:s + n] += sound[:n] * gain

    def drums(self, pattern, kit, gain=1.0, swing=0.0, bars=None):
        """pattern 每個字元是一個十六分音符：D 低鼓 T 高鼓 k 輕敲 F 框鼓 C 拍手 . 休止"""
        steps = len(pattern)
        per_bar = self.bpb * 4
        for bar in range(bars if bars is not None else self.bars):
            for i, ch in enumerate(pattern):
                if ch == ".":
                    continue
                pos = bar * self.bpb + (i % per_bar) / 4 + (i // per_bar) * self.bpb
                if i % 2 == 1:
                    pos += swing
                vel = 0.85 + 0.15 * RNG.random()
                self.put(pos, kit[ch](vel), gain)
            if steps > per_bar:
                break

    def melody(self, inst, root, mode, notes, start=0.0, gain=1.0, octave=0):
        """notes: [(級數, 拍數)]，級數 None 是休止"""
        pos = start
        for d, dur in notes:
            if d is not None:
                f = hz(deg(root, mode, d) + 12 * octave)
                sec = dur * self.beat * (1.05 if inst is aulos or inst is choir else 1.6)
                self.put(pos, inst(f, sec), gain)
            pos += dur
        return pos

    def render(self):
        n = self.length
        y = self.buf[:n].copy()
        tail = self.buf[n:]
        y[: len(tail)] += tail          # 尾巴折回開頭：循環時餘音接得上
        return y


KIT = {"D": doum, "T": tek, "k": ka, "F": daf, "C": clap}


def save(name, y, target_db=-20.0):
    # 每首調到一樣的平均音量（切歌時不會忽大忽小），再用 tanh 柔性限幅避免破音
    rms = np.sqrt((y ** 2).mean()) + 1e-9
    y = y * (10 ** (target_db / 20) / rms)
    y = np.tanh(y * 1.2) / 1.2
    tmp = os.path.join(OUT, "_" + name + ".wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, "music_" + name + ".ogg")], check=True)
    os.remove(tmp)
    print("music_%s.ogg  %.1f 秒" % (name, len(y) / SR))


# ---------- 曲目 ----------
# ---------- 戰鬥用的樂器 ----------
def _saw(f, t, n_harm, decay_by_k=0.0):
    y = np.zeros_like(t)
    for k in range(1, n_harm + 1):
        if f * k > 7000:
            break
        y += np.sin(2 * np.pi * f * k * t) / k * (np.exp(-t * decay_by_k * k) if decay_by_k else 1.0)
    return y


def bass(f, sec, vel=1.0):
    """撥奏低音：短、厚"""
    t = ta(sec)
    # 手機喇叭放不出很低的音，所以多留一點中頻泛音，聽起來才有「咚咚咚」的推進感
    return _saw(f, t, 14, 0.6) * np.exp(-t * 8) * np.clip(t / 0.003, 0, 1) * vel * 0.28


def spic(f, sec, vel=1.0):
    """弦樂斷奏：很短的一下，兩把微微走音"""
    t = ta(min(sec, 0.18))
    y = _saw(f, t, 10) + _saw(f * 1.004, t, 10)
    return y * np.exp(-t * 22) * np.clip(t / 0.004, 0, 1) * vel * 0.2


def brass(f, sec, vel=1.0):
    """銅管重音：起音有一點推進，泛音隨著打開"""
    t = ta(sec)
    y = np.zeros_like(t)
    open_ = np.clip(t / 0.08, 0, 1)
    for k in range(1, 12):
        if f * k > 6000:
            break
        y += np.sin(2 * np.pi * f * k * t) / k * (open_ ** (k * 0.3))
    env = np.clip(t / 0.03, 0, 1) * (0.55 + 0.45 * np.exp(-t * 5)) * np.clip((sec - t) / 0.1, 0, 1)
    return y * env * vel * 0.22


def aulos(f, sec, vel=1.0):
    """阿洛斯（古希臘雙管）：奇次泛音為主、圓潤，兩根管子微微走音"""
    t = ta(sec)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) / 0.25, 0, 1)
    y = np.zeros_like(t)
    for det in (1.0, 1.003):
        ph = 2 * np.pi * np.cumsum(f * det * vib) / SR
        for k, a in [(1, 1.0), (2, 0.12), (3, 0.55), (4, 0.08), (5, 0.3), (7, 0.15), (9, 0.07)]:
            if f * k < 8000:
                y += a * np.sin(k * ph)
    n = len(t)
    breath = NOISE_HP[:n] if n <= len(NOISE_HP) else np.resize(NOISE_HP, n)
    env = np.clip(t / 0.03, 0, 1) * np.clip((sec - t) / 0.08, 0, 1)
    return (y + breath * 0.15) * env * vel * 0.26


def kithara(f, sec, vel=1.0):
    """基薩拉（古希臘里拉琴）：明亮、有共鳴的撥弦"""
    t = ta(sec)
    y = np.zeros_like(t)
    for k, a in [(1, 1.0), (2, 0.6), (3, 0.4), (4, 0.3), (5, 0.18), (6, 0.1)]:
        y += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (2.5 + k * 1.8))
    return y * np.clip(t / 0.002, 0, 1) * vel * 0.3


def taiko(vel=1.0):
    """大鼓：很低、很長的轟"""
    t = ta(0.7)
    f = 55 + 70 * np.exp(-t * 18)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = (np.sin(ph) * 0.45 + np.sin(2 * ph) * 0.5 + np.sin(3.1 * ph) * 0.25) * np.exp(-t * 6)
    hit = NOISE_LP[: len(t)] * np.exp(-t * 35) * 2.2
    return (body + hit) * vel * 0.9


def snare(vel=1.0):
    t = ta(0.2)
    n = NOISE[: len(t)] - lowpass(NOISE[: len(t)], 0.15)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return (n * np.exp(-t * 22) * 0.8 + body * 0.6) * vel * 0.75


def shaker(vel=1.0):
    t = ta(0.05)
    return NOISE_HP[: len(t)] * np.exp(-t * 90) * vel * 0.18


KIT.update({"B": taiko, "S": snare, "h": shaker})


def battle(root, mode, bpm, prog, motif, answer, lead=aulos, taiko_a="B.......B..B....", taiko_b="B..B..B.B..B.B..",
           frame="F...k.k.F...k...", extra=None):
    """戰鬥曲：2 小節前奏 → A 段 8 小節（主題＋回應）→ B 段 6 小節（銅管＋主題高八度）。共 16 小節，可循環。"""
    tr = Track(bpm=bpm, bars=16)
    chord = lambda bar: prog[bar % len(prog)]
    # 鼓
    for bar in range(16):
        pat = taiko_a if bar < 10 else taiko_b
        for i, ch in enumerate(pat):
            if ch != ".":
                tr.put(bar * 4 + i / 4, taiko(0.85 + 0.15 * RNG.random()), 1.0)
        for i in range(16):
            tr.put(bar * 4 + i / 4, shaker(1.0 if i % 4 == 0 else 0.6), 1.0)
        if bar >= 2:
            snare_pat = "....S.......S..." if bar not in (9, 15) else "....S...S.S.SSSS"
            for i, ch in enumerate(snare_pat):
                if ch == "S":
                    tr.put(bar * 4 + i / 4, snare(0.7 + 0.3 * (i >= 8 and bar in (9, 15))), 1.0)
        for i, ch in enumerate(frame):
            if ch != ".":
                tr.put(bar * 4 + i / 4, KIT[ch](0.8), 0.5)
    # 前奏最後一拍：鼓滾
    for i in range(8):
        tr.put(7 + i / 8, snare(0.4 + i * 0.08), 1.0)
    # 低音：奔馳節奏（八分＋兩個十六分）
    for bar in range(2, 16):
        r = deg(root - 24, mode, chord(bar))
        for beat in range(4):
            for off, v in [(0, 1.0), (0.5, 0.7), (0.75, 0.75)]:
                tr.put(bar * 4 + beat + off, bass(hz(r + (12 if beat == 3 and off == 0.75 else 0)), 0.25, v), 1.0)
    # 弦樂斷奏琶音
    for bar in range(2, 16):
        c = chord(bar)
        for i in range(16):
            d = c + [0, 2, 4, 7, 4, 2, 0, 2][i % 8]
            tr.put(bar * 4 + i / 4, spic(hz(deg(root - 12, mode, d)), 0.15, 0.9 if i % 4 == 0 else 0.6), 1.0)
    # B 段：每小節開頭銅管重音（和弦三個音）
    for bar in range(10, 16):
        c = chord(bar)
        for d in (c, c + 2, c + 4):
            tr.put(bar * 4, brass(hz(deg(root - 12, mode, d)), tr.beat * (1.5 if bar % 2 else 3.5)), 1.0)
    # 主旋律
    pos = 8.0
    pos = tr.melody(lead, root, mode, motif, pos, 1.0)
    pos = tr.melody(lead, root, mode, answer, pos, 1.0)
    tr.melody(lead, root, mode, motif, 40.0, 1.0, octave=1)
    tr.melody(kithara, root, mode, motif, 40.0, 0.7)
    # 基薩拉琴的分解和弦（A、B 段都有）
    for bar in range(2, 16):
        c = chord(bar)
        for i, d in enumerate([0, 4, 2, 4, 7, 4, 2, 4]):
            tr.put(bar * 4 + i * 0.5, kithara(hz(deg(root, mode, c + d)), 0.6, 0.55), 1.0)
    if extra:
        extra(tr)
    return tr.render()


def camp():
    # 營地：慢、溫暖。D 多利安，阿洛斯主奏、基薩拉琴分解和弦、輕輕的框鼓
    tr = Track(bpm=66, bars=16)
    root = 62
    tr.put(0, drone(hz(38), tr.length / SR + 2), 0.6)
    tr.drums("F.......F...k...", KIT, 0.5)
    a = [(4, 1.5), (3, 0.5), (2, 1), (1, 1), (2, 3), (None, 1)]
    b = [(2, 1), (3, 1), (4, 1), (6, 1), (5, 2), (4, 1), (3, 1)]
    c = [(4, 1.5), (5, 0.5), (4, 1), (3, 1), (2, 1), (1, 1), (0, 2)]
    pos = 8.0
    for phrase in [a, b, a, c, b, c]:
        pos = tr.melody(aulos, root, "dorian", phrase, pos, 0.55)
    for bar in range(16):
        base = [0, 0, 3, 4][bar % 4]
        for i, d in enumerate([0, 4, 7, 4]):
            tr.melody(kithara, root - 12, "dorian", [(base + d, 1)], bar * 4 + i, 0.6)
    return tr.render()


def philippi():
    motif = [(0, 1), (1, 0.5), (2, 0.5), (3, 1), (2, 0.5), (1, 0.5), (0, 2), (None, 2), (4, 1), (3, 1), (2, 1), (1, 1), (0, 4)]
    answer = [(4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (3, 1.5), (2, 0.5), (1, 2), (2, 1), (1, 1), (0, 2), (-1, 2), (0, 2)]
    # 腓立比：D 多利安，i - IV - i - VII
    return battle(62, "dorian", 132, [0, 3, 0, 6], motif, answer)


def thessalonica():
    # 暴動：最快、鼓最密
    motif = [(0, 0.5), (0, 0.5), (1, 0.5), (2, 0.5), (3, 1), (4, 1), (3, 0.5), (2, 0.5), (1, 1), (0, 2), (4, 0.5), (4, 0.5), (5, 1), (4, 1), (3, 1), (2, 1), (1, 1), (0, 2)]
    answer = [(7, 1), (6, 0.5), (5, 0.5), (4, 1), (3, 1), (4, 0.5), (3, 0.5), (2, 1), (1, 2), (2, 0.5), (3, 0.5), (2, 1), (1, 1), (0, 1), (-1, 1), (0, 2)]
    # 帖撒羅尼迦：E 自然小調，i - VI - VII - i，最快
    return battle(64, "aeolian", 144, [0, 5, 6, 0], motif, answer, taiko_a="B..B....B..B....", taiko_b="B.BB..B.B.BB.BB.",
                  frame="F.k.k.k.F.k.k.kk")


def corinth():
    # 哥林多：A 自然小調，i - VI - III - VII
    motif = [(4, 2), (3, 1), (2, 1), (3, 1.5), (2, 0.5), (1, 1), (2, 1), (0, 4), (None, 1), (2, 1), (3, 1), (4, 1), (5, 2), (4, 2)]
    answer = [(6, 1.5), (5, 0.5), (4, 1), (3, 1), (2, 2), (3, 1), (2, 1), (1, 1), (0, 1), (-1, 2), (0, 4)]
    return battle(57, "aeolian", 136, [0, 5, 2, 6], motif, answer, frame="F..kF...k..k....")


def ephesus():
    # 暗：i - bII - bVII - i，底下加低沉合唱
    motif = [(0, 2), (1, 1), (0, 1), (-1, 2), (0, 2), (3, 2), (2, 1), (1, 1), (0, 4)]
    answer = [(4, 1), (3, 1), (4, 1), (5, 1), (4, 2), (3, 1), (1, 1), (2, 2), (1, 1), (0, 1), (0, 4)]

    def chant(tr):
        for bar in range(2, 16, 2):
            tr.melody(choir, 48, "phrygian", [([0, 1, -1, 0][(bar // 2) % 4], 8)], bar * 4, 0.7)
    # 以弗所：C 弗里吉亞（古希臘調式，暗），i - bII - bVII - i
    return battle(60, "phrygian", 128, [0, 1, -1, 0], motif, answer, frame="F..kF.k.F..kF.k.", extra=chant)


def boss():
    # Boss：最快、大鼓每拍、銅管不停
    tr_motif = [(0, 0.5), (1, 0.5), (0, 0.5), (-1, 0.5), (0, 1), (3, 1), (2, 0.5), (1, 0.5), (0, 0.5), (-1, 0.5), (0, 2), (4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (1, 2), (0, 2)]
    answer = [(7, 1), (5, 1), (4, 1), (3, 1), (4, 0.5), (3, 0.5), (2, 0.5), (1, 0.5), (0, 2), (4, 1), (3, 1), (1, 1), (2, 1), (0, 4)]

    def stabs(tr):
        for bar in range(2, 10):
            for beat in (0, 2):
                tr.put(bar * 4 + beat, brass(hz(deg(50, "aeolian", [0, 5, 6, 4][bar % 4])), tr.beat * 0.8), 0.9)
    # Boss：D 自然小調，i - VI - VII - V，最快、銅管連打
    return battle(62, "aeolian", 150, [0, 5, 6, 4], tr_motif, answer, taiko_a="B...B...B...B.B.", taiko_b="B.B.B.B.B.B.BBBB",
                  frame="F.kkF.k.F.kkF.kk", extra=stabs)


def fever():
    # 五旬節：明亮大調 I - IV - V - I，拍手、合唱
    tune = [(4, 1), (4, 0.5), (5, 0.5), (6, 1), (4, 1), (7, 2), (6, 1), (5, 1), (4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (4, 4)]
    answer = [(7, 1), (6, 0.5), (5, 0.5), (4, 1), (5, 1), (6, 2), (4, 2), (5, 1), (4, 1), (3, 1), (2, 1), (0, 4)]

    def joy(tr):
        tr.drums("....C.......C...", KIT, 1.0)
        for bar in range(0, 16, 2):
            c = [0, 3, 4, 0][(bar // 2) % 4]
            for d in (c, c + 2, c + 4):
                tr.melody(choir, 62, "rast", [(d, 8)], bar * 4, 0.5)
    return battle(62, "rast", 140, [0, 3, 4, 0], tune, answer, lead=kithara, frame="F...k.F.F...k.k.", extra=joy)


def athens():
    # 雅典：G 混合利底亞，基薩拉琴主奏，明亮、像在廣場上辯論
    motif = [(4, 1), (5, 0.5), (4, 0.5), (2, 1), (4, 1), (7, 2), (6, 1), (4, 1), (5, 1), (4, 0.5), (2, 0.5), (1, 1), (0, 2)]
    answer = [(2, 0.5), (3, 0.5), (4, 1), (2, 1), (0, 1), (1, 1), (2, 2), (4, 1), (3, 1), (2, 1), (1, 1), (0, 4)]
    return battle(67, "mixolydian", 126, [0, 6, 3, 0], motif, answer, lead=kithara,
                  taiko_a="B.......B.......", taiko_b="B...B...B..B.B..", frame="F..kk.k.F..k.k..")


def jerusalem():
    # 耶路撒冷：E 弗里吉亞，慢而重，低沉合唱與大鼓，像城裡的喧嚷
    motif = [(0, 1), (1, 1), (0, 1), (-1, 1), (0, 2), (1, 0.5), (2, 0.5), (3, 1), (2, 2), (1, 1), (0, 1), (-1, 2), (0, 2)]
    answer = [(3, 1), (4, 1), (5, 2), (4, 1), (3, 1), (1, 2), (2, 1), (1, 1), (0, 4)]

    def chant(tr):
        for bar in range(0, 16, 2):
            tr.melody(choir, 52, "phrygian", [([0, 1, 0, -1][(bar // 2) % 4], 8)], bar * 4, 0.8)
            tr.put(bar * 4, drone(hz(40), tr.beat * 8), 0.5)
    return battle(64, "phrygian", 116, [0, 1, 6, 0], motif, answer,
                  taiko_a="B..B....B..B..B.", taiko_b="BB.B..B.BB.B..BB", frame="F...F.k.F...F.kk", extra=chant)


def malta():
    # 馬爾他：D 多利安，像海上的暴風：快、低音翻騰，加上浪聲般的合唱
    motif = [(0, 0.5), (2, 0.5), (4, 0.5), (2, 0.5), (3, 1), (2, 1), (1, 0.5), (2, 0.5), (0, 1), (-1, 2), (0, 0.5), (2, 0.5), (4, 0.5), (5, 0.5), (4, 1), (3, 1), (2, 2), (0, 2)]
    answer = [(5, 1), (4, 0.5), (3, 0.5), (4, 1), (2, 1), (3, 1), (1, 1), (2, 2), (0, 1), (1, 1), (-1, 1), (0, 3)]

    def sea(tr):
        for bar in range(0, 16, 4):
            for d in (0, 2, 4):
                tr.melody(choir, 50, "dorian", [(d, 16)], bar * 4, 0.35)
    return battle(62, "dorian", 140, [0, 6, 5, 6], motif, answer,
                  taiko_a="B.....B.B.....B.", taiko_b="B..B..B.B..B..BB", frame="F.kkF.kkF.kkF.kk", extra=sea)


def rome():
    # 羅馬：C 自然小調，進行曲：小鼓滾、銅管主奏，最莊嚴的最後一站
    motif = [(0, 1), (0, 0.5), (0, 0.5), (2, 1), (4, 1), (5, 2), (4, 1), (2, 1), (3, 1), (2, 0.5), (1, 0.5), (0, 2), (None, 2)]
    answer = [(4, 1), (4, 0.5), (4, 0.5), (5, 1), (7, 1), (6, 2), (4, 2), (5, 1), (4, 1), (3, 1), (1, 1), (0, 4)]

    def march(tr):
        for bar in range(2, 16):
            for beat in range(4):
                tr.put(bar * 4 + beat, brass(hz(deg(48, "aeolian", [0, 5, 3, 4][bar % 4])), tr.beat * 0.5), 0.6)
    return battle(60, "aeolian", 120, [0, 5, 3, 4], motif, answer, lead=brass,
                  taiko_a="B.......B.......", taiko_b="B...B...B...B.B.", frame="F.kkF.kkF.kkF.k.", extra=march)


def patmos():
    # 拔摩海島：B 弗里吉亞，神秘的異象：號筒（銅管）宣告、合唱長音、鼓像遠處的雷聲（啟 8:6 七位天使拿著七枝號）
    motif = [(0, 2), (1, 1), (0, 1), (4, 2), (3, 1), (1, 1), (0, 1), (1, 1), (3, 1), (4, 1), (5, 2), (4, 2)]
    answer = [(7, 1), (5, 1), (4, 2), (3, 1), (1, 1), (0, 2), (1, 1), (0, 1), (-1, 2), (0, 4)]

    def vision(tr):
        for bar in range(0, 16, 2):
            for d in (0, 4):
                tr.melody(choir, 59, "phrygian", [([0, 1, 5, 0][(bar // 2) % 4] + d, 8)], bar * 4, 0.45)
            tr.put(bar * 4, drone(hz(47), tr.beat * 8), 0.5)
        for bar in range(4, 16, 4):
            for i in range(3):
                tr.put(bar * 4 + i * 0.5, brass(hz(deg(59, "phrygian", 4)), tr.beat * 0.4), 0.7)
    return battle(59, "phrygian", 112, [0, 1, 5, 0], motif, answer, lead=brass,
                  taiko_a="B.......B...B...", taiko_b="B..B....B.BB..B.", frame="F...k...F...k.kk", extra=vision)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]   # 只產生指定的曲子：python tools/make_music.py athens rome
    for name, fn in [("camp", camp), ("philippi", philippi), ("thessalonica", thessalonica), ("corinth", corinth),
                     ("ephesus", ephesus), ("athens", athens), ("jerusalem", jerusalem), ("malta", malta), ("rome", rome), ("patmos", patmos),
                     ("boss", boss), ("fever", fever)]:
        if only and name not in only:
            continue
        save(name, fn())
    old = os.path.join(OUT, "music_battle.ogg")
    if os.path.exists(old):
        os.remove(old)
