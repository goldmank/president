#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from math import ceil
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "marketing" / "cards" / "png"
PREVIEW_PATH = ROOT / "marketing" / "cards" / "preview_grid.png"
JOKER_PATH = ROOT / "app" / "assets" / "joker.png"

CARD_BASE_WIDTH = 72
CARD_BASE_HEIGHT = 102
SCALE = 7
CARD_WIDTH = CARD_BASE_WIDTH * SCALE
CARD_HEIGHT = CARD_BASE_HEIGHT * SCALE

CANVAS_PADDING_X = 28
CANVAS_PADDING_TOP = 20
CANVAS_PADDING_BOTTOM = 60
CANVAS_WIDTH = CARD_WIDTH + (CANVAS_PADDING_X * 2)
CANVAS_HEIGHT = CARD_HEIGHT + CANVAS_PADDING_TOP + CANVAS_PADDING_BOTTOM
CARD_LEFT = CANVAS_PADDING_X
CARD_TOP = CANVAS_PADDING_TOP

CARD_RADIUS = int(round(9 * SCALE))
CARD_INSET = int(round(3.5 * SCALE))
INNER_RADIUS = int(round(6.5 * SCALE))
OUTER_BORDER_WIDTH = max(1, int(round(1.15 * SCALE)))
INNER_BORDER_WIDTH = max(1, int(round(0.75 * SCALE)))
SHADOW_BLUR = int(round(4.0 * SCALE))
SHADOW_OFFSET_Y = int(round(6 * SCALE))

JOKER_BORDER_WIDTH = max(1, int(round(1.4 * SCALE)))
JOKER_SHADOW_BLUR = int(round(4.4 * SCALE))
JOKER_SHADOW_OFFSET_Y = int(round(8 * SCALE))

PRESIDENT_SURFACE_LOWEST = (0x0C, 0x0E, 0x10, 0xFF)
PRESIDENT_SURFACE_LOW = (0x1A, 0x1C, 0x1E, 0xFF)
PRESIDENT_SURFACE_HIGH = (0x33, 0x35, 0x37, 0xCC)
PRESIDENT_PRIMARY_DARK = (0x9B, 0x82, 0x00, 0xFF)

CARD_FILL = (0xF8, 0xF5, 0xEE, 0xFF)
GRADIENT_START = (0xFF, 0xFF, 0xFF, 0xF5)
GRADIENT_END = (0xF2, 0xEC, 0xE0, 0xFF)

SUIT_COLORS = {
    "clubs": (0x20, 0x23, 0x26, 0xFF),
    "diamonds": (0xC0, 0x39, 0x2B, 0xFF),
    "hearts": (0xB0, 0x3A, 0x2E, 0xFF),
    "spades": (0x15, 0x18, 0x1B, 0xFF),
}
SUIT_SYMBOLS = {
    "clubs": "♣",
    "diamonds": "♦",
    "hearts": "♥",
    "spades": "♠",
}

RANK_LABELS = {
    3: "3",
    4: "4",
    5: "5",
    6: "6",
    7: "7",
    8: "8",
    9: "9",
    10: "10",
    11: "J",
    12: "Q",
    13: "K",
    14: "A",
    15: "2",
    16: "JKR",
}
SUITS = ("clubs", "diamonds", "hearts", "spades")

RANK_FONT_CANDIDATES = (
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
)
SUIT_FONT_CANDIDATES = (
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
    "/System/Library/Fonts/SFNS.ttf",
)

try:
    RESAMPLING_LANCZOS = Image.Resampling.LANCZOS
except AttributeError:
    RESAMPLING_LANCZOS = Image.LANCZOS


@dataclass(frozen=True)
class CardSpec:
    filename: str
    rank: int
    suit: str
    joker_index: int | None = None


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    cards: list[tuple[CardSpec, Image.Image]] = []
    for rank in range(3, 16):
        for suit in SUITS:
            spec = CardSpec(filename=f"{RANK_LABELS[rank].lower()}_{suit}.png", rank=rank, suit=suit)
            image = render_standard_card(rank, suit)
            image.save(OUTPUT_DIR / spec.filename)
            cards.append((spec, image))

    for joker_index in (1, 2):
        spec = CardSpec(filename=f"joker_{joker_index}.png", rank=16, suit="joker", joker_index=joker_index)
        image = render_joker_card()
        image.save(OUTPUT_DIR / spec.filename)
        cards.append((spec, image))

    build_preview_grid(cards)
    print(f"Generated {len(cards)} marketing card images in {OUTPUT_DIR}")
    print(f"Preview sheet: {PREVIEW_PATH}")


