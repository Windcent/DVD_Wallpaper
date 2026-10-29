// SPDX-FileCopyrightText: 2026 Antigravity Pair
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property color logoColor: "#ffaa00"
    property real targetWidth: 300
    property real targetHeight: targetWidth / 2.2719
    property bool glowEnabled: true
    property string customLogoPath: ""
    property bool celebratePulse: false

    width: targetWidth
    height: targetHeight

    scale: celebratePulse ? 1.15 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutBack
        }
    }

    // Neon Glow effect behind the logo
    DropShadow {
        id: glowEffect
        anchors.fill: logoImage
        source: logoImage
        color: root.logoColor
        radius: 14
        samples: 28
        spread: 0.35
        visible: root.glowEnabled
        opacity: root.celebratePulse ? 1.0 : 0.75
    }

    // Base SVG / Image source
    Image {
        id: logoImage
        anchors.fill: parent
        source: root.customLogoPath !== "" ? root.customLogoPath : Qt.resolvedUrl("DVD_logo.svg")
        sourceSize.width: Math.max(32, Math.round(root.width * Screen.devicePixelRatio))
        sourceSize.height: Math.max(16, Math.round(root.height * Screen.devicePixelRatio))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    // Color overlay for dynamic vibrant color tinting
    ColorOverlay {
        id: overlay
        anchors.fill: logoImage
        source: logoImage
        color: root.logoColor
        visible: root.customLogoPath === "" || root.customLogoPath.endsWith(".svg")
    }

    // If a custom non-SVG image is used (e.g. photo/PNG), render directly
    Image {
        anchors.fill: parent
        source: root.customLogoPath
        sourceSize.width: Math.max(32, Math.round(root.width * Screen.devicePixelRatio))
        sourceSize.height: Math.max(16, Math.round(root.height * Screen.devicePixelRatio))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: root.customLogoPath !== "" && !root.customLogoPath.endsWith(".svg")
    }
}
