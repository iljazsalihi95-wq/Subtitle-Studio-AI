"""Generate original branded Android launcher icons with Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw

MODE = "studio"
size = 512
navy = (7, 17, 31) if MODE == "studio" else (7, 27, 23)
gold = (232, 193, 112) if MODE == "studio" else (221, 187, 112)
accent = (34, 58, 83) if MODE == "studio" else (23, 72, 59)
im = Image.new("RGB", (size, size), navy)
d = ImageDraw.Draw(im)
d.rounded_rectangle((24, 24, 488, 488), radius=108, fill=accent, outline=gold, width=11)
if MODE == "studio":
    d.rounded_rectangle((100, 169, 412, 373), radius=27, fill=navy, outline=gold, width=12)
    d.polygon([(107, 159), (375, 105), (406, 166), (132, 220)], fill=gold)
    for x in (150, 220, 290, 360):
        d.line((x, 140, x + 24, 184), fill=navy, width=15)
    d.rounded_rectangle((145, 275, 367, 335), radius=15, outline=gold, width=9)
    d.line((185, 306, 237, 306), fill=gold, width=11)
    d.line((271, 306, 323, 306), fill=gold, width=11)
else:
    d.polygon([(256, 147), (129, 115), (129, 355), (256, 394)], fill=navy)
    d.polygon([(256, 147), (383, 115), (383, 355), (256, 394)], fill=navy)
    d.line([(256, 147), (256, 394)], fill=gold, width=13)
    d.line([(129, 115), (129, 355), (256, 394), (383, 355), (383, 115)], fill=gold, width=15, joint="curve")
    d.line([(151, 158), (226, 180)], fill=gold, width=7)
    d.line([(151, 196), (226, 218)], fill=gold, width=7)
    d.line([(286, 180), (360, 158)], fill=gold, width=7)
    d.line([(286, 218), (360, 196)], fill=gold, width=7)
    d.ellipse((338, 75, 365, 102), fill=gold)
for density, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    out = Path("android/app/src/main/res") / ("mipmap-" + density) / "ic_launcher.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    im.resize((px, px), Image.Resampling.LANCZOS).save(out)
print("Generated original launcher icons:", MODE)
