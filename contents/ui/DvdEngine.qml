// SPDX-FileCopyrightText: 2026 Antigravity Pair
// SPDX-License-Identifier: GPL-2.0-or-later

pragma Singleton

import QtQuick

Item {
    id: engine

    // --- Configuration from active wallpapers ---
    property int speed: 5
    property real logoWidth: 300
    property real logoHeight: 132
    property int colorMode: 0
    property color customColor: "#ffaa00"

    // --- Simulation State ---
    property real globalX: 300
    property real globalY: 300
    property real velocityX: 3.8
    property real velocityY: 2.7
    property color currentColor: "#ffaa00"
    property int bounceCount: 0
    property int cornerHitCount: 0
    property real cornerHitX: 0
    property real cornerHitY: 0
    property int cornerCelebrationTrigger: 0
    property real hue: 0.5
    property bool isInitialized: false
    property bool isPaused: false

    // Classic retro DVD bounce colors (Amber Gold first for amber theme)
    readonly property var palette: [
        "#ffaa00", // Amber Gold
        "#00d2ff", // Electric Blue
        "#ff007f", // Hot Magenta
        "#ffe600", // Vivid Yellow
        "#00ff66", // Neon Green
        "#ff6600", // Bright Orange
        "#00ffff", // Cyan
        "#b038ff", // Electric Purple
        "#ff2255", // Neon Red
        "#00ffc8"  // Mint
    ]
    property int paletteIndex: 0

    // --- Active Monitors Tracking ---
    property var registeredScreens: ({})
    property var activeScreens: []
    property real canvasMinX: 0
    property real canvasMaxX: 1920
    property real canvasMinY: 0
    property real canvasMaxY: 1080

    function resetScreens() {
        registeredScreens = {};
        activeScreens = [];
        isInitialized = false;
    }

    function registerScreen(screenKey, x, y, width, height) {
        if (!screenKey) return;
        var r = registeredScreens;
        r[String(screenKey)] = {
            name: String(screenKey),
            x: Number(x) || 0,
            y: Number(y) || 0,
            width: Math.max(100, Number(width) || 1920),
            height: Math.max(100, Number(height) || 1080)
        };
        registeredScreens = r;
        updateActiveScreens();
    }

    function unregisterScreen(screenKey) {
        if (!screenKey) return;
        var r = registeredScreens;
        delete r[String(screenKey)];
        registeredScreens = r;
        updateActiveScreens();
    }

    function updateActiveScreens() {
        var list = [];
        var keys = Object.keys(registeredScreens);
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            var r = registeredScreens[k];
            if (r && r.width > 0 && r.height > 0) {
                list.push({
                    name: r.name,
                    x: r.x,
                    y: r.y,
                    width: r.width,
                    height: r.height
                });
            }
        }

        // If no views registered yet, query Qt.application.screens
        if (list.length === 0 && typeof Qt !== "undefined" && Qt.application && Qt.application.screens) {
            for (var j = 0; j < Qt.application.screens.length; j++) {
                var s = Qt.application.screens[j];
                list.push({
                    name: s.name || ("screen_" + j),
                    x: (typeof s.virtualX !== "undefined") ? s.virtualX : 0,
                    y: (typeof s.virtualY !== "undefined") ? s.virtualY : 0,
                    width: s.width || 1920,
                    height: s.height || 1080
                });
            }
        }

        if (list.length === 0) {
            list.push({ name: "default", x: 0, y: 0, width: 1920, height: 1080 });
        }
        activeScreens = list;

        // Calculate bounding box across all screens
        var minX = activeScreens[0].x;
        var maxX = activeScreens[0].x + activeScreens[0].width;
        var minY = activeScreens[0].y;
        var maxY = activeScreens[0].y + activeScreens[0].height;
        for (var m = 1; m < activeScreens.length; m++) {
            var sc = activeScreens[m];
            if (sc.x < minX) minX = sc.x;
            if (sc.x + sc.width > maxX) maxX = sc.x + sc.width;
            if (sc.y < minY) minY = sc.y;
            if (sc.y + sc.height > maxY) maxY = sc.y + sc.height;
        }
        canvasMinX = minX;
        canvasMaxX = maxX;
        canvasMinY = minY;
        canvasMaxY = maxY;

        // Position initial logo if not yet placed or out of bounds
        if (!isInitialized || !isPositionValid(globalX, globalY, logoWidth, logoHeight)) {
            var s0 = activeScreens[0];
            globalX = s0.x + Math.max(30, (s0.width - logoWidth) / 2);
            globalY = s0.y + Math.max(30, (s0.height - logoHeight) / 2);
            isInitialized = true;
        }
    }

    function isPositionValid(rx, ry, rw, rh) {
        if (activeScreens.length === 0) return true;

        // Check if inside canvas bounding box
        if (rx < canvasMinX || rx + rw > canvasMaxX ||
            ry < canvasMinY || ry + rh > canvasMaxY) {
            return false;
        }

        // Calculate visible intersection area with all active screens
        var visibleArea = 0.0;
        var totalArea = rw * rh;

        for (var i = 0; i < activeScreens.length; i++) {
            var s = activeScreens[i];
            // 4px tolerance margin to absorb fractional scaling or subpixel monitor alignment seams
            var sx = s.x - 4;
            var sy = s.y - 4;
            var sw = s.width + 8;
            var sh = s.height + 8;

            var ix1 = Math.max(rx, sx);
            var iy1 = Math.max(ry, sy);
            var ix2 = Math.min(rx + rw, sx + sw);
            var iy2 = Math.min(ry + rh, sy + sh);

            if (ix2 > ix1 && iy2 > iy1) {
                visibleArea += (ix2 - ix1) * (iy2 - iy1);
            }
        }

        // Allow crossing as long as at least 75% of the logo is on a visible screen surface
        // (absorbs fractional scaling seams, bezel margins, and staggered monitor edges)
        return (visibleArea / totalArea) >= 0.75;
    }

    function stepSimulation() {
        if (activeScreens.length === 0) {
            updateActiveScreens();
        }

        // Color modes
        if (colorMode === 1) {
            // Smooth rainbow
            hue = (hue + 0.0015) % 1.0;
            currentColor = Qt.hsva(hue, 1.0, 1.0, 1.0);
        } else if (colorMode === 2) {
            // Custom single color
            currentColor = customColor;
        }

        var speedFactor = Math.max(0.2, speed / 5.0);
        var stepX = velocityX * speedFactor;
        var stepY = velocityY * speedFactor;

        var nextX = globalX + stepX;
        var nextY = globalY + stepY;

        var bouncedX = false;
        var bouncedY = false;

        // Test X movement
        if (!isPositionValid(nextX, globalY, logoWidth, logoHeight)) {
            velocityX = -velocityX;
            bouncedX = true;
        } else {
            globalX = nextX;
        }

        // Test Y movement
        if (!isPositionValid(globalX, nextY, logoWidth, logoHeight)) {
            velocityY = -velocityY;
            bouncedY = true;
        } else {
            globalY = nextY;
        }

        if (bouncedX || bouncedY) {
            bounceCount++;
            if (colorMode === 0) {
                paletteIndex = (paletteIndex + 1) % palette.length;
                currentColor = palette[paletteIndex];
            }

            if (bouncedX && bouncedY) {
                cornerHitCount++;
                cornerHitX = globalX + (stepX > 0 ? logoWidth : 0);
                cornerHitY = globalY + (stepY > 0 ? logoHeight : 0);
                cornerCelebrationTrigger++;
            }
        }
    }

    function randomizeColor() {
        paletteIndex = Math.floor(Math.random() * palette.length);
        currentColor = palette[paletteIndex];
    }

    function resetCenter() {
        if (activeScreens.length > 0) {
            var s0 = activeScreens[0];
            globalX = s0.x + (s0.width - logoWidth) / 2;
            globalY = s0.y + (s0.height - logoHeight) / 2;
        }
    }

    Timer {
        id: physicsTimer
        interval: 16 // ~60fps
        repeat: true
        running: !engine.isPaused
        onTriggered: engine.stepSimulation()
    }

    Component.onCompleted: {
        updateActiveScreens();
    }
}
