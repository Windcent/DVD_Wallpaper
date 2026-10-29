#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Antigravity Pair
# SPDX-License-Identifier: GPL-2.0-or-later

"""
Bouncing DVD Logo Live Wallpaper Daemon (Independent of Plasma Wallpapers)
Runs non-interactive, click-through, pinned-to-back desktop windows.
Works natively on:
  - KDE Plasma 6 Wayland (via Wayland LayerShell: LayerBottom)
  - KDE Plasma X11 (via Desktop StaysOnBottom flags)
  - Any Linux desktop environment (GNOME, Sway, Hyprland, XFCE)
"""

import sys
import os

# Ensure Wayland LayerShell integration is enabled under Wayland before any Qt import
if "WAYLAND_DISPLAY" in os.environ or os.environ.get("XDG_SESSION_TYPE") == "wayland":
    os.environ["QT_WAYLAND_SHELL_INTEGRATION"] = "layer-shell"

import argparse
import signal
import subprocess
import time

PID_FILE = f"/tmp/dvd_wallpaper_{os.getuid()}.pid"

def get_base_dir():
    return os.path.dirname(os.path.abspath(__file__))

def ensure_robco_assets(base_dir):
    """Ensure authentic RobCo CRT pixel grid transparent overlay tile assets exist."""
    assets_dir = os.path.join(base_dir, "contents", "ui", "assets")
    crt_path = os.path.join(assets_dir, "robco_crt_grid.png")
    comp_path = os.path.join(assets_dir, "robco_composite_grid.png")
    if os.path.exists(crt_path) and os.path.exists(comp_path):
        return

    os.makedirs(assets_dir, exist_ok=True)
    from PyQt6.QtGui import QImage, QColor
    from PyQt6.QtCore import Qt

    def generate_overlay(width, height, is_composite=False):
        img = QImage(width, height, QImage.Format.Format_ARGB32_Premultiplied)
        img.fill(Qt.GlobalColor.transparent)
        for y in range(height):
            for x in range(width):
                dark_alpha = 0.0
                if y % 2 == 1:
                    dark_alpha += 0.28
                if y % 4 in (2, 3):
                    dark_alpha += 0.12
                dark_alpha = min(0.60, dark_alpha)

                xm = x % 3
                pr, pg, pb, pa = 0, 0, 0, 0.0
                if xm == 0:
                    pr, pg, pb, pa = 255, 30, 0, 0.06
                elif xm == 1:
                    pr, pg, pb, pa = 0, 255, 30, 0.025
                elif xm == 2:
                    pr, pg, pb, pa = 0, 70, 255, 0.06

                is_coord = is_composite and ((x % 20 == 0) or (y % 20 == 0))
                cr, cg, cb, ca = (255, 176, 0, 0.10) if is_coord else (0, 0, 0, 0.0)

                r, g, b, a = 0.0, 0.0, 0.0, 0.0
                if dark_alpha > 0:
                    r, g, b, a = 0.0, 0.0, 0.0, dark_alpha
                if pa > 0:
                    out_a = pa + a * (1.0 - pa)
                    if out_a > 0:
                        r = (pr * pa + r * a * (1.0 - pa)) / out_a
                        g = (pg * pa + g * a * (1.0 - pa)) / out_a
                        b = (pb * pa + b * a * (1.0 - pa)) / out_a
                        a = out_a
                if ca > 0:
                    out_a = ca + a * (1.0 - ca)
                    if out_a > 0:
                        r = (cr * ca + r * a * (1.0 - ca)) / out_a
                        g = (cg * ca + g * a * (1.0 - ca)) / out_a
                        b = (cb * ca + b * a * (1.0 - ca)) / out_a
                        a = out_a

                img.setPixelColor(x, y, QColor(int(round(r)), int(round(g)), int(round(b)), int(round(a * 255))))
        return img

    generate_overlay(6, 4, is_composite=False).save(crt_path)
    generate_overlay(60, 60, is_composite=True).save(comp_path)

def get_all_running_pids():
    pids = []
    my_pid = os.getpid()

    # Check PID file first
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, 'r') as f:
                for line in f.read().split():
                    val = int(line.strip())
                    if val != my_pid:
                        try:
                            os.kill(val, 0)
                            if val not in pids:
                                pids.append(val)
                        except OSError:
                            pass
        except Exception:
            pass

    # Scan /proc for any process running dvd_runner.py
    try:
        for entry in os.listdir('/proc'):
            if not entry.isdigit():
                continue
            pid = int(entry)
            if pid == my_pid:
                continue
            try:
                with open(f'/proc/{pid}/cmdline', 'rb') as f:
                    cmd = f.read().decode('latin1', errors='ignore')
                    if 'dvd_runner.py' in cmd:
                        if pid not in pids:
                            pids.append(pid)
            except Exception:
                continue
    except Exception:
        pass

    return pids

