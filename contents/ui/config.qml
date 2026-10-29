// SPDX-FileCopyrightText: 2026 Antigravity Pair
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout

    property alias cfg_MultiMonitorMode: multiMonitorCombo.currentIndex
    property alias cfg_Speed: speedSlider.value
    property alias cfg_LogoSize: sizeSlider.value
    property alias cfg_BackgroundColor: bgColorButton.color
    property alias cfg_BackgroundImage: bgImageField.text
    property alias cfg_ColorMode: colorModeCombo.currentIndex
    property alias cfg_CustomColor: customColorButton.color
    property alias cfg_GlowEffect: glowCheck.checked
    property alias cfg_MotionTrail: trailCheck.checked
    property alias cfg_CornerCelebration: celebrationCheck.checked
    property alias cfg_ShowStats: statsCheck.checked
    property alias cfg_CustomLogo: customLogoField.text

    // --- Multi-Monitor Setting ---
    QQC2.ComboBox {
        id: multiMonitorCombo
        Kirigami.FormData.label: "Multi-Monitor Mode:"
        model: [
            "Bounce Across All Monitors (Seamless Spanning)",
            "Independent Logo per Monitor"
        ]
    }

    // --- Speed Slider ---
    RowLayout {
        Kirigami.FormData.label: "Movement Speed:"
        spacing: 12
        QQC2.Slider {
            id: speedSlider
            from: 1
            to: 20
            stepSize: 1
            value: 5
            Layout.fillWidth: true
        }
        QQC2.Label {
            text: Math.round(speedSlider.value)
            Layout.minimumWidth: 28
        }
    }

    // --- Logo Size Slider ---
    RowLayout {
        Kirigami.FormData.label: "Logo Size:"
        spacing: 12
        QQC2.Slider {
            id: sizeSlider
            from: 80
            to: 450
            stepSize: 10
            value: 300
            Layout.fillWidth: true
        }
        QQC2.Label {
            text: Math.round(sizeSlider.value) + " px"
            Layout.minimumWidth: 50
        }
    }

    // --- Background Color ---
    KQuickControls.ColorButton {
        id: bgColorButton
        Kirigami.FormData.label: "Background Color:"
        dialogTitle: "Choose Wallpaper Background Color"
        color: "#000000"
    }

    // --- Background Image ---
    RowLayout {
        Kirigami.FormData.label: "Background Image:"
        spacing: 8
        QQC2.TextField {
            id: bgImageField
            placeholderText: "Path to optional background wallpaper image"
            Layout.fillWidth: true
        }
        QQC2.Button {
            text: "Browse…"
            icon.name: "document-open"
            onClicked: bgFileDialog.open()
        }
        QQC2.Button {
            text: "Clear"
            icon.name: "edit-clear"
            visible: bgImageField.text !== ""
            onClicked: bgImageField.text = ""
        }
    }

    // --- Logo Color Mode ---
    QQC2.ComboBox {
        id: colorModeCombo
        Kirigami.FormData.label: "Logo Color Mode:"
        model: [
            "Classic Retro Palette (Cycle on bounce)",
            "Smooth Rainbow (Continuous hue cycling)",
            "Custom Single Color"
        ]
    }

    // --- Custom Color Picker ---
    KQuickControls.ColorButton {
        id: customColorButton
        Kirigami.FormData.label: "Custom Logo Color:"
        dialogTitle: "Choose Logo Color"
        color: "#00d2ff"
        visible: colorModeCombo.currentIndex === 2
    }

    // --- Visual Effects ---
    QQC2.CheckBox {
        id: glowCheck
        Kirigami.FormData.label: "Visual Effects:"
        text: "Enable neon glow around logo"
        checked: true
    }

    QQC2.CheckBox {
        id: trailCheck
        text: "Enable subtle motion trail (ghosting)"
        checked: false
    }

    // --- Corner Hit Celebration ---
    QQC2.CheckBox {
        id: celebrationCheck
        Kirigami.FormData.label: "Corner Hit:"
        text: "Celebrate when hitting exact corner (particles & banner)"
        checked: true
    }

    // --- Stats Overlay ---
    QQC2.CheckBox {
        id: statsCheck
        Kirigami.FormData.label: "HUD Overlay:"
        text: "Show bounce count & corner hits on screen"
        checked: false
    }

    // --- Custom Logo Path ---
    RowLayout {
        Kirigami.FormData.label: "Custom Logo:"
        spacing: 8
        QQC2.TextField {
            id: customLogoField
            placeholderText: "Leave blank for classic DVD Video logo"
            Layout.fillWidth: true
        }
        QQC2.Button {
            text: "Browse…"
            icon.name: "document-open"
            onClicked: logoFileDialog.open()
        }
        QQC2.Button {
            text: "Default"
            icon.name: "edit-clear"
            visible: customLogoField.text !== ""
            onClicked: customLogoField.text = ""
        }
    }

    // --- File Dialogs ---
    Dialogs.FileDialog {
        id: bgFileDialog
        title: "Select Background Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.svg *.bmp)"]
        onAccepted: {
            var path = String(selectedFile);
            if (path.indexOf("file://") === 0) path = path.substring(7);
            bgImageField.text = path;
        }
    }

    Dialogs.FileDialog {
        id: logoFileDialog
        title: "Select Custom Logo (SVG or Image)"
        nameFilters: ["Vector / Image files (*.svg *.png *.jpg *.webp)"]
        onAccepted: {
            var path = String(selectedFile);
            if (path.indexOf("file://") === 0) path = path.substring(7);
            customLogoField.text = path;
        }
    }
}
