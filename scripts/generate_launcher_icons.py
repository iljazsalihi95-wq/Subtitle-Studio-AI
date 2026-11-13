"""Render an original premium Subtitle Studio AI launcher mark (no external assets)."""
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4
S = SIZE * SCALE
# Render the gradient at final resolution; avoid 16.7 million Python pixel writes.
# The vector artwork below is still supersampled for crisp launcher sizes.
background = Image.new("RGB", (SIZE, SIZE))
bp = background.load()
for y in range(SIZE):
    t = y / (SIZE - 1)
    for x in range(SIZE):
        glow = max(0.0, 1.0 - ((x / SIZE - .70) ** 2 + (y / SIZE - .22) ** 2) * 3.3)
        bp[x, y] = (
            int(7 + 16 * (1-t) + 9 * glow),
            int(13 + 24 * (1-t) + 18 * glow),
            int(28 + 37 * (1-t) + 25 * glow),
        )
im = background.resize((S, S), Image.Resampling.BICUBIC)
gold = (244, 203, 120)
white = (245, 249, 255)
d = ImageDraw.Draw(im)
def rect(box, radius, fill, outline=None, width=1):
    d.rounded_rectangle(tuple(int(v*SCALE) for v in box), radius=radius*SCALE,
                        fill=fill, outline=outline, width=width*SCALE)
# The mark is deliberately bold at 48px: film frame, dual subtitles and timeline.
rect((84, 84, 940, 940), 205, (17, 35, 58), gold, 20)
rect((166, 230, 858, 744), 92, (9, 19, 36), (91, 124, 156), 10)
# Film perforations, not emoji or borrowed artwork.
for x in (223, 344, 465, 586, 707):
    rect((x, 267, x+70, 305), 12, gold)
    rect((x, 669, x+70, 707), 12, gold)
# Speech lines with visual hierarchy.
rect((245, 379, 779, 423), 20, white)
rect((303, 461, 721, 505), 20, white)
rect((380, 543, 644, 571), 14, gold)
# Playback/timeline accent.
d.ellipse((465*SCALE, 788*SCALE, 559*SCALE, 882*SCALE), fill=gold)
im = im.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
assert im.getbbox() is not None, "Launcher artwork is empty"
for density, px in (("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)):
    out = Path("android/app/src/main/res") / f"mipmap-{density}" / "ic_launcher.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    icon = im.resize((px,px), Image.Resampling.LANCZOS)
    assert icon.size == (px, px)
    icon.save(out)
print("Generated original premium Subtitle Studio AI launcher icons")
