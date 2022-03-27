from math import floor
from PIL import Image
from itertools import chain, combinations

prefix_img_str = "../../assets/"

# Load Blank Backing
back_blank_img = Image.open(f"{prefix_img_str}back_blank.png").convert("RGBA")
back_blank_width, back_blank_height = back_blank_img.size

# Load numbers to overlay backing
back_num_imgs = list(map(
    lambda n: {
        "name": f"{n+1}",
        "img": Image.open(f"{prefix_img_str}back_{n+1}.png").convert("RGBA")
    },
    range(5)
))

# Position numbers to overlay backing
for img_ref in back_num_imgs:
    width, height = img_ref['img'].size
    img_ref['pos'] = (
        floor(back_blank_width / 2) - floor(width / 2),
        back_blank_height - 200 + floor(height/2)
    )

# Load color swatches to overlay backing
back_colr_imgs = list(map(
    lambda c: {
        "name": c,
        "img": Image.open(f"{prefix_img_str}back_{c}.png").convert("RGBA")
    }, 
    ['b','g','r','w','y']
))

# Position color swatches to overlay backing
for i, img_ref in enumerate(back_colr_imgs):
    width, height = img_ref['img'].size
    if(i < 3):
        img_ref['pos'] = (
            (floor(back_blank_width / 4) * (i + 1)) - floor(width / 2),
            170 - floor(height/2)
        )
    else:
        img_ref['pos'] = (
            (floor(back_blank_width / 3) * (i - 2)) - floor(width / 2),
            70 - floor(height/2)
        )

# Return an iterable over all combinations of the input iterable
def all_subsets(ss):
    return chain(*map(lambda x: combinations(ss, x), range(0, len(ss)+1)))

# Save a new image for all combinations of colors and numbers.
for color_subset in all_subsets(back_colr_imgs):

    color_string = ""

    back_blank = back_blank_img.copy()

    for color_img in color_subset:
        color_string += color_img['name']
        back_blank.paste(color_img["img"], color_img["pos"], mask = color_img["img"])
    
    back_blank.save(f"{prefix_img_str}generated/back_{color_string}.png")

    for num_img in back_num_imgs:
        back_blank_colored = back_blank.copy()
        back_blank_colored.paste(num_img["img"], num_img["pos"], mask = num_img["img"])
        back_blank_colored.save(f"{prefix_img_str}generated/back_{num_img['name']}{color_string}.png")