#!/usr/bin/env python3
"""Draws the game's icon (Nooni with her glasses, cat ears on the corners) into godot/icon.png (needs Pillow)."""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
img = Image.new("RGB", (S, S), (38, 28, 82))
d = ImageDraw.Draw(img)
# Sunset gradient background.
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=(int(60 + 190 * t), int(40 + 90 * t), int(110 - 30 * t)))
# Skyline silhouette.
for i, (x, h) in enumerate([(40, 260), (180, 380), (330, 300), (700, 340), (830, 440), (930, 280)]):
    d.rectangle([x, S - h, x + 110, S], fill=(60, 36, 92))

hair = (62, 30, 20)
skin = (240, 190, 152)
# Long curly hair behind her head.
for cx, cy, r in [(300, 560, 150), (724, 560, 150), (260, 760, 140), (764, 760, 140), (512, 380, 270)]:
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hair)
# Abaya shoulders.
d.ellipse([200, 820, 824, 1300], fill=(34, 40, 92))
# Face.
d.ellipse([312, 330, 712, 790], fill=skin)
# Hair on top.
d.pieslice([300, 250, 724, 640], 180, 360, fill=hair)
for cx in range(340, 700, 70):
    d.ellipse([cx - 45, 300, cx + 45, 390], fill=hair)
# Glasses.
for cx in (420, 604):
    d.ellipse([cx - 82, 520, cx + 82, 684], outline=(24, 18, 40), width=16)
    d.ellipse([cx - 66, 536, cx + 66, 668], fill=(210, 235, 250))
d.line([(502, 592), (522, 592)], fill=(24, 18, 40), width=14)
# Glint on the glasses.
d.polygon([(380, 545), (415, 545), (385, 600), (350, 600)], fill=(255, 255, 255))
# Smile.
d.arc([440, 660, 584, 740], 20, 160, fill=(150, 70, 70), width=10)
# Cat ears peeking in the top corners (Bruce and Semba).
d.polygon([(40, 40), (300, 40), (40, 300)], fill=(40, 40, 60))
d.polygon([(984, 40), (724, 40), (984, 300)], fill=(190, 150, 95))
img = img.filter(ImageFilter.SMOOTH)
out = os.path.join(os.path.dirname(__file__), "..", "godot", "icon.png")
img.resize((512, 512), Image.LANCZOS).save(out)
print("wrote", out)
