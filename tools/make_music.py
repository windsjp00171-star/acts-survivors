"""產生遊戲配樂：希臘羅馬史詩風（全部用程式合成，沒有外部素材）。

用法：python tools/make_music.py [曲名 ...]   （需要 numpy、scipy 和 ffmpeg）
輸出：assets/audio/music_*.ogg，每首都可以無縫循環。

- 32kHz 立體聲：每種樂器有自己的左右位置，合唱與弦樂比較寬；每一層都加一點殘響（像在石造的大廳裡）。
- 關卡曲分成三層（_perc 鼓、_harm 低音與伴奏、_top 旋律、銅管、合唱），遊戲裡同步播放，
  依戰況調每一層的音量（sfx.gd 的 set_intensity）。營地、標題、過場是單一檔案。
- 曲式：前奏 2 小節 → A 主題 → B 銅管與主題高八度 → C 段（聖詩旋律或「宣教之路」主題，鼓變少）→ A' 全團。
- 「宣教之路」主題（THEME）在標題、營地、過場、每一章的 C 段都會出現，用各章自己的調式。
- 聖詩旋律只用 1929 年以前、已是公版的曲調，而且只用旋律、不用歌詞：
  歡樂頌（貝多芬 1824）、以馬內利來臨（VENI EMMANUEL，15 世紀）、耶穌愛我（Bradbury 1862）、
  奇異恩典（NEW BRITAIN，1835）、讚美真神萬福之源（OLD HUNDREDTH，1551）。
樂器：阿洛斯雙管（aulos）、基薩拉琴（kithara）、羅馬銅管、戰鼓、框鼓、弦樂斷奏、低音、合唱。
"""
import os
import subprocess
import wave

import numpy as np
from scipy.signal import lfilter

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RNG = np.random.default_rng(11)

# 調式（相對主音的半音）
MODES = {
    "rast":     [0, 2, 4, 5, 7, 9, 11],    # 大調
    "dorian":   [0, 2, 3, 5, 7, 9, 10],
    "aeolian":  [0, 2, 3, 5, 7, 8, 10],    # 自然小調
    "phrygian": [0, 1, 3, 5, 7, 8, 10],    # 弗里吉亞（古希臘調式，沒有增二度）
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
}
# 每個調式裡「同一組音的大調」的主音在第幾級（聖詩旋律用大調唱，和聲仍在同一組音裡）
REL_MAJOR = {"rast": 0, "dorian": -1, "aeolian": 2, "phrygian": -2, "mixolydian": 3}

# 「宣教之路」主題：往上走、停一下、再往更高處去（大調級數，0 是主音）
THEME = [(0, 1), (2, 1), (4, 2), (5, 1), (4, 1), (2, 1), (4, 1), (7, 4),
         (6, 1), (5, 1), (4, 1), (5, 1), (4, 1), (2, 1), (1, 1), (2, 1), (0, 4),
         (4, 1), (7, 1), (9, 2), (8, 1), (7, 1), (5, 2), (7, 4)]

# 公版聖詩旋律（大調級數；minor=True 的是小調級數）
HYMNS = {
    # 歡樂頌（HYMN TO JOY）
    "joy": [(2, 1), (2, 1), (3, 1), (4, 1), (4, 1), (3, 1), (2, 1), (1, 1), (0, 1), (0, 1), (1, 1), (2, 1), (2, 1.5), (1, 0.5), (1, 2),
            (2, 1), (2, 1), (3, 1), (4, 1), (4, 1), (3, 1), (2, 1), (1, 1), (0, 1), (0, 1), (1, 1), (2, 1), (1, 1.5), (0, 0.5), (0, 2)],
    # 以馬內利來臨（VENI EMMANUEL），小調
    "emmanuel": [(0, 1), (2, 1), (4, 1), (4, 1), (4, 1), (3, 1), (5, 1), (4, 1), (3, 1), (2, 3),
                 (3, 1), (4, 1), (2, 1), (0, 1), (2, 1), (3, 1), (1, 1), (0, 1), (-1, 1), (0, 3)],
    # 耶穌愛我
    "jesusloves": [(4, 1), (2, 1), (2, 1), (1, 1), (2, 1), (4, 1), (4, 2), (5, 1), (5, 1), (7, 1), (5, 1), (5, 1), (4, 1), (4, 2),
                   (4, 1), (2, 1), (2, 1), (1, 1), (2, 1), (4, 1), (4, 2), (5, 1), (5, 1), (4, 1), (0, 1), (2, 1), (1, 1), (0, 2)],
    # 奇異恩典（NEW BRITAIN）
    "grace": [(-3, 1), (0, 2), (2, 0.5), (0, 0.5), (2, 2), (1, 1), (0, 2), (-2, 1), (-3, 2), (-3, 1), (0, 2), (2, 0.5), (0, 0.5), (2, 2), (1, 1), (4, 5),
              (2, 1), (4, 2), (2, 0.5), (4, 0.5), (2, 2), (0, 1), (-3, 2), (-2, 0.5), (0, 0.5), (0, 2), (-2, 1), (-3, 2), (-3, 1), (0, 2), (2, 0.5), (0, 0.5), (2, 2), (1, 1), (0, 4)],
    # 讚美真神萬福之源（OLD HUNDREDTH）
    "doxology": [(0, 2), (0, 1), (-1, 1), (-2, 1), (-3, 1), (0, 1), (1, 1), (2, 2), (None, 2),
                 (2, 2), (2, 1), (2, 1), (1, 1), (0, 1), (3, 1), (2, 1), (1, 2), (None, 2),
                 (0, 2), (1, 1), (2, 1), (1, 1), (0, 1), (-2, 1), (-1, 1), (0, 2), (None, 2),
                 (-3, 2), (2, 1), (0, 1), (1, 1), (3, 1), (2, 1), (1, 1), (0, 2), (None, 2)],
}
MINOR_HYMNS = {"emmanuel"}


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
    return lfilter([a], [1, -(1 - a)], x)


NOISE = RNG.standard_normal(SR * 2)
NOISE_LP = lowpass(NOISE, 0.08)
NOISE_HP = NOISE - lowpass(NOISE, 0.35)


def _noise(arr, n):
    return arr[:n] if n <= len(arr) else np.resize(arr, n)


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
            if fk > SR * 0.45:
                break
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


def strings(f, sec, vel=1.0):
    """弦樂長音（C 段的鋪底）：慢慢進來，幾把微微走音"""
    t = ta(sec)
    y = sum(_saw(f * d, t, 8) for d in (0.997, 1.0, 1.004))
    y = lowpass(y, 0.12)
    env = np.clip(t / 0.5, 0, 1) * np.clip((sec - t) / 0.5, 0, 1)
    return y * env * vel * 0.07


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
    breath = _noise(NOISE_HP, len(t))
    env = np.clip(t / 0.03, 0, 1) * np.clip((sec - t) / 0.08, 0, 1)
    return (y + breath * 0.15) * env * vel * 0.26


def kithara(f, sec, vel=1.0):
    """基薩拉（古希臘里拉琴）：明亮、有共鳴的撥弦"""
    t = ta(sec)
    y = np.zeros_like(t)
    for k, a in [(1, 1.0), (2, 0.6), (3, 0.4), (4, 0.3), (5, 0.18), (6, 0.1)]:
        y += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (2.5 + k * 1.8))
    return y * np.clip(t / 0.002, 0, 1) * vel * 0.3


def ney(f, sec, vel=1.0):
    """奈伊笛（中東的蘆葦笛）：氣聲很多、音色空，滑音進來"""
    t = ta(sec)
    glide = 1 - 0.03 * np.exp(-t * 18)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * glide * vib) / SR
    y = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    breath = lowpass(_noise(NOISE_HP, len(t)), 0.3) * 0.5
    env = np.clip(t / 0.08, 0, 1) * np.clip((sec - t) / 0.12, 0, 1)
    return (y + breath) * env * vel * 0.2


