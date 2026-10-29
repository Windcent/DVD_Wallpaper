// SPDX-FileCopyrightText: 2026 Antigravity Pair
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import "."

Window {
    id: win

    // Screen geometry for this window in virtual desktop coordinates
    property real screenVirtualX: 0
    property real screenVirtualY: 0
    property real screenVirtualWidth: 0
    property real screenVirtualHeight: 0
    property string targetScreenName: ""

    // Engine handle for external control
    property var dvdEngine: DvdEngine

    // Configuration properties
    property int cfgMultiMonitorMode: 0
    property int cfgLayer: 0 // 0: LayerBackground, 1: LayerBottom
    property int cfgSpeed: 5
    property real cfgLogoSize: 300
    property color cfgBackgroundColor: "#140b00"
    property string cfgBackgroundImage: ""
    property string cfgBackgroundType: "robco" // "robco", "robco_coord", "plain", "black", "transparent", "image"
    property bool cfgRobCoVignette: true
    property int cfgColorMode: 0
    property color cfgCustomColor: "#ffaa00"
    property bool cfgGlowEffect: true
    property bool cfgMotionTrail: false
    property bool cfgCornerCelebration: true
    property bool cfgShowStats: false
    property string cfgCustomLogo: ""

    // Sizing
    readonly property real actualLogoWidth: Math.max(60, cfgLogoSize)
    readonly property real actualLogoHeight: actualLogoWidth / 2.2719

    // Window configuration (pinned to back, borderless, non-interactive)
    visible: false
    color: (cfgBackgroundType === "transparent") ? "transparent" : (cfgBackgroundType === "black" ? "#000000" : (cfgBackgroundType.indexOf("robco") === 0 ? "#140b00" : cfgBackgroundColor))
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus

    // Wayland LayerShell configuration (LayerBackground stays when peeking at desktop)
    LayerShell.Window.scope: "desktop"
    LayerShell.Window.wantsToBeOnActiveScreen: false
    LayerShell.Window.activateOnShow: false
    LayerShell.Window.layer: (cfgLayer === 1) ? LayerShell.Window.LayerBottom : LayerShell.Window.LayerBackground
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.exclusionZone: -1

    // Multi-Monitor / Independent Position
    readonly property real displayLogoX: (cfgMultiMonitorMode === 0) ? (DvdEngine.globalX - screenVirtualX) : localX
    readonly property real displayLogoY: (cfgMultiMonitorMode === 0) ? (DvdEngine.globalY - screenVirtualY) : localY
    readonly property color displayLogoColor: (cfgMultiMonitorMode === 0) ? DvdEngine.currentColor : localColor

    // Visibility test on this monitor (only render if overlapping this monitor's area)
    readonly property bool isLogoOnScreen: {
        var w = (screenVirtualWidth > 0) ? screenVirtualWidth : win.width;
        var h = (screenVirtualHeight > 0) ? screenVirtualHeight : win.height;
        return (displayLogoX + actualLogoWidth > -50 &&
                displayLogoX < w + 50 &&
                displayLogoY + actualLogoHeight > -50 &&
                displayLogoY < h + 50);
    }

    // Called directly from Python runner with exact monitor properties
    function configureScreen(name, vx, vy, vw, vh) {
        targetScreenName = String(name);
        screenVirtualX = Number(vx);
        screenVirtualY = Number(vy);
        screenVirtualWidth = Number(vw);
        screenVirtualHeight = Number(vh);
        if (cfgMultiMonitorMode === 0) {
            DvdEngine.logoWidth = actualLogoWidth;
            DvdEngine.logoHeight = actualLogoHeight;
            DvdEngine.speed = cfgSpeed;
            DvdEngine.colorMode = cfgColorMode;
            DvdEngine.customColor = cfgCustomColor;
            DvdEngine.registerScreen(targetScreenName, screenVirtualX, screenVirtualY, screenVirtualWidth, screenVirtualHeight);
        }
    }

    // Dynamic runtime controls from system tray
    property bool isPaused: false

    function setPaused(p) {
        win.isPaused = p;
        if (cfgMultiMonitorMode === 0) {
            DvdEngine.isPaused = p;
        }
    }

    function randomizeColor() {
        if (cfgMultiMonitorMode === 0) {
            DvdEngine.randomizeColor();
        } else {
            localPaletteIndex = (localPaletteIndex + 1) % DvdEngine.palette.length;
            localColor = DvdEngine.palette[localPaletteIndex];
        }
    }

    function resetCenter() {
        if (cfgMultiMonitorMode === 0) {
            DvdEngine.resetCenter();
        } else {
            var curW = (screenVirtualWidth > 0) ? screenVirtualWidth : win.width;
            var curH = (screenVirtualHeight > 0) ? screenVirtualHeight : win.height;
            localX = (curW - actualLogoWidth) / 2;
            localY = (curH - actualLogoHeight) / 2;
        }
    }

    // Local state for independent mode
    property real localX: 100
    property real localY: 100
    property real localVx: 3.8
    property real localVy: 2.7
    property color localColor: "#ffaa00"
    property int localPaletteIndex: 0
    property int localBounces: 0
    property int localCornerHits: 0
    property real localHue: 0.5
    property bool localPulse: false

    // Independent mode physics
    function stepLocalPhysics() {
        if (cfgColorMode === 1) {
            localHue = (localHue + 0.0015) % 1.0;
            localColor = Qt.hsva(localHue, 1.0, 1.0, 1.0);
        } else if (cfgColorMode === 2) {
            localColor = cfgCustomColor;
        }

        var speedFactor = Math.max(0.2, cfgSpeed / 5.0);
        var stepX = localVx * speedFactor;
        var stepY = localVy * speedFactor;

        var nextX = localX + stepX;
        var nextY = localY + stepY;

        var bouncedX = false;
        var bouncedY = false;

        var curW = (screenVirtualWidth > 0) ? screenVirtualWidth : win.width;
        var curH = (screenVirtualHeight > 0) ? screenVirtualHeight : win.height;
        var maxX = curW - actualLogoWidth;
        var maxY = curH - actualLogoHeight;

        if (nextX <= 0) {
            localX = 0;
            localVx = Math.abs(localVx);
            bouncedX = true;
        } else if (nextX >= maxX) {
            localX = Math.max(0, maxX);
            localVx = -Math.abs(localVx);
            bouncedX = true;
        } else {
            localX = nextX;
        }

        if (nextY <= 0) {
            localY = 0;
            localVy = Math.abs(localVy);
            bouncedY = true;
        } else if (nextY >= maxY) {
            localY = Math.max(0, maxY);
            localVy = -Math.abs(localVy);
            bouncedY = true;
        } else {
            localY = nextY;
        }

        if (bouncedX || bouncedY) {
            localBounces++;
            if (cfgColorMode === 0) {
                localPaletteIndex = (localPaletteIndex + 1) % DvdEngine.palette.length;
                localColor = DvdEngine.palette[localPaletteIndex];
            }

            if (bouncedX && bouncedY) {
                localCornerHits++;
                if (cfgCornerCelebration) {
                    celebrationItem.trigger(localX + (stepX > 0 ? actualLogoWidth : 0),
                                            localY + (stepY > 0 ? actualLogoHeight : 0),
                                            localColor);
                    pulseTimer.restart();
                }
            }
        }
    }

    Connections {
        target: DvdEngine
        function onCornerCelebrationTriggerChanged() {
            if (cfgMultiMonitorMode === 0 && cfgCornerCelebration) {
                var localHitX = DvdEngine.cornerHitX - screenVirtualX;
                var localHitY = DvdEngine.cornerHitY - screenVirtualY;
                var curW = (screenVirtualWidth > 0) ? screenVirtualWidth : win.width;
                var curH = (screenVirtualHeight > 0) ? screenVirtualHeight : win.height;
                if (localHitX >= -50 && localHitX <= curW + 50 &&
                    localHitY >= -50 && localHitY <= curH + 50) {
                    celebrationItem.trigger(localHitX, localHitY, DvdEngine.currentColor);
                    pulseTimer.restart();
                }
            }
        }
    }

    // Optional background image (if user explicitly provided one)
    Image {
        anchors.fill: parent
        source: win.cfgBackgroundImage
        fillMode: Image.PreserveAspectCrop
        visible: win.cfgBackgroundImage !== "" && win.cfgBackgroundType === "image"
        smooth: true
    }

    // DVD Logo & Animation Layer (renders UNDER the pixel grid)
    Item {
        anchors.fill: parent
        clip: true

        // Motion Trail (Optional)
        Repeater {
            model: win.cfgMotionTrail ? 3 : 0
            DvdLogo {
                targetWidth: win.actualLogoWidth
                targetHeight: win.actualLogoHeight
                logoColor: win.displayLogoColor
                glowEnabled: false
                customLogoPath: win.cfgCustomLogo
                opacity: 0.28 / (index + 1)
                visible: win.isLogoOnScreen
                x: win.displayLogoX - (win.cfgMultiMonitorMode === 0 ? DvdEngine.velocityX : win.localVx) * (index + 1) * 2
                y: win.displayLogoY - (win.cfgMultiMonitorMode === 0 ? DvdEngine.velocityY : win.localVy) * (index + 1) * 2
            }
        }

        // Main DVD Logo
        DvdLogo {
            id: mainLogo
            targetWidth: win.actualLogoWidth
            targetHeight: win.actualLogoHeight
            logoColor: win.displayLogoColor
            glowEnabled: win.cfgGlowEffect
            customLogoPath: win.cfgCustomLogo
            celebratePulse: win.localPulse
            visible: win.isLogoOnScreen
            x: win.displayLogoX
            y: win.displayLogoY
        }

        CornerCelebration {
            id: celebrationItem
            anchors.fill: parent
        }
    }

    // RobCo CRT Pixel Grid & Vignette Overlay (renders ON TOP of the DVD logo)
    // Recreated from RobCo_OS/assets/css/style.css:
    // Puts scanlines, phosphor aperture grille, and CRT tube vignette directly over the bouncing logo
    RobCoBackground {
        anchors.fill: parent
        screenVirtualX: win.screenVirtualX
        screenVirtualY: win.screenVirtualY
        showCoordinateGrid: (win.cfgBackgroundType === "robco_coord")
        showVignette: win.cfgRobCoVignette
        visible: (win.cfgBackgroundType === "robco" || win.cfgBackgroundType === "robco_coord")
    }

    // HUD Stats Overlay
    Rectangle {
        visible: win.cfgShowStats
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        width: statsCol.width + 24
        height: statsCol.height + 16
        radius: 10
        color: "#99000000"
        border.color: win.displayLogoColor
        border.width: 1

        Column {
            id: statsCol
            anchors.centerIn: parent
            spacing: 3
            Row {
                spacing: 8
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: win.displayLogoColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "DVD Live Wallpaper"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#ffffff"
                }
            }
            Text {
                text: "Mode: " + (win.cfgMultiMonitorMode === 0 ? ("Spanning (" + DvdEngine.activeScreens.length + " monitors)") : "Independent")
                font.pixelSize: 10
                color: "#cccccc"
            }
            Text {
                text: "Bounces: " + (win.cfgMultiMonitorMode === 0 ? DvdEngine.bounceCount : win.localBounces) +
                      "  |  Corners: " + (win.cfgMultiMonitorMode === 0 ? DvdEngine.cornerHitCount : win.localCornerHits)
                font.pixelSize: 10
                color: win.displayLogoColor
            }
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: (win.cfgMultiMonitorMode === 1) && !win.isPaused
        onTriggered: win.stepLocalPhysics()
    }

    Timer {
        id: pulseTimer
        interval: 350
        onTriggered: win.localPulse = false
    }
}
