#!/usr/bin/env python3
"""مولّد أصوات «مدينة الصقيع» — توليد إجرائي كامل (بلا ملفات خارجية).

يولّد المؤثرات القصيرة (WAV) + حلقتي الجو (رياح وموسيقى محيطة) ثم يحوّل
الحلقات إلى OGG بـ ffmpeg. التوليد حتمي (seed ثابت) ويمكن إعادة تشغيله بأمان.

الاستخدام:  python3 tools/gen_audio.py
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

SR = 22050  # معدل العينات — كافٍ للمؤثرات ويقلل الحجم
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(19983010)  # seed ثابت — نفس الأصوات في كل توليد


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def norm(x: np.ndarray, peak: float = 0.7) -> np.ndarray:
    """تطبيع المستوى مع هوامش أمان ضد القطع (clipping)."""
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def env(n: int, a: float, r: float, curve: float = 2.0) -> np.ndarray:
    """غلاف هجوم/تلاشٍ ناعم."""
    na, nr = max(int(a * SR), 1), max(int(r * SR), 1)
    e = np.ones(n)
    na = min(na, n)
    nr = min(nr, n)
    e[:na] = np.linspace(0, 1, na) ** (1 / curve)
    e[n - nr:] = np.linspace(1, 0, nr) ** (1 / curve)
    return e


def lowpass_fast(x: np.ndarray, cutoff: float) -> np.ndarray:
    """مرشح أحادي القطب سريع (يكفي لمعظم الأصوات هنا)."""
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    out = np.empty_like(x)
    cur = 0.0
    for i in range(len(x)):
        cur += alpha * (x[i] - cur)
        out[i] = cur
    return out


def bell(freq: float, dur: float, partials=((1, 1.0), (2.7, 0.35), (5.4, 0.12))) -> np.ndarray:
    """نغمة جرسية دافئة — توافقيات غير صحيحة تعطي طابعًا طبيعيًا."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for ratio, amp in partials:
        x += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-3.0 * t * ratio)
    return x


def save_wav(name: str, x: np.ndarray) -> Path:
    x = np.asarray(x, dtype=np.float64)
    assert np.all(np.isfinite(x)), f"{name}: قيم غير منتهية"
    x = x - np.mean(x)  # إزالة أي انزياح DC
    peak = np.max(np.abs(x))
    assert peak <= 0.95, f"{name}: قطع محتمل peak={peak}"
    p = OUT / name
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    import wave
    with wave.open(str(p), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name}: {len(x)/SR:.2f}s peak={peak:.2f}")
    return p


