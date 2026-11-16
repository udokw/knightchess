"""把原版天空盒贴图拼成 2048x1024 等距全景图，供 Godot PanoramaSkyMaterial 使用。

原版贴图并不是标准立方体面：
  * skybox1_{f,b,l,r} 是 512x512 的竖向切片，只有中间一条是森林，上下是黑边；
  * skybox1_t 是一张天空渐变图。
所以这里按"天空渐变 + 中纬度森林环带 + 地面色"重建全景，而不是做立方体投影。

用法：python tools/make_skybox.py
输出：assets/textures/skybox_panorama.png
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
W, H = 2048, 1024

# 森林带在侧贴图中的行范围（占 512 的比例）与对应的仰角范围
BAND_TOP, BAND_BOTTOM = 0.22, 0.60
LAT_TOP, LAT_BOTTOM = 18.0, -4.0


def load(name: str) -> np.ndarray:
    img = Image.open(os.path.join(TEX, f"skybox1_{name}.png")).convert("RGB")
    return np.asarray(img, dtype=np.float32) / 255.0


def main() -> None:
    sky = load("t")
    sides = [load("f"), load("r"), load("b"), load("l")]
    sky_h, sky_w = sky.shape[:2]

    top_color = sky[int(sky_h * 0.04), sky_w // 2]
    horizon_color = sky[int(sky_h * 0.62), sky_w // 2]

    out = np.zeros((H, W, 3), dtype=np.float32)
    lat = 90.0 - (np.arange(H) + 0.5) / H * 180.0
    lon_deg = (np.arange(W) + 0.5) / W * 360.0

    # 天空渐变（18° 以上）
    t = np.clip((lat - LAT_TOP) / (90.0 - LAT_TOP), 0.0, 1.0)[:, None]
    t = t ** 0.65
    out[:] = horizon_color[None, None, :] * (1 - t[:, :, None]) + top_color[None, None, :] * t[:, :, None]

    # 森林环带
    band = (lat <= LAT_TOP) & (lat >= LAT_BOTTOM)
    if band.any():
        ys = np.where(band)[0]
        v = (LAT_TOP - lat[ys]) / (LAT_TOP - LAT_BOTTOM)
        row = np.clip(((BAND_TOP + (BAND_BOTTOM - BAND_TOP) * v) * 511.0).astype(np.int32), 0, 511)
        quad = np.clip((lon_deg / 90.0).astype(np.int32), 0, 3)
        col = np.clip((((lon_deg % 90.0) / 90.0) * 511.0).astype(np.int32), 0, 511)
        for x in range(W):
            out[ys, x] = sides[quad[x]][row, col[x]]

    # 地面
    ground = (lat < LAT_BOTTOM)
    if ground.any():
        out[ground] = np.array([0.22, 0.31, 0.19], dtype=np.float32)

    dst = os.path.join(TEX, "skybox_panorama.png")
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(dst, optimize=True)
    print("saved:", dst)


if __name__ == "__main__":
    main()
