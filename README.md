# Bouncing DVD Logo Live Wallpaper (Standalone Linux / KDE)

A standalone, non-interactive bouncing DVD Video logo live wallpaper for **KDE Plasma** and Linux desktops.

**100% Independent of Plasma Wallpaper plugins**:
- No installing to system or Plasma directories
- No fiddling with KDE's "Configure Desktop and Wallpaper" settings
- Zero desktop icons blocked: **clicks pass straight through** to your desktop (`Qt.WindowTransparentForInput`)
- **Pinned to the back**: Uses native Wayland LayerShell (`LayerBackground`) on modern KDE / KWin, and Desktop StaysOnBottom flags on X11
- **Multi-Monitor Spanning**: Bounces seamlessly across all your monitors, or runs independently per screen

---

## Quick Start

### 1. Launch in Background (Spans all monitors)
```bash
./run.sh
```
*To stop anytime:*
```bash
./run.sh --stop
```

### 2. Desktop Background & Peek-at-Desktop
By default, the wallpaper runs on **`LayerBackground`** with plain color `#0d0b05`:
- **Stays when peeking at desktop**: KWin reveals `LayerBackground` surfaces when using "Peek at Desktop" or "Show Desktop" (e.g. Meta+D).
- **Stays when clicking on the desktop**: Will not be covered by Plasma's wallpaper when clicking desktop elements.
- Stays behind all active normal windows (terminals, browsers, editors).

To run with a transparent background on `LayerBottom`:
```bash
./run.sh --transparent --layer bottom
```
Or with solid black:
```bash
./run.sh --black
```

### 3. System Tray Icon (New!)
A system tray icon appears automatically in your KDE Plasma panel whenever the wallpaper runs.
Click the tray icon to manage settings on the fly without restarting:
- **Live Counters**: View total bounces and corner hits in real time.
- **Pause / Resume**: Freeze the animation in place anytime.
- **Switch Modes**: Toggle between **Spanning** (all monitors) and **Independent** (per-screen).
- **Adjust Speed**: Select from presets (Slow, Normal, Fast, Hyper).
- **Resize Logo**: Change logo scale instantly (160px – 400px).
- **Colors & Palettes**: Choose Classic 10-Color, Smooth Rainbow, or open a Custom Color Picker.
- **Effects**: Toggle neon glow, motion trail, corner hit celebration, and HUD stats overlay.
- **Quick Actions**: Randomize color instantly, or reset logo to center.
- **Stop**: One-click graceful quit.

### 4. Check Status
```bash
./run.sh --status
```

---

## Multi-Monitor Modes

- **Span across all monitors (Default)**:
  ```bash
  ./run.sh --mode span
  ```
  The DVD logo treats all your connected monitors as a single unified canvas. When it moves from Monitor 1 toward Monitor 2, it seamlessly crosses the bezel between the two displays and bounces off the outer perimeter!

- **Independent logo per monitor**:
  ```bash
  ./run.sh --mode independent
  ```
  Each monitor has its own separate DVD logo bouncing within that monitor's bounds.

---

## Customization Options

| Command | Description |
|---|---|
| `./run.sh --speed 8` | Change movement speed (1–20, default: 5) |
| `./run.sh --size 400` | Change logo width in pixels (Large 300 default, 160-400px) |
| `./run.sh` | RobCo CRT Pixel Grid on `LayerBackground` (stays on click & peek desktop) |
| `./run.sh --transparent --layer bottom` | Transparent background over your existing wallpaper |
| `./run.sh --black` | Classic solid black background |
| `./run.sh --background /path/to/img.jpg` | Use a custom image behind the bouncing logo |
| `./run.sh --color-mode 1` | Smooth rainbow color cycling |
| `./run.sh --color-mode 2 --color "#ff007f"` | Custom fixed logo color |
| `./run.sh --stats` | Show HUD counter overlay (tracks bounces & corner hits) |
| `./run.sh --trail` | Enable subtle retro phosphor motion trail |
| `./run.sh --custom-logo /path/to/logo.svg` | Use your own custom SVG or image logo |
| `./run.sh --foreground` | Run in the terminal (press Ctrl+C to stop) |
| `./run.sh --no-tray` | Run without creating a system tray icon |

---

## Start Automatically on Login

To make it automatically start when you log into your desktop:
```bash
./run.sh --autostart
```
To remove autostart:
```bash
./run.sh --remove-autostart
```

---

## Architecture: How Pinned-to-Back Click-Through Works

1. **Layer Placement**:
   - **Wayland (KDE Plasma 6 / KWin)**:
     Uses `org.kde.layershell` (`LayerShellQt`) with `LayerShell.Window.layer: LayerBackground` and `exclusionZone: -1`. KWin anchors the surface to the desktop background layer beneath all normal windows and taskbars.
   - **X11**:
     Configured with `Qt.WindowStaysOnBottomHint | Qt.WindowDoesNotAcceptFocus | Qt.FramelessWindowHint`.
2. **Click-Through Input Mask**:
   The window sets `Qt.WindowTransparentForInput` and an empty input mask via `win.setMask(QRegion())`. All mouse clicks, double clicks, right clicks, and desktop icon selections fall straight through to your desktop.
3. **Multi-Monitor Coordinated Canvas**:
   A single background Python process creates one synchronized window per connected screen. All windows share a single `DvdEngine` physics singleton, guaranteeing 60 FPS sub-pixel continuous motion across display boundaries with zero inter-process latency.

---

## Automated Test Suite

To verify compilation and 3,000 frames of multi-monitor physics:
```bash
./test_wallpaper.py
```
# DVD_Wallpaper
# DVD_Wallpaper
# DVD_Wallpaper
# DVD_Wallpaper
