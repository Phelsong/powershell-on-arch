$STEAM_MULTIPLE_XWAYLANDS = 1
$STEAM_GAMESCOPE_HDR_SUPPORTED = 1
#$VK_COLOR_SPACE_EXTENDED_SRGB_LINEAR_EXT = 1
$MANGO_HUD=1

gamescope -e -f --xwayland-count 4 --rt --sdr-gamut-wideness 1 -- steam-native -pipewire-dmabuf -gamepadui -steamos -mangohud
# --hdr-enabled
