"""生成暮色天空全景图（等距柱状投影），供 Godot PanoramaSkyMaterial 使用。

风格：深靛蓝穹顶 → 玫紫中段 → 暖橙地平线，下方是云海，上方有星点。
用法：python tools/make_sky_dusk.py
输出：assets/textures/sky_dusk.png (2048x1024)
"""

import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
W, H = 2048, 1024


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def fbm(shape, octaves, seed, base=4, stretch=1.0):
    h, w = shape
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        gh = max(2, base * (2 ** o))
        gw = max(2, int(gh * 2 * stretch))
        g = rng.random((gh, gw)).astype(np.float32)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += amp * (np.asarray(img, np.float32) / 255.0)
        norm += amp
        amp *= 0.5
    return out / norm


def mix(a, b, t):
    return a * (1.0 - t) + b * t


def main():
    lat = 90.0 - (np.arange(H) + 0.5) / H * 180.0
    lon = (np.arange(W) + 0.5) / W * 360.0
    LAT = lat[:, None]
    LON = lon[None, :]

    # 天空渐变（地平线以上）
    stops_lat = np.array([90.0, 58.0, 26.0, 8.0, 0.0])
    stops_rgb = np.array([
        [0.020, 0.035, 0.105],
        [0.075, 0.095, 0.260],
        [0.330, 0.230, 0.450],
        [0.960, 0.450, 0.310],
        [1.000, 0.640, 0.400],
    ])
    sky = np.zeros((H, W, 3), np.float32)
    for c in range(3):
        sky[:, :, c] = np.interp(lat, stops_lat[::-1], stops_rgb[::-1, c])[:, None]

    # 太阳光晕（方位 300°，仰角 10°）
    sun_lat, sun_lon = np.radians(10.0), np.radians(300.0)
    la, lo = np.radians(LAT), np.radians(LON)
    cosd = np.sin(la) * np.sin(sun_lat) + np.cos(la) * np.cos(sun_lat) * np.cos(lo - sun_lon)
    cosd = np.clip(cosd, 0.0, 1.0)
    glow = (cosd ** 6) * 0.35 + (cosd ** 40) * 0.85
    sky += glow[:, :, None] * np.array([1.0, 0.52, 0.24], np.float32)[None, None, :]

    # 高层卷云
    n1 = fbm((H, W), 5, 7, base=5, stretch=2.2)
    n1 = smoothstep(0.50, 0.70, n1)
    band = smoothstep(3.0, 16.0, LAT) * (1.0 - smoothstep(46.0, 72.0, LAT))
    warm = np.clip(1.0 - LAT / 24.0, 0.0, 1.0)[:, :, None]
    cloud_col = (np.array([0.62, 0.55, 0.72], np.float32)[None, None, :] * (1.0 - warm)
                 + np.array([1.0, 0.68, 0.50], np.float32)[None, None, :] * warm)
    sky = mix(sky, cloud_col, (n1 * band * 0.75)[:, :, None])

    # 地平线附近的一条暖色雾带
    haze = np.exp(-((LAT - 1.0) / 7.0) ** 2) * 0.45
    sky = mix(sky, np.array([1.0, 0.62, 0.42], np.float32)[None, None, :], haze[:, :, None])

    # 星点（仅高空）
    rng = np.random.default_rng(23)
    star_mask = (rng.random((H, W)) > 0.9993) & (LAT > 42.0)
    star_mask = np.asarray(Image.fromarray((star_mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    sky += star_mask[:, :, None] * np.array([0.85, 0.90, 1.0], np.float32)[None, None, :] * 0.9

    # 云海（地平线以下）
    sea_grad = np.zeros((H, W, 3), np.float32)
    t = smoothstep(-55.0, 0.0, LAT)
    for c in range(3):
        sea_grad[:, :, c] = mix(
            np.full_like(LAT, [0.055, 0.075, 0.150][c]),
            np.full_like(LAT, [0.90, 0.58, 0.45][c]),
            t,
        )
    n2 = fbm((H, W), 5, 19, base=6, stretch=3.0)
    sea = smoothstep(0.42, 0.68, n2)
    sea_warm = smoothstep(-45.0, 0.0, LAT)[:, :, None]
    sea_col = (np.array([0.16, 0.20, 0.32], np.float32)[None, None, :] * (1.0 - sea_warm)
               + np.array([1.0, 0.72, 0.58], np.float32)[None, None, :] * sea_warm)
    below = LAT < 0.0
    sea_img = mix(sea_grad, sea_col * np.ones_like(sea_grad), (sea * 0.85 * smoothstep(-60.0, -6.0, LAT))[:, :, None])
    sky = np.where(below[:, :, None], sea_img, sky)

    sky = np.clip(sky, 0.0, 1.0)
    dst = os.path.join(TEX, "sky_dusk.png")
    Image.fromarray((sky * 255).astype(np.uint8)).save(dst, optimize=True)
    print("saved:", dst)


if __name__ == "__main__":
    main()
