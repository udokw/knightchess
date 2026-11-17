# -*- coding: utf-8 -*-
"""程序化生成骑士飞行棋用的环境音与音效（纯标准库，无外部素材）。

输出到 assets/sounds/：
  amb_dusk / amb_frost / amb_ember   三套主题环境循环（8s，首尾交叉淡入淡出）
  sfx_event      随机事件爆裂
  sfx_bigboom    俄罗斯轮盘触发的全屏爆裂
  sfx_roulette   轮盘旋转拨片滴答
  sfx_win        轮盘命中道具的上扬音阶
  sfx_drop       道具掉落 / 拾取的清脆铃音
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sounds")


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    data = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32000)
        data += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))
    print("%-18s %6.1f KB" % (name, len(data) / 1024.0))


def lowpass(samples, alpha):
    out = []
    prev = 0.0
    for s in samples:
        prev += (s - prev) * alpha
        out.append(prev)
    return out


def normalize(samples, peak=0.9):
    m = max(abs(s) for s in samples) or 1.0
    k = peak / m
    return [s * k for s in samples]


def loopify(samples, fade=0.45):
    """把尾部与头部交叉淡化，得到可无缝循环的片段。"""
    n = len(samples)
    f = int(fade * RATE)
    body = samples[:n - f]
    tail = samples[n - f:]
    head = body[:f]
    mixed = [(head[i] * (i / f) + tail[i] * (1.0 - i / f)) for i in range(f)]
    return body[f:] + mixed


def pad_loop(seconds, layers):
    """layers: [(freq, amp, detune_hz, lfo_hz)] 组成缓慢呼吸的和声垫。"""
    n = int(seconds * RATE)
    out = [0.0] * n
    for freq, amp, det, lfo in layers:
        ph1 = random.random() * math.tau
        ph2 = random.random() * math.tau
        for i in range(n):
            t = i / RATE
            env = 0.55 + 0.45 * math.sin(math.tau * lfo * t + freq * 0.01)
            out[i] += amp * env * (
                math.sin(math.tau * freq * t + ph1) * 0.6 +
                math.sin(math.tau * (freq + det) * t + ph2) * 0.4
            )
    return out


def noise(n, smooth=0.2):
    rnd = random.Random(4242)
    raw = [rnd.uniform(-1.0, 1.0) for _ in range(n)]
    return lowpass(raw, smooth)


def amb_dusk():
    n = int(8.0 * RATE)
    out = pad_loop(8.0, [
        (110.0, 0.16, 0.6, 0.09),
        (164.81, 0.11, -0.5, 0.07),
        (220.0, 0.08, 0.9, 0.05),
        (329.63, 0.05, -0.8, 0.04),
        (440.0, 0.028, 0.4, 0.03),
    ])
    wind = noise(n, 0.012)
    for i in range(n):
        t = i / RATE
        out[i] += wind[i] * 0.10 * (0.5 + 0.5 * math.sin(math.tau * 0.06 * t))
        # 远处的钟声泛音
        out[i] += 0.022 * math.sin(math.tau * 880.0 * t) * (0.5 + 0.5 * math.sin(math.tau * 0.13 * t))
    out = lowpass(out, 0.6)
    return loopify(normalize(out, 0.55))


def amb_frost():
    n = int(8.0 * RATE)
    out = pad_loop(8.0, [
        (196.0, 0.10, 0.4, 0.05),
        (293.66, 0.08, -0.4, 0.045),
        (392.0, 0.06, 0.7, 0.035),
        (587.33, 0.04, -0.6, 0.025),
        (880.0, 0.022, 0.3, 0.02),
    ])
    hiss = noise(n, 0.35)
    rnd = random.Random(99)
    bells = []
    for _ in range(14):
        bells.append((rnd.uniform(0.0, 7.6), rnd.choice([1318.5, 1567.98, 1760.0, 2093.0]), rnd.uniform(0.4, 1.4)))
    for i in range(n):
        t = i / RATE
        out[i] += hiss[i] * 0.05
        for bt, bf, dur in bells:
            dt = t - bt
            if 0.0 <= dt <= dur:
                env = math.exp(-dt * 4.5) * (1.0 - dt / dur)
                out[i] += 0.05 * env * math.sin(math.tau * bf * dt)
    return loopify(normalize(out, 0.5))


def amb_ember():
    n = int(8.0 * RATE)
    out = pad_loop(8.0, [
        (55.0, 0.24, 0.3, 0.08),
        (82.41, 0.14, -0.3, 0.06),
        (110.0, 0.1, 0.5, 0.05),
        (164.81, 0.05, -0.4, 0.04),
    ])
    rumble = lowpass(noise(n, 0.02), 0.25)
    rnd = random.Random(711)
    crackles = [(rnd.uniform(0.0, 7.9), rnd.uniform(0.6, 1.4), rnd.uniform(0.02, 0.06)) for _ in range(90)]
    for i in range(n):
        t = i / RATE
        out[i] += rumble[i] * 0.30 * (0.6 + 0.4 * math.sin(math.tau * 0.09 * t))
        for ct, amp, dur in crackles:
            dt = t - ct
            if 0.0 <= dt <= dur:
                out[i] += amp * 0.14 * math.exp(-dt * 34.0) * math.sin(math.tau * 2200.0 * dt)
    out = lowpass(out, 0.55)
    return loopify(normalize(out, 0.62))


def amb_jade():
    """翠玉遗迹：竹风 + 五声音阶风铃 + 低沉玉磬。"""
    n = int(8.0 * RATE)
    out = pad_loop(8.0, [
        (98.0, 0.13, 0.4, 0.06),
        (146.83, 0.10, -0.4, 0.05),
        (196.0, 0.07, 0.6, 0.04),
        (293.66, 0.04, -0.5, 0.03),
    ])
    breeze = lowpass(noise(n, 0.06), 0.35)
    rnd = random.Random(2026)
    chimes = []
    for _ in range(26):
        chimes.append((rnd.uniform(0.0, 7.7), rnd.choice([523.25, 587.33, 659.25, 783.99, 880.0]),
                       rnd.uniform(0.5, 1.6)))
    for i in range(n):
        t = i / RATE
        out[i] += breeze[i] * 0.07 * (0.55 + 0.45 * math.sin(math.tau * 0.07 * t))
        for ct, cf, dur in chimes:
            dt = t - ct
            if 0.0 <= dt <= dur:
                env = math.exp(-dt * 5.5) * (1.0 - dt / dur)
                out[i] += 0.055 * env * (math.sin(math.tau * cf * dt) + 0.3 * math.sin(math.tau * cf * 2.01 * dt))
    out = lowpass(out, 0.72)
    return loopify(normalize(out, 0.52))


def amb_void():
    """虚空星海：深空低频嗡鸣 + 缓慢上浮的闪烁泛音。"""
    n = int(8.0 * RATE)
    out = pad_loop(8.0, [
        (41.20, 0.20, 0.2, 0.03),
        (61.74, 0.13, -0.2, 0.04),
        (82.41, 0.08, 0.3, 0.05),
        (123.47, 0.05, -0.3, 0.03),
    ])
    air = noise(n, 0.15)
    rnd = random.Random(3141)
    shimmer = [(rnd.uniform(0.0, 8.0), rnd.choice([1244.5, 1661.2, 1864.7, 2349.3]),
                rnd.uniform(0.8, 2.6)) for _ in range(16)]
    for i in range(n):
        t = i / RATE
        out[i] += air[i] * 0.06 * (0.4 + 0.6 * math.sin(math.tau * 0.04 * t))
        out[i] += 0.02 * math.sin(math.tau * 55.0 * t) * (0.5 + 0.5 * math.sin(math.tau * 0.11 * t))
        for st, sf, dur in shimmer:
            dt = t - st
            if 0.0 <= dt <= dur:
                env = math.exp(-dt * 2.2) * (1.0 - dt / dur)
                out[i] += 0.03 * env * math.sin(math.tau * sf * dt)
    out = lowpass(out, 0.8)
    return loopify(normalize(out, 0.5))


def sfx_explosion(name, seconds, low, bright, tail):
    n = int(seconds * RATE)
    rnd = random.Random(31)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * tail)
        body = math.sin(math.tau * low * t * (1.0 - t * 0.55)) * 0.8
        noise_part = rnd.uniform(-1.0, 1.0) * bright * math.exp(-t * 9.0)
        out.append((body + noise_part) * env)
    out = lowpass(out, 0.5)
    return normalize(out, 0.95)


def sfx_event():
    n = int(1.8 * RATE)
    base = sfx_explosion("x", 1.8, 120.0, 0.55, 2.6)
    rnd = random.Random(77)
    for i in range(n):
        t = i / RATE
        if t > 0.12:
            base[i] += 0.18 * math.sin(math.tau * (900.0 - 500.0 * t) * t) * math.exp(-(t - 0.12) * 4.0)
        base[i] += rnd.uniform(-0.02, 0.02) * math.exp(-t * 2.0)
    return normalize(base, 0.92)


def sfx_bigboom():
    n = int(2.6 * RATE)
    base = sfx_explosion("x", 2.6, 58.0, 0.7, 2.1)
    rnd = random.Random(5)
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 1.6)
        base[i] += 0.32 * env * math.sin(math.tau * 44.0 * t)
        base[i] += 0.12 * env * math.sin(math.tau * (1600.0 - 520.0 * t) * t)
        base[i] += rnd.uniform(-0.03, 0.03) * env
    out = lowpass(base, 0.65)
    return normalize(out, 1.0)


def sfx_roulette():
    n = int(0.085 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 70.0)
        out.append(env * (math.sin(math.tau * 1850.0 * t) * 0.5 + (1.0 if (i % 9) == 0 else -1.0) * 0.12))
    return normalize(out, 0.8)


def sfx_win():
    n = int(1.5 * RATE)
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    out = [0.0] * n
    for k, f in enumerate(notes):
        start = 0.11 * k
        for i in range(n):
            t = i / RATE - start
            if t < 0:
                continue
            env = math.exp(-t * 5.0)
            out[i] += 0.22 * env * (math.sin(math.tau * f * t) + 0.35 * math.sin(math.tau * f * 2.0 * t))
    for i in range(n):
        t = i / RATE
        out[i] += 0.05 * math.sin(math.tau * 2637.0 * t) * math.exp(-t * 6.0)
    return normalize(out, 0.85)


def sfx_drop():
    n = int(0.9 * RATE)
    out = [0.0] * n
    for k, f in enumerate([1174.66, 1567.98, 2093.0]):
        start = 0.055 * k
        for i in range(n):
            t = i / RATE - start
            if t < 0:
                continue
            env = math.exp(-t * 9.0)
            out[i] += 0.26 * env * math.sin(math.tau * f * t)
    return normalize(out, 0.8)


def main():
    write_wav("amb_dusk.wav", amb_dusk())
    write_wav("amb_frost.wav", amb_frost())
    write_wav("amb_ember.wav", amb_ember())
    write_wav("amb_jade.wav", amb_jade())
    write_wav("amb_void.wav", amb_void())
    write_wav("sfx_event.wav", sfx_event())
    write_wav("sfx_bigboom.wav", sfx_bigboom())
    write_wav("sfx_roulette.wav", sfx_roulette())
    write_wav("sfx_win.wav", sfx_win())
    write_wav("sfx_drop.wav", sfx_drop())


if __name__ == "__main__":
    main()
