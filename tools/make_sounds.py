"""產生遊戲的音效與音樂（全部用程式合成，沒有外部素材，不用擔心授權）。

用法：python tools/make_sounds.py
輸出：assets/audio/*.wav（音效）、assets/audio/*.ogg（音樂，需要 ffmpeg）

想改聲音：改下面對應的函式，再跑一次。原則是「少而清楚」——
常出現的聲音（命中、撿經驗）要短、要輕。
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, release=None, curve=4.0):
    """快起、指數衰減的包絡"""
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    dur = n / SR
    d = np.exp(-curve * x / dur) if release is None else np.clip(1 - (x - (dur - release)) / release, 0, 1)
    return a * d


def pluck(freq, sec, bright=0.4):
    """像里拉琴的撥弦：幾個泛音、高音衰減比較快"""
    t = t_axis(sec)
    y = np.zeros_like(t)
    for k, amp in [(1, 1.0), (2, bright), (3, bright * 0.5), (4, bright * 0.25)]:
        y += amp * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (3 + k * 2.5))
    return y * env(len(t), 0.003, curve=2.0)


def bell(freq, sec):
    t = t_axis(sec)
    y = np.zeros_like(t)
    for ratio, amp, dec in [(1, 1, 3), (2.76, 0.5, 5), (5.4, 0.25, 8), (8.9, 0.12, 12)]:
        y += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * dec)
    return y * env(len(t), 0.002, curve=1.0)


def noise(sec, lp=0.2):
    n = np.random.default_rng(7).standard_normal(int(SR * sec))
    out = np.zeros_like(n)
    acc = 0.0
    for i, v in enumerate(n):  # 一階低通
        acc += lp * (v - acc)
        out[i] = acc
    return out / (np.abs(out).max() + 1e-9)


def mix(*parts):
    n = max(int(start * SR) + len(p) for start, p in parts)
    y = np.zeros(n)
    for start, p in parts:
        s = int(start * SR)
        y[s:s + len(p)] += p
    return y


def fit(y, n):
    """補零或截斷成 n 個取樣"""
    return np.pad(y, (0, max(0, n - len(y))))[:n]


def note(n):
    """MIDI 音高 → 頻率"""
    return 440.0 * 2 ** ((n - 69) / 12)


def save_wav(name, y, peak=0.8):
    y = y / (np.abs(y).max() + 1e-9) * peak
    data = (y * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path


def save_ogg(name, y, peak=0.7):
    tmp = save_wav("_" + name, y, peak)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


# ---------- 音效 ----------
def sfx():
    t = t_axis
    # 命中：很短很輕的「答」
    save_wav("hit", noise(0.03, 0.5) * env(int(SR * 0.03), 0.001, curve=6), 0.5)
    # 驅散：柔和的「啵」，音高往下掉
    tt = t(0.09)
    f = 900 - 4000 * tt
    save_wav("kill", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.002, curve=5), 0.6)
    # 撿經驗：小小的高音
    save_wav("gem", np.sin(2 * np.pi * 1760 * t(0.05)) * env(int(SR * 0.05), 0.002, curve=6), 0.35)
    # 升級：撥弦琶音 D F# A D
    save_wav("levelup", mix(*[(i * 0.07, pluck(note(n), 0.7)) for i, n in enumerate([62, 66, 69, 74])]))
    # 選卡
    save_wav("pick", pluck(note(81), 0.25, 0.6), 0.6)
    # 五旬節：和弦慢慢湧起，加上高音閃光
    tt = t(1.8)
    pad = sum(np.sin(2 * np.pi * note(n) * tt) * 0.25 for n in [50, 57, 62, 66, 69, 76])
    swell = np.clip(tt / 0.6, 0, 1) * np.exp(-np.clip(tt - 0.6, 0, None) * 1.5)
    save_wav("fever", pad * swell + fit(mix(*[(0.3 + i * 0.08, bell(note(n), 0.8) * 0.3) for i, n in enumerate([81, 86, 90, 93])]), len(tt)))
    # 五旬節結束的爆發：低沉的「轟」＋和弦
    tt = t(1.2)
    boom = np.sin(2 * np.pi * (60 + 40 * np.exp(-tt * 8)) * tt) * np.exp(-tt * 3)
    save_wav("burst", boom + 0.4 * noise(1.2, 0.05) * np.exp(-tt * 5) + fit(mix((0.05, pluck(note(62), 1.0) + pluck(note(69), 1.0))), len(tt)))
    # 肢體連結觸發：鈴聲（三種高度，連鎖越深越高）
    for i, n in enumerate([79, 83, 86]):
        save_wav("link%d" % (i + 1), bell(note(n), 0.5), 0.55)
    # 進化：往上爬的琶音＋鈴
    save_wav("evolve", mix(*[(i * 0.06, pluck(note(n), 0.9)) for i, n in enumerate([62, 66, 69, 74, 78, 81])], (0.4, bell(note(86), 1.2) * 0.6)))
    # 寶箱
    save_wav("chest", mix(*[(i * 0.05, bell(note(n), 0.5) * 0.6) for i, n in enumerate([84, 88, 91, 96])]))
    # 受傷：低悶的一下
    tt = t(0.16)
    save_wav("hurt", np.sin(2 * np.pi * (140 - 300 * tt) * tt) * env(len(tt), 0.002, curve=5) + 0.3 * noise(0.16, 0.1) * env(len(tt), 0.001, curve=8), 0.7)
    # 治療：兩個音往上
    save_wav("heal", mix((0, pluck(note(74), 0.35, 0.2)), (0.08, pluck(note(81), 0.4, 0.2))), 0.45)
    # 菁英吼叫：低頻顫動
    tt = t(0.7)
    saw = 2 * ((80 * tt) % 1) - 1
    save_wav("roar", saw * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * tt)) * env(len(tt), 0.05, curve=3) + 0.4 * noise(0.7, 0.08) * env(len(tt), 0.02, curve=3), 0.6)
    # Boss 預警：低沉嗡聲
    tt = t(0.6)
    save_wav("warn", (np.sin(2 * np.pi * 55 * tt) + 0.5 * np.sin(2 * np.pi * 110.5 * tt)) * np.sin(np.pi * tt / 0.6), 0.6)
    # 地震（半夜的詩歌）
    tt = t(0.9)
    save_wav("quake", noise(0.9, 0.03) * np.exp(-tt * 3) + 0.6 * np.sin(2 * np.pi * 45 * tt) * np.exp(-tt * 2.5))
    # 通關與失敗
    win = mix(*[(i * 0.35, pluck(note(a), 1.4) + pluck(note(b), 1.4) * 0.7 + pluck(note(c), 1.4) * 0.5)
                for i, (a, b, c) in enumerate([(62, 66, 69), (67, 71, 74), (69, 73, 76), (74, 78, 81)])])
    save_wav("win", win)
    save_wav("lose", mix(*[(i * 0.4, pluck(note(n), 1.2, 0.2)) for i, n in enumerate([69, 65, 62, 57])]), 0.6)
    # 介面點擊
    save_wav("ui", pluck(note(76), 0.12, 0.3), 0.4)


# ---------- 音樂（可以無縫循環） ----------
def music():
    rng = np.random.default_rng(3)
    # 營地：慢的撥弦旋律＋低音持續音，D 大調五聲音階
    bpm = 72
    beat = 60 / bpm
    bars = 8
    sec = bars * 4 * beat
    y = np.zeros(int(SR * sec))
    tt = t_axis(sec)
    y += 0.12 * (np.sin(2 * np.pi * note(38) * tt) + 0.5 * np.sin(2 * np.pi * note(45) * tt))
    scale = [62, 64, 66, 69, 71, 74, 76]
    melody = [0, 2, 3, 2, 4, 3, 2, 1, 0, 2, 3, 5, 4, 3, 2, -1, 3, 4, 5, 4, 3, 2, 1, 2, 0, 1, 2, 3, 2, 1, 0, -1]
    for i, m in enumerate(melody):
        if m < 0:
            continue
        st = int(i * beat * SR)
        p = pluck(note(scale[m]), 1.6, 0.35) * 0.5
        y[st:st + len(p)] += p[: len(y) - st]
        if i % 4 == 0:  # 和聲
            q = pluck(note(scale[m] - 12), 1.8, 0.2) * 0.3
            y[st:st + len(q)] += q[: len(y) - st]
    save_ogg("music_camp", y * np.clip(np.minimum(tt, sec - tt) / 0.05, 0, 1))

    # 戰鬥：低音持續＋框鼓節奏＋零星撥弦，D 多利安
    bpm = 100
    beat = 60 / bpm
    bars = 8
    sec = bars * 4 * beat
    tt = t_axis(sec)
    y = 0.1 * (np.sin(2 * np.pi * note(38) * tt) + 0.6 * np.sin(2 * np.pi * note(45) * tt + 0.3 * np.sin(2 * np.pi * 0.25 * tt)))
    drum_low = np.sin(2 * np.pi * (70 + 60 * np.exp(-t_axis(0.3) * 30)) * t_axis(0.3)) * np.exp(-t_axis(0.3) * 12)
    drum_hi = noise(0.08, 0.3) * np.exp(-t_axis(0.08) * 40) * 0.35
    pattern = [1, 0, 2, 0, 1, 2, 2, 0]  # 八分音符：1 低鼓、2 高鼓
    for b in range(bars * 8):
        k = pattern[b % 8]
        if k == 0:
            continue
        st = int(b * beat / 2 * SR)
        d = drum_low if k == 1 else drum_hi
        y[st:st + len(d)] += d[: len(y) - st] * 0.6
    scale = [62, 64, 65, 67, 69, 71, 72, 74]
    motif = [0, 2, 4, 3, 2, 0, 1, 2]
    for bar in range(bars):
        if bar % 2 == 1:
            continue
        for i, m in enumerate(motif):
            st = int((bar * 4 + i * 0.5) * beat * SR)
            p = pluck(note(scale[(m + (bar // 2) % 3) % len(scale)]), 0.6, 0.3) * 0.3
            y[st:st + len(p)] += p[: len(y) - st]
    save_ogg("music_battle", y * np.clip(np.minimum(tt, sec - tt) / 0.03, 0, 1))


# ---------- 對話的咕噥聲（像動物森友會那樣） ----------
def voices():
    """五個母音般的短音節，基準音高 220Hz；遊戲裡每個角色用不同的 pitch_scale 播放。"""
    t = t_axis(0.075)
    vowels = {  # 第一、第二共振峰的大約位置（Hz）
        "a": (750, 1200), "e": (500, 1800), "i": (300, 2200), "o": (500, 900), "u": (350, 800),
    }
    f0 = 220 * (1 + 0.03 * np.sin(2 * np.pi * 9 * t))
    phase = 2 * np.pi * np.cumsum(f0) / SR
    for name, (f1, f2) in vowels.items():
        y = np.zeros_like(t)
        for k in range(1, 14):  # 諧波，靠近共振峰的放大
            fk = 220 * k
            w = np.exp(-((fk - f1) / 180) ** 2) + 0.6 * np.exp(-((fk - f2) / 260) ** 2) + 0.05
            y += w * np.sin(k * phase) / k ** 0.3
        save_wav("voice_" + name, y * env(len(t), 0.008, curve=3.5), 0.5)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    voices()
    music()
    print("done:", sorted(os.listdir(OUT)))
