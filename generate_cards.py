#!/usr/bin/env python3
"""
Generates stylized credit card PNG images for the Credit Card Benefit Tracker app.
Each card is 750x471 pixels (standard credit card ratio ≈ 1.586:1).
"""

from PIL import Image, ImageDraw, ImageFont
import os, math, sys

CARD_W, CARD_H = 750, 471
CORNER_R = 36
OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else "."


def hex_to_rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_rounded_rect(img: Image.Image, color):
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=CORNER_R, fill=255)
    bg = Image.new("RGB", img.size, color)
    img.paste(bg, mask=mask)
    return mask


def gradient_bg(img: Image.Image, c1, c2, mask):
    """Top-left → bottom-right gradient."""
    pix = img.load()
    w, h = img.size
    mk = mask.load()
    diag = math.sqrt(w**2 + h**2)
    for y in range(h):
        for x in range(w):
            if mk[x, y] == 0:
                continue
            t = (x / w + y / h) / 2
            pix[x, y] = lerp_color(c1, c2, t)


def shine_overlay(img: Image.Image, mask):
    """Subtle top-left white shine."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    # ellipse shine
    od.ellipse([-100, -120, 400, 200], fill=(255, 255, 255, 40))
    base = img.convert("RGBA")
    base.alpha_composite(overlay)
    result = base.convert("RGB")
    # re-apply mask (keep rounded corners)
    final = Image.new("RGBA", img.size, (0, 0, 0, 0))
    final.paste(result, mask=mask)
    return final


def try_font(size):
    for name in [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Arial.ttf",
    ]:
        if os.path.exists(name):
            try:
                return ImageFont.truetype(name, size)
            except Exception:
                pass
    return ImageFont.load_default()


def make_card(out_path: str, issuer: str, card_name: str, color_hex: str, color2_hex: str = None, text_color=(255, 255, 255)):
    img = Image.new("RGB", (CARD_W, CARD_H), (0, 0, 0))
    c1 = hex_to_rgb(color_hex)
    c2 = hex_to_rgb(color2_hex) if color2_hex else tuple(max(0, v - 60) for v in c1)

    mask = draw_rounded_rect(img, c1)
    gradient_bg(img, c1, c2, mask)
    final = shine_overlay(img, mask)

    d = ImageDraw.Draw(final)

    # Issuer text (top-left)
    f_issuer = try_font(28)
    d.text((36, 32), issuer.upper(), font=f_issuer, fill=(*text_color, 220))

    # Card name (bottom-left, two lines if needed)
    f_name = try_font(36)
    name_lines = card_name.split("\n") if "\n" in card_name else [card_name]
    y_name = CARD_H - 56 - (len(name_lines) - 1) * 44
    for line in name_lines:
        d.text((36, y_name), line, font=f_name, fill=(*text_color, 255))
        y_name += 44

    # Decorative chip rectangle
    chip_x, chip_y = 36, 100
    chip_w, chip_h = 52, 40
    chip_color = tuple(min(255, v + 80) for v in c1) + (200,)
    d.rounded_rectangle([chip_x, chip_y, chip_x + chip_w, chip_y + chip_h], radius=6, fill=chip_color)

    # Subtle horizontal lines (card number placeholder)
    for i in range(4):
        x_start = 36 + i * 50
        d.text((x_start, 170), "••••", font=try_font(22), fill=(*text_color, 100))

    final.save(out_path, "PNG", optimize=True)
    print(f"  ✓ {os.path.basename(out_path)}")


CARDS = [
    # (filename_no_ext, issuer, card_name, primary_hex, secondary_hex)
    ("amex_platinum",       "American Express",  "Platinum Card",            "#A8A9AD", "#6E6F72"),
    ("amex_gold",           "American Express",  "Gold Card",                "#C6973F", "#8A6120"),
    ("amex_bcp",            "American Express",  "Blue Cash\nPreferred",     "#007BC1", "#004A80"),
    ("amex_hilton_aspire",  "American Express",  "Hilton Honors\nAspire",    "#1A2B5E", "#0D1A38"),
    ("amex_hilton_surpass", "American Express",  "Hilton Honors\nSurpass",   "#2A4078", "#172242"),
    ("amex_hilton_honors",  "American Express",  "Hilton Honors\nCard",      "#3C5A9A", "#253975"),
    ("chase_csr",           "Chase",             "Sapphire Reserve",         "#1A1A2E", "#0A0A18"),
    ("chase_csp",           "Chase",             "Sapphire\nPreferred",      "#4A90D9", "#2060A0"),
    ("chase_cfu",           "Chase",             "Freedom\nUnlimited",       "#2C5F8A", "#164070"),
    ("chase_cff",           "Chase",             "Freedom Flex",             "#1A4B73", "#0D2E4A"),
    ("chase_amazon_prime",  "Chase",             "Amazon\nPrime Visa",       "#FF9900", "#CC7700"),
    ("cap1_venturex",       "Capital One",       "Venture X",                "#1A1A1A", "#333333"),
    ("cap1_venture",        "Capital One",       "Venture",                  "#9B0000", "#660000"),
    ("cap1_savorone",       "Capital One",       "SavorOne",                 "#7B2D8B", "#4A1A55"),
    ("citi_strata_premier", "Citi",              "Strata Premier",           "#00529B", "#003268"),
    ("citi_doublecash",     "Citi",              "Double Cash",              "#003087", "#001A4F"),
    ("apple_card",          "Apple",             "Apple Card",               "#888888", "#555555"),
    ("discover_it",         "Discover",          "it Cash Back",             "#FF6600", "#CC4400"),
    ("wf_autograph_journey","Wells Fargo",        "Autograph\nJourney",       "#CD1409", "#8A0006"),
    ("boa_premium_elite",   "Bank of America",   "Premium Rewards\nElite",   "#E31837", "#A00020"),
    ("usb_altitude_reserve","U.S. Bank",          "Altitude\nReserve",        "#002244", "#001128"),
]

os.makedirs(OUT_DIR, exist_ok=True)
print(f"Generating {len(CARDS)} card images → {OUT_DIR}")
for filename, issuer, name, c1, c2 in CARDS:
    out = os.path.join(OUT_DIR, f"{filename}.png")
    make_card(out, issuer, name, c1, c2)

print("Done!")
