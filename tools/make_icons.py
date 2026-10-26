"""Flat UI icons (96x96 PNG) for the game, drawn with Pillow."""
import os, math
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)
S = 384

def new():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)

def save(im, n):
    im.resize((96, 96), Image.LANCZOS).save(os.path.join(OUT, n + ".png"))

def outline(d, shape, xy, fill, w=18, **kw):
    getattr(d, shape)(xy, fill=fill, outline=(25, 30, 40, 255), width=w, **kw)

# food: meat leg
im, d = new()
outline(d, "ellipse", (70, 60, 290, 260), (205, 85, 70, 255))
d.ellipse((110, 95, 220, 190), fill=(235, 130, 110, 255))
outline(d, "rectangle", (230, 230, 290, 330), (245, 235, 220, 255))
outline(d, "ellipse", (255, 290, 335, 360), (245, 235, 220, 255))
outline(d, "ellipse", (215, 300, 290, 370), (245, 235, 220, 255))
save(im, "food")
# wood: logs
im, d = new()
for (x, y) in [(60, 190), (200, 190), (130, 70)]:
    outline(d, "ellipse", (x, y, x + 130, y + 130), (160, 105, 60, 255))
    d.ellipse((x + 30, y + 30, x + 100, y + 100), fill=(215, 165, 110, 255))
    d.ellipse((x + 52, y + 52, x + 78, y + 78), fill=(160, 105, 60, 255))
save(im, "wood")
# coal
im, d = new()
outline(d, "polygon", [(70, 250), (120, 120), (230, 80), (320, 160), (320, 280), (200, 330)], (55, 58, 66, 255))
d.polygon([(130, 140), (220, 105), (250, 170), (160, 200)], fill=(105, 110, 122, 255))
save(im, "coal")
# iron ingot
im, d = new()
outline(d, "polygon", [(50, 260), (110, 150), (320, 150), (340, 260)], (150, 170, 190, 255))
d.polygon([(120, 165), (305, 165), (290, 200), (130, 200)], fill=(210, 225, 238, 255))
outline(d, "polygon", [(50, 260), (340, 260), (330, 300), (60, 300)], (110, 128, 148, 255))
save(im, "iron")
# gem
im, d = new()
outline(d, "polygon", [(192, 340), (50, 160), (110, 70), (274, 70), (334, 160)], (70, 190, 255, 255))
d.polygon([(110, 70), (192, 160), (274, 70)], fill=(160, 225, 255, 255))
d.polygon([(50, 160), (192, 160), (192, 340)], fill=(40, 140, 220, 255))
save(im, "gem")
# population
im, d = new()
outline(d, "ellipse", (140, 50, 245, 155), (240, 215, 185, 255))
outline(d, "pieslice", (85, 170, 300, 400), (80, 140, 200, 255), start=180, end=360)
save(im, "pop")
# temperature
im, d = new()
outline(d, "rounded_rectangle", (155, 40, 230, 260), (240, 245, 250, 255), radius=36)
outline(d, "ellipse", (120, 220, 265, 360), (230, 80, 60, 255))
d.rectangle((180, 120, 205, 250), fill=(230, 80, 60, 255))
save(im, "temp")
# time
im, d = new()
outline(d, "ellipse", (50, 50, 334, 334), (245, 230, 190, 255))
d.line((192, 192, 192, 95), fill=(25, 30, 40, 255), width=22)
d.line((192, 192, 265, 230), fill=(25, 30, 40, 255), width=22)
save(im, "time")
# sick
im, d = new()
outline(d, "rounded_rectangle", (60, 60, 324, 324), (245, 245, 248, 255), radius=60)
d.rectangle((160, 100, 224, 284), fill=(215, 60, 60, 255)); d.rectangle((100, 160, 284, 224), fill=(215, 60, 60, 255))
save(im, "sick")
# hammer (builder)
im, d = new()
outline(d, "polygon", [(170, 150), (215, 150), (225, 350), (160, 350)], (165, 110, 65, 255))
outline(d, "rounded_rectangle", (70, 60, 320, 160), (140, 150, 165, 255), radius=20)
save(im, "hammer")
# lock
im, d = new()
d.arc((110, 40, 274, 220), 180, 360, fill=(25, 30, 40, 255), width=50)
d.arc((125, 55, 259, 205), 180, 360, fill=(170, 180, 190, 255), width=20)
outline(d, "rounded_rectangle", (80, 150, 304, 340), (232, 180, 74, 255), radius=30)
save(im, "lock")
# fire
im, d = new()
outline(d, "polygon", [(192, 30), (300, 200), (290, 300), (192, 350), (94, 300), (84, 200), (150, 150)], (255, 140, 50, 255))
d.polygon([(192, 170), (250, 260), (192, 320), (134, 260)], fill=(255, 220, 110, 255))
save(im, "fire")
# task scroll
im, d = new()
outline(d, "rounded_rectangle", (80, 50, 304, 334), (245, 230, 190, 255), radius=30)
for y in (120, 180, 240):
    d.line((125, y, 260, y), fill=(120, 90, 60, 255), width=18)