def oud(f, sec, vel=1.0):
    """烏德琴（中東的短頸琵琶）：低沉、溫暖、撥得重，雙弦微微走音"""
    t = ta(min(sec, 1.6))
    y = np.zeros_like(t)
    for det in (1.0, 1.003):
        for k, a in [(1, 1.0), (2, 0.8), (3, 0.45), (4, 0.3), (5, 0.15), (6, 0.08)]:
            y += a * np.sin(2 * np.pi * f * det * k * t) * np.exp(-t * (3 + k * 2.0))
    pick = lowpass(_noise(NOISE_HP, len(t)), 0.4) * np.exp(-t * 200) * 0.5
    return lowpass(y + pick, 0.3) * np.clip(t / 0.002, 0, 1) * vel * 0.2


def harp(f, sec, vel=1.0):
    """琴（大衛彈的 kinnor）：柔和的撥弦，餘音長"""
    t = ta(min(sec, 2.5))
    y = sum(a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (1.2 + k * 1.1)) for k, a in [(1, 1.0), (2, 0.35), (3, 0.15), (4, 0.06)])
    return y * np.clip(t / 0.003, 0, 1) * vel * 0.24


def shofar(f, sec, vel=1.0):
    """羊角號：粗、往上滑一點，五度與八度的呼喊"""
    t = ta(sec)
    glide = 1 - 0.06 * np.exp(-t * 8)
    ph = 2 * np.pi * np.cumsum(f * glide) / SR
    y = sum(np.sin(k * ph) / k ** 0.8 for k in range(1, 9) if f * k < 7000)
    env = np.clip(t / 0.06, 0, 1) * np.clip((sec - t) / 0.15, 0, 1)
    return lowpass(y, 0.18) * env * vel * 0.12


def piano(f, sec, vel=1.0):
    """鋼琴：每個泛音各自衰減（高的衰得快），弦有一點不和諧（inharmonic），加一點敲槌的聲音"""
    sec = min(sec, 6.0)
    t = ta(sec)
    y = np.zeros_like(t)
    B = 0.0004
    for k in range(1, 14):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > SR * 0.45:
            break
        amp = (1.0 / k) * (0.55 if k == 1 else 1.0) * (1.0 + 0.4 * vel * (k > 3))
        y += amp * np.sin(2 * np.pi * fk * t + k * 0.7) * np.exp(-t * (0.6 + 0.35 * k) * (f / 400) ** 0.3)
    y += 0.25 * _noise(NOISE_HP, len(t)) * np.exp(-t * 60)          # 敲槌
    env = np.clip(t / 0.004, 0, 1) * np.clip((sec - t) / 0.25, 0, 1)
    return lowpass(y, 0.35 + 0.25 * vel) * env * vel * 0.16


def pad(f, sec, vel=1.0):
    """溫暖的鋪底：幾條微微走音的鋸齒波，濾得很柔，慢慢進來慢慢走"""
    t = ta(sec)
    y = sum(_saw(f * d, t, 10) for d in (0.993, 0.998, 1.0, 1.003, 1.008))
    y = lowpass(lowpass(y, 0.05), 0.08)
    env = np.clip(t / 1.4, 0, 1) * np.clip((sec - t) / 1.6, 0, 1)
    return y * env * vel * 0.05


def cello(f, sec, vel=1.0):
    """大提琴：有揉弦的鋸齒波，聲音比 strings 集中"""
    t = ta(sec)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.6, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    y = sum(np.sin(k * ph) / k ** 1.1 for k in range(1, 12) if f * k < 6000)
    y = lowpass(y, 0.09)
    env = np.clip(t / 0.25, 0, 1) * np.clip((sec - t) / 0.4, 0, 1)
    return y * env * vel * 0.09


def bell(f, sec, vel=1.0):
    """鐘琴：幾個不和諧的泛音，亮、衰得慢"""
    t = ta(min(sec, 4.0))
    y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d) for r, a, d in ((1, 1, 1.2), (2.76, 0.4, 2.5), (5.4, 0.2, 4.0), (8.9, 0.1, 6.0)))
    return y * np.clip(t / 0.002, 0, 1) * vel * 0.07


def timp(vel=1.0):
    """定音鼓的輕滾：一陣慢慢變大的低鼓"""
    t = ta(3.0)
    roll = np.zeros_like(t)
    for i in range(36):
        s = int(i * 0.07 * SR)
        n = len(t) - s
        hit = np.sin(2 * np.pi * 73 * t[:n]) * np.exp(-t[:n] * 5) * (i / 36) ** 1.6
        roll[s:] += hit[:n]
    return lowpass(roll, 0.2) * vel * 0.18


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


# ---- 台灣（府城 1865）：北管的鑼鼓、殼仔弦、月琴、嗩吶 ----
def kexian(f, sec, vel=1.0):
    """殼仔弦（椰殼胡琴）：拉弦的鋸齒波、鼻音很重的共振峰；每個音從下面滑上來，慢慢加上揉弦"""
    t = ta(sec)
    scoop = 1 - 0.06 * np.exp(-t / 0.035)
    vib = 1 + 0.009 * np.sin(2 * np.pi * 5.8 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * scoop * vib) / SR
    y = np.zeros_like(t)
    for k in range(1, 16):
        fk = f * k
        if fk > 7500:
            break
        w = (np.exp(-((fk - 1100) / 380) ** 2) * 1.4 + np.exp(-((fk - 2600) / 500) ** 2) * 0.6 + 0.35) / k ** 0.6
        y += w * np.sin(k * ph)
    bow = _noise(NOISE_HP, len(t)) * 0.04
    env = np.clip(t / 0.04, 0, 1) * (0.85 + 0.15 * np.clip(t / 0.3, 0, 1)) * np.clip((sec - t) / 0.08, 0, 1)
    return (y + bow) * env * vel * 0.11


def yueqin(f, sec, vel=1.0):
    """月琴：兩條同音的弦、亮而短的撥弦，帶一點金屬的泛音"""
    t = ta(min(sec, 1.2))
    y = np.zeros_like(t)
    for det in (1.0, 1.004):
        for k, a in [(1, 1.0), (2, 0.7), (3, 0.5), (4, 0.35), (5, 0.25), (6, 0.15), (8, 0.08)]:
            y += a * np.sin(2 * np.pi * f * det * k * t) * np.exp(-t * (4 + k * 2.5))
    pick = _noise(NOISE_HP, len(t)) * np.exp(-t * 300) * 0.4
    return (y + pick) * np.clip(t / 0.001, 0, 1) * vel * 0.17


def suona(f, sec, vel=1.0):
    """嗩吶：很亮、很衝的雙簧，起音往上推，長音有揉音"""
    t = ta(sec)
    scoop = 1 - 0.04 * np.exp(-t / 0.03)
    vib = 1 + 0.008 * np.sin(2 * np.pi * 6.2 * t) * np.clip((t - 0.2) / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * scoop * vib) / SR
    y = np.zeros_like(t)
    for k in range(1, 20):
        fk = f * k
        if fk > 9000:
            break
        w = (np.exp(-((fk - 1500) / 600) ** 2) + 0.8 * np.exp(-((fk - 3200) / 700) ** 2) + 0.2) / k ** 0.35
        y += w * np.sin(k * ph)
    env = np.clip(t / 0.02, 0, 1) * np.clip((sec - t) / 0.06, 0, 1)
    return np.tanh(y * 0.5) * env * vel * 0.16


def _metal(freqs, sec, decay, glide=0.0):
    t = ta(sec)
    y = np.zeros_like(t)
    for i, (fr, a) in enumerate(freqs):
        g = 1 + glide * (1 - np.exp(-t * 6))
        y += a * np.sin(2 * np.pi * np.cumsum(np.full_like(t, fr) * g) / SR + i) * np.exp(-t * decay * (1 + i * 0.15))
    return y


def xiaoluo(vel=1.0):
    """小鑼「噹」：打下去音會往上飄"""
    y = _metal([(780, 1.0), (1650, 0.4), (2470, 0.25)], 0.5, 7, glide=0.12)
    return y * vel * 0.22


