from PIL import Image

im = Image.open("cards.png")

suits = [
    ("clubs", 0),
    ("diamonds", 243),
    ("hearts", 243*2),
    ("spades", 243*3)
]

faces = [
    ("ace", 0),
    ("ten", 2178 - 167*4 - 2),
    ("jack", 2178 - 167*3 - 2),
    ("queen", 2178 - 167*2 - 2),
    ("king", 2178 - 167 - 2)
]

for suit, y in suits:
    size = 40
    region = im.crop((167/2-size, y+243/2-size-8, 167/2+size, y+243/2+size-8))
    region.save(f"cards/{suit}.png")

    for face, x in faces:
        region = im.crop((x, y, x+167, y+243))
        region.save(f"cards/{suit}_{face}.png")

region = im.crop((167*2 + 1, 243*4, 167*3 + 1, 243*5))
region.save(f"cards/unkown.png")


region = im.crop((167*3 + 167/2-size, 243*4+243/2-size-8, 167*3 + 167/2+size, 243*4+243/2+size-8))
region.save(f"cards/nosuit.png")

region = im.crop((167*3 + 2, 243*4 + 2, 167*4 + 2, 243*5 + 2))
region.save(f"cards/nocard.png")
