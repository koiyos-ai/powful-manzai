# Sprite Specification

All playable/NPC character sprites share a single canvas size.
This is the authoritative reference for sprite dimensions across all characters.

## Canvas Size

| Property | Value |
|----------|-------|
| Width    | 112 px |
| Height   | 192 px |
| Format   | PNG (32-bit RGBA) |

Reference sprite: `images/px/hero_base.png` (112x192)

## Conversion Pipeline (smooth illustration -> pixel art)

Source illustrations are high-resolution chibi PNGs with alpha transparency,
stored in `images/parts/<char>_master.png`.

### Step 1: Pre-fit (`tools/px_prefit.ps1`)
- Trims transparent padding (auto bounding-box)
- Scales to **448x768** (4x canvas) using bicubic interpolation
- Centers on canvas

### Step 2: Ingest (`tools/px2ingest.ps1`)
- Mode (majority-color) downscale: each 4x4 block -> 1 pixel
- Auto-detects up to 26 colors
- Removes isolated single pixels

### Step 3: Palette map (`tools/px_palmap.ps1`)
- Maps each pixel to nearest color in the character's fixed palette
- Palettes defined in `tools/pxpalettes.ps1`

### Output
- `images/px/<char>_base.png` (112x192, final sprite)

## Palette Rules

- Each character has a fixed 12-color palette (`tools/pxpalettes.ps1`)
- Skin (S/1) and hair (H/2) colors are shared across characters for visual unity
- Outline (K) may differ per character to blend with their suit color
- Style: flat + 1 shadow, 1px blending outline (not pure black)
- No nose, no mouth on face (eyes + eyebrows only)