def render_standard_card(rank: int, suit: str) -> Image.Image:
    canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    pip_color = SUIT_COLORS[suit]
    draw_shadow(
        canvas,
        color=(PRESIDENT_SURFACE_LOWEST[0], PRESIDENT_SURFACE_LOWEST[1], PRESIDENT_SURFACE_LOWEST[2], int(255 * 0.12)),
        blur_radius=SHADOW_BLUR,
        offset_y=SHADOW_OFFSET_Y,
    )

    card = Image.new("RGBA", (CARD_WIDTH, CARD_HEIGHT), (0, 0, 0, 0))
    mask = rounded_rect_mask(CARD_WIDTH, CARD_HEIGHT, CARD_RADIUS)
    gradient = diagonal_gradient(CARD_WIDTH, CARD_HEIGHT, GRADIENT_START, GRADIENT_END)
    card.paste(Image.new("RGBA", (CARD_WIDTH, CARD_HEIGHT), CARD_FILL), (0, 0))
    card = Image.alpha_composite(card, gradient)
    card.putalpha(mask)

    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle(
        (0, 0, CARD_WIDTH - 1, CARD_HEIGHT - 1),
        radius=CARD_RADIUS,
        outline=PRESIDENT_SURFACE_HIGH,
        width=OUTER_BORDER_WIDTH,
    )
    inner_color = (*pip_color[:3], int(255 * 0.18))
    card_draw.rounded_rectangle(
        (
            CARD_INSET,
            CARD_INSET,
            CARD_WIDTH - 1 - CARD_INSET,
            CARD_HEIGHT - 1 - CARD_INSET,
        ),
        radius=INNER_RADIUS,
        outline=inner_color,
        width=INNER_BORDER_WIDTH,
    )

    corner_mark = make_corner_mark(RANK_LABELS[rank], pip_color)
    card.alpha_composite(corner_mark, (int(round(6 * SCALE)), int(round(8 * SCALE))))
    rotated_corner = corner_mark.rotate(180, resample=Image.Resampling.BICUBIC if hasattr(Image, "Resampling") else Image.BICUBIC)
    card.alpha_composite(
        rotated_corner,
        (
            CARD_WIDTH - int(round(6 * SCALE)) - rotated_corner.width,
            CARD_HEIGHT - int(round(8 * SCALE)) - rotated_corner.height,
        ),
    )

    symbol = SUIT_SYMBOLS[suit]
    center_font = load_font(SUIT_FONT_CANDIDATES, int(round(30 * SCALE)))
    draw_text_centered(
        card_draw,
        symbol,
        center_font,
        pip_color,
        (
            int(round(11 * SCALE)),
            int(round(14 * SCALE)),
            CARD_WIDTH - int(round(11 * SCALE)),
            CARD_HEIGHT - int(round(14 * SCALE)),
        ),
    )

    canvas.alpha_composite(card, (CARD_LEFT, CARD_TOP))
    return canvas


