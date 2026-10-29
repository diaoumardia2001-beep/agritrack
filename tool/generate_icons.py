# tool/generate_icons.py
import math
import os
from PIL import Image, ImageDraw

def create_agritrack_icon(size: int, is_maskable: bool = False) -> Image.Image:
    scale = 4
    canvas_size = size * scale
    
    # 1. Base image
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # Gradient background
    # from #C4F75C (196, 247, 92) to #A9E82C (169, 232, 44)
    bg_grad = Image.new("RGBA", (canvas_size, canvas_size))
    c_top = (196, 247, 92)
    c_bot = (169, 232, 44)
    for y in range(canvas_size):
        r = int(c_top[0] + (c_bot[0] - c_top[0]) * (y / canvas_size))
        g = int(c_top[1] + (c_bot[1] - c_top[1]) * (y / canvas_size))
        b = int(c_top[2] + (c_bot[2] - c_top[2]) * (y / canvas_size))
        for x in range(canvas_size):
            bg_grad.putpixel((x, y), (r, g, b, 255))
            
    # Mask for rounded corners
    mask = Image.new("L", (canvas_size, canvas_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    if is_maskable:
        mask_draw.rectangle([0, 0, canvas_size, canvas_size], fill=255)
    else:
        margin = int(canvas_size * 0.04)
        radius = int(canvas_size * 0.23)
        mask_draw.rounded_rectangle(
            [margin, margin, canvas_size - margin, canvas_size - margin],
            radius=radius,
            fill=255
        )
    
    img.paste(bg_grad, (0, 0), mask)
    draw = ImageDraw.Draw(img)
    
    # 2. Draw Lucide Leaf
    # Icon box in center
    icon_w = canvas_size * (0.54 if is_maskable else 0.58)
    ox = (canvas_size - icon_w) / 2.0
    oy = (canvas_size - icon_w) / 2.0
    
    def tx(x):
        return ox + (x / 24.0) * icon_w
        
    def ty(y):
        return oy + (y / 24.0) * icon_w
        
    def cubic_bezier(p0, p1, p2, p3, steps=40):
        pts = []
        for i in range(steps + 1):
            t = i / steps
            x = (1-t)**3 * p0[0] + 3*(1-t)**2 * t * p1[0] + 3*(1-t) * t**2 * p2[0] + t**3 * p3[0]
            y = (1-t)**3 * p0[1] + 3*(1-t)**2 * t * p1[1] + 3*(1-t) * t**2 * p2[1] + t**3 * p3[1]
            pts.append((tx(x), ty(y)))
        return pts

    def arc_pts(cx, cy, rx, ry, start_angle, end_angle, steps=40):
        pts = []
        for i in range(steps + 1):
            t = i / steps
            theta = start_angle + t * (end_angle - start_angle)
            x = cx + rx * math.cos(theta)
            y = cy + ry * math.sin(theta)
            pts.append((tx(x), ty(y)))
        return pts

    stroke_width = int(canvas_size * 0.048)
    leaf_color = (11, 20, 5, 255) # #0B1405
    
    # Arc parameters for A 7 7 0 0 1 9.8 6.1:
    pts1 = arc_pts(10.9788, 13.0, 7.0, 7.0, math.radians(89.83), math.radians(260.31), 50)
    # C 15.5 5 17 4.48 19 2
    pts2 = cubic_bezier((9.8, 6.1), (15.5, 5.0), (17.0, 4.48), (19.0, 2.0), 30)
    # C 20 4 21 6.18 21 10
    pts3 = cubic_bezier((19.0, 2.0), (20.0, 4.0), (21.0, 6.18), (21.0, 10.0), 30)
    # C 21 15.5 16.22 20 11 20
    pts4 = cubic_bezier((21.0, 10.0), (21.0, 15.5), (16.22, 20.0), (11.0, 20.0), 30)
    
    leaf_outline = pts1 + pts2[1:] + pts3[1:] + pts4[1:]
    
    # Stem:
    # M 2 21 C 2 18 3.85 15.64 7.08 15 C 9.5 14.52 12 13 13 12
    stem1 = cubic_bezier((2.0, 21.0), (2.0, 18.0), (3.85, 15.64), (7.08, 15.0), 30)
    stem2 = cubic_bezier((7.08, 15.0), (9.5, 14.52), (12.0, 13.0), (13.0, 12.0), 30)
    stem = stem1 + stem2[1:]
    
    # Draw with smooth joint circles
    def draw_thick_path(points, width, color):
        for i in range(len(points) - 1):
            draw.line([points[i], points[i+1]], fill=color, width=width)
            draw.ellipse([points[i][0] - width/2, points[i][1] - width/2,
                          points[i][0] + width/2, points[i][1] + width/2], fill=color)
        draw.ellipse([points[-1][0] - width/2, points[-1][1] - width/2,
                      points[-1][0] + width/2, points[-1][1] + width/2], fill=color)

    draw_thick_path(leaf_outline, stroke_width, leaf_color)
    draw_thick_path(stem, stroke_width, leaf_color)
    
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

def main():
    os.makedirs("web/icons", exist_ok=True)
    os.makedirs("assets/images", exist_ok=True)

    print("Generating official AgriTrack CI icons...")
    # 512
    icon512 = create_agritrack_icon(512, is_maskable=False)
    icon512.save("web/icons/Icon-512.png", "PNG")
    
    # 192
    icon192 = create_agritrack_icon(192, is_maskable=False)
    icon192.save("web/icons/Icon-192.png", "PNG")
    icon192.save("assets/images/agritrack_logo.png", "PNG")
    
    # Maskable
    mask512 = create_agritrack_icon(512, is_maskable=True)
    mask512.save("web/icons/Icon-maskable-512.png", "PNG")
    
    mask192 = create_agritrack_icon(192, is_maskable=True)
    mask192.save("web/icons/Icon-maskable-192.png", "PNG")
    
    # Favicon
    fav = create_agritrack_icon(64, is_maskable=False)
    fav.save("web/favicon.png", "PNG")
    
    print("Done! All icons successfully created.")

if __name__ == "__main__":
    main()
