// SPDX-FileCopyrightText: 2026 Antigravity Pair
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick

Item {
    id: root
    anchors.fill: parent
    visible: root.active

    property real originX: 0
    property real originY: 0
    property color celebrationColor: "#ffe600"
    property bool active: false

    readonly property var particleColors: [
        "#ff0055", "#00d2ff", "#ffe600", "#00ff66",
        "#ff6600", "#b038ff", "#00ffff", "#ffffff"
    ]

    function trigger(x, y, color) {
        originX = Math.max(0, Math.min(parent.width, x));
        originY = Math.max(0, Math.min(parent.height, y));
        celebrationColor = color;
        active = true;

        // Reset and launch particles
        for (var i = 0; i < particleRepeater.count; i++) {
            var item = particleRepeater.itemAt(i);
            if (item) {
                item.launch(originX, originY, celebrationColor);
            }
        }

        shockwaveAnim.restart();
        bannerAnim.restart();
        resetTimer.restart();
    }

    // Shockwave expanding ring from corner
    Rectangle {
        id: shockwave
        x: root.originX - width / 2
        y: root.originY - height / 2
        width: 10
        height: 10
        radius: width / 2
        color: "transparent"
        border.color: root.celebrationColor
        border.width: 4
        opacity: 0

        ParallelAnimation {
            id: shockwaveAnim
            NumberAnimation {
                target: shockwave
                property: "width"
                from: 10
                to: 350
                duration: 600
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shockwave
                property: "height"
                from: 10
                to: 350
                duration: 600
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shockwave
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 600
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: shockwave
                property: "border.width"
                from: 5
                to: 1
                duration: 600
            }
        }
    }

    // Confetti and sparkle particles
    Repeater {
        id: particleRepeater
        model: 24

        Rectangle {
            id: p
            property real vx: 0
            property real vy: 0
            property real gravity: 0.15

            width: 8 + (index % 4) * 2
            height: (index % 3 === 0) ? width : width * 0.5
            radius: (index % 2 === 0) ? width / 2 : 2
            color: root.particleColors[index % root.particleColors.length]
            opacity: 0

            function launch(ox, oy, baseColor) {
                x = ox;
                y = oy;
                rotation = Math.random() * 360;

                // Shoot outward in radial spray
                var angle = Math.random() * Math.PI * 2;
                var speed = 4 + Math.random() * 8;
                vx = Math.cos(angle) * speed;
                vy = Math.sin(angle) * speed - 2.0;

                particleAnim.restart();
            }

            SequentialAnimation {
                id: particleAnim
                NumberAnimation {
                    target: p
                    property: "opacity"
                    from: 1.0
                    to: 1.0
                    duration: 10
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: p
                        property: "x"
                        to: p.x + p.vx * 35
                        duration: 800
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: p
                        property: "y"
                        to: p.y + p.vy * 35 + 80
                        duration: 800
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: p
                        property: "rotation"
                        to: p.rotation + (p.vx > 0 ? 360 : -360)
                        duration: 800
                    }
                    NumberAnimation {
                        target: p
                        property: "opacity"
                        from: 1.0
                        to: 0.0
                        duration: 800
                        easing.type: Easing.InCubic
                    }
                }
            }
        }
    }

    // Celebratory Toast Banner
    Rectangle {
        id: banner
        anchors.centerIn: parent
        width: bannerText.contentWidth + 40
        height: bannerText.contentHeight + 20
        radius: 12
        color: "#d0000000"
        border.color: root.celebrationColor
        border.width: 2
        opacity: 0
        scale: 0.5

        Text {
            id: bannerText
            anchors.centerIn: parent
            text: "CORNER HIT!"
            font.pixelSize: 28
            font.bold: true
            color: root.celebrationColor
        }

        SequentialAnimation {
            id: bannerAnim
            ParallelAnimation {
                NumberAnimation {
                    target: banner
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: banner
                    property: "scale"
                    from: 0.5
                    to: 1.15
                    duration: 250
                    easing.type: Easing.OutBack
                }
            }
            NumberAnimation {
                target: banner
                property: "scale"
                to: 1.0
                duration: 150
            }
            PauseAnimation { duration: 900 }
            ParallelAnimation {
                NumberAnimation {
                    target: banner
                    property: "opacity"
                    to: 0.0
                    duration: 350
                    easing.type: Easing.InQuad
                }
                NumberAnimation {
                    target: banner
                    property: "scale"
                    to: 0.8
                    duration: 350
                }
            }
        }
    }

    Timer {
        id: resetTimer
        interval: 1800
        onTriggered: {
            root.active = false;
        }
    }
}