def daluo(vel=1.0):
    """大鑼「匡」：低沉、很長，音往下沉"""
    t = ta(1.4)
    y = _metal([(165, 1.0), (243, 0.6), (371, 0.45), (529, 0.3), (812, 0.2)], 1.4, 2.2, glide=-0.06)
    hit = NOISE_LP[: len(t)] * np.exp(-t * 30) * 1.5
    return (y + hit) * vel * 0.32


def bo(vel=1.0):
    """鈸「鏘」：亮的金屬雜訊"""
    t = ta(0.7)
    n = _noise(NOISE_HP, len(t))
    shimmer = _metal([(3100, 0.3), (4700, 0.2), (5900, 0.15)], 0.7, 5)
    return (n * np.exp(-t * 6) * 0.6 + shimmer) * vel * 0.2


def bangu(vel=1.0):
    """板鼓：又高又乾的一下（帶頭打拍子的鼓）"""
    t = ta(0.12)
    f = 420 + 200 * np.exp(-t * 60)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 40) * vel * 0.5


def tonggu(vel=1.0):
    """通鼓：低一點的鼓"""
    t = ta(0.4)
    f = 110 + 80 * np.exp(-t * 25)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    return (body + NOISE_LP[: len(t)] * np.exp(-t * 40)) * vel * 0.7


def paiban(vel=1.0):
    """拍板：木頭「喀」"""
    t = ta(0.05)
    return (np.sin(2 * np.pi * 1900 * t) + 0.6 * np.sin(2 * np.pi * 3100 * t)) * np.exp(-t * 120) * vel * 0.35


KIT = {"D": doum, "T": tek, "k": ka, "F": daf, "C": clap, "B": taiko, "S": snare, "h": shaker,
       "x": xiaoluo, "G": daluo, "c": bo, "b": bangu, "t": tonggu, "w": paiban}
# 樂器的左右位置（-1 左、1 右）與寬度（右聲道晚幾毫秒，聽起來比較開）
PAN = {doum: 0.0, tek: 0.35, ka: 0.35, daf: -0.35, clap: 0.2, taiko: 0.0, snare: 0.12, shaker: 0.45,
       xiaoluo: 0.3, daluo: -0.1, bo: 0.2, bangu: -0.25, tonggu: 0.0, paiban: 0.4,
       kexian: 0.1, yueqin: -0.3, suona: 0.0,
       bass: 0.0, spic: 0.35, strings: 0.0, brass: -0.15, aulos: 0.05, kithara: -0.3, choir: 0.0, drone: 0.0}
WIDTH = {choir: 14, strings: 11, drone: 9, brass: 4, daluo: 6, kexian: 3}
PAN.update({piano: -0.2, pad: 0.0, cello: 0.25, bell: 0.35, ney: 0.1, oud: -0.3, harp: -0.35, shofar: -0.1})
WIDTH.update({pad: 13, piano: 6, cello: 5, bell: 4})


# ---------- 殘響 ----------
def reverb(st, amount):
    """簡化的 Freeverb：四組梳狀濾波＋兩組全通，左右聲道的延遲略不同（石造大廳）"""
    if amount <= 0:
        return st
    out = np.zeros_like(st)
    pre = int(SR * 0.02)
    for ch in range(2):
        x = np.concatenate([np.zeros(pre), st[ch]])[: st.shape[1]]
        x = lowpass(x, 0.35)
        sp = 17 * ch
        wet = np.zeros_like(x)
        for d in (1116, 1188, 1277, 1356):
            D = int((d + sp) * SR / 44100)
            a = np.zeros(D + 1)
            a[0], a[D] = 1.0, -0.82
            wet += lfilter([1.0], a, x)
        for d in (556, 441):
            D = int((d + sp) * SR / 44100)
            b = np.zeros(D + 1)
            b[0], b[D] = -0.5, 1.0
            a = np.zeros(D + 1)
            a[0], a[D] = 1.0, -0.5
            wet = lfilter(b, a, wet)
        out[ch] = st[ch] + wet * amount * 0.12
    return out


# ---------- 編曲 ----------
class Track:
    """三層立體聲的譜：perc 鼓、harm 低音與伴奏、top 旋律與銅管、合唱。put 之前設 self.layer。"""
    LAYERS = ("perc", "harm", "top")

    def __init__(self, bpm, bars, beats_per_bar=4):
        self.beat = 60.0 / bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.length = int(SR * self.beat * beats_per_bar * bars)
        self.bufs = {k: np.zeros((2, self.length + SR * 5)) for k in self.LAYERS}
        self.layer = "top"

    def put(self, at_beat, sound, gain=1.0, inst=None, layer=None):
        s = int(at_beat * self.beat * SR)
        buf = self.bufs[layer or self.layer]
        n = min(len(sound), buf.shape[1] - s)
        if n <= 0:
            return
        p = PAN.get(inst, 0.0)
        gl, gr = np.cos((p + 1) * np.pi / 4) * 1.41, np.sin((p + 1) * np.pi / 4) * 1.41
        buf[0, s:s + n] += sound[:n] * gain * gl
        w = int(WIDTH.get(inst, 0) * SR / 1000)
        n2 = min(len(sound), buf.shape[1] - s - w)
        buf[1, s + w:s + w + n2] += sound[:n2] * gain * gr

    def hit(self, at_beat, ch, vel=1.0, gain=1.0):
        fn = KIT[ch]
        self.put(at_beat, fn(vel), gain, fn, "perc")

    def note(self, inst, at_beat, f, sec, gain=1.0, vel=1.0):
        self.put(at_beat, inst(f, sec, vel), gain, inst)

    def drums(self, pattern, gain=1.0, bars=range(0)):
        """pattern 每個字元是一個十六分音符：D 低鼓 T 高鼓 k 輕敲 F 框鼓 C 拍手 B 大鼓 S 小鼓 h 沙鈴 . 休止"""
        for bar in bars:
            for i, ch in enumerate(pattern):
                if ch != ".":
                    self.hit(bar * self.bpb + i / 4, ch, 0.85 + 0.15 * RNG.random(), gain)

    def melody(self, inst, root, mode, notes, start=0.0, gain=1.0, octave=0, legato=None):
        """notes: [(級數, 拍數)]，級數 None 是休止"""
        pos = start
        lg = legato if legato is not None else (1.05 if inst in (aulos, choir, strings, brass) else 1.6)
        for d, dur in notes:
            if d is not None:
                self.note(inst, pos, hz(deg(root, mode, d) + 12 * octave), dur * self.beat * lg, gain)
            pos += dur
        return pos

    def render(self, rev=None):
        rev = rev or {"perc": 0.6, "harm": 1.0, "top": 1.4}
        out = {}
        n = self.length
        for k, b in self.bufs.items():
            b = reverb(b, rev[k])
            y = b[:, :n].copy()
            tail = b[:, n:]
            y[:, : tail.shape[1]] += tail          # 尾巴折回開頭：循環時餘音接得上
            out[k] = y
        return out


def beats(notes):
    return sum(d for _, d in notes)


