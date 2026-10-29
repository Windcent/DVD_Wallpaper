#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Antigravity Pair
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_EXEC="python3"

if ! command -v "$PYTHON_EXEC" >/dev/null 2>&1; then
    echo "Error: python3 is not installed."
    exit 1
fi

# Check for PyQt6
if ! "$PYTHON_EXEC" -c "import PyQt6" 2>/dev/null; then
    echo "Error: PyQt6 is not found. Please install with: sudo apt install python3-pyqt6"
    exit 1
fi

# Enable native Wayland LayerShell integration for KDE Plasma 6
if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" == "wayland" ]; then
    export QT_WAYLAND_SHELL_INTEGRATION="layer-shell"
fi

# By default, if no flags like --stop or --status or --help or --foreground are given, launch with -d (daemon)
RUN_FOREGROUND=false
for arg in "$@"; do
    if [ "$arg" == "--foreground" ] || [ "$arg" == "-f" ]; then
        RUN_FOREGROUND=true
    fi
done

if [ "$#" -eq 0 ]; then
    # Default: launch in background spanning all monitors
    exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" --daemon
elif [ "$1" == "--stop" ] || [ "$1" == "--kill" ]; then
    exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" --stop
elif [ "$1" == "--status" ]; then
    exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" --status
elif [ "$1" == "--autostart" ] || [ "$1" == "--install-autostart" ]; then
    exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" --install-autostart
elif [ "$1" == "--remove-autostart" ] || [ "$1" == "--no-autostart" ]; then
    exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" --remove-autostart
elif [ "$RUN_FOREGROUND" == "true" ]; then
    # Filter out --foreground before passing
    ARGS=()
    for arg in "$@"; do
        if [ "$arg" != "--foreground" ] && [ "$arg" != "-f" ]; then
            ARGS+=("$arg")
        fi
    done
    exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" "${ARGS[@]}"
else
    # Check if daemon flag or action flag is present
    HAS_ACTION=false
    for arg in "$@"; do
        if [ "$arg" == "--daemon" ] || [ "$arg" == "-d" ] || [ "$arg" == "--help" ] || [ "$arg" == "-h" ]; then
            HAS_ACTION=true
            break
        fi
    done
    if [ "$HAS_ACTION" == "true" ]; then
        exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" "$@"
    else
        # Default to background daemon mode for user convenience
        exec "$PYTHON_EXEC" "$SCRIPT_DIR/dvd_runner.py" --daemon "$@"
    fi
fi