save(im, "task")
# map
im, d = new()
outline(d, "polygon", [(50, 90), (150, 60), (240, 90), (334, 60), (334, 300), (240, 330), (150, 300), (50, 330)], (150, 200, 230, 255))
d.line((150, 70, 150, 300), fill=(25, 30, 40, 255), width=14); d.line((240, 90, 240, 320), fill=(25, 30, 40, 255), width=14)
d.ellipse((170, 150, 220, 200), fill=(220, 60, 60, 255))
save(im, "map")
# gear
im, d = new()
for k in range(8):
    a = k * math.pi / 4
    x, y = 192 + math.cos(a) * 125, 192 + math.sin(a) * 125
    d.ellipse((x - 42, y - 42, x + 42, y + 42), fill=(25, 30, 40, 255))
    d.ellipse((x - 26, y - 26, x + 26, y + 26), fill=(180, 190, 205, 255))
outline(d, "ellipse", (75, 75, 309, 309), (180, 190, 205, 255))
d.ellipse((145, 145, 239, 239), fill=(25, 30, 40, 255))
save(im, "gear")
# gift
im, d = new()
outline(d, "rectangle", (70, 150, 314, 330), (220, 70, 90, 255))
outline(d, "rectangle", (55, 110, 329, 170), (240, 90, 110, 255))
d.rectangle((170, 110, 214, 330), fill=(240, 200, 80, 255))
d.ellipse((110, 40, 190, 120), outline=(240, 200, 80, 255), width=22); d.ellipse((194, 40, 274, 120), outline=(240, 200, 80, 255), width=22)
save(im, "gift")

K = (25, 30, 40, 255)
# army: crossed swords
im, d = new()
for flip in (1, -1):
    pts = [(192 - flip * 130, 60), (192 - flip * 100, 40), (192 + flip * 120, 280), (192 + flip * 95, 300)]
    outline(d, "polygon", pts, (205, 215, 228, 255), 14)
    cx, cy = 192 + flip * 110, 295
    outline(d, "rounded_rectangle", (cx - 22, cy - 22, cx + 22, cy + 60), (165, 110, 65, 255), 12, radius=10)
    outline(d, "polygon", [(cx - 60, cy - 30), (cx + 40, cy - 70), (cx + 55, cy - 45), (cx - 45, cy - 5)], (232, 180, 74, 255), 12)
