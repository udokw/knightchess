"""生成 1024x1024 应用图标（纯自绘，不依赖原版素材）。

用法：python tools/make_icon.py [输出路径]
默认输出项目根目录的 icon.png。
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
TEAM_COLORS = [(196, 60, 60), (58, 120, 210), (58, 160, 84), (214, 176, 48)]


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "icon.png")

    # 深绿底 + 径向提亮
    img = Image.new("RGB", (SIZE, SIZE), (14, 24, 16))
    draw = ImageDraw.Draw(img)
    steps = 96
    for i in range(steps):
        r = SIZE * 0.72 * (1 - i / steps)
        k = 1 - i / steps
        color = (int(14 + 26 * k), int(24 + 52 * k), int(16 + 26 * k))
        draw.ellipse([SIZE / 2 - r, SIZE / 2 - r, SIZE / 2 + r, SIZE / 2 + r], fill=color)

    # 四角斜切色块代表四支队伍
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    c = SIZE / 2
    quads = [
        [(0, 0), (SIZE, 0), (c, c)],
        [(SIZE, 0), (SIZE, SIZE), (c, c)],
        [(SIZE, SIZE), (0, SIZE), (c, c)],
        [(0, SIZE), (0, 0), (c, c)],
    ]
    for poly, col in zip(quads, TEAM_COLORS):
        od.polygon(poly, fill=(*col, 165))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    # 中央圆盘 + 白色骑士
    draw = ImageDraw.Draw(img)
    ring = SIZE * 0.415
    draw.ellipse([c - ring, c - ring, c + ring, c + ring], fill=(18, 28, 20))
    draw.ellipse([c - ring, c - ring, c + ring, c + ring], outline=(240, 240, 235), width=18)

    font = ImageFont.truetype(r"C:\Windows\Fonts\seguisym.ttf", int(SIZE * 0.62))
    draw.text((c, c - SIZE * 0.02), "\u265e", font=font, fill=(245, 245, 240), anchor="mm")

    img.save(out, optimize=True)
    print("icon saved:", os.path.abspath(out), img.size)


if __name__ == "__main__":
    main()
