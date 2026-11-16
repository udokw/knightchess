"""程序化生成可平铺的石材贴图（albedo + roughness），给石台/石板/底座用。

不做任何外部素材依赖：全部用 numpy 的周期性格点噪声叠出来，
保证 1024×1024 四边无缝，Godot 里直接开三向投影即可。

用法：python tools/make_stone.py
输出：assets/textures/stone_albedo.png / assets/textures/stone_rough.png
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
SIZE = 1024


def smooth(t: np.ndarray) -> np.ndarray:
    return t * t * (3.0 - 2.0 * t)


def periodic_noise(rng: np.random.Generator, grid: int, size: int) -> np.ndarray:
    """周期性双线性插值噪声：格点首尾相接，保证可平铺。"""
    g = rng.random((grid, grid), dtype=np.float32)
    x = np.arange(size, dtype=np.float32) / size * grid
    y = np.arange(size, dtype=np.float32) / size * grid
    xi = np.floor(x).astype(np.int32)
    yi = np.floor(y).astype(np.int32)
    xf = smooth(x - xi)[None, :]
    yf = smooth(y - yi)[:, None]
    x0 = xi % grid
    x1 = (xi + 1) % grid
    y0 = yi % grid
    y1 = (yi + 1) % grid
    v00 = g[np.ix_(y0, x0)]
    v10 = g[np.ix_(y0, x1)]
    v01 = g[np.ix_(y1, x0)]
    v11 = g[np.ix_(y1, x1)]
    top = v00 * (1.0 - xf) + v10 * xf
    bot = v01 * (1.0 - xf) + v11 * xf
    return top * (1.0 - yf) + bot * yf


def fbm(rng: np.random.Generator, size: int, octaves: int, base: int) -> np.ndarray:
    out = np.zeros((size, size), dtype=np.float32)
    amp = 1.0
    total = 0.0
    grid = base
    for _ in range(octaves):
        out += periodic_noise(rng, grid, size) * amp
        total += amp
        amp *= 0.5
        grid *= 2
    return out / total


def ridged(rng: np.random.Generator, size: int, octaves: int, base: int) -> np.ndarray:
    n = fbm(rng, size, octaves, base)
    return 1.0 - np.abs(n * 2.0 - 1.0)


def main() -> None:
    rng = np.random.default_rng(20261117)
    size = SIZE

    coarse = fbm(rng, size, 6, 4)
    fine = fbm(rng, size, 6, 64)
    micro = fbm(rng, size, 4, 160)
    grain = rng.random((size, size), dtype=np.float32)
    veins = ridged(rng, size, 5, 8)

    # 基础色调：冷灰蓝的花岗岩，带一点暖灰
    dark = np.array([0.085, 0.100, 0.135], dtype=np.float32)
    light = np.array([0.255, 0.285, 0.345], dtype=np.float32)
    t = np.clip(coarse * 1.3 + (fine - 0.5) * 0.7 + (micro - 0.5) * 0.35, 0.0, 1.0)[:, :, None]
    col = dark[None, None, :] * (1.0 - t) + light[None, None, :] * t

    # 细颗粒：石面砂感
    col = col + (grain[:, :, None] - 0.5) * 0.055

    # 矿脉：细亮的线
    vein = np.clip((veins - 0.80) / 0.12, 0.0, 1.0)[:, :, None]
    col = col + vein * np.array([0.20, 0.21, 0.24], dtype=np.float32)

    # 结晶亮点
    spark = np.clip((micro - 0.86) / 0.08, 0.0, 1.0)[:, :, None]
    col = col + spark * 0.26

    # 暗裂
    crack = np.clip((0.13 - veins) / 0.09, 0.0, 1.0)[:, :, None]
    col = col * (1.0 - crack * 0.65)

    # 逐块明暗（模拟石材拼接的色差）
    block = periodic_noise(rng, 4, size)
    col = col * (0.88 + block[:, :, None] * 0.26)

    albedo = np.clip(col, 0.0, 1.0)
    Image.fromarray((albedo * 255.0).astype(np.uint8)).save(
        os.path.join(TEX, "stone_albedo.png"), optimize=True
    )

    # 粗糙度：整体偏粗糙，矿脉/结晶处更亮（更粗糙），裂缝更暗（更光滑的阴影）
    rough = np.clip(
        0.66 + (fine - 0.5) * 0.22 + (grain - 0.5) * 0.10 + vein * 0.12 - crack * 0.22,
        0.25, 0.98,
    )[:, :, 0]
    Image.fromarray((rough * 255.0).astype(np.uint8)).convert("L").save(
        os.path.join(TEX, "stone_rough.png"), optimize=True
    )
    print("saved stone_albedo.png / stone_rough.png at", TEX)


if __name__ == "__main__":
    main()
