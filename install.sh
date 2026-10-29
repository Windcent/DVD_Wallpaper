#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Antigravity Pair
# SPDX-License-Identifier: GPL-2.0-or-later

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ID="org.kde.plasma.dvdwallpaper"
PLASMA_WALLPAPERS_DIR="$HOME/.local/share/plasma/wallpapers"
INSTALL_DEST="$PLASMA_WALLPAPERS_DIR/$TARGET_ID"

echo "=========================================================="
echo "  Bouncing DVD Logo Live Wallpaper Installer"
echo "=========================================================="
echo ""

# Ensure target directories exist
mkdir -p "$PLASMA_WALLPAPERS_DIR"

# 1. Install Plasma 6 Wallpaper Plugin
echo "[1/3] Installing native KDE Plasma 6 wallpaper plugin..."
if [ -d "$INSTALL_DEST" ] || [ -L "$INSTALL_DEST" ]; then
    echo "  Removing previous installation at $INSTALL_DEST..."
    rm -rf "$INSTALL_DEST"
fi

mkdir -p "$INSTALL_DEST"
cp -r "$SCRIPT_DIR/metadata.json" "$INSTALL_DEST/"
cp -r "$SCRIPT_DIR/contents" "$INSTALL_DEST/"

# Register with kpackagetool6 if available
if command -v kpackagetool6 >/dev/null 2>&1; then
    echo "  Refreshing Plasma package index via kpackagetool6..."
    kpackagetool6 --type Plasma/Wallpaper --upgrade "$INSTALL_DEST" 2>/dev/null || true
fi

echo "  [OK] Successfully installed to $INSTALL_DEST"

# 2. Make runner executable
echo ""
echo "[2/3] Preparing standalone non-interactive wallpaper runner..."
chmod +x "$SCRIPT_DIR/dvd_runner.py"
echo "  [OK] dvd_runner.py is executable"

# 3. Instructions
echo ""
echo "[3/3] Installation Complete!"
echo "----------------------------------------------------------"
echo "You can use this live wallpaper in TWO flexible ways:"
echo ""
echo "METHOD A: Native KDE Plasma Wallpaper (Recommended for KDE)"
echo "  1. Right-click anywhere on your desktop and select 'Configure Desktop and Wallpaper'."
echo "  2. Under 'Wallpaper Type', choose 'Bouncing DVD Logo'."
echo "  3. Configure speed, size, multi-monitor mode (span or independent), and color cycling!"
echo ""
echo "METHOD B: Standalone Non-Interactive Pinned-to-Back Window"
echo "  Launch the lightweight daemon directly:"
echo "    ./dvd_runner.py --mode span --speed 5"
echo ""
echo "  Options for dvd_runner.py:"
echo "    --mode span           Bounce seamlessly across all monitors"
echo "    --mode independent    Independent DVD logo per monitor"
echo "    --speed 8             Set movement speed (1-20)"
echo "    --size 250            Set logo width in pixels"
echo "    --stats               Show bounce & corner hit stats HUD"
echo "    --install-autostart   Start automatically when logging into desktop"
echo "    --kill                Stop running wallpaper daemon"
echo "=========================================================="