def stop_daemon():
    pids = get_all_running_pids()
    if pids:
        stopped = []
        for pid in pids:
            try:
                os.kill(pid, signal.SIGTERM)
                stopped.append(pid)
            except OSError:
                pass

        # Wait up to 1.5s for graceful SIGTERM exit
        alive = list(stopped)
        for _ in range(15):
            time.sleep(0.1)
            still_alive = []
            for pid in alive:
                try:
                    os.kill(pid, 0)
                    still_alive.append(pid)
                except OSError:
                    pass
            alive = still_alive
            if not alive:
                break

        # Force kill any hung process
        for pid in alive:
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass

        print(f"[OK] Stopped {len(stopped)} DVD Live Wallpaper instance(s): PID {', '.join(map(str, stopped))}.")
    else:
        print("DVD Live Wallpaper daemon is not running.")

    if os.path.exists(PID_FILE):
        try:
            os.remove(PID_FILE)
        except OSError:
            pass

def print_status():
    pids = get_all_running_pids()
    if pids:
        print(f"[RUNNING] DVD Live Wallpaper ({len(pids)} process(es): {', '.join(map(str, pids))})")
    else:
        print("[STOPPED] DVD Live Wallpaper")

def is_autostart_installed():
    desktop_file = os.path.expanduser("~/.config/autostart/dvd-wallpaper.desktop")
    return os.path.exists(desktop_file)

def install_autostart(args=None):
    autostart_dir = os.path.expanduser("~/.config/autostart")
    os.makedirs(autostart_dir, exist_ok=True)
    desktop_file = os.path.join(autostart_dir, "dvd-wallpaper.desktop")
    run_sh = os.path.join(get_base_dir(), "run.sh")

    content = f"""[Desktop Entry]
Type=Application
Name=DVD Bouncing Live Wallpaper
Comment=Non-interactive pinned-to-back bouncing DVD logo wallpaper
Exec={run_sh}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-phase=2
StartupNotify=false
Terminal=false
"""
    with open(desktop_file, "w") as f:
        f.write(content)
    os.chmod(desktop_file, 0o755)
    print(f"[OK] Autostart entry installed: {desktop_file}")

def remove_autostart():
    desktop_file = os.path.expanduser("~/.config/autostart/dvd-wallpaper.desktop")
    if os.path.exists(desktop_file):
        os.remove(desktop_file)
        print(f"[OK] Removed autostart entry: {desktop_file}")
    else:
        print("No autostart entry found.")

