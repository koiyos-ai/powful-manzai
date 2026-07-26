# Sprite Specification

All playable/NPC character sprites share a single canvas size.
This is the authoritative reference for sprite dimensions across all characters.

## Canvas Size

| Property | Value |
|----------|-------|
| Width    | **160 px** |
| Height   | 192 px |
| Format   | PNG (32-bit RGBA) |

Reference sprite: `images/px/hero_base.png` (160x192)

> **Changed 2026-07-26: 112x192 -> 160x192.** The width was raised so that *every pose*
> (including hand-up poses, whose arms extend outward) fits in the **same** canvas with the
> body centred. See "Pose Variants" below for why this matters. 192px height and the
> `y=190` ground line are unchanged.

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
- `images/px/<char>_base.png` (160x192, final sprite)

## Pose Variants — all poses share ONE canvas (2026-07-26)

| Pose  | Canvas      | Body Center X | Notes            |
|-------|-------------|---------------|------------------|
| base  | **160x192** | **80 (center)** | Standing pose    |
| upL   | **160x192** | **80 (center)** | Left hand raised |
| upR   | **160x192** | **80 (center)** | Right hand raised|

**Rule: every pose of every character uses the same canvas, with the body center at the
exact canvas center.** Swapping poses therefore never changes the element's size or the
body's position — no CSS compensation is needed anywhere.

### Why this rule exists (do not break it)

Hand-up poses were originally cropped to 144x192 (wider than base's 112x192) so the hand
tips would not be cut off. That made canvas width vary per pose, which caused position
drift in **two different ways**:

| Layout | Mechanism | Symptom |
|--------|-----------|---------|
| Absolute positioning anchored on an edge (`manzai-play`) | the element's own edge moves when width changes | the character jumps sideways when raising a hand |
| Flex row (`success-play` `#duo`) | a wider element pushes its neighbours | **the *other* character jumps** when this one changes expression |

Patching each site separately (e.g. a body-center `translateX`) fixes only the first case
and has to be redone every time the sprites are used somewhere new. Unifying the canvas
removes the hazard at the source.

- "Body center" = horizontal centre of the **legs/shoes** (bottom 20 rows). Arms move
  between poses; legs do not, so this is the only stable reference.
- Feet are aligned at `y=190` across all characters, so characters of different heights
  stand on the same ground line.
- Regenerate/verify with `tools/px_recanvas_160.ps1` (idempotent: re-running a
  already-correct file is a no-op).

Files: `images/px/<char>_base.png`, `<char>_upL.png`, `<char>_upR.png`

## Palette Rules

- Each character has a fixed 12-color palette (`tools/pxpalettes.ps1`)
- Skin (S/1) and hair (H/2) colors are shared across characters for visual unity
- Outline (K) may differ per character to blend with their suit color
- Style: flat + 1 shadow, 1px blending outline (not pure black)
- No nose, no mouth on face (eyes + eyebrows only)
