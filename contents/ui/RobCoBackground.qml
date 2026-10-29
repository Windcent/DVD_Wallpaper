// SPDX-FileCopyrightText: 2026 Antigravity Pair
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick

Item {
    id: root

    // Monitor virtual offsets for seamless multi-monitor tile alignment
    property real screenVirtualX: 0
    property real screenVirtualY: 0

    // Options
    property bool showBaseBackground: false
    property bool showCoordinateGrid: false
    property bool showVignette: true
    property real vignetteIntensity: 0.85

    // Base RobCo Amber Terminal Background (only when standalone preview requested)
    Rectangle {
        anchors.fill: parent
        color: "#140b00"
        visible: root.showBaseBackground
    }

    // Tile period: 60px for composite (aperture grille + scanlines + 20px grid)
    //              6px for pure CRT raster (aperture grille + scanlines)
    readonly property int tilePeriodX: showCoordinateGrid ? 60 : 6
    readonly property int tilePeriodY: showCoordinateGrid ? 60 : 4

    // Tiled CRT Raster & Pixel Grid Overlay (renders on top of the DVD logo)
    Item {
        anchors.fill: parent
        clip: true

        Image {
            id: gridImage
            source: root.showCoordinateGrid ? "assets/robco_composite_grid.png" : "assets/robco_crt_grid.png"
            fillMode: Image.Tile
            smooth: false // Razor-sharp subpixel scanlines without interpolation blur
            cache: true

            // Multi-monitor virtual coordinate alignment
            x: -((Math.round(root.screenVirtualX) % root.tilePeriodX + root.tilePeriodX) % root.tilePeriodX)
            y: -((Math.round(root.screenVirtualY) % root.tilePeriodY + root.tilePeriodY) % root.tilePeriodY)
            width: root.width + root.tilePeriodX * 2
            height: root.height + root.tilePeriodY * 2
        }
    }

    // CRT Screen Curvature & Inset Vignette Overlay
    // Recreates: box-shadow: inset 0 0 150px rgba(0, 0, 0, 0.9) from RobCo_OS/assets/css/style.css
    Item {
        anchors.fill: parent
        visible: root.showVignette
        opacity: root.vignetteIntensity

        // Top edge vignette
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: Math.min(180, parent.height * 0.25)
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#f0000000" }
                GradientStop { position: 0.4; color: "#a0000000" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Bottom edge vignette
        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            height: Math.min(180, parent.height * 0.25)
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.6; color: "#a0000000" }
                GradientStop { position: 1.0; color: "#f0000000" }
            }
        }

        // Left edge vignette
        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: Math.min(180, parent.width * 0.25)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#f0000000" }
                GradientStop { position: 0.4; color: "#a0000000" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Right edge vignette
        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: Math.min(180, parent.width * 0.25)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.6; color: "#a0000000" }
                GradientStop { position: 1.0; color: "#f0000000" }
            }
        }
    }
}