class DvdTrayManager:
    def __init__(self, app, windows, current_args):
        from PyQt6.QtWidgets import QSystemTrayIcon, QMenu
        from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QActionGroup
        from PyQt6.QtCore import Qt, QRect, QMetaObject, Q_ARG, QVariant

        self.app = app
        self.windows = windows
        self.args = current_args
        self.is_paused = False
        self.current_bg_type = getattr(self.args, "bg_type", "robco")

        self.dvd_engine = self.windows[0].property("dvdEngine") if self.windows else None

        self.tray = QSystemTrayIcon()
        self.tray.setIcon(self.generate_tray_icon())
        self.update_tooltip()

        # Build context menu (DBusMenu natively exposes this to KDE Plasma's panel)
        self.menu = QMenu()
        self.build_menu()
        self.tray.setContextMenu(self.menu)

        # Do NOT call self.menu.popup()!
        # Calling .popup() client-side under Wayland layer-shell spawns a full-screen layer window that auto-clicks on hover.
        # Right-click is handled natively by KDE Plasma via StatusNotifierItem / DBusMenu docked to panel.
        # Left-click toggles pause/resume.
        self.tray.activated.connect(self.on_tray_activated)
        self.tray.show()

    def update_tooltip(self):
        state = "PAUSED" if self.is_paused else "RUNNING"
        self.tray.setToolTip(
            f"DVD Live Wallpaper ({state})\n"
            f"- Left-Click: {'Resume' if self.is_paused else 'Pause'} Animation\n"
            f"- Right-Click: Settings & Presets\n"
            f"- Middle-Click: Randomize Color\n"
            f"- Double-Click: Reset Center"
        )

    def generate_tray_icon(self):
        from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QPen
        from PyQt6.QtCore import Qt, QRectF

        svg_path = os.path.join(get_base_dir(), "DVD_logo.svg")
        has_svg = os.path.exists(svg_path)
        base_svg_icon = QIcon(svg_path) if has_svg else None

        icon = QIcon()
        # Multi-resolution icon set (16, 22, 24, 32, 48, 64) for crisp rendering on any panel scale
        for size in (16, 22, 24, 32, 48, 64):
            pix = QPixmap(size, size)
            pix.fill(Qt.GlobalColor.transparent)
            painter = QPainter(pix)
            painter.setRenderHint(QPainter.RenderHint.Antialiasing)

            # Warm amber dark badge with glowing amber outline
            pad = max(1.0, size * 0.05)
            badge_rect = QRectF(pad, pad, size - 2 * pad, size - 2 * pad)
            painter.setBrush(QColor(18, 12, 4, 235))
            painter.setPen(QPen(QColor(255, 170, 0, 220), max(1.0, size * 0.05)))
            painter.drawRoundedRect(badge_rect, size * 0.22, size * 0.22)

            if base_svg_icon and not base_svg_icon.isNull():
                # Luminous amber-tinted DVD logo
                logo_w = size * 0.76
                logo_h = logo_w / 2.272
                logo_x = (size - logo_w) / 2.0
                logo_y = (size - logo_h) / 2.0

                tw = max(1, int(round(logo_w * 2)))
                th = max(1, int(round(logo_h * 2)))
                temp_pix = QPixmap(tw, th)
                temp_pix.fill(Qt.GlobalColor.transparent)
                tp = QPainter(temp_pix)
                tp.setRenderHint(QPainter.RenderHint.Antialiasing)
                base_svg_icon.paint(tp, temp_pix.rect())
                tp.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceIn)
                tp.fillRect(temp_pix.rect(), QColor("#ffaa00"))
                tp.end()

                painter.drawPixmap(QRectF(logo_x, logo_y, logo_w, logo_h), temp_pix, QRectF(temp_pix.rect()))
            else:
                painter.setPen(QColor("#ffaa00"))
                font = painter.font()
                font.setPixelSize(max(8, int(size * 0.35)))
                font.setBold(True)
                painter.setFont(font)
                painter.drawText(QRectF(0, 0, size, size), Qt.AlignmentFlag.AlignCenter, "DVD")

            painter.end()
            icon.addPixmap(pix)

        return icon

    def on_tray_activated(self, reason):
        from PyQt6.QtWidgets import QSystemTrayIcon
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            # Single left click toggles pause / resume
            self.toggle_pause()
        elif reason == QSystemTrayIcon.ActivationReason.MiddleClick:
            # Middle click randomizes color
            self.randomize_color()
        elif reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            # Double click resets logo to center
            self.reset_center()

    def update_stats(self):
        bounces = 0
        corners = 0
        if self.dvd_engine and self.args.mode == "span":
            bounces = self.dvd_engine.property("bounceCount") or 0
            corners = self.dvd_engine.property("cornerHitCount") or 0
        else:
            for w in self.windows:
                bounces += w.property("localBounces") or 0
                corners += w.property("localCornerHits") or 0

        self.stats_act.setText(f"Bounces: {bounces}  |  Corners: {corners}")
        self.pause_act.setText("Resume Animation" if self.is_paused else "Pause Animation")

    def toggle_pause(self):
        from PyQt6.QtCore import QMetaObject, Q_ARG, QVariant
        self.is_paused = not self.is_paused
        for w in self.windows:
            QMetaObject.invokeMethod(w, "setPaused", Q_ARG(QVariant, self.is_paused))
        self.pause_act.setText("Resume Animation" if self.is_paused else "Pause Animation")
        self.update_tooltip()

    def set_speed(self, speed):
        self.args.speed = speed
        for w in self.windows:
            w.setProperty("cfgSpeed", speed)
        if self.dvd_engine:
            self.dvd_engine.setProperty("speed", speed)

    def set_size(self, size):
        self.args.size = size
        for w in self.windows:
            w.setProperty("cfgLogoSize", float(size))
            actual_w = w.property("actualLogoWidth")
            actual_h = w.property("actualLogoHeight")
            if self.dvd_engine:
                self.dvd_engine.setProperty("logoWidth", actual_w)
                self.dvd_engine.setProperty("logoHeight", actual_h)

    def set_mode(self, mode_int):
        self.args.mode = "span" if mode_int == 0 else "independent"
        for w in self.windows:
            w.setProperty("cfgMultiMonitorMode", mode_int)

    def set_color_mode(self, mode_int, custom_color=None):
        from PyQt6.QtGui import QColor
        self.args.color_mode = mode_int
        for w in self.windows:
            w.setProperty("cfgColorMode", mode_int)
            if custom_color:
                w.setProperty("cfgCustomColor", QColor(custom_color))
        if self.dvd_engine:
            self.dvd_engine.setProperty("colorMode", mode_int)
            if custom_color:
                self.dvd_engine.setProperty("customColor", QColor(custom_color))

    def pick_custom_color(self):
        from PyQt6.QtWidgets import QColorDialog
        from PyQt6.QtGui import QColor
        cur = QColor(getattr(self.args, "color", "#ffaa00"))
        chosen = QColorDialog.getColor(cur, None, "Select DVD Logo Color")
        if chosen.isValid():
            self.args.color = chosen.name()
            self.set_color_mode(2, chosen.name())
            self.act_custom_color.setChecked(True)

    def toggle_glow(self, checked):
        self.args.glow = checked
        for w in self.windows:
            w.setProperty("cfgGlowEffect", checked)

    def toggle_trail(self, checked):
        self.args.trail = checked
        for w in self.windows:
            w.setProperty("cfgMotionTrail", checked)

    def toggle_celebration(self, checked):
        self.args.celebration = checked
        for w in self.windows:
            w.setProperty("cfgCornerCelebration", checked)

    def toggle_stats(self, checked):
        self.args.stats = checked
        for w in self.windows:
            w.setProperty("cfgShowStats", checked)

    def randomize_color(self):
        from PyQt6.QtCore import QMetaObject
        for w in self.windows:
            QMetaObject.invokeMethod(w, "randomizeColor")

    def reset_center(self):
        from PyQt6.QtCore import QMetaObject
        for w in self.windows:
            QMetaObject.invokeMethod(w, "resetCenter")

    def set_background_mode(self, bg_type, color_hex="#140b00"):
        from PyQt6.QtGui import QColor
        self.current_bg_type = bg_type
        color = QColor(color_hex)
        for w in self.windows:
            w.setProperty("cfgBackgroundType", bg_type)
            w.setProperty("cfgBackgroundColor", color)
            w.setProperty("color", color)

    def toggle_autostart(self, enabled):
        if enabled:
            install_autostart(self.args)
        else:
            remove_autostart()

    def build_menu(self):
        from PyQt6.QtGui import QActionGroup

        # Amber dark theme stylesheet for Qt menu rendering
        self.menu.setStyleSheet("""
            QMenu {
                background-color: #140d04;
                color: #ffcc66;
                border: 1px solid #774e11;
                border-radius: 8px;
                padding: 6px;
            }
            QMenu::item {
                background-color: transparent;
                padding: 6px 24px 6px 14px;
                border-radius: 4px;
            }
            QMenu::item:selected {
                background-color: #3d2806;
                color: #ffaa00;
            }
            QMenu::item:disabled {
                color: #775533;
            }
            QMenu::separator {
                height: 1px;
                background: #443318;
                margin: 4px 8px;
            }
        """)

        self.menu.aboutToShow.connect(self.update_stats)

        # Title & Stats header
        header = self.menu.addAction("Bouncing DVD Wallpaper")
        header.setEnabled(False)
        self.stats_act = self.menu.addAction("Bounces: 0  |  Corners: 0")
        self.stats_act.setEnabled(False)
        self.menu.addSeparator()

        # Pause / Resume
        self.pause_act = self.menu.addAction("Pause Animation")
        self.pause_act.triggered.connect(self.toggle_pause)

        # Multi-Monitor Mode
        mode_menu = self.menu.addMenu("Mode")
        ag_mode = QActionGroup(mode_menu)
        act_span = mode_menu.addAction("Span Across All Monitors")
        act_span.setCheckable(True)
        act_span.setChecked(self.args.mode == "span")
        act_span.triggered.connect(lambda: self.set_mode(0))
        ag_mode.addAction(act_span)

        act_indep = mode_menu.addAction("Independent Logo Per Screen")
        act_indep.setCheckable(True)
        act_indep.setChecked(self.args.mode == "independent")
        act_indep.triggered.connect(lambda: self.set_mode(1))
        ag_mode.addAction(act_indep)

        # Speed
        speed_menu = self.menu.addMenu("Speed")
        ag_speed = QActionGroup(speed_menu)
        speeds = [
            (2, "Very Slow (2)"),
            (3, "Slow (3)"),
            (5, "Normal (5)"),
            (8, "Fast (8)"),
            (12, "Very Fast (12)"),
            (18, "Ludicrous (18)")
        ]
        for spd, label in speeds:
            a = speed_menu.addAction(label)
            a.setCheckable(True)
            if self.args.speed == spd:
                a.setChecked(True)
            a.triggered.connect(lambda checked, s=spd: self.set_speed(s))
            ag_speed.addAction(a)

        # Logo Size
        size_menu = self.menu.addMenu("Logo Size")
        ag_size = QActionGroup(size_menu)
        sizes = [
            (160, "Small (160 px)"),
            (220, "Medium (220 px)"),
            (300, "Large (300 px - Default)"),
            (400, "Extra Large (400 px)")
        ]
        for sz, label in sizes:
            a = size_menu.addAction(label)
            a.setCheckable(True)
            if self.args.size == sz:
                a.setChecked(True)
            a.triggered.connect(lambda checked, s=sz: self.set_size(s))
            ag_size.addAction(a)

        # Colors
        color_menu = self.menu.addMenu("Logo Colors")
        ag_color = QActionGroup(color_menu)
        act_palette = color_menu.addAction("Retro 10-Color Palette (Amber Start)")
        act_palette.setCheckable(True)
        act_palette.setChecked(self.args.color_mode == 0)
        act_palette.triggered.connect(lambda: self.set_color_mode(0))
        ag_color.addAction(act_palette)

        act_rainbow = color_menu.addAction("Smooth Rainbow Cycle")
        act_rainbow.setCheckable(True)
        act_rainbow.setChecked(self.args.color_mode == 1)
        act_rainbow.triggered.connect(lambda: self.set_color_mode(1))
        ag_color.addAction(act_rainbow)

        color_menu.addSeparator()
        presets_menu = color_menu.addMenu("Custom Color Presets")
        presets = [
            ("Amber Gold (Theme Default)", "#ffaa00"),
            ("Warm Amber CRT", "#ff8800"),
            ("Neon Amber Yellow", "#ffc400"),
            ("Electric Blue", "#00d2ff"),
            ("Hot Magenta", "#ff007f"),
            ("Vivid Yellow", "#ffe600"),
            ("Neon Green", "#00ff66"),
            ("Flame Orange", "#ff6600"),
            ("Cyan Mint", "#00ffff"),
            ("Electric Purple", "#b038ff"),
            ("Pure White", "#ffffff")
        ]
        for name, hex_val in presets:
            a = presets_menu.addAction(name)
            a.triggered.connect(lambda checked, h=hex_val: (self.set_color_mode(2, h), self.act_custom_color.setChecked(True)))

        self.act_custom_color = color_menu.addAction("Pick Custom Color...")
        self.act_custom_color.setCheckable(True)
        self.act_custom_color.setChecked(self.args.color_mode == 2)
        self.act_custom_color.triggered.connect(self.pick_custom_color)
        ag_color.addAction(self.act_custom_color)

        # Visual Effects
        fx_menu = self.menu.addMenu("Visual Effects")
        act_glow = fx_menu.addAction("Neon Glow Behind Logo")
        act_glow.setCheckable(True)
        act_glow.setChecked(self.args.glow)
        act_glow.toggled.connect(self.toggle_glow)

        act_trail = fx_menu.addAction("Motion Phosphor Trail")
        act_trail.setCheckable(True)
        act_trail.setChecked(self.args.trail)
        act_trail.toggled.connect(self.toggle_trail)

        act_celeb = fx_menu.addAction("Corner Hit Star Explosion")
        act_celeb.setCheckable(True)
        act_celeb.setChecked(self.args.celebration)
        act_celeb.toggled.connect(self.toggle_celebration)

        act_hud = fx_menu.addAction("Show On-Screen Stats HUD")
        act_hud.setCheckable(True)
        act_hud.setChecked(self.args.stats)
        act_hud.toggled.connect(self.toggle_stats)

        # Quick Actions
        self.menu.addSeparator()
        act_rand = self.menu.addAction("Randomize Color Now")
        act_rand.triggered.connect(self.randomize_color)

        act_reset = self.menu.addAction("Reset Logo to Center")
        act_reset.triggered.connect(self.reset_center)

        # Background
        self.menu.addSeparator()
        bg_menu = self.menu.addMenu("Background")
        ag_bg = QActionGroup(bg_menu)

        act_robco = bg_menu.addAction("RobCo CRT Pixel Grid (Default)")
        act_robco.setCheckable(True)
        act_robco.setChecked(self.current_bg_type == "robco")
        act_robco.triggered.connect(lambda: self.set_background_mode("robco", "#140b00"))
        ag_bg.addAction(act_robco)

        act_robco_grid = bg_menu.addAction("RobCo CRT with Coordinate Lines")
        act_robco_grid.setCheckable(True)
        act_robco_grid.setChecked(self.current_bg_type == "robco_coord")
        act_robco_grid.triggered.connect(lambda: self.set_background_mode("robco_coord", "#140b00"))
        ag_bg.addAction(act_robco_grid)

        act_dark = bg_menu.addAction("Plain Dark Amber (#0d0b05)")
        act_dark.setCheckable(True)
        act_dark.setChecked(self.current_bg_type == "plain")
        act_dark.triggered.connect(lambda: self.set_background_mode("plain", "#0d0b05"))
        ag_bg.addAction(act_dark)

        act_black = bg_menu.addAction("Solid Black (#000000)")
        act_black.setCheckable(True)
        act_black.setChecked(self.current_bg_type == "black")
        act_black.triggered.connect(lambda: self.set_background_mode("black", "#000000"))
        ag_bg.addAction(act_black)

        act_trans = bg_menu.addAction("Transparent")
        act_trans.setCheckable(True)
        act_trans.setChecked(self.current_bg_type == "transparent")
        act_trans.triggered.connect(lambda: self.set_background_mode("transparent", "transparent"))
        ag_bg.addAction(act_trans)

        # Autostart with session toggle
        self.menu.addSeparator()
        self.autostart_act = self.menu.addAction("Start with Session (Autostart)")
        self.autostart_act.setCheckable(True)
        self.autostart_act.setChecked(is_autostart_installed())
        self.autostart_act.toggled.connect(self.toggle_autostart)

        # Quit
        self.menu.addSeparator()
        quit_act = self.menu.addAction("Stop Wallpaper")
        quit_act.triggered.connect(self.app.quit)

