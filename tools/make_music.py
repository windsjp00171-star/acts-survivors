"""產生遊戲配樂：中東古風（全部用程式合成，沒有外部素材）。

用法：python tools/make_music.py   （需要 numpy 和 ffmpeg）
輸出：assets/audio/music_*.ogg，每首都可以無縫循環。

樂器：烏德琴（oud）、卡農琴（qanun）、奈伊笛（ney）、達布卡鼓（doum／tek）、框鼓、持續低音、合唱。
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
    "hijaz":    [0, 1, 4, 5, 7, 8, 10],    # 弗里吉亞屬音階，最有中東味
    "nahawand": [0, 2, 3, 5, 7, 8, 11],    # 和聲小調
    "kurd":     [0, 1, 3, 5, 7, 8, 10],    # 弗里吉亞，比較暗
    "rast":     [0, 2, 4, 5, 7, 9, 11],    # 大調（不用四分之一音的簡化）
    "dorian":   [0, 2, 3, 5, 7, 9, 10],
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
def oud(f, sec, vel=1.0):
    """烏德琴：低泛音飽滿、起音稍微往下滑，兩條弦微微走音（成對的弦）"""
    t = ta(sec)
    bend = 1 + 0.012 * np.exp(-t * 40)
    y = np.zeros_like(t)
    for detune in (0.0, 0.35):
        ph = 2 * np.pi * np.cumsum((f + detune) * bend) / SR
        for k, a in [(1, 1.0), (2, 0.7), (3, 0.45), (4, 0.25), (5, 0.12), (6, 0.06)]:
            y += a * np.sin(k * ph) * np.exp(-t * (2.2 + k * 1.6))
    att = np.clip(t / 0.004, 0, 1)
    return y * att * vel * 0.35


def qanun(f, sec, vel=1.0):
    """卡農琴：比較亮、衰減快"""
    t = ta(sec)
    y = np.zeros_like(t)
    for k, a in [(1, 1.0), (2, 0.5), (3, 0.5), (4, 0.3), (5, 0.25), (7, 0.1)]:
        y += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (4 + k * 2.5))
    return y * np.clip(t / 0.002, 0, 1) * vel * 0.3


def ney(f, sec, vel=1.0):
    """奈伊笛：氣音、慢起音、顫音"""
    t = ta(sec)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    n = len(t)
    breath = NOISE_HP[:n] if n <= len(NOISE_HP) else np.resize(NOISE_HP, n)
    env = np.clip(t / 0.09, 0, 1) * np.clip((sec - t) / 0.12, 0, 1)
    return (tone * 0.8 + breath * 0.12) * env * vel * 0.28


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
                sec = dur * self.beat * (1.05 if inst is ney or inst is choir else 1.6)
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
def camp():
    # 營地：慢、溫暖。D 多利安，奈伊笛主奏、烏德琴分解和弦、輕輕的框鼓
    tr = Track(bpm=66, bars=16)
    root = 62
    tr.put(0, drone(hz(38), tr.length / SR + 2), 0.8)
    tr.drums("F.......F...k...", KIT, 0.5)
    a = [(4, 1.5), (3, 0.5), (2, 1), (1, 1), (2, 3), (None, 1)]
    b = [(2, 1), (3, 1), (4, 1), (6, 1), (5, 2), (4, 1), (3, 1)]
    c = [(4, 1.5), (5, 0.5), (4, 1), (3, 1), (2, 1), (1, 1), (0, 2)]
    pos = 8.0
    for phrase in [a, b, a, c, b, c]:
        pos = tr.melody(ney, root, "dorian", phrase, pos, 0.9)
        pos += 0.0
    for bar in range(16):
        base = [0, 0, 3, 4][bar % 4]
        for i, d in enumerate([0, 4, 7, 4]):
            tr.melody(oud, root - 12, "dorian", [(base + d, 1)], bar * 4 + i, 0.55)
    return tr.render()


def city(root, mode, bpm, drum, motif, answer, lead=oud, extra=None, drone_note=None):
    tr = Track(bpm=bpm, bars=20)
    tr.put(0, drone(hz(drone_note or root - 24), tr.length / SR + 2), 1.0)
    tr.drums(drum, KIT, 0.8)
    # 前 4 小節只有鼓和低音，之後旋律進來（主題 → 回應 → 主題 → 變奏）
    pos = 16.0
    for phrase in [motif, answer, motif, [(d + 2 if d is not None else None, l) for d, l in answer]]:
        pos = tr.melody(lead, root, mode, phrase, pos, 1.0)
    # 卡農琴的快速裝飾音型
    for bar in range(4, 20, 2):
        for i in range(8):
            tr.melody(qanun, root + 12, mode, [([0, 1, 2, 1, 0, -1, 0, 2][i], 0.5)], bar * 4 + i * 0.5, 0.35)
    if extra:
        extra(tr)
    return tr.render()


def philippi():
    maqsum = "D..T..T.D...T..."   # 中東最常見的節奏型「麥格蘇姆」
    motif = [(0, 1), (1, 0.5), (2, 0.5), (3, 1), (2, 0.5), (1, 0.5), (0, 2), (None, 2), (4, 1), (3, 1), (2, 1), (1, 1), (0, 4)]
    answer = [(4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (3, 1.5), (2, 0.5), (1, 2), (2, 1), (1, 1), (0, 2), (-1, 2), (0, 2)]
    return city(62, "hijaz", 100, maqsum, motif, answer)


def thessalonica():
    # 暴動：比較快、鼓比較密
    malfuf = "D..T..T.D..T.kT."
    motif = [(0, 0.5), (0, 0.5), (1, 0.5), (2, 0.5), (3, 1), (4, 1), (3, 0.5), (2, 0.5), (1, 1), (0, 2), (4, 0.5), (4, 0.5), (5, 1), (4, 1), (3, 1), (2, 1), (1, 1), (0, 2)]
    answer = [(7, 1), (6, 0.5), (5, 0.5), (4, 1), (3, 1), (4, 0.5), (3, 0.5), (2, 1), (1, 2), (2, 0.5), (3, 0.5), (2, 1), (1, 1), (0, 1), (-1, 1), (0, 2)]

    def stomp(tr):
        tr.drums("D...D...D...D.D.", KIT, 0.35)
    return city(64, "hijaz", 112, malfuf, motif, answer, extra=stomp)


def corinth():
    # 港口城市：和聲小調，奈伊笛主奏，比較抒情但不安
    saidi = "D..TD...T..T...."
    motif = [(4, 2), (3, 1), (2, 1), (3, 1.5), (2, 0.5), (1, 1), (2, 1), (0, 4), (None, 1), (2, 1), (3, 1), (4, 1), (5, 2), (4, 2)]
    answer = [(6, 1.5), (5, 0.5), (4, 1), (3, 1), (2, 2), (3, 1), (2, 1), (1, 1), (0, 1), (-1, 2), (0, 4)]

    def oud_bass(tr):
        for bar in range(20):
            tr.melody(oud, 57 - 12, "nahawand", [(0, 1.5), (4, 0.5), (3, 1), (2, 1)], bar * 4, 0.55)
    return city(57, "nahawand", 104, saidi, motif, answer, lead=ney, extra=oud_bass)


def ephesus():
    # 亞底米的城：暗、低沉的人聲持續、慢一點但重
    ayoub = "D..kD.T.D..kD.T."
    motif = [(0, 2), (1, 1), (0, 1), (-1, 2), (0, 2), (3, 2), (2, 1), (1, 1), (0, 4)]
    answer = [(4, 1), (3, 1), (4, 1), (5, 1), (4, 2), (3, 1), (1, 1), (2, 2), (1, 1), (0, 1), (0, 4)]

    def chant(tr):
        for bar in range(0, 20, 2):
            d = [0, 0, 3, 1, 0, 0, -2, 0, 3, 0][bar // 2]
            tr.melody(choir, 60 - 12, "kurd", [(d, 8)], bar * 4, 0.8)
    return city(60, "kurd", 96, ayoub, motif, answer, extra=chant, drone_note=36)


def boss():
    tr = Track(bpm=124, bars=8)
    root = 62
    tr.put(0, drone(hz(38), tr.length / SR + 2), 1.4)
    tr.drums("D.DTD.T.D.DTD.TT", KIT, 0.95)
    tr.drums("F...F...F...F.F.", KIT, 0.5)
    riff = [(0, 0.5), (1, 0.5), (0, 0.5), (-1, 0.5), (0, 1), (None, 1)]
    for bar in range(8):
        shift = [0, 0, 1, 0, 0, 0, 3, 2][bar]
        tr.melody(oud, root - 12, "hijaz", [(d + shift if d is not None else None, l) for d, l in riff], bar * 4, 1.0)
    hi = [(4, 1), (5, 1), (4, 1), (3, 1), (2, 2), (1, 2), (4, 1), (5, 1), (7, 2), (5, 2), (4, 2)]
    tr.melody(qanun, root + 12, "hijaz", hi, 16, 0.7)
    return tr.render()


def fever():
    # 五旬節：明亮的大調，合唱、拍手、快節奏
    tr = Track(bpm=128, bars=8)
    root = 62
    tr.put(0, drone(hz(50), tr.length / SR + 2), 0.6)
    tr.drums("D...T.D.D...T.k.", KIT, 0.8)
    tr.drums("....C.......C...", KIT, 0.9)
    for bar in range(0, 8, 2):
        chord = [[0, 2, 4], [3, 5, 7], [4, 6, 8], [0, 2, 4]][bar // 2]
        for d in chord:
            tr.melody(choir, root, "rast", [(d, 8)], bar * 4, 0.55)
    tune = [(4, 1), (4, 0.5), (5, 0.5), (6, 1), (4, 1), (7, 2), (6, 1), (5, 1), (4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (4, 4)]
    tr.melody(qanun, root + 12, "rast", tune, 0, 0.9)
    tr.melody(qanun, root + 12, "rast", tune, 16, 0.9)
    return tr.render()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("camp", camp), ("philippi", philippi), ("thessalonica", thessalonica), ("corinth", corinth),
                     ("ephesus", ephesus), ("boss", boss), ("fever", fever)]:
        save(name, fn())
    old = os.path.join(OUT, "music_battle.ogg")
    if os.path.exists(old):
        os.remove(old)
