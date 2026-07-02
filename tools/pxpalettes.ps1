# Fixed per-character pixel-art palettes. Dot-source this file to define $PXPAL.
# Symbol -> R,G,B,A. Variants use DIGITS because PowerShell hash keys are case-insensitive.
# Style: flat + 1 shadow; blending dark 1px outline (not pure black).
# ASCII only.
$PXPAL = @{
  'hero' = @{
    '.' = @(0,0,0,0)
    'K' = @(38,24,24,255)     # outline (warm dark, blends into red/skin)
    'H' = @(43,38,34,255)     # hair
    '2' = @(74,68,64,255)     # hair highlight
    'S' = @(247,199,159,255)  # skin
    '1' = @(214,157,111,255)  # skin shadow
    'W' = @(242,239,230,255)  # shirt / eye white
    '9' = @(203,202,209,255)  # shirt shadow
    'R' = @(226,32,31,255)    # red suit
    '3' = @(174,22,25,255)    # red shadow
    'T' = @(240,197,35,255)   # tie yellow (master has a yellow tie)
    'C' = @(246,150,148,255)  # cheek pink
    '5' = @(112,58,38,255)    # shoe red-brown
  }
  'yada' = @{
    '.' = @(0,0,0,0)
    'K' = @(28,24,30,255)     # outline (cool dark, blends into blue)
    'H' = @(34,31,33,255)     # hair (near-black)
    '2' = @(112,116,126,255)  # hair shine (cool gray)
    'S' = @(254,216,175,255)  # skin
    '1' = @(224,175,133,255)  # skin shadow
    'W' = @(240,238,232,255)  # shirt / eye white
    '9' = @(200,201,208,255)  # shirt shadow
    'B' = @(19,66,160,255)    # blue suit
    '4' = @(14,44,112,255)    # blue shadow
    'T' = @(240,197,35,255)   # tie yellow (master has a yellow tie)
    'C' = @(246,150,148,255)  # cheek pink
    '5' = @(112,58,38,255)    # shoe red-brown
  }
  'person1' = @{
    '.' = @(0,0,0,0)
    'K' = @(26,20,28,255)     # outline (dark violet-black)
    'H' = @(45,32,48,255)     # hair (dark purple)
    '2' = @(82,60,88,255)     # hair highlight
    'S' = @(249,202,160,255)  # skin
    '1' = @(214,167,129,255)  # skin shadow
    'W' = @(238,236,232,255)  # shirt
    '9' = @(198,199,206,255)  # shirt shadow
    'P' = @(90,52,100,255)    # purple suit
    '5' = @(60,38,66,255)     # purple shadow
    'G' = @(206,216,228,255)  # glasses lens glint
    'T' = @(36,32,44,255)     # tie
    'C' = @(246,150,148,255)  # cheek pink
  }
  'person2' = @{
    '.' = @(0,0,0,0)
    'K' = @(28,20,16,255)     # outline (dark brown-black)
    'D' = @(68,41,25,255)     # dark hair / beard
    '7' = @(104,66,42,255)    # hair/beard highlight
    'S' = @(251,200,157,255)  # skin
    '1' = @(214,163,120,255)  # skin shadow
    'W' = @(238,236,230,255)  # shirt
    '9' = @(198,198,204,255)  # shirt shadow
    'N' = @(150,96,52,255)    # brown/camel suit
    '6' = @(108,68,40,255)    # brown shadow
    'T' = @(52,62,92,255)     # tie (dark navy)
    'A' = @(150,172,205,255)  # shirt light blue
    'C' = @(244,148,146,255)  # cheek pink
  }
}