def seamless(x: np.ndarray, xf_sec: float = 1.0) -> np.ndarray:
    """تدوير متقاطع لتسهيل حلقة سلسة — دمج آخر ثانية مع أولها."""
    n = int(xf_sec * SR)
    n = min(n, len(x) // 2)
    fade = np.linspace(0, 1, n) ** 2
    x[:n] = x[:n] * fade + x[-n:] * (1 - fade)
    return x[:-n]


# ---------------------------------------------------------------- المؤثرات
def gen_click() -> np.ndarray:
    t = t_axis(0.06)
    x = np.sin(2 * np.pi * 1900 * t) * np.exp(-60 * t)
    x += 0.4 * np.sin(2 * np.pi * 950 * t) * np.exp(-45 * t)
    # نبضة نقر خفيفة
    noise = rng.standard_normal(len(t)) * np.exp(-300 * t)
    return norm(x + 0.15 * noise, 0.45)


def gen_collect() -> np.ndarray:
    a = bell(660, 0.16)  # E5
    b = bell(880, 0.26)  # A5
    x = np.zeros(int(SR * 0.40))
    x[: len(a)] += 0.8 * a
    i = int(SR * 0.10)
    x[i: i + len(b)] += 0.9 * b[: len(x) - i]
    return norm(x, 0.55)


def gen_build() -> np.ndarray:
    # طرقة عميقة (سقوط نغمة) + جرس تأكيد بعدها
    t = t_axis(0.18)
    thunk = np.sin(2 * np.pi * (160 - 60 * t / 0.18) * t) * np.exp(-16 * t)
    noise = lowpass_fast(rng.standard_normal(len(t)) * np.exp(-40 * t), 900)
    ch = bell(523, 0.3)  # C5
    x = np.zeros(int(SR * 0.5))
    x[: len(thunk)] += 0.9 * thunk + 0.2 * noise
    i = int(SR * 0.18)
    x[i: i + len(ch)] += 0.5 * ch
    return norm(x, 0.6)


def gen_march() -> np.ndarray:
    # بوق قصير متصاعد — انطلاق فرقة
    t = t_axis(0.45)
    f = 220 + (330 - 220) * (t / 0.45) ** 0.6
    phase = 2 * np.pi * np.cumsum(f) / SR
    horn = 0.6 * np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    horn = lowpass_fast(horn, 1800)
    e = env(len(t), 0.04, 0.18)
    return norm(horn * e, 0.55)


def gen_victory() -> np.ndarray:
    # صعود ثلاثي مبتهج: A3 C4 E4 A4
    notes = [(220, 0.0), (261.6, 0.14), (329.6, 0.28), (440, 0.42)]
    x = np.zeros(int(SR * 1.0))
    for f, at in notes:
        b = bell(f, 0.5)
        i = int(at * SR)
        x[i: i + len(b)] += 0.7 * b[: len(x) - i]
    x = lowpass_fast(x, 4000)
    return norm(x, 0.6)


def gen_defeat() -> np.ndarray:
    # هبوط حزين: E4 C4 A3
    notes = [(329.6, 0.0), (261.6, 0.2), (220, 0.4)]
    x = np.zeros(int(SR * 1.0))
    for f, at in notes:
        b = bell(f, 0.55)
        b = lowpass_fast(b, 1200)  # أغمق
        i = int(at * SR)
        x[i: i + len(b)] += 0.8 * b[: len(x) - i]
    return norm(x, 0.55)


def gen_alert() -> np.ndarray:
    # إنذار ثنائي النغمة هادئ (ليس مزعجًا)
    t = t_axis(0.8)
    f = np.where((t % 0.4) < 0.2, 784, 588)  # G5 / D5
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + 0.3 * np.sin(2 * phase)
    x = lowpass_fast(x, 2500)
    e = env(len(t), 0.02, 0.15)
    return norm(x * e, 0.5)


def gen_storm() -> np.ndarray:
    # دمدمة عاصفة — ضجيج بني منخفض مع تضخم
    n = int(SR * 1.0)
    brown = np.cumsum(rng.standard_normal(n))
    brown -= np.linspace(brown[0], brown[-1], n)  # إزالة الانزياح
    brown /= np.max(np.abs(brown))
    brown = lowpass_fast(brown, 160)
    swell = np.sin(np.pi * np.linspace(0, 1, n)) ** 2
    boom = np.sin(2 * np.pi * 55 * np.linspace(0, 1, n)) * swell
    return norm(brown * swell * 0.8 + 0.35 * boom, 0.65)


# ---------------------------------------------------------------- حلقات الجو
def gen_wind() -> np.ndarray:
    """رياح 12 ثانية — ضجيج وردي + تذبذب بطيء، حلقة سلسة."""
    dur = 12.0
    n = int(SR * dur)
    pink = np.cumsum(rng.standard_normal(n))
    pink -= np.linspace(pink[0], pink[-1], n)
    pink /= np.max(np.abs(pink))
    # ترشيح ثنائي: جسم الرياح منخفض + صفير عالٍ خفيف
    body = lowpass_fast(pink, 500)
    hiss = lowpass_fast(rng.standard_normal(n), 3000) * 0.25
    lfo = 0.65 + 0.35 * np.sin(2 * np.pi * np.linspace(0, 2.3, n))  # تذبذب بطيء
    x = (body * 0.9 + hiss * 0.3) * lfo
    return seamless(norm(x, 0.5), 1.5)


def gen_music() -> np.ndarray:
    """موسيقى محيطة باردة 48 ثانية — وسادة وترية بطيئة + أجراس متفرقة.

    تقدم: Am → F → C → Em (12 ثانية لكل وتر) — طابع صقيعي هادئ.
    """
    dur = 48.0
    n = int(SR * dur)
    x = np.zeros(n)

    def add_tone(freq, at, length, amp, harmonics=((1, 1.0), (2, 0.28), (3, 0.1))):
        i0, i1 = int(at * SR), min(int((at + length) * SR), n)
        if i0 >= n:
            return
        t = np.arange(i1 - i0) / SR
        seg = np.zeros(len(t))
        for r, a in harmonics:
            seg += a * np.sin(2 * np.pi * freq * r * t)
        # هجوم بطيء وتلاشٍ بطيء — وسادة
        e = np.sin(np.pi * np.linspace(0, 1, len(t))) ** 1.5 if len(t) > 2 else np.ones(len(t))
        x[i0:i1] += amp * seg * e

    # وسادة الوتر: ثلاثة أصوات لكل وتر (تداخل نصف ثانية)
    chords = [
        [220.0, 261.6, 329.6],   # Am
        [174.6, 220.0, 261.6],   # F
        [130.8, 164.8, 196.0],   # C
        [164.8, 196.0, 246.9],   # Em
    ]
    for ci, ch in enumerate(chords):
        at = ci * 12.0
        for f in ch:
            add_tone(f, at, 12.5, 0.16)
            add_tone(f * 0.5, at, 12.5, 0.10)  # عمق إضافي

    # أجراس متفرقة — سلم خماسي (A C D E G) فوق الوسط
    bells = [(880, 3.0), (659.3, 9.5), (784, 15.0), (1046.5, 21.5),
             (880, 27.0), (587.3, 33.5), (784, 39.0), (987.8, 44.0)]
    for f, at in bells:
        add_tone(f, at, 3.5, 0.10, harmonics=((1, 1.0), (2.76, 0.3), (5.4, 0.08)))

    x = lowpass_fast(x, 3500)
    return seamless(norm(x, 0.45), 2.0)  # ذروة متحفظة — هوامش مزج


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    print("توليد المؤثرات:")
    save_wav("click.wav", gen_click())
    save_wav("collect.wav", gen_collect())
    save_wav("build.wav", gen_build())
    save_wav("march.wav", gen_march())
    save_wav("victory.wav", gen_victory())
    save_wav("defeat.wav", gen_defeat())
    save_wav("alert.wav", gen_alert())
    save_wav("storm.wav", gen_storm())
    print("توليد حلقات الجو:")
    wind = save_wav("_wind_tmp.wav", gen_wind())
    music = save_wav("_music_tmp.wav", gen_music())
    # تحويل الحلقات إلى OGG (أصغر بكثير — أنسب للهاتف)
    for src, dst in [("_wind_tmp.wav", "wind.ogg"), ("_music_tmp.wav", "music.ogg")]:
        r = subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(OUT / src),
             "-c:a", "libvorbis", "-qscale:a", "4", str(OUT / dst)],
            capture_output=True, text=True,
        )
        if r.returncode != 0:
            print(f"ffmpeg فشل: {r.stderr}")
            sys.exit(1)
        (OUT / src).unlink()
        print(f"  {dst}: OK")
    print("اكتمل التوليد في", OUT)


if __name__ == "__main__":
    main()