def render_joker_card() -> Image.Image:
    canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    draw_shadow(
        canvas,
        color=(PRESIDENT_SURFACE_LOWEST[0], PRESIDENT_SURFACE_LOWEST[1], PRESIDENT_SURFACE_LOWEST[2], int(255 * 0.28)),
        blur_radius=JOKER_SHADOW_BLUR,
        offset_y=JOKER_SHADOW_OFFSET_Y,
    )

    card = Image.new("RGBA", (CARD_WIDTH, CARD_HEIGHT), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle(
        (0, 0, CARD_WIDTH - 1, CARD_HEIGHT - 1),
        radius=CARD_RADIUS,
        fill=PRESIDENT_SURFACE_LOW,
        outline=PRESIDENT_PRIMARY_DARK,
        width=JOKER_BORDER_WIDTH,
    )

    joker = Image.open(JOKER_PATH).convert("RGBA")
    content_box = (
        int(round(14 * SCALE)),
        int(round(14 * SCALE)),
        CARD_WIDTH - int(round(14 * SCALE)),
        CARD_HEIGHT - int(round(14 * SCALE)),
    )
    joker = fit_image(joker, content_box[2] - content_box[0], content_box[3] - content_box[1])
    joker_left = content_box[0] + ((content_box[2] - content_box[0]) - joker.width) // 2
    joker_top = content_box[1] + ((content_box[3] - content_box[1]) - joker.height) // 2
    card.alpha_composite(joker, (joker_left, joker_top))

    canvas.alpha_composite(card, (CARD_LEFT, CARD_TOP))
    return canvas


def build_preview_grid(cards: Iterable[tuple[CardSpec, Image.Image]]) -> None:
    thumbs = list(cards)
    columns = 6
    thumb_width = 168
    thumb_height = int(round((CANVAS_HEIGHT / CANVAS_WIDTH) * thumb_width))
    label_height = 30
    gap = 24
    padding = 32
    rows = ceil(len(thumbs) / columns)

    sheet_width = padding * 2 + columns * thumb_width + (columns - 1) * gap
    sheet_height = padding * 2 + rows * (thumb_height + label_height) + (rows - 1) * gap

    background = (0x0F, 0x11, 0x13, 0xFF)
    surface = (0x1A, 0x1C, 0x1E, 0xFF)
    text_color = (0xE2, 0xE2, 0xE5, 0xFF)
    label_font = load_font(RANK_FONT_CANDIDATES, 18)

    sheet = Image.new("RGBA", (sheet_width, sheet_height), background)
    sheet_draw = ImageDraw.Draw(sheet)

    for index, (spec, image) in enumerate(thumbs):
        row = index // columns
        column = index % columns
        x = padding + column * (thumb_width + gap)
        y = padding + row * (thumb_height + label_height + gap)

        tile = Image.new("RGBA", (thumb_width, thumb_height), (0, 0, 0, 0))
        tile_draw = ImageDraw.Draw(tile)
        tile_draw.rounded_rectangle(
            (0, 0, thumb_width - 1, thumb_height - 1),
            radius=24,
            fill=surface,
        )

        thumb = image.copy()
        thumb.thumbnail((thumb_width - 24, thumb_height - 24), RESAMPLING_LANCZOS)
        thumb_left = (thumb_width - thumb.width) // 2
        thumb_top = (thumb_height - thumb.height) // 2
        tile.alpha_composite(thumb, (thumb_left, thumb_top))
        sheet.alpha_composite(tile, (x, y))

        label = spec.filename.removesuffix(".png")
        label_bbox = sheet_draw.textbbox((0, 0), label, font=label_font)
        label_x = x + (thumb_width - (label_bbox[2] - label_bbox[0])) / 2 - label_bbox[0]
        label_y = y + thumb_height + 6 - label_bbox[1]
        sheet_draw.text((label_x, label_y), label, font=label_font, fill=text_color)

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW_PATH)


def draw_shadow(canvas: Image.Image, color: tuple[int, int, int, int], blur_radius: int, offset_y: int) -> None:
    shadow = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (
            CARD_LEFT,
            CARD_TOP + offset_y,
            CARD_LEFT + CARD_WIDTH - 1,
            CARD_TOP + offset_y + CARD_HEIGHT - 1,
        ),
        radius=CARD_RADIUS,
        fill=color,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    canvas.alpha_composite(shadow)


def make_corner_mark(rank: str, color: tuple[int, int, int, int]) -> Image.Image:
    width = int(round(16 * SCALE))
    height = int(round(18 * SCALE))
    font_size = int(round((8.6 if len(rank) > 1 else 10.5) * SCALE))
    font = load_font(RANK_FONT_CANDIDATES, font_size)

    mark = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)
    bbox = draw.textbbox((0, 0), rank, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (width - text_width) / 2 - bbox[0]
    y = 0 - bbox[1]
    if text_height < height:
        y += (height - text_height) * 0.08
    draw.text((x, y), rank, font=font, fill=color)
    return mark


def draw_text_centered(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int],
    box: tuple[int, int, int, int],
) -> None:
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    left, top, right, bottom = box
    x = left + ((right - left) - text_width) / 2 - bbox[0]
    y = top + ((bottom - top) - text_height) / 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=fill)


def rounded_rect_mask(width: int, height: int, radius: int) -> Image.Image:
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    return mask


def diagonal_gradient(
    width: int,
    height: int,
    start: tuple[int, int, int, int],
    end: tuple[int, int, int, int],
) -> Image.Image:
    gradient = Image.new("RGBA", (width, height))
    pixels: list[tuple[int, int, int, int]] = []

    for y in range(height):
        y_ratio = y / max(1, height - 1)
        for x in range(width):
            x_ratio = x / max(1, width - 1)
            t = (x_ratio + y_ratio) / 2
            pixels.append(tuple(lerp_channel(a, b, t) for a, b in zip(start, end)))

    gradient.putdata(pixels)
    return gradient


def fit_image(image: Image.Image, max_width: int, max_height: int) -> Image.Image:
    copy = image.copy()
    copy.thumbnail((max_width, max_height), RESAMPLING_LANCZOS)
    return copy


def load_font(candidates: Iterable[str], size: int) -> ImageFont.FreeTypeFont:
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def lerp_channel(start: int, end: int, t: float) -> int:
    return int(round(start + ((end - start) * t)))


if __name__ == "__main__":
    main()
