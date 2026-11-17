"""生成另外两套棋盘主题的全景天空（等距柱状投影）。

霜封荒原：冷靛穹顶 -> 冰蓝中段 -> 苍白地平线，下方是冻结云海。
熔火深渊：黑红穹顶 -> 暗紫中段 -> 炽橙地平线，下方是熔岩雾海。
用法：python tools/make_skies.py
输出：assets/textures/sky_frost.png / sky_ember.png (2048x1024)
"""

import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
W, H = 2048, 1024

THEMES = {
    "frost": {
        "stops_lat": [90.0, 62.0, 30.0, 10.0, 0.0],
        "stops_rgb": [
            [0.012, 0.030, 0.075],
            [0.090, 0.190, 0.330],
            [0.320, 0.520, 0.700],
            [0.760, 0.880, 0.980],
            [0.900, 0.960, 1.000],
        ],
        "sun_rgb": [0.70, 0.90, 1.00],
        "sun_lat": 7.0,
        "sun_lon": 315.0,
        "glow": (0.24, 0.55),
        "cloud_hi": [0.78, 0.86, 0.95],
        "cloud_lo": [0.86, 0.94, 1.00],
        "haze_rgb": [0.80, 0.92, 1.00],
        "haze_amt": 0.38,
        "sea_deep": [0.070, 0.130, 0.210],
        "sea_near": [0.620, 0.790, 0.930],
        "sea_col_lo": [0.180, 0.290, 0.420],
        "sea_col_hi": [0.800, 0.910, 1.000],
        "star_thresh": 0.99955,
        "star_rgb": [0.85, 0.94, 1.00],
        "star_lat": 38.0,
    },
    "ember": {
        "stops_lat": [90.0, 60.0, 28.0, 9.0, 0.0],
        "stops_rgb": [
            [0.040, 0.010, 0.016],
            [0.170, 0.045, 0.055],
            [0.430, 0.100, 0.070],
            [0.960, 0.330, 0.090],
            [1.000, 0.520, 0.170],
        ],
        "sun_rgb": [1.00, 0.42, 0.12],
        "sun_lat": 5.0,
        "sun_lon": 288.0,
        "glow": (0.40, 0.95),
        "cloud_hi": [0.260, 0.110, 0.130],
        "cloud_lo": [0.560, 0.210, 0.140],
        "haze_rgb": [1.000, 0.380, 0.150],
        "haze_amt": 0.42,
        "sea_deep": [0.090, 0.020, 0.018],
        "sea_near": [0.900, 0.340, 0.120],
        "sea_col_lo": [0.220, 0.050, 0.030],
        "sea_col_hi": [1.000, 0.520, 0.220],
        "star_thresh": 0.99965,
        "star_rgb": [1.00, 0.72, 0.45],
        "star_lat": 48.0,
    },
    "jade": {
        "stops_lat": [90.0, 60.0, 30.0, 10.0, 0.0],
        "stops_rgb": [
            [0.010, 0.045, 0.038],
            [0.045, 0.200, 0.150],
            [0.220, 0.560, 0.400],
            [0.780, 0.960, 0.820],
            [0.900, 1.000, 0.880],
        ],
        "sun_rgb": [0.80, 1.00, 0.72],
        "sun_lat": 12.0,
        "sun_lon": 330.0,
        "glow": (0.30, 0.70),
        "cloud_hi": [0.62, 0.85, 0.72],
        "cloud_lo": [0.86, 0.98, 0.88],
        "haze_rgb": [0.85, 1.00, 0.90],
        "haze_amt": 0.34,
        "sea_deep": [0.030, 0.090, 0.070],
        "sea_near": [0.520, 0.880, 0.700],
        "sea_col_lo": [0.080, 0.240, 0.180],
        "sea_col_hi": [0.700, 0.980, 0.820],
        "star_thresh": 0.99970,
        "star_rgb": [0.85, 1.00, 0.92],
        "star_lat": 38.0,
    },
    "void": {
        "stops_lat": [90.0, 58.0, 26.0, 8.0, 0.0],
        "stops_rgb": [
            [0.008, 0.006, 0.030],
            [0.045, 0.030, 0.130],
            [0.140, 0.080, 0.300],
            [0.420, 0.230, 0.620],
            [0.640, 0.420, 0.850],
        ],
        "sun_rgb": [0.70, 0.55, 1.00],
        "sun_lat": 6.0,
        "sun_lon": 300.0,
        "glow": (0.45, 1.00),
        "cloud_hi": [0.100, 0.070, 0.240],
        "cloud_lo": [0.340, 0.200, 0.550],
        "haze_rgb": [0.550, 0.420, 0.950],
        "haze_amt": 0.40,
        "sea_deep": [0.030, 0.020, 0.070],
        "sea_near": [0.300, 0.180, 0.560],
        "sea_col_lo": [0.060, 0.040, 0.160],
        "sea_col_hi": [0.480, 0.340, 0.900],
        "star_thresh": 0.99920,
        "star_rgb": [0.86, 0.80, 1.00],
        "star_lat": 22.0,
    },
}


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


