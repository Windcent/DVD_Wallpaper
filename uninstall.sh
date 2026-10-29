#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Antigravity Pair
# SPDX-License-Identifier: GPL-2.0-or-later

TARGET_ID="org.kde.plasma.dvdwallpaper"
INSTALL_DEST="$HOME/.local/share/plasma/wallpapers/$TARGET_ID"
AUTOSTART_FILE="$HOME/.config/autostart/dvd-wallpaper.desktop"
SERVICE_FILE="$HOME/.config/systemd/user/dvd-wallpaper.service"

echo "Uninstalling Bouncing DVD Logo Live Wallpaper..."

# Stop any running runner
python3 "$(dirname "$0")/dvd_runner.py" --kill 2>/dev/null || true

# Remove Plasma wallpaper package
if [ -d "$INSTALL_DEST" ] || [ -L "$INSTALL_DEST" ]; then
    rm -rf "$INSTALL_DEST"
    echo "Removed $INSTALL_DEST"
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Wallpaper --remove "$TARGET_ID" 2>/dev/null || true
fi

# Remove autostart / systemd entries if present
if [ -f "$AUTOSTART_FILE" ]; then
    rm -f "$AUTOSTART_FILE"
    echo "Removed autostart file $AUTOSTART_FILE"
fi

if [ -f "$SERVICE_FILE" ]; then
    systemctl --user stop dvd-wallpaper.service 2>/dev/null || true
    systemctl --user disable dvd-wallpaper.service 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Removed systemd service $SERVICE_FILE"
fi

echo "Uninstallation complete."
