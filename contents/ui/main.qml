// SPDX-FileCopyrightText: 2026 Antigravity Pair
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import "."

WallpaperItem {
    id: root

    // --- Configuration properties from KConfig ---
    readonly property int cfgMultiMonitorMode: root.configuration ? root.configuration.MultiMonitorMode : 0
    readonly property int cfgSpeed: root.configuration ? root.configuration.Speed : 5
    readonly property int cfgFps: root.configuration ? (root.configuration.TargetFps || 30) : 30
    readonly property int cfgLogoSize: root.configuration ? root.configuration.LogoSize : 300
    readonly property color cfgBackgroundColor: root.configuration ? root.configuration.BackgroundColor : "#000000"
    readonly property string cfgBackgroundImage: root.configuration ? root.configuration.BackgroundImage : ""
    readonly property int cfgColorMode: root.configuration ? root.configuration.ColorMode : 0
    readonly property color cfgCustomColor: root.configuration ? root.configuration.CustomColor : "#ffaa00"
    readonly property bool cfgGlowEffect: root.configuration ? root.configuration.GlowEffect : true
    readonly property bool cfgMotionTrail: root.configuration ? root.configuration.MotionTrail : false
    readonly property bool cfgCornerCelebration: root.configuration ? root.configuration.CornerCelebration : true
    readonly property bool cfgShowStats: root.configuration ? root.configuration.ShowStats : false
    readonly property string cfgCustomLogo: root.configuration ? root.configuration.CustomLogo : ""

    // --- Sizing ---
    readonly property real actualLogoWidth: Math.max(60, cfgLogoSize)
    readonly property real actualLogoHeight: actualLogoWidth / 2.2719

    // --- Screen identification & virtual desktop geometry ---
    readonly property string screenId: {
        if (typeof Plasmoid !== "undefined" && Plasmoid.screen >= 0) {
            return "screen_" + Plasmoid.screen;
        }
        if (typeof Screen !== "undefined" && Screen.name) {
            return "screen_" + Screen.name;
        }
        return "screen_default";
    }

    readonly property real myVirtualX: {
        if (typeof Plasmoid !== "undefined" && Plasmoid.screenGeometry && Plasmoid.screenGeometry.width > 0) {
            return Plasmoid.screenGeometry.x;
        }
        if (typeof Screen !== "undefined" && typeof Screen.virtualX !== "undefined") {
            return Screen.virtualX;
        }
        return 0;
    }

    readonly property real myVirtualY: {
        if (typeof Plasmoid !== "undefined" && Plasmoid.screenGeometry && Plasmoid.screenGeometry.height > 0) {
            return Plasmoid.screenGeometry.y;
        }
        if (typeof Screen !== "undefined" && typeof Screen.virtualY !== "undefined") {
            return Screen.virtualY;
        }
        return 0;
    }

    // --- Multi-Monitor / Independent Position ---
    readonly property real displayLogoX: (cfgMultiMonitorMode === 0) ? (DvdEngine.globalX - myVirtualX) : localX
    readonly property real displayLogoY: (cfgMultiMonitorMode === 0) ? (DvdEngine.globalY - myVirtualY) : localY
    readonly property color displayLogoColor: (cfgMultiMonitorMode === 0) ? DvdEngine.currentColor : localColor

    // Visibility test on this monitor (only render if overlapping this monitor's area)
    readonly property bool isLogoOnScreen: {
        return (displayLogoX + actualLogoWidth > -50 &&
                displayLogoX < root.width + 50 &&
                displayLogoY + actualLogoHeight > -50 &&
                displayLogoY < root.height + 50);
    }

    // --- Independent Mode Local State ---
    property real localX: 150
    property real localY: 150
    property real localVx: 3.8
    property real localVy: 2.7
    property color localColor: "#00d2ff"
    property int localPaletteIndex: 0
    property int localBounces: 0
    property int localCornerHits: 0
    property real localHue: 0.5
    property bool localPulse: false

    // Sync settings to DvdEngine
    onCfgSpeedChanged: DvdEngine.speed = cfgSpeed
    onActualLogoWidthChanged: {
        DvdEngine.logoWidth = actualLogoWidth;
        DvdEngine.logoHeight = actualLogoHeight;
    }
    onCfgColorModeChanged: DvdEngine.colorMode = cfgColorMode
    onCfgCustomColorChanged: DvdEngine.customColor = cfgCustomColor

    onWidthChanged: registerToEngine()
    onHeightChanged: registerToEngine()
    onMyVirtualXChanged: registerToEngine()
    onMyVirtualYChanged: registerToEngine()

    function registerToEngine() {
        if (cfgMultiMonitorMode === 0 && root.width > 0 && root.height > 0) {
            DvdEngine.registerScreen(root.screenId, myVirtualX, myVirtualY, root.width, root.height);
        }
    }

    function stepLocalPhysics() {
        if (cfgColorMode === 1) {
            localHue = (localHue + 0.0015) % 1.0;
            localColor = Qt.hsva(localHue, 1.0, 1.0, 1.0);
        } else if (cfgColorMode === 2) {
            localColor = cfgCustomColor;
        }

        var dtFactor = (1000.0 / Math.max(10, cfgFps)) / 16.666;
        var speedFactor = Math.max(0.2, cfgSpeed / 5.0) * dtFactor;
        var stepX = localVx * speedFactor;
        var stepY = localVy * speedFactor;

        var nextX = localX + stepX;
        var nextY = localY + stepY;

        var bouncedX = false;
        var bouncedY = false;

        var maxX = root.width - actualLogoWidth;
        var maxY = root.height - actualLogoHeight;

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
                triggerCornerHit(localX + (stepX > 0 ? actualLogoWidth : 0),
                                 localY + (stepY > 0 ? actualLogoHeight : 0),
                                 localColor);
            }
        }
    }

    function triggerCornerHit(hitX, hitY, hitColor) {
        if (cfgCornerCelebration) {
            celebrationItem.trigger(hitX, hitY, hitColor);
            pulseTimer.restart();
        }
    }

    // Multi-monitor corner hit listener from DvdEngine
    Connections {
        target: DvdEngine
        function onCornerCelebrationTriggerChanged() {
            if (cfgMultiMonitorMode === 0 && cfgCornerCelebration) {
                var localHitX = DvdEngine.cornerHitX - myVirtualX;
                var localHitY = DvdEngine.cornerHitY - myVirtualY;
                // If the hit happened within or immediately adjacent to this monitor
                if (localHitX >= -50 && localHitX <= root.width + 50 &&
                    localHitY >= -50 && localHitY <= root.height + 50) {
                    triggerCornerHit(localHitX, localHitY, DvdEngine.currentColor);
                }
            }
        }
    }

    // ==========================================
    // UI LAYOUT
    // ==========================================

    // Background Color
    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: root.cfgBackgroundColor
    }

    // Optional Background Wallpaper Image
    Image {
        id: bgImage
        anchors.fill: parent
        source: root.cfgBackgroundImage
        fillMode: Image.PreserveAspectCrop
        visible: root.cfgBackgroundImage !== ""
        smooth: true
    }

    // Double-click desktop wallpaper to instantly randomize color or reset
    MouseArea {
        anchors.fill: parent
        onDoubleClicked: {
            if (root.cfgMultiMonitorMode === 0) {
                DvdEngine.randomizeColor();
            } else {
                root.localPaletteIndex = (root.localPaletteIndex + 1) % DvdEngine.palette.length;
                root.localColor = DvdEngine.palette[root.localPaletteIndex];
            }
        }
    }

    // Container clipped to screen bounds (ensures flawless edge transitions)
    Item {
        id: screenCanvas
        anchors.fill: parent
        clip: true
        visible: root.isLogoOnScreen || celebrationItem.active

        // Motion Trail Layers (Optional)
        Repeater {
            model: root.cfgMotionTrail ? 3 : 0
            DvdLogo {
                id: trailLogo
                targetWidth: root.actualLogoWidth
                targetHeight: root.actualLogoHeight
                logoColor: root.displayLogoColor
                glowEnabled: false
                customLogoPath: root.cfgCustomLogo
                opacity: 0.28 / (index + 1)
                visible: root.isLogoOnScreen

                // Offset slightly behind current movement direction
                x: root.displayLogoX - (root.cfgMultiMonitorMode === 0 ? DvdEngine.velocityX : root.localVx) * (index + 1) * 2
                y: root.displayLogoY - (root.cfgMultiMonitorMode === 0 ? DvdEngine.velocityY : root.localVy) * (index + 1) * 2
            }
        }

        // Active DVD Logo
        DvdLogo {
            id: mainLogo
            targetWidth: root.actualLogoWidth
            targetHeight: root.actualLogoHeight
            logoColor: root.displayLogoColor
            glowEnabled: root.cfgGlowEffect
            customLogoPath: root.cfgCustomLogo
            celebratePulse: root.localPulse
            visible: root.isLogoOnScreen

            x: root.displayLogoX
            y: root.displayLogoY
        }

        // Corner Celebration Animation (Particles, Shockwave & Toast)
        CornerCelebration {
            id: celebrationItem
            anchors.fill: parent
        }
    }

    // Stats & Info Overlay (Optional HUD)
    Rectangle {
        id: statsBadge
        visible: root.cfgShowStats
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        width: statsColumn.width + 24
        height: statsColumn.height + 16
        radius: 10
        color: "#99000000"
        border.color: root.displayLogoColor
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        Column {
            id: statsColumn
            anchors.centerIn: parent
            spacing: 3

            Row {
                spacing: 8
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: root.displayLogoColor
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
                text: "Mode: " + (root.cfgMultiMonitorMode === 0 ? ("Spanning (" + DvdEngine.activeScreens.length + " monitors)") : "Independent")
                font.pixelSize: 10
                color: "#cccccc"
            }

            Text {
                text: "Bounces: " + (root.cfgMultiMonitorMode === 0 ? DvdEngine.bounceCount : root.localBounces) +
                      "  |  Corners: " + (root.cfgMultiMonitorMode === 0 ? DvdEngine.cornerHitCount : root.localCornerHits)
                font.pixelSize: 10
                color: root.displayLogoColor
            }
        }
    }

    // Independent mode physics timer
    Timer {
        id: localPhysicsTimer
        interval: Math.max(10, Math.round(1000 / cfgFps))
        repeat: true
        running: root.cfgMultiMonitorMode === 1
        onTriggered: root.stepLocalPhysics()
    }

    // Celebration pulse timer
    Timer {
        id: pulseTimer
        interval: 350
        onTriggered: root.localPulse = false
    }

    Component.onCompleted: {
        DvdEngine.speed = cfgSpeed;
        DvdEngine.targetFps = cfgFps;
        DvdEngine.logoWidth = actualLogoWidth;
        DvdEngine.logoHeight = actualLogoHeight;
        DvdEngine.colorMode = cfgColorMode;
        DvdEngine.customColor = cfgCustomColor;
        registerToEngine();
    }

    Component.onDestruction: {
        if (cfgMultiMonitorMode === 0) {
            DvdEngine.unregisterScreen(root.screenId);
        }
    }
}