def build(theme_id, cfg, seed):
    lat = 90.0 - (np.arange(H) + 0.5) / H * 180.0
    lon = (np.arange(W) + 0.5) / W * 360.0
    LAT = lat[:, None]
    LON = lon[None, :]

    stops_lat = np.array(cfg["stops_lat"])
    stops_rgb = np.array(cfg["stops_rgb"])
    sky = np.zeros((H, W, 3), np.float32)
    for c in range(3):
        sky[:, :, c] = np.interp(lat, stops_lat[::-1], stops_rgb[::-1, c])[:, None]

    # 主光源光晕
    sun_lat = np.radians(cfg["sun_lat"])
    sun_lon = np.radians(cfg["sun_lon"])
    la, lo = np.radians(LAT), np.radians(LON)
    cosd = np.sin(la) * np.sin(sun_lat) + np.cos(la) * np.cos(sun_lat) * np.cos(lo - sun_lon)
    cosd = np.clip(cosd, 0.0, 1.0)
    wide, tight = cfg["glow"]
    glow = (cosd ** 6) * wide + (cosd ** 40) * tight
    sky += glow[:, :, None] * np.array(cfg["sun_rgb"], np.float32)[None, None, :]

    # 层云
    n1 = fbm((H, W), 5, seed + 3, base=5, stretch=2.4)
    n1 = smoothstep(0.50, 0.70, n1)
    band = smoothstep(2.0, 15.0, LAT) * (1.0 - smoothstep(48.0, 74.0, LAT))
    warm = np.clip(1.0 - LAT / 26.0, 0.0, 1.0)[:, :, None]
    cloud_col = (np.array(cfg["cloud_hi"], np.float32)[None, None, :] * (1.0 - warm)
                 + np.array(cfg["cloud_lo"], np.float32)[None, None, :] * warm)
    sky = mix(sky, cloud_col, (n1 * band * 0.72)[:, :, None])

    # 地平线雾带
    haze = np.exp(-((LAT - 1.0) / 7.5) ** 2) * cfg["haze_amt"]
    sky = mix(sky, np.array(cfg["haze_rgb"], np.float32)[None, None, :], haze[:, :, None])

    # 星点
    rng = np.random.default_rng(seed + 11)
    star_mask = (rng.random((H, W)) > cfg["star_thresh"]) & (LAT > cfg["star_lat"])
    star_mask = np.asarray(
        Image.fromarray((star_mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)),
        np.float32,
    ) / 255.0
    sky += star_mask[:, :, None] * np.array(cfg["star_rgb"], np.float32)[None, None, :] * 0.85

    # 地平线以下的云海 / 雾海
    sea_grad = np.zeros((H, W, 3), np.float32)
    t = smoothstep(-55.0, 0.0, LAT)
    for c in range(3):
        sea_grad[:, :, c] = mix(
            np.full_like(LAT, cfg["sea_deep"][c]),
            np.full_like(LAT, cfg["sea_near"][c]),
            t,
        )
    n2 = fbm((H, W), 5, seed + 17, base=6, stretch=3.0)
    sea = smoothstep(0.42, 0.68, n2)
    sea_warm = smoothstep(-45.0, 0.0, LAT)[:, :, None]
    sea_col = (np.array(cfg["sea_col_lo"], np.float32)[None, None, :] * (1.0 - sea_warm)
               + np.array(cfg["sea_col_hi"], np.float32)[None, None, :] * sea_warm)
    below = LAT < 0.0
    sea_img = mix(sea_grad, sea_col * np.ones_like(sea_grad),
                  (sea * 0.85 * smoothstep(-60.0, -6.0, LAT))[:, :, None])
    sky = np.where(below[:, :, None], sea_img, sky)

    sky = np.clip(sky, 0.0, 1.0)
    dst = os.path.join(TEX, "sky_%s.png" % theme_id)
    Image.fromarray((sky * 255).astype(np.uint8)).save(dst, optimize=True)
    print("saved:", dst)


def main():
    for i, (tid, cfg) in enumerate(THEMES.items()):
        build(tid, cfg, seed=101 + i * 37)


if __name__ == "__main__":
    main()