def main():
    parser = argparse.ArgumentParser(
        description="Bouncing DVD Logo Non-Interactive Desktop Wallpaper Runner (Independent of Plasma Wallpapers)"
    )
    parser.add_argument("--mode", choices=["span", "independent"], default="span",
                        help="Multi-monitor mode: 'span' (bounce across all monitors) or 'independent' (one logo per screen)")
    parser.add_argument("--speed", type=int, default=5,
                        help="Movement speed (1 - 20, default: 5)")
    parser.add_argument("--size", type=int, default=300,
                        help="Logo width in pixels (Large: 300, default: 300)")
    parser.add_argument("--transparent", action="store_true", default=False,
                        help="Use transparent background")
    parser.add_argument("--black", action="store_true", default=False,
                        help="Use solid black background")
    parser.add_argument("--background", type=str, default="robco",
                        help="Background mode: 'robco' (CRT pixel grid, default), 'robco-grid' (with coordinate lines), 'plain' (#0d0b05), or custom color/image")
    parser.add_argument("--layer", choices=["background", "bottom"], default="background",
                        help="Wayland Layer: 'background' (stays during peek desktop, default) or 'bottom'")
    parser.add_argument("--color-mode", type=int, choices=[0, 1, 2], default=0,
                        help="0: Classic retro palette, 1: Smooth rainbow, 2: Custom single color")
    parser.add_argument("--color", type=str, default="#ffaa00",
                        help="Custom logo color when color-mode is 2 (default: #ffaa00)")
    parser.add_argument("--no-glow", action="store_false", dest="glow", default=True,
                        help="Disable neon glow effect behind logo")
    parser.add_argument("--trail", action="store_true", default=False,
                        help="Enable subtle motion trail effect")
    parser.add_argument("--no-celebration", action="store_false", dest="celebration", default=True,
                        help="Disable celebratory particles on corner hits")
    parser.add_argument("--stats", action="store_true", default=False,
                        help="Show corner hits & bounce count HUD overlay")
    parser.add_argument("--custom-logo", type=str, default="",
                        help="Path to custom SVG or image logo")
    parser.add_argument("--daemon", "-d", action="store_true", default=False,
                        help="Run detached in the background")
    parser.add_argument("--stop", "--kill", action="store_true",
                        help="Stop running wallpaper daemon and exit")
    parser.add_argument("--status", action="store_true",
                        help="Check whether the wallpaper daemon is running")
    parser.add_argument("--install-autostart", action="store_true",
                        help="Install autostart entry for desktop login")
    parser.add_argument("--remove-autostart", action="store_true",
                        help="Remove autostart entry for desktop login")
    parser.add_argument("--no-tray", action="store_true", default=False,
                        help="Disable system tray management icon")

    args = parser.parse_args()

    if args.status:
        print_status()
        sys.exit(0)

    if args.stop:
        stop_daemon()
        sys.exit(0)

    if args.install_autostart:
        install_autostart(args)
        sys.exit(0)

    if args.remove_autostart:
        remove_autostart()
        sys.exit(0)

    # Stop any previously running instance BEFORE starting or forking
    stop_daemon()

    # If background daemon requested, fork
    if args.daemon:
        cmd = [sys.executable, os.path.abspath(__file__)]
        for arg in sys.argv[1:]:
            if arg not in ("--daemon", "-d"):
                cmd.append(arg)
        log_file = f"/tmp/dvd_wallpaper_{os.getuid()}.log"
        with open(log_file, "a") as log_out:
            proc = subprocess.Popen(
                cmd,
                stdout=log_out,
                stderr=log_out,
                stdin=subprocess.DEVNULL,
                start_new_session=True
            )
        # Write PID immediately
        with open(PID_FILE, 'w') as f:
            f.write(str(proc.pid))
        print(f"[OK] Started DVD Live Wallpaper in background (PID: {proc.pid})")
        print(f"  Logs: {log_file}")
        print("  Run './run.sh --stop' to stop anytime.")
        sys.exit(0)

    # Write current PID for foreground mode
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))

    # Initialize Qt
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtGui import QColor, QRegion
    from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
    from PyQt6.QtCore import QUrl, Qt, QRect, QMetaObject, Q_ARG, QVariant, QTimer

    app = QApplication(sys.argv)
    app.setApplicationName("Bouncing DVD Wallpaper")
    app.setOrganizationName("Antigravity")
    app.setQuitOnLastWindowClosed(False)

    base_dir = get_base_dir()
    ensure_robco_assets(base_dir)
    ui_dir = os.path.join(base_dir, "contents", "ui")

    engine = QQmlApplicationEngine()
    engine.addImportPath(ui_dir)

    qml_file = os.path.join(ui_dir, "standalone_window.qml")
    comp = QQmlComponent(engine, QUrl.fromLocalFile(qml_file))

    if comp.isError():
        print("Error compiling QML:")
        for err in comp.errors():
            print("  *", err.toString())
        sys.exit(1)

    screens = app.screens()
    print("==========================================================")
    print("  Bouncing DVD Logo Desktop Wallpaper")
    print("  (Independent of Plasma Wallpapers)")
    print("==========================================================")
    print(f"Detected {len(screens)} monitor(s):")

    # Determine background setting: RobCo CRT Pixel Grid by default on LayerBackground
    bg_type = "robco"
    bg_color = QColor("#140b00")
    bg_image = ""

    if args.transparent:
        bg_type = "transparent"
        bg_color = QColor(0, 0, 0, 0) # 100% transparent
        print("  • Background: Fully Transparent")
    elif args.black:
        bg_type = "black"
        bg_color = QColor(0, 0, 0, 255)
        print("  • Background: Solid Black (#000000)")
    elif args.background == "robco-grid":
        bg_type = "robco_coord"
        bg_color = QColor("#140b00")
        print("  • Background: RobCo CRT Pixel Grid + 20px Coordinate Lines (#140b00)")
    elif args.background in ("robco", "crt", "grid", ""):
        bg_type = "robco"
        bg_color = QColor("#140b00")
        print("  • Background: RobCo CRT Pixel Grid (from RobCo_OS/pages/, #140b00)")
    elif os.path.isfile(args.background):
        bg_type = "image"
        bg_image = os.path.abspath(args.background)
        bg_color = QColor("#140b00")
        print(f"  • Background image: {bg_image}")
    elif args.background in ("plain", "amber"):
        bg_type = "plain"
        bg_color = QColor("#0d0b05")
        print("  • Background: Plain Dark Amber (#0d0b05)")
    else:
        bg_type = "plain"
        bg_color = QColor(args.background)
        print(f"  • Background color: {args.background}")

    args.bg_type = bg_type

    layer_mode = 0 if args.layer == "background" else 1
    print(f"  • Layer: {'LayerBackground (revealed on peek desktop)' if layer_mode == 0 else 'LayerBottom'}")

    mode_int = 0 if args.mode == "span" else 1
    print(f"  • Mode: {'Bounce across all monitors (Seamless Spanning)' if mode_int == 0 else 'Independent logo per monitor'}")
    print(f"  • Speed: {args.speed} | Size: {args.size}px | Glow: {args.glow}")

    windows = []

    for i, screen in enumerate(screens):
        geom = screen.geometry()
        sname = screen.name() or f"screen_{i}"
        print(f"  • Monitor {i} [{sname}]: {geom.width()}x{geom.height()} at virtual ({geom.x()}, {geom.y()})")

        win = comp.create()
        if not win:
            print(f"Failed to create window for screen {sname}")
            continue

        # Position to cover the screen
        win.setScreen(screen)
        for c in win.children():
            if "LayerShellQt" in c.metaObject().className():
                c.setProperty("scope", "desktop")
                c.setProperty("screen", screen)
                c.setProperty("activateOnShow", False)

        win.setGeometry(geom)

        # Set appearance properties
        win.setProperty("cfgMultiMonitorMode", mode_int)
        win.setProperty("cfgLayer", layer_mode)
        win.setProperty("cfgSpeed", args.speed)
        win.setProperty("cfgLogoSize", float(args.size))
        win.setProperty("cfgBackgroundType", bg_type)
        win.setProperty("cfgBackgroundColor", bg_color)
        win.setProperty("cfgBackgroundImage", bg_image)
        win.setProperty("cfgColorMode", args.color_mode)
        win.setProperty("cfgCustomColor", QColor(args.color))
        win.setProperty("cfgGlowEffect", args.glow)
        win.setProperty("cfgMotionTrail", args.trail)
        win.setProperty("cfgCornerCelebration", args.celebration)
        win.setProperty("cfgShowStats", args.stats)
        win.setProperty("cfgCustomLogo", os.path.abspath(args.custom_logo) if args.custom_logo else "")

        # Pinned-to-back, borderless, non-interactive flags (NO Qt.Tool!)
        flags = (
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowDoesNotAcceptFocus
        )
        if args.transparent or layer_mode == 1:
            flags |= Qt.WindowType.WindowTransparentForInput
        if not os.environ.get("WAYLAND_DISPLAY"):
            flags |= Qt.WindowType.WindowStaysOnBottomHint

        win.setFlags(flags)
        win.setProperty("color", bg_color)

        # Non-interactive click-through input mask if transparent or bottom layer
        if args.transparent or layer_mode == 1:
            try:
                win.setMask(QRegion())
            except Exception:
                pass

        # Configure exact screen geometry and register to DvdEngine
        QMetaObject.invokeMethod(
            win, "configureScreen",
            Q_ARG(QVariant, sname),
            Q_ARG(QVariant, float(geom.x())),
            Q_ARG(QVariant, float(geom.y())),
            Q_ARG(QVariant, float(geom.width())),
            Q_ARG(QVariant, float(geom.height()))
        )

        win.show()
        windows.append(win)

    # Initialize System Tray Icon Manager
    tray_manager = None
    if not args.no_tray:
        try:
            tray_manager = DvdTrayManager(app, windows, args)
            print("  • System Tray Icon: Active (manage speed, colors, mode, pause from panel)")
        except Exception as e:
            print(f"  • System Tray: Could not initialize ({e})")

    print("==========================================================")

    from PyQt6.QtCore import QTimer
    # Periodic timer so the Python GIL wakes up to process POSIX signals (Ctrl+C / SIGINT)
    sig_timer = QTimer()
    sig_timer.timeout.connect(lambda: None)
    sig_timer.start(200)

    def sig_handler(signum, frame):
        print("\nShutting down DVD Wallpaper...")
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except OSError:
                pass
        app.quit()

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    if args.transparent or layer_mode == 1:
        print("[OK] Running! Bouncing across your monitors on a transparent canvas.")
        print("  All mouse clicks pass straight through to your desktop.")
    else:
        print("[OK] Running! Bouncing across your monitors on LayerBackground with RobCo CRT Pixel Grid (#140b00).")
        print("  Stays visible when clicking the desktop and when peeking at the desktop.")
    print("  Press Ctrl+C to stop.")
    ret = app.exec()

    if os.path.exists(PID_FILE):
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
    sys.exit(ret)

if __name__ == "__main__":
    main()
