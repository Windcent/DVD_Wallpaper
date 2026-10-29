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

    // Transform scale directly on the root scene graph node (does not dirty layer cache)
    scale: celebratePulse ? 1.15 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutBack
        }
    }

    // GPU Texture Cache:
    // Caches the composite of logo + glow into a single texture.
    // As the logo moves across the screen, Qt simply blits the cached texture quad.
    // The expensive DropShadow blur and ColorOverlay shaders ONLY execute when
    // color changes (e.g. on bounce), not on every frame!
    Item {
        id: cachedLayer
        anchors.centerIn: parent
        // Margin to prevent glow from being clipped by layer bounds
        width: parent.width + 48
        height: parent.height + 48
        layer.enabled: true
        layer.smooth: true

        // Base SVG / Image source
        Image {
            id: logoImage
            anchors.centerIn: parent
            width: root.targetWidth
            height: root.targetHeight
            source: root.customLogoPath !== "" ? root.customLogoPath : Qt.resolvedUrl("DVD_logo.svg")
            sourceSize.width: Math.max(32, Math.round(root.targetWidth * (typeof Screen !== "undefined" ? Screen.devicePixelRatio : 1)))
            sourceSize.height: Math.max(16, Math.round(root.targetHeight * (typeof Screen !== "undefined" ? Screen.devicePixelRatio : 1)))
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: false
        }

        // Optimized Neon Glow effect behind the logo
        DropShadow {
            id: glowEffect
            anchors.fill: logoImage
            source: logoImage
            color: root.logoColor
            radius: 12
            samples: 16
            spread: 0.3
            fast: true
            cached: true
            visible: root.glowEnabled
            opacity: root.celebratePulse ? 1.0 : 0.75
        }

        // Color overlay for dynamic vibrant color tinting
        ColorOverlay {
            id: overlay
            anchors.fill: logoImage
            source: logoImage
            color: root.logoColor
            cached: true
            visible: root.customLogoPath === "" || root.customLogoPath.endsWith(".svg")
        }

        // If a custom non-SVG image is used (e.g. photo/PNG), render directly
        Image {
            anchors.fill: logoImage
            source: root.customLogoPath
            sourceSize.width: logoImage.sourceSize.width
            sourceSize.height: logoImage.sourceSize.height
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: root.customLogoPath !== "" && !root.customLogoPath.endsWith(".svg")
        }
    }
}