def _write_ogg(path, y, q, mono=False):
    tmp = path + ".wav"
    if mono:
        y = y.mean(axis=0, keepdims=True)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1 if mono else 2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(y.T, -1, 1) * 32767).astype(np.int16).tobytes())
    rate = ["-ar", "22050"] if mono else []     # 鼓層：取樣率也降一點（檔案小三成，疊在底下聽不出來）
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp] + rate + ["-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)


def save(name, layers, stems=True, target_db=-19.0):
    """每首調到一樣的平均音量（切歌時不會忽大忽小）；分層的話三層用同一個增益（疊起來就是完整的曲子）"""
    full = sum(layers.values())
    rms = np.sqrt((full ** 2).mean()) + 1e-9
    g = 10 ** (target_db / 20) / rms
    peak = np.abs(full).max() * g
    if peak > 0.97:
        g *= 0.97 / peak          # 最大音量不破音（之後再柔性限幅）
    for f in os.listdir(OUT):
        if f.startswith("music_%s." % name) or f.startswith("music_%s_" % name) and f.split("_")[-1].split(".")[0] in Track.LAYERS:
            if f.endswith(".ogg"):
                os.remove(os.path.join(OUT, f))
    if stems:
        for k, y in layers.items():
            # 鼓層大多是雜訊、檔案最大：用單聲道、品質低一級（疊在其他層底下聽不出差別）
            _write_ogg(os.path.join(OUT, "music_%s_%s.ogg" % (name, k)), np.tanh(y * g * 1.1) / 1.1,
                       -1 if k == "perc" else 0, k == "perc")
    else:
        _write_ogg(os.path.join(OUT, "music_%s.ogg" % name), np.tanh(full * g * 1.1) / 1.1, 1)
    print("music_%s%s  %.1f 秒" % (name, "（三層）" if stems else "", full.shape[1] / SR))


# ---------- 曲目 ----------
def battle(root, mode, bpm, prog, motif, answer, lead=aulos, taiko_a="B.......B..B....", taiko_b="B..B..B.B..B.B..",
           frame="F...k.k.F...k...", extra=None, quote="theme", region="greek"):
    """戰鬥曲：前奏 2 小節 → A 8 小節 → B 8 小節 → C 段（聖詩或主題，鼓變少）→ A' 8 小節。可循環。
    region 決定配器（每一關聽起來要不一樣）：
      judea  猶太地：羊角號、琴（kinnor）、框鼓，沒有軍鼓和沙鈴
      levant 敘利亞（大馬色、安提阿）：烏德琴、奈伊笛、中東手鼓
      greek  希臘：基薩拉琴、阿洛斯、弦樂斷奏（原本的配器）
      rome   羅馬：銅管、軍鼓、大鼓
      sea    海上（約帕、馬爾他）：弦樂顫音、琴、大鼓
      vision 異象（拔摩）：合唱、鐘琴、持續音"""
    R = {"judea": dict(arp=harp, acc=harp, snare=False, shaker=False, brass=shofar),
         "levant": dict(arp=oud, acc=oud, snare=False, shaker=False, brass=ney),
         "greek": dict(arp=kithara, acc=spic, snare=True, shaker=True, brass=brass),
         "rome": dict(arp=kithara, acc=spic, snare=True, shaker=False, brass=brass),
         "sea": dict(arp=harp, acc=strings, snare=False, shaker=True, brass=brass),
         "vision": dict(arp=bell, acc=strings, snare=False, shaker=False, brass=brass)}[region]
    if lead is aulos and region in ("levant", "judea"):
        lead = ney           # 中東與猶太地：蘆葦笛主奏
    big = "D" if region == "levant" else "B"   # 敘利亞用中東低鼓，不用大鼓
    q = HYMNS.get(quote, THEME)
    minor_q = quote in MINOR_HYMNS
    c_bars = int(np.ceil(beats(q) / 4)) + 1
    A, B, C = 2, 10, 18
    A2 = C + c_bars
    total = A2 + 8
    tr = Track(bpm=bpm, bars=total)
    chord = lambda bar: prog[bar % len(prog)]
    # C 段的和聲：聖詩用大調（同一組音的大調 I - IV - V - I），小調聖詩與主題用這首自己的和弦
    rel = REL_MAJOR[mode]
    c_prog = [rel, rel + 3, rel + 4, rel] if quote in HYMNS and not minor_q else prog
    cchord = lambda bar: c_prog[(bar - C) // 2 % len(c_prog)] if quote in HYMNS and not minor_q else chord(bar)
    in_c = lambda bar: C <= bar < A2

    # ---- 鼓 ----
    for bar in range(total):
        if in_c(bar):
            pat = "B..............." if bar % 2 == 0 else "........B......."
        else:
            pat = taiko_a if bar < B or bar >= A2 and bar < A2 + 4 else taiko_b
        for i, ch in enumerate(pat):
            if ch != ".":
                tr.hit(bar * 4 + i / 4, big, 0.85 + 0.15 * RNG.random())
        for i in range(16):
            if R["shaker"] and (not in_c(bar) or i % 4 == 0):
                tr.hit(bar * 4 + i / 4, "h", 1.0 if i % 4 == 0 else 0.6)
        if bar >= A and not in_c(bar) and R["snare"]:
            fill = bar in (B - 1, C - 1, total - 1)
            snare_pat = "....S...S.S.SSSS" if fill else "....S.......S..."
            for i, ch in enumerate(snare_pat):
                if ch == "S":
                    tr.hit(bar * 4 + i / 4, "S", 0.7 + 0.3 * (fill and i >= 8))
        if not in_c(bar):
            for i, ch in enumerate(frame):
                if ch != ".":
                    tr.hit(bar * 4 + i / 4, ch, 0.8, 0.5)
    roll = "S" if R["snare"] else "T"
    for i in range(8):                       # 前奏、C 段結束前：鼓滾（沒有軍鼓的地區用手鼓）
        tr.hit(7 + i / 8, roll, 0.4 + i * 0.08)
        tr.hit((A2 - 1) * 4 + 2 + i / 4, roll, 0.3 + i * 0.09)

    # ---- 低音與伴奏 ----
    tr.layer = "harm"
    for bar in range(A, total):
        c = cchord(bar)
        r = deg(root - 24, mode, c)
        if in_c(bar):
            if bar % 2 == 0:
                tr.note(bass, bar * 4, hz(r), 0.6, 1.0)
                for d in (c, c + 2, c + 4):
                    tr.note(strings, bar * 4, hz(deg(root - 12, mode, d)), tr.beat * 8.2, 1.0)
            continue
        for beat in range(4):
            for off, v in [(0, 1.0), (0.5, 0.7), (0.75, 0.75)]:
                tr.note(bass, bar * 4 + beat + off, hz(r + (12 if beat == 3 and off == 0.75 else 0)), 0.25, 1.0, v)
    for bar in range(A, total):
        c = cchord(bar)
        soft = 0.55 if in_c(bar) else 1.0
        for i in range(16):
            if in_c(bar) and i % 2:
                continue
            d = c + [0, 2, 4, 7, 4, 2, 0, 2][i % 8]
            if R["acc"] is strings:
                if i % 8 == 0:   # 海與異象：弦樂長音代替斷奏
                    tr.note(strings, bar * 4 + i / 4, hz(deg(root - 12, mode, d)), tr.beat * 2.1, soft * 0.9)
                continue
            if R["acc"] is not spic and i % 2:
                continue     # 撥弦樂器：八分音符就好，不要像弦樂那麼密
            tr.note(R["acc"], bar * 4 + i / 4, hz(deg(root - 12, mode, d)), 0.15 if R["acc"] is spic else 0.5, soft, 0.9 if i % 4 == 0 else 0.6)
        for i, d in enumerate([0, 4, 2, 4, 7, 4, 2, 4]):
            tr.note(R["arp"], bar * 4 + i * 0.5, hz(deg(root, mode, c + d)), 0.6, 1.0, 0.55)

    # ---- 旋律、銅管、合唱 ----
    tr.layer = "top"
    for bar in list(range(B, C)) + list(range(A2, total)):
        c = chord(bar)
        for d in ((c, c + 4) if R["brass"] is shofar else (c, c + 2, c + 4)):
            tr.note(R["brass"], bar * 4, hz(deg(root - 12, mode, d)), tr.beat * (1.5 if bar % 2 else 3.5), 0.8 if R["brass"] is not brass else 1.0)
    pos = tr.melody(lead, root, mode, motif, A * 4)
    tr.melody(lead, root, mode, answer, pos)
    pos = tr.melody(lead, root, mode, motif, B * 4, octave=1)
    tr.melody(R["arp"], root, mode, motif, B * 4, 0.7)
    tr.melody(R["brass"], root - 12, mode, answer, pos, 0.8)
    # C 段：聖詩（大調級數放在同一組音的大調上）或主題，阿洛斯主奏、合唱跟著長音
    if minor_q or quote not in HYMNS:
        q_root, q_mode = root, mode
    else:
        q_root, q_mode = deg(root, mode, rel), "rast"
    q_inst = aulos if lead is not aulos or quote in HYMNS else kithara
    tr.melody(q_inst, q_root, q_mode, q, C * 4 + 2, 0.95)
    tr.melody(choir, q_root - 12, q_mode, [(d, dur) for d, dur in q], C * 4 + 2, 0.45, legato=1.0)
    # A'：主題回來，高八度＋銅管齊奏
    pos = tr.melody(lead, root, mode, motif, A2 * 4, octave=1)
    tr.melody(R["brass"], root - 12, mode, motif, A2 * 4, 0.6)
    tr.melody(lead, root, mode, answer, pos)
    if extra:
        extra(tr, total, in_c)
    return tr.render()


def pentecost():
    # 五旬節：G 大調，快、明亮，像一陣大風吹進屋子；C 段是〈歡樂頌〉
    motif = [(0, 0.5), (2, 0.5), (4, 1), (5, 0.5), (4, 0.5), (2, 1), (4, 1), (7, 2), (6, 0.5), (5, 0.5), (4, 1), (2, 1), (0, 2)]
    answer = [(7, 1), (9, 0.5), (7, 0.5), (5, 1), (4, 1), (5, 1), (4, 0.5), (2, 0.5), (4, 2), (2, 1), (1, 1), (0, 4)]
    return battle(67, "rast", 138, [0, 3, 4, 0], motif, answer, lead=kithara,
                  taiko_a="B.......B..B....", taiko_b="B..B..B.B..B.BB.", frame="F.kk.k.kF.kk.k.k", quote="joy", region="judea")


def _pads(chords_root, mode, degs, every, gain):
    """合唱長音：每 every 小節換一個和弦（C 段不唱，讓聖詩出來）"""
    def fn(tr, total, in_c):
        tr.layer = "top"
        for bar in range(0, total, every):
            if in_c(bar):
                continue
            tr.melody(choir, chords_root, mode, [(degs[(bar // every) % len(degs)], every * 4)], bar * 4, gain)
    return fn


def stephen():
    # 司提反：D 自然小調，慢、莊重，合唱很長；C 段是〈以馬內利來臨〉
    motif = [(0, 2), (2, 1), (3, 1), (4, 2), (3, 1), (2, 1), (1, 2), (0, 2)]
    answer = [(4, 1), (5, 1), (7, 2), (6, 1), (5, 1), (4, 2), (3, 1), (2, 1), (0, 4)]
    return battle(62, "aeolian", 108, [0, 3, 5, 4], motif, answer,
                  taiko_a="B...............", taiko_b="B.......B..B....", frame="F.......F...k...",
                  extra=_pads(50, "aeolian", [0, 3, 5, 4], 2, 0.7), quote="emmanuel", region="judea")


def samaria():
    # 撒馬利亞：E 多利安，輕快的牧歌，城裡大有歡喜；C 段是〈耶穌愛我〉
    motif = [(0, 0.5), (1, 0.5), (2, 1), (4, 1), (3, 0.5), (2, 0.5), (1, 1), (2, 2), (4, 0.5), (5, 0.5), (4, 1), (2, 1), (0, 2)]
    answer = [(2, 1), (3, 0.5), (4, 0.5), (5, 1), (4, 1), (2, 1), (1, 1), (0, 2), (1, 1), (-1, 1), (0, 4)]
    return battle(64, "dorian", 124, [0, 3, 0, 4], motif, answer,
                  taiko_a="B.......B.......", taiko_b="B..B....B..B..B.", frame="F..k.kk.F..k.k..", quote="jesusloves", region="judea")


def joppa():
    # 約帕：C 混合利底亞，海邊的城，波浪般起伏的旋律
    motif = [(0, 1), (2, 0.5), (4, 0.5), (5, 1), (4, 1), (2, 1), (4, 1), (6, 2), (5, 1), (4, 0.5), (2, 0.5), (0, 2)]
    answer = [(4, 1), (6, 1), (7, 1), (6, 0.5), (4, 0.5), (5, 2), (4, 1), (2, 1), (1, 1), (0, 3)]
    return battle(60, "mixolydian", 120, [0, 6, 3, 0], motif, answer, lead=kithara,
                  taiko_a="B.......B..B....", taiko_b="B...B...B..B.B..", frame="F...k.k.F...k.k.", region="sea")


def antioch():
    # 安提阿：A 多利安，出發的歌，步伐穩定往前走
    motif = [(0, 1), (0, 0.5), (2, 0.5), (3, 1), (4, 1), (3, 0.5), (2, 0.5), (1, 1), (2, 2), (4, 1), (5, 1), (4, 1), (2, 1), (0, 2)]
    answer = [(5, 1), (4, 1), (3, 1), (4, 1), (2, 2), (3, 1), (1, 1), (2, 1), (-1, 1), (0, 4)]
    return battle(57, "dorian", 130, [0, 6, 3, 4], motif, answer,
                  taiko_a="B.......B..B....", taiko_b="B..B..B.B..B.B..", frame="F...k.k.F...k...", region="levant")


def damascus():
    # 大馬色：A 自然小調，慢、低沉，主題從低處一路往上爬；C 段轉到大調唱〈奇異恩典〉——瞎眼的，現在看見了
    motif = [(0, 1), (-1, 0.5), (0, 0.5), (2, 1), (1, 1), (0, 2), (None, 1), (2, 1), (3, 1), (4, 1), (3, 0.5), (2, 0.5), (1, 2)]
    answer = [(4, 1), (5, 1), (6, 1), (7, 1), (6, 0.5), (5, 0.5), (4, 1), (2, 2), (3, 1), (2, 0.5), (1, 0.5), (0, 4)]
    return battle(57, "aeolian", 112, [0, 5, 3, 4], motif, answer,
                  taiko_a="B.......B.......", taiko_b="B..B....B..B.B..", frame="F...k...F...k.k.",
                  extra=_pads(57, "aeolian", [0, 5, 3, 4], 4, 0.6), quote="grace", region="levant")


def philippi():
    # 腓立比：D 多利安，i - IV - i - VII；C 段是〈讚美真神〉——半夜在監裡唱詩讚美神
    motif = [(0, 1), (1, 0.5), (2, 0.5), (3, 1), (2, 0.5), (1, 0.5), (0, 2), (None, 2), (4, 1), (3, 1), (2, 1), (1, 1), (0, 4)]
    answer = [(4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (3, 1.5), (2, 0.5), (1, 2), (2, 1), (1, 1), (0, 2), (-1, 2), (0, 2)]
    return battle(62, "dorian", 132, [0, 3, 0, 6], motif, answer, quote="doxology", region="greek")


def thessalonica():
    # 帖撒羅尼迦：E 自然小調，i - VI - VII - i，暴動：最快、鼓最密
    motif = [(0, 0.5), (0, 0.5), (1, 0.5), (2, 0.5), (3, 1), (4, 1), (3, 0.5), (2, 0.5), (1, 1), (0, 2), (4, 0.5), (4, 0.5), (5, 1), (4, 1), (3, 1), (2, 1), (1, 1), (0, 2)]
    answer = [(7, 1), (6, 0.5), (5, 0.5), (4, 1), (3, 1), (4, 0.5), (3, 0.5), (2, 1), (1, 2), (2, 0.5), (3, 0.5), (2, 1), (1, 1), (0, 1), (-1, 1), (0, 2)]
    return battle(64, "aeolian", 144, [0, 5, 6, 0], motif, answer, taiko_a="B..B....B..B....", taiko_b="B.BB..B.B.BB.BB.",
                  frame="F.k.k.k.F.k.k.kk", region="greek")


def corinth():
    # 哥林多：A 自然小調，i - VI - III - VII
    motif = [(4, 2), (3, 1), (2, 1), (3, 1.5), (2, 0.5), (1, 1), (2, 1), (0, 4), (None, 1), (2, 1), (3, 1), (4, 1), (5, 2), (4, 2)]
    answer = [(6, 1.5), (5, 0.5), (4, 1), (3, 1), (2, 2), (3, 1), (2, 1), (1, 1), (0, 1), (-1, 2), (0, 4)]
    return battle(57, "aeolian", 136, [0, 5, 2, 6], motif, answer, frame="F..kF...k..k....", region="greek")


def ephesus():
    # 以弗所：C 弗里吉亞（古希臘調式，暗），i - bII - bVII - i，底下低沉合唱
    motif = [(0, 2), (1, 1), (0, 1), (-1, 2), (0, 2), (3, 2), (2, 1), (1, 1), (0, 4)]
    answer = [(4, 1), (3, 1), (4, 1), (5, 1), (4, 2), (3, 1), (1, 1), (2, 2), (1, 1), (0, 1), (0, 4)]
    return battle(60, "phrygian", 128, [0, 1, -1, 0], motif, answer, frame="F..kF.k.F..kF.k.",
                  extra=_pads(48, "phrygian", [0, 1, -1, 0], 2, 0.7), region="greek")


def boss():
    # Boss：D 自然小調，i - VI - VII - V，最快、大鼓每拍、銅管連打
    tr_motif = [(0, 0.5), (1, 0.5), (0, 0.5), (-1, 0.5), (0, 1), (3, 1), (2, 0.5), (1, 0.5), (0, 0.5), (-1, 0.5), (0, 2), (4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (1, 2), (0, 2)]
    answer = [(7, 1), (5, 1), (4, 1), (3, 1), (4, 0.5), (3, 0.5), (2, 0.5), (1, 0.5), (0, 2), (4, 1), (3, 1), (1, 1), (2, 1), (0, 4)]

    def stabs(tr, total, in_c):
        tr.layer = "top"
        for bar in range(2, total):
            if in_c(bar):
                continue
            for beat in (0, 2):
                tr.note(brass, bar * 4 + beat, hz(deg(50, "aeolian", [0, 5, 6, 4][bar % 4])), tr.beat * 0.8, 0.9)
    return battle(62, "aeolian", 150, [0, 5, 6, 4], tr_motif, answer, taiko_a="B...B...B...B.B.", taiko_b="B.B.B.B.B.B.BBBB",
                  frame="F.kkF.k.F.kkF.kk", extra=stabs)


def fever():
    # 聖靈充滿：明亮大調 I - IV - V - I，拍手、合唱
    tune = [(4, 1), (4, 0.5), (5, 0.5), (6, 1), (4, 1), (7, 2), (6, 1), (5, 1), (4, 1), (5, 0.5), (4, 0.5), (3, 1), (2, 1), (4, 4)]
    answer = [(7, 1), (6, 0.5), (5, 0.5), (4, 1), (5, 1), (6, 2), (4, 2), (5, 1), (4, 1), (3, 1), (2, 1), (0, 4)]

    def joy(tr, total, in_c):
        tr.drums("....C.......C...", 1.0, range(total))
        tr.layer = "top"
        for bar in range(0, total, 2):
            c = [0, 3, 4, 0][(bar // 2) % 4]
            for d in (c, c + 2, c + 4):
                tr.melody(choir, 62, "rast", [(d, 8)], bar * 4, 0.5)
    return battle(62, "rast", 140, [0, 3, 4, 0], tune, answer, lead=kithara, frame="F...k.F.F...k.k.", extra=joy)


def athens():
    # 雅典：G 混合利底亞，基薩拉琴主奏，明亮、像在廣場上辯論
    motif = [(4, 1), (5, 0.5), (4, 0.5), (2, 1), (4, 1), (7, 2), (6, 1), (4, 1), (5, 1), (4, 0.5), (2, 0.5), (1, 1), (0, 2)]
    answer = [(2, 0.5), (3, 0.5), (4, 1), (2, 1), (0, 1), (1, 1), (2, 2), (4, 1), (3, 1), (2, 1), (1, 1), (0, 4)]
    return battle(67, "mixolydian", 126, [0, 6, 3, 0], motif, answer, lead=kithara,
                  taiko_a="B.......B.......", taiko_b="B...B...B..B.B..", frame="F..kk.k.F..k.k..", region="greek")


def jerusalem():
    # 耶路撒冷：E 弗里吉亞，慢而重，低沉合唱與大鼓，像城裡的喧嚷
    motif = [(0, 1), (1, 1), (0, 1), (-1, 1), (0, 2), (1, 0.5), (2, 0.5), (3, 1), (2, 2), (1, 1), (0, 1), (-1, 2), (0, 2)]
    answer = [(3, 1), (4, 1), (5, 2), (4, 1), (3, 1), (1, 2), (2, 1), (1, 1), (0, 4)]

    def chant(tr, total, in_c):
        _pads(52, "phrygian", [0, 1, 0, -1], 2, 0.8)(tr, total, in_c)
        tr.layer = "harm"
        for bar in range(0, total, 2):
            tr.put(bar * 4, drone(hz(40), tr.beat * 8), 0.5, drone)
    return battle(64, "phrygian", 116, [0, 1, 6, 0], motif, answer,
                  taiko_a="B..B....B..B..B.", taiko_b="BB.B..B.BB.B..BB", frame="F...F.k.F...F.kk", extra=chant, region="judea")


def malta():
    # 米利大：D 多利安，像海上的暴風：快、低音翻騰，加上浪聲般的合唱
    motif = [(0, 0.5), (2, 0.5), (4, 0.5), (2, 0.5), (3, 1), (2, 1), (1, 0.5), (2, 0.5), (0, 1), (-1, 2), (0, 0.5), (2, 0.5), (4, 0.5), (5, 0.5), (4, 1), (3, 1), (2, 2), (0, 2)]
    answer = [(5, 1), (4, 0.5), (3, 0.5), (4, 1), (2, 1), (3, 1), (1, 1), (2, 2), (0, 1), (1, 1), (-1, 1), (0, 3)]

    def sea(tr, total, in_c):
        tr.layer = "top"
        for bar in range(0, total, 4):
            if in_c(bar):
                continue
            for d in (0, 2, 4):
                tr.melody(choir, 50, "dorian", [(d, 16)], bar * 4, 0.35)
    return battle(62, "dorian", 140, [0, 6, 5, 6], motif, answer,
                  taiko_a="B.....B.B.....B.", taiko_b="B..B..B.B..B..BB", frame="F.kkF.kkF.kkF.kk", extra=sea, region="sea")


def rome():
    # 羅馬：C 自然小調，進行曲：小鼓滾、銅管主奏，最莊嚴的最後一站
    motif = [(0, 1), (0, 0.5), (0, 0.5), (2, 1), (4, 1), (5, 2), (4, 1), (2, 1), (3, 1), (2, 0.5), (1, 0.5), (0, 2), (None, 2)]
    answer = [(4, 1), (4, 0.5), (4, 0.5), (5, 1), (7, 1), (6, 2), (4, 2), (5, 1), (4, 1), (3, 1), (1, 1), (0, 4)]

    def march(tr, total, in_c):
        tr.layer = "top"
        for bar in range(2, total):
            if in_c(bar):
                continue
            for beat in range(4):
                tr.note(brass, bar * 4 + beat, hz(deg(48, "aeolian", [0, 5, 3, 4][bar % 4])), tr.beat * 0.5, 0.6)
    return battle(60, "aeolian", 120, [0, 5, 3, 4], motif, answer, lead=brass,
                  taiko_a="B.......B.......", taiko_b="B...B...B...B.B.", frame="F.kkF.kkF.kkF.k.", extra=march, region="rome")


def patmos():
    # 拔摩海島：B 弗里吉亞，神秘的異象：號筒宣告、合唱長音、鼓像遠處的雷聲
    motif = [(0, 2), (1, 1), (0, 1), (4, 2), (3, 1), (1, 1), (0, 1), (1, 1), (3, 1), (4, 1), (5, 2), (4, 2)]
    answer = [(7, 1), (5, 1), (4, 2), (3, 1), (1, 1), (0, 2), (1, 1), (0, 1), (-1, 2), (0, 4)]

    def vision(tr, total, in_c):
        tr.layer = "top"
        for bar in range(0, total, 2):
            if not in_c(bar):
                for d in (0, 4):
                    tr.melody(choir, 59, "phrygian", [([0, 1, 5, 0][(bar // 2) % 4] + d, 8)], bar * 4, 0.45)
            tr.put(bar * 4, drone(hz(47), tr.beat * 8), 0.5, drone, "harm")
        for bar in range(4, total, 4):
            if in_c(bar):
                continue
            for i in range(3):
                tr.note(brass, bar * 4 + i * 0.5, hz(deg(59, "phrygian", 4)), tr.beat * 0.4, 0.7)
    return battle(59, "phrygian", 112, [0, 1, 5, 0], motif, answer, lead=brass,
                  taiko_a="B.......B...B...", taiko_b="B..B....B.BB..B.", frame="F...k...F...k.kk", extra=vision, region="vision")


def fucheng():
    """府城（1865）：G 大調五聲音階（do re mi sol la）。北管的鑼鼓（板鼓帶頭、大鑼、小鑼、鈸）、
    殼仔弦拉主旋律、月琴撥伴奏，A' 段嗩吶接手；C 段鑼鼓停下來，殼仔弦慢慢拉「宣教之路」主題。"""
    root, mode, bpm = 67, "rast", 126
    motif = [(4, 1), (5, 0.5), (4, 0.5), (2, 1), (1, 0.5), (2, 0.5), (4, 2), (5, 1), (7, 1), (5, 1.5), (4, 0.5), (2, 1), (1, 1), (0, 2), (None, 1)]
    answer = [(2, 1), (4, 0.5), (2, 0.5), (1, 1), (0, 1), (-2, 1.5), (-1, 0.5), (0, 2), (2, 1), (1, 0.5), (2, 0.5), (4, 1), (5, 1), (4, 2), (2, 1), (1, 1)]
    prog = [0, 4, 5, 4]
    q = THEME
    c_bars = int(np.ceil(beats(q) / 4)) + 1
    A, B, C = 2, 10, 18
    A2 = C + c_bars
    total = A2 + 8
    tr = Track(bpm=bpm, bars=total)
    in_c = lambda bar: C <= bar < A2
    # ---- 鑼鼓：板鼓打底、匡（大鑼）在小節頭、小鑼與鈸穿插；段落交界一串「匡七台七匡」 ----
    pat_a = {"b": "b.b.b.b.b.bbb.b.", "G": "G...............", "x": "....x.x.....x.x.", "c": "........c.......", "t": "t.....t.t.......", "w": "w...w...w...w..."}
    pat_b = {"b": "b.b.bbb.b.b.bbb.", "G": "G.......G.......", "x": "..x.x.x...x.x.x.", "c": "....c.......c...", "t": "t..t..t.t..t....", "w": "w...w...w...w..."}
    roll = {"b": "bbbbbbbbbbbbbbbb", "G": "G.......G...G...", "c": "....c.c.....c.c.", "x": "..x...x...x...x."}
    for bar in range(total):
        if in_c(bar):
            for i, ch in enumerate("w.......w......."):
                if ch != ".":
                    tr.hit(bar * 4 + i / 4, ch, 0.7)
            if bar % 4 == 0:
                tr.hit(bar * 4, "x", 0.5)
            continue
        pat = roll if bar in (A - 1, B - 1, C - 1, total - 1) else (pat_a if bar < B or A2 <= bar < A2 + 4 else pat_b)
        for ch, line in pat.items():
            for i, c in enumerate(line):
                if c != ".":
                    tr.hit(bar * 4 + i / 4, ch, (0.75 + 0.25 * RNG.random()) * (0.6 if ch == "b" and i % 4 else 1.0))
    # ---- 伴奏：月琴撥分解和弦；殼仔弦低八度拉長音當低音（像大廣弦） ----
    tr.layer = "harm"
    for bar in range(A, total):
        c = prog[bar % len(prog)] if not in_c(bar) else [0, 3, 4, 0][(bar - C) // 2 % 4]
        soft = 0.6 if in_c(bar) else 1.0
        for i, d in enumerate([0, 4, 7, 4, 2, 4, 7, 4]):
            if in_c(bar) and i % 2:
                continue
            tr.note(yueqin, bar * 4 + i * 0.5, hz(deg(root - 12, mode, c + d)), 0.5, soft, 0.9 if i % 4 == 0 else 0.6)
        tr.note(kexian, bar * 4, hz(deg(root - 24, mode, c)), tr.beat * 3.8, 0.55 * soft)
        if not in_c(bar):
            for beat in range(4):
                tr.note(bass, bar * 4 + beat, hz(deg(root - 24, mode, c)), 0.2, 0.7, 0.8)
    # ---- 旋律：殼仔弦；B 段月琴高八度跟著輪指；A' 嗩吶接手 ----
    tr.layer = "top"
    pos = tr.melody(kexian, root, mode, motif, A * 4)
    tr.melody(kexian, root, mode, answer, pos)
    pos = tr.melody(kexian, root, mode, motif, B * 4, octave=1)
    tr.melody(yueqin, root, mode, motif, B * 4, 0.6, octave=1)
    tr.melody(kexian, root, mode, answer, pos, octave=1)
    tr.melody(kexian, root, mode, q, C * 4 + 2, 0.85)
    pos = tr.melody(suona, root, mode, motif, A2 * 4, 0.9)
    tr.melody(kexian, root, mode, motif, A2 * 4, 0.5, octave=1)
    tr.melody(suona, root, mode, answer, pos, 0.9)
    return tr.render({"perc": 0.5, "harm": 0.8, "top": 1.1})


# ---------- 營地、標題、過場（單一檔案） ----------
def camp():
    # 營地：慢、溫暖。D 多利安，阿洛斯主奏、基薩拉琴分解和弦、輕輕的框鼓；中間是「宣教之路」主題
    a = [(4, 1.5), (3, 0.5), (2, 1), (1, 1), (2, 3), (None, 1)]
    b = [(2, 1), (3, 1), (4, 1), (6, 1), (5, 2), (4, 1), (3, 1)]
    c = [(4, 1.5), (5, 0.5), (4, 1), (3, 1), (2, 1), (1, 1), (0, 2)]
    root = 62
    body = [a, b, a, c]
    total_beats = 8 + sum(beats(p) for p in body) + beats(THEME) + 8
    bars = int(np.ceil(total_beats / 4))
    bars += (-bars) % 4
    tr = Track(bpm=66, bars=bars)
    tr.layer = "harm"
    tr.put(0, drone(hz(38), tr.length / SR + 2), 0.6, drone)
    tr.drums("F.......F...k...", 0.5, range(bars))
    tr.layer = "top"
    pos = 8.0
    for phrase in body[:2]:
        pos = tr.melody(aulos, root, "dorian", phrase, pos, 0.55)
    # 主題（D 多利安的同一組音的大調＝C 大調），基薩拉琴主奏，合唱輕輕跟著
    q_root = deg(root, "dorian", REL_MAJOR["dorian"])
    tr.melody(choir, q_root - 12, "rast", THEME, pos, 0.3, legato=1.0)
    pos = tr.melody(kithara, q_root, "rast", THEME, pos, 0.7)
    for phrase in body[2:]:
        pos = tr.melody(aulos, root, "dorian", phrase, pos, 0.55)
    tr.layer = "harm"
    for bar in range(bars):
        base = [0, 0, 3, 4][bar % 4]
        for i, d in enumerate([0, 4, 7, 4]):
            tr.melody(kithara, root - 12, "dorian", [(base + d, 1)], bar * 4 + i, 0.6)
    return tr.render()


def title():
    # 標題：G 大調，主題完整唱一次：先是阿洛斯，再由銅管和合唱接高八度；底下是持續音和基薩拉琴
    root, mode = 67, "rast"
    bars = 4 + int(np.ceil(beats(THEME) / 4)) * 2 + 2
    tr = Track(bpm=80, bars=bars)
    tr.layer = "harm"
    tr.put(0, drone(hz(43), tr.length / SR + 2), 0.7, drone)
    prog = [0, 3, 4, 0, 5, 3, 4, 0]
    for bar in range(bars):
        c = prog[bar // 2 % len(prog)]
        for i, d in enumerate([0, 4, 7, 9, 7, 4]):
            tr.note(kithara, bar * 4 + i * 4 / 6, hz(deg(root - 12, mode, c + d)), 1.0, 0.7, 0.55)
        if bar % 2 == 0:
            for d in (c, c + 2, c + 4):
                tr.note(strings, bar * 4, hz(deg(root - 12, mode, d)), tr.beat * 8.2, 0.8)
    tr.drums("B...............", 0.5, range(4, bars, 2))
    tr.layer = "top"
    pos = tr.melody(aulos, root, mode, THEME, 16.0, 0.8)
    tr.melody(brass, root, mode, THEME, pos, 0.75)
    tr.melody(choir, root - 12, mode, THEME, pos, 0.5, legato=1.0)
    return tr.render({"perc": 0.8, "harm": 1.4, "top": 1.8})


def story():
    # 開場與章節過場：A 多利安，很慢，基薩拉琴與合唱輕輕唱主題（在小調裡），像在說一個很久以前的故事
    root, mode = 57, "dorian"
    bars = 4 + int(np.ceil(beats(THEME) / 4)) + 4
    tr = Track(bpm=60, bars=bars)
    tr.layer = "harm"
    tr.put(0, drone(hz(33), tr.length / SR + 2), 0.6, drone)
    for bar in range(0, bars, 2):
        c = [0, 3, 6, 4][bar // 2 % 4]
        for d in (c, c + 2, c + 4):
            tr.note(strings, bar * 4, hz(deg(root - 12, mode, d)), tr.beat * 8.2, 0.9)
        for i, d in enumerate([0, 4, 7, 4, 2, 4, 7, 4]):
            tr.note(kithara, bar * 4 + i, hz(deg(root - 12, mode, c + d)), 1.4, 0.45, 0.5)
    tr.layer = "top"
    tr.melody(aulos, root, mode, THEME, 16.0, 0.6)
    tr.melody(choir, root - 12, mode, THEME, 16.0, 0.35, legato=1.0)
    return tr.render({"perc": 0.8, "harm": 1.6, "top": 2.0})


def ending():
    """結局（拔摩海島之後、通過府城以後的過場）：奇異恩典（NEW BRITAIN，1835，公版旋律）三段，越唱越滿，最後轉調。
    3/4 拍、66 拍／分。一、鋼琴獨奏＋鋪底（馬雅各上岸，溫柔）；二、大提琴與弦樂唱旋律，鋼琴琶音，合唱鋪底；
    三、升一個全音，合唱與弦樂齊唱、鐘琴點綴、定音鼓推上去（今天的你）；最後鋼琴收在主和弦。"""
    root, mode = 62, "rast"            # D 大調
    mel = HYMNS["grace"]
    chords = [0, 0, 3, 0, 0, 0, 4, 4, 0, 0, 3, 0, 0, 4, 0, 0]      # 每小節的和弦（級數）
    verse = 16
    intro, outro = 4, 4
    bars = intro + verse * 3 + 2 + outro
    tr = Track(bpm=66, bars=bars, beats_per_bar=3)
    tr.layer = "harm"

    def harmony(start_bar, rt, fill, arps=True, strings_on=False, choir_on=False, gain=1.0):
        for i, c in enumerate(chords):
            b0 = (start_bar + i) * 3
            tr.note(cello if strings_on else bass, b0, hz(deg(rt - 24, mode, c)), tr.beat * 3.1, 0.9 * gain)
            tr.note(pad, b0, hz(deg(rt - 12, mode, c)), tr.beat * 3.4, 0.9 * gain)
            tr.note(pad, b0, hz(deg(rt - 12, mode, c + 2)), tr.beat * 3.4, 0.7 * gain)
            tr.note(pad, b0, hz(deg(rt - 12, mode, c + 4)), tr.beat * 3.4, 0.7 * gain)
            if arps:
                for j, d in enumerate(fill):
                    tr.note(piano, b0 + j * 0.5, hz(deg(rt - 12, mode, c + d)), 2.0, 0.55 * gain, 0.45)
            if strings_on:
                for d in (c + 2, c + 4, c + 7):
                    tr.note(strings, b0, hz(deg(rt - 12, mode, d)), tr.beat * 3.2, 0.6 * gain)
            if choir_on:
                for d in (c, c + 2, c + 4):
                    tr.note(choir, b0, hz(deg(rt - 12, mode, d)), tr.beat * 3.2, 0.5 * gain)

    # 前奏：鋼琴輕輕的琶音
    for i in range(intro):
        c = [0, 3, 0, 4][i]
        tr.note(pad, i * 3, hz(deg(root - 12, mode, c)), tr.beat * 3.4, 0.8)
        for j, d in enumerate([0, 4, 7, 9, 7, 4]):
            tr.note(piano, i * 3 + j * 0.5, hz(deg(root - 12, mode, c + d)), 2.0, 0.5, 0.4)
    # 第一段：鋼琴唱旋律
    v1 = intro
    harmony(v1, root, [0, 4, 7, 4, 2, 4], gain=0.8)
    tr.layer = "top"
    tr.melody(piano, root, mode, mel, v1 * 3 - 1, 1.0, octave=0)
    # 第二段：大提琴唱，弦樂與合唱鋪底
    v2 = v1 + verse
    tr.layer = "harm"
    harmony(v2, root, [0, 4, 7, 9, 7, 4], strings_on=True, gain=0.9)
    tr.layer = "top"
    tr.melody(cello, root - 12, mode, mel, v2 * 3 - 1, 1.2, legato=1.0)
    tr.melody(choir, root, mode, mel, v2 * 3 - 1 + 24, 0.25, legato=1.0)   # 後半合唱輕輕跟進來
    # 過門兩小節：定音鼓滾奏，升一個全音
    br = v2 + verse
    tr.layer = "perc"
    tr.put(br * 3, timp(1.0), 1.0, taiko, "perc")
    tr.layer = "harm"
    for i, c in enumerate([4, 4]):
        for d in (c, c + 2, c + 4, c + 6):
            tr.note(strings, (br + i) * 3, hz(deg(root - 12, mode, d)), tr.beat * 3.2, 0.7 + 0.3 * i)
    # 第三段：E 大調，合唱與弦樂齊唱，鐘琴點綴
    r3 = root + 2
    v3 = br + 2
    harmony(v3, r3, [0, 4, 7, 9, 11, 9], strings_on=True, choir_on=True, gain=1.0)
    tr.layer = "top"
    tr.melody(choir, r3, mode, mel, v3 * 3 - 1, 0.75, legato=1.0)
    tr.melody(strings, r3, mode, mel, v3 * 3 - 1, 1.0, octave=1, legato=1.0)
    tr.melody(bell, r3, mode, mel[::2], v3 * 3 - 1 + 24, 0.6, octave=1)
    tr.layer = "perc"
    for i in range(0, verse, 4):
        tr.put((v3 + i) * 3, timp(0.5), 0.7, taiko, "perc")
    # 尾聲：鋼琴最後一句，停在主和弦
    oo = v3 + verse
    tr.layer = "top"
    tr.melody(piano, r3, mode, mel[-8:], oo * 3, 0.9)
    tr.layer = "harm"
    for d in (0, 2, 4, 7):
        tr.note(pad, oo * 3, hz(deg(r3 - 12, mode, d)), tr.beat * 12, 0.9)
        tr.note(strings, oo * 3, hz(deg(r3 - 12, mode, d)), tr.beat * 12, 0.6)
    return tr.render({"perc": 1.0, "harm": 1.8, "top": 2.0})


SONGS = [("camp", camp, False), ("title", title, False), ("story", story, False), ("ending", ending, False),
         ("pentecost", pentecost, True), ("stephen", stephen, True), ("samaria", samaria, True),
         ("damascus", damascus, True), ("joppa", joppa, True), ("antioch", antioch, True), ("philippi", philippi, True),
         ("thessalonica", thessalonica, True), ("corinth", corinth, True), ("ephesus", ephesus, True), ("athens", athens, True),
         ("jerusalem", jerusalem, True), ("malta", malta, True), ("rome", rome, True), ("patmos", patmos, True), ("fucheng", fucheng, True),
         ("boss", boss, True), ("fever", fever, False)]

if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]   # 只產生指定的曲子：python tools/make_music.py athens rome
    for name, fn, stems in SONGS:
        if only and name not in only:
            continue
        save(name, fn(), stems)
