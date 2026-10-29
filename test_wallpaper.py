#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Antigravity Pair
# SPDX-License-Identifier: GPL-2.0-or-later

"""
Automated Test Suite for Bouncing DVD Logo Live Wallpaper
Specifically tests:
  1. Compilation of all QML components
  2. 3-Monitor Physics Simulation:
     - 1 wide monitor at bottom (3440x1440)
     - 2 smaller monitors on top (each 1920x1080)
     - Smooth vertical crossing between bottom wide and top monitors
     - Smooth horizontal crossing between top left and top right
     - Escape from single screen verification
"""

import os
import sys

os.environ['QT_QPA_PLATFORM'] = 'offscreen'

from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtCore import QUrl, QMetaObject, Q_ARG, QVariant

def run_tests():
    print("=" * 65)
    print("  Bouncing DVD Logo Multi-Monitor Test Suite")
    print("  Testing 3-Monitor Setup: 1 Wide Bottom + 2 Smaller Top")
    print("=" * 65)

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    base_dir = os.path.dirname(os.path.abspath(__file__))
    ui_dir = os.path.join(base_dir, "contents", "ui")
    engine.addImportPath(ui_dir)

    qml_files = [
        "DvdLogo.qml",
        "CornerCelebration.qml",
        "DvdEngine.qml",
        "RobCoBackground.qml",
        "main.qml",
        "config.qml",
        "standalone_window.qml"
    ]

    print("\n[Step 1] Compiling all QML components...")
    for filename in qml_files:
        filepath = os.path.join(ui_dir, filename)
        comp = QQmlComponent(engine, QUrl.fromLocalFile(filepath))
        if comp.isError():
            print(f"  [FAIL] FAILED: {filename}")
            for err in comp.errors():
                print("     *", err.toString())
            sys.exit(1)
        else:
            print(f"  [OK] {filename} compiled cleanly")

    print("\n[Step 2] Testing 3-Monitor Registration in DvdEngine...")
    comp_engine = QQmlComponent(engine, QUrl.fromLocalFile(os.path.join(ui_dir, "DvdEngine.qml")))
    dvd_engine = comp_engine.create()
    assert dvd_engine is not None, "Failed to instantiate DvdEngine"

    dvd_engine.setProperty("logoWidth", 300.0)
    dvd_engine.setProperty("logoHeight", 132.0)
    dvd_engine.setProperty("speed", 10)

    # 3-monitor setup:
    # Top Left: 1920x1080 at (0, 0)
    # Top Right: 1920x1080 at (1920, 0)
    # Bottom Wide: 3440x1440 at (200, 1080)
    QMetaObject.invokeMethod(dvd_engine, "registerScreen",
                             Q_ARG(QVariant, "TopLeft"), Q_ARG(QVariant, 0.0), Q_ARG(QVariant, 0.0),
                             Q_ARG(QVariant, 1920.0), Q_ARG(QVariant, 1080.0))
    QMetaObject.invokeMethod(dvd_engine, "registerScreen",
                             Q_ARG(QVariant, "TopRight"), Q_ARG(QVariant, 1920.0), Q_ARG(QVariant, 0.0),
                             Q_ARG(QVariant, 1920.0), Q_ARG(QVariant, 1080.0))
    QMetaObject.invokeMethod(dvd_engine, "registerScreen",
                             Q_ARG(QVariant, "BottomWide"), Q_ARG(QVariant, 200.0), Q_ARG(QVariant, 1080.0),
                             Q_ARG(QVariant, 3440.0), Q_ARG(QVariant, 1440.0))

    min_x = dvd_engine.property("canvasMinX")
    max_x = dvd_engine.property("canvasMaxX")
    min_y = dvd_engine.property("canvasMinY")
    max_y = dvd_engine.property("canvasMaxY")

    print(f"  [OK] 3-Monitor Bounding Canvas: X=[{min_x}, {max_x}], Y=[{min_y}, {max_y}]")
    assert min_x == 0.0 and max_x == 3840.0
    assert min_y == 0.0 and max_y == 2520.0

    print("\n[Step 3] Simulating Motion across 3-Monitor Layout Variations...")
    layouts = {
        "User Hardware Layout (HDMI-A-2, DP-4, DP-5)": [
            ("HDMI-A-2", 168.0, 26.0, 1280.0, 1024.0),
            ("DP-4", 0.0, 1050.0, 3127.0, 1309.0),
            ("DP-5", 1448.0, 0.0, 1680.0, 1050.0)
        ],
        "Centered Bottom": [
            ("TopLeft", 0.0, 0.0, 1920.0, 1080.0),
            ("TopRight", 1920.0, 0.0, 1920.0, 1080.0),
            ("BottomWide", 200.0, 1080.0, 3440.0, 1440.0)
        ],
        "Left-Aligned Bottom": [
            ("TopLeft", 0.0, 0.0, 1920.0, 1080.0),
            ("TopRight", 1920.0, 0.0, 1920.0, 1080.0),
            ("BottomWide", 0.0, 1080.0, 3440.0, 1440.0)
        ],
        "Negative Coordinates (Bottom Primary at 0,0)": [
            ("TopLeft", 0.0, -1080.0, 1920.0, 1080.0),
            ("TopRight", 1920.0, -1080.0, 1920.0, 1080.0),
            ("BottomWide", 0.0, 0.0, 3440.0, 1440.0)
        ]
    }

    for layout_name, scr_list in layouts.items():
        QMetaObject.invokeMethod(dvd_engine, "resetScreens")
        for sname, sx, sy, sw, sh in scr_list:
            QMetaObject.invokeMethod(dvd_engine, "registerScreen",
                                     Q_ARG(QVariant, sname), Q_ARG(QVariant, float(sx)),
                                     Q_ARG(QVariant, float(sy)), Q_ARG(QVariant, float(sw)),
                                     Q_ARG(QVariant, float(sh)))
        
        # Start on bottom monitor moving up into top monitors
        bottom = max(scr_list, key=lambda s: s[2])
        dvd_engine.setProperty("globalX", float(bottom[1] + 500))
        dvd_engine.setProperty("globalY", float(bottom[2] + 500))
        dvd_engine.setProperty("velocityX", 4.1)
        dvd_engine.setProperty("velocityY", -3.7)

        visits = {s[0]: 0 for s in scr_list}
        for _ in range(10000):
            QMetaObject.invokeMethod(dvd_engine, "stepSimulation")
            gx = dvd_engine.property("globalX")
            gy = dvd_engine.property("globalY")
            cx = gx + 110.0
            cy = gy + 48.5
            for sname, sx, sy, sw, sh in scr_list:
                if sx <= cx < sx + sw and sy <= cy < sy + sh:
                    visits[sname] += 1
                    break

        print(f"  [OK] [{layout_name}] Visits: {visits}, Bounces: {dvd_engine.property('bounceCount')}")
        assert all(v > 300 for v in visits.values()), f"Failed coverage in {layout_name}"

    print("\n[Step 4] Verifying escape from single screen across vertical seams...")
    # Register Centered Bottom again for vertical seam check
    QMetaObject.invokeMethod(dvd_engine, "resetScreens")
    for sname, sx, sy, sw, sh in layouts["Centered Bottom"]:
        QMetaObject.invokeMethod(dvd_engine, "registerScreen",
                                 Q_ARG(QVariant, sname), Q_ARG(QVariant, float(sx)),
                                 Q_ARG(QVariant, float(sy)), Q_ARG(QVariant, float(sw)),
                                 Q_ARG(QVariant, float(sh)))
    dvd_engine.setProperty("globalX", 1000.0)
    dvd_engine.setProperty("globalY", 1090.0)
    dvd_engine.setProperty("velocityY", -5.0) # moving up

    crossed_vertical_seam = False
    for step in range(30):
        QMetaObject.invokeMethod(dvd_engine, "stepSimulation")
        gy = dvd_engine.property("globalY")
        if gy < 1080.0:
            crossed_vertical_seam = True
            break

    print(f"  [OK] Escaped Bottom Wide into Top Monitor: {crossed_vertical_seam} (at Y={dvd_engine.property('globalY'):.1f})")
    assert crossed_vertical_seam, "Logo must cross from bottom monitor into top monitor!"

    print("\n" + "=" * 65)
    print("  ALL 3-MONITOR SIMULATION TESTS PASSED!")
    print("  The logo escapes single screens and traverses all 3 monitors.")
    print("=" * 65)

if __name__ == "__main__":
    run_tests()
