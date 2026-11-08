"""史詩感示範曲（風格提案用，不進遊戲）。沿用 make_music.py 的樂器與殘響，只換曲式、速度與配器：
D 自然小調、80 BPM（現有關卡曲約 126–150）、定音鼓滾奏與太鼓、大提琴低音、弦樂鋪底、銅管主題、合唱、鐘。
用法：python tools/music_epic_sample.py <輸出資料夾>   輸出 epic_sample.wav 與 epic_sample.ogg（需要 ffmpeg）
"""
import os
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_music as mm  # noqa: E402

ROOT, MODE, BPM, BARS = 50, "aeolian", 80, 16
CHORDS = [0, 5, 2, 6]   # i - VI - III - VII，每 2 小節換一次
THEME = [(0, 2), (2, 1), (4, 1), (7, 3), (6, 1), (5, 2), (4, 2), (2, 2), (0, 2)]   # 16 拍 = 4 小節


def compose() -> dict:
    tr = mm.Track(BPM, BARS)
    note = lambda d, oct_=0: mm.hz(mm.deg(ROOT, MODE, d) + 12 * oct_)  # noqa: E731
    for bar in range(BARS):
        c = CHORDS[(bar // 2) % 4]
        b = bar * 4
        tr.layer = "harm"
        tr.note(mm.cello, b, note(c, -1), tr.beat * 4.2, 1.0)                       # 低音
        if bar >= 2:
            for k in (0, 2, 4):
                tr.note(mm.strings, b, note(c + k), tr.beat * 4.2, 0.55)            # 弦樂鋪底
        tr.layer = "top"
        if bar >= 6:
            for k in (0, 2, 4):
                tr.note(mm.choir, b, note(c + k, 1), tr.beat * 4.2, 0.6 if bar < 14 else 0.35)
        if bar % 4 == 3:
            tr.note(mm.bell, b + 3, note(c + 4, 2), tr.beat * 2, 0.5)
        # 打擊：開頭定音鼓滾奏；之後每小節一拍與三拍半；高潮每拍
        if bar in (0, 1, 7, 11, 15):
            tr.put(b, mm.timp(1.0), 1.0, None, "perc")
        beats = [0] if bar < 6 else [0, 2.5] if bar < 10 else [0, 1, 2, 3] if bar < 14 else [0]
        for t in beats:
            tr.hit(b + t, "B", 1.0 if t == 0 else 0.8, 1.0)
    for start, oct_, g in ((4, 0, 0.55), (8, 0, 0.9), (12, 1, 1.0)):                # 銅管主題三次，越來越高越大聲
        tr.layer = "top"
        tr.melody(mm.brass, ROOT, MODE, THEME, start * 4, g, octave=oct_)
    return tr.render()


def main(out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    layers = compose()
    y = sum(layers.values())
    # 力度走勢：弱起 → 銅管進來 → 高潮 → 收尾（逐小節的音量倍率，中間內插）
    arc = [0.25, 0.3, 0.4, 0.45, 0.55, 0.6, 0.8, 0.9, 1.0, 1.0, 1.0, 1.05, 1.1, 1.0, 0.6, 0.35]
    bar_len = int(mm.SR * 60 / BPM * 4)
    env = np.interp(np.arange(y.shape[1]), (np.arange(BARS) + 0.5) * bar_len, arc)
    y = y * env
    y = y * (10 ** (-17 / 20) / (np.sqrt((y ** 2).mean()) + 1e-9))
    y = np.tanh(y * 1.1) / 1.1
    wav = os.path.join(out_dir, "epic_sample.wav")
    pcm = (np.clip(y, -1, 1).T * 32767).astype("<i2")
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(mm.SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                    os.path.join(out_dir, "epic_sample.ogg")], check=True)
    print("done %.1f 秒" % (y.shape[1] / mm.SR))


if __name__ == "__main__":
    main(sys.argv[1])