save(im, "army")
# shield troop
im, d = new()
outline(d, "polygon", [(192, 40), (320, 90), (300, 240), (192, 350), (84, 240), (64, 90)], (80, 140, 200, 255))
d.polygon([(192, 85), (275, 115), (262, 225), (192, 300)], fill=(140, 190, 235, 255))
save(im, "shield")
# spear troop
im, d = new()
outline(d, "polygon", [(180, 120), (204, 120), (214, 360), (170, 360)], (165, 110, 65, 255), 14)
outline(d, "polygon", [(192, 20), (240, 130), (192, 160), (144, 130)], (215, 225, 238, 255))
outline(d, "rectangle", (150, 160, 234, 185), (210, 70, 60, 255), 12)
save(im, "spear")
# bow troop
im, d = new()
d.arc((60, 40, 300, 344), 270, 90, fill=K, width=50)
d.arc((75, 55, 285, 329), 270, 90, fill=(165, 110, 65, 255), width=22)
d.line((180, 52, 180, 332), fill=(235, 235, 235, 255), width=8)
outline(d, "polygon", [(40, 192), (300, 182), (300, 202)], (215, 225, 238, 255), 10)
outline(d, "polygon", [(330, 192), (290, 160), (290, 224)], (215, 225, 238, 255), 10)
save(im, "bow")
# hero: helmet with plume
im, d = new()
outline(d, "pieslice", (70, 80, 314, 330), (232, 180, 74, 255), start=180, end=360)
outline(d, "rectangle", (70, 200, 314, 300), (232, 180, 74, 255))
d.rectangle((120, 215, 264, 245), fill=K)
d.rectangle((180, 240, 204, 300), fill=K)
outline(d, "polygon", [(192, 90), (150, 20), (260, 30), (230, 95)], (215, 60, 60, 255), 12)
save(im, "hero")
# research: flask
im, d = new()
outline(d, "polygon", [(150, 40), (234, 40), (234, 150), (330, 330), (54, 330), (150, 150)], (225, 240, 250, 255))
d.polygon([(118, 230), (266, 230), (310, 315), (74, 315)], fill=(90, 220, 240, 255))
d.ellipse((160, 255, 195, 290), fill=(200, 250, 255, 255)); d.ellipse((215, 270, 240, 295), fill=(200, 250, 255, 255))
outline(d, "rectangle", (135, 30, 249, 60), (180, 190, 205, 255), 12)
save(im, "research")
# aurora crystal
im, d = new()
outline(d, "polygon", [(192, 20), (262, 150), (230, 350), (154, 350), (122, 150)], (120, 240, 255, 255))
d.polygon([(192, 20), (192, 350), (154, 350), (122, 150)], fill=(80, 200, 240, 255))
outline(d, "polygon", [(90, 170), (130, 220), (115, 340), (70, 340), (55, 230)], (180, 140, 255, 255), 12)
outline(d, "polygon", [(300, 190), (330, 240), (318, 340), (280, 340), (265, 250)], (180, 140, 255, 255), 12)
save(im, "aurora")
# decision: two-way signpost
im, d = new()
outline(d, "rectangle", (175, 60, 209, 360), (165, 110, 65, 255), 12)
outline(d, "polygon", [(60, 90), (280, 90), (330, 135), (280, 180), (60, 180)], (232, 180, 74, 255))
outline(d, "polygon", [(324, 200), (104, 200), (54, 245), (104, 290), (324, 290)], (110, 180, 230, 255))
save(im, "decision")
# wolf head
im, d = new()
outline(d, "polygon", [(80, 40), (150, 120), (234, 120), (304, 40), (320, 200), (192, 350), (64, 200)], (140, 150, 165, 255))
d.polygon([(130, 230), (254, 230), (192, 340)], fill=(220, 225, 232, 255))
d.ellipse((125, 160, 165, 195), fill=(255, 210, 90, 255)); d.ellipse((219, 160, 259, 195), fill=(255, 210, 90, 255))
d.ellipse((172, 300, 212, 330), fill=K)
save(im, "wolf")
# power: fist / flame star
im, d = new()
pts = []
for k in range(10):
    a = -math.pi / 2 + k * math.pi / 5
    r = 165 if k % 2 == 0 else 75
    pts.append((192 + math.cos(a) * r, 200 + math.sin(a) * r))
outline(d, "polygon", pts, (255, 120, 70, 255))
save(im, "power")
# trust: heart
im, d = new()
outline(d, "polygon", [(192, 350), (40, 170), (60, 80), (130, 45), (192, 100), (254, 45), (324, 80), (344, 170)], (235, 90, 110, 255))
d.ellipse((90, 90, 150, 150), fill=(255, 170, 185, 255))
save(im, "trust")
# star
im, d = new()
pts = []
for k in range(10):
    a = -math.pi / 2 + k * math.pi / 5
    r = 170 if k % 2 == 0 else 70
    pts.append((192 + math.cos(a) * r, 205 + math.sin(a) * r))
outline(d, "polygon", pts, (255, 211, 107, 255))
save(im, "star")
print(sorted(os.listdir(OUT)))
