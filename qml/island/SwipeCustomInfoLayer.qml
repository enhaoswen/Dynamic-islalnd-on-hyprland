import QtQuick
import IslandBackend
import Quickshell.Widgets

Item {
    id: root

    readonly property var userConfig: UserConfig

    property var items: []
    property var cavaLevels: []
    property string timeText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string timeFontFamily: activeConfig.timeFontFamily
    property bool showCondition: false
    property bool showSecondaryText: true
    property bool recordingActive: false
    property real transitionProgress: 0
    property real minimumWidth: 220
    property real maximumWidth: minimumWidth
    property real horizontalPadding: 14
    property real hiddenLeftPadding: 18
    property real hiddenRightPadding: 18
    property real groupSpacing: 16
    property real iconSpacing: 8
    property int textPixelSize: userConfig.bodyFontSize
    property int iconPixelSize: userConfig.iconFontSize
    property int iconBoxSize: 18
    property int albumCoverSize: 28
    property int albumCoverRadius: 7
    property int maximumMediaTextWidth: 180
    property int batteryIconWidth: 37
    property int batteryIconHeight: 17
    property int batteryFontSize: 13
    property int batteryFontSizeCharging: 12
    property int batteryBoltSize: 10
    property int batteryTipWidth: 2
    property int batteryTipHeight: 5
    property int batteryOuterRadius: 6
    property int batteryInnerRadius: 3
    property real iconVerticalOffset: 1
    property int recordingDotSpacing: 12
    property real batteryChargingXOffset: 0
    property real batteryChargingYOffset: 0
    readonly property string chargingIconGlyph: "\uf0e7"

    readonly property real clampedProgress: Math.max(0, Math.min(1, -transitionProgress))
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real centeredTimeX: horizontalPadding
    readonly property real centeredItemsX: (width - contentRow.implicitWidth) / 2
    readonly property real timeHiddenLeftX: -textWidth - hiddenLeftPadding
    readonly property real itemsHiddenRightX: width + hiddenRightPadding
    readonly property real timeExitDistance: Math.max(0, centeredTimeX - timeHiddenLeftX)
    readonly property real itemsEntryDistance: Math.max(0, itemsHiddenRightX - centeredItemsX)
    readonly property real dragDistance: Math.max(timeExitDistance, itemsEntryDistance)
    readonly property real itemsX: centeredItemsX + (1 - clampedProgress) * dragDistance
    readonly property real timeX: centeredTimeX - clampedProgress * dragDistance
    readonly property real visibleTimeWidth: Math.min(textWidth, Math.max(0, timeMetrics.advanceWidth))
    readonly property real timeRecordingDotX: Math.max(
        4,
        timeX + (textWidth - visibleTimeWidth) / 2 - recordingDotSpacing - timeRecordingIndicator.width
    )
    readonly property real preferredWidth: Math.max(
        minimumWidth,
        Math.min(Math.max(minimumWidth, maximumWidth), contentRow.implicitWidth + horizontalPadding * 2 + 28)
    )

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: timeMetrics
        font.family: timeFontFamily
        font.pixelSize: root.textPixelSize + 1
        font.weight: Font.Bold
        text: timeText
    }

    Row {
        id: contentRow
        x: itemsX
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        opacity: clampedProgress
        spacing: groupSpacing

        Repeater {
            model: root.items

            delegate: Item {
                readonly property bool hasIcon: modelData.icon !== ""
                readonly property bool isCava: modelData.kind === "cava"
                readonly property bool isBattery: modelData.kind === "battery"
                readonly property bool isAlbumArt: modelData.kind === "albumArt"
                readonly property bool isMediaText: modelData.kind === "trackName"
                readonly property bool hasLeadingVisual: hasIcon || isBattery
                readonly property real boundedTextWidth: isMediaText
                    ? Math.min(valueText.implicitWidth, root.maximumMediaTextWidth)
                    : valueText.implicitWidth
                implicitWidth: isCava
                    ? cavaBars.implicitWidth
                    : isAlbumArt
                      ? root.albumCoverSize
                    : isBattery
                      ? root.batteryIconWidth
                      : leadingVisual.width + (hasLeadingVisual ? root.iconSpacing : 0) + boundedTextWidth
                implicitHeight: root.height
                width: implicitWidth
                height: implicitHeight

                SwipeCavaBars {
                    id: cavaBars
                    visible: parent.isCava
                    anchors.centerIn: parent
                    levels: root.cavaLevels
                }

                Item {
                    visible: parent.isAlbumArt
                    anchors.centerIn: parent
                    width: root.albumCoverSize
                    height: root.albumCoverSize

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: root.albumCoverRadius
                        color: "#73594f"
                        antialiasing: true

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#a56e5a" }
                                GradientStop { position: 1; color: "#493b43" }
                            }
                        }

                        Image {
                            anchors.fill: parent
                            source: modelData.artUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: source.toString() !== ""
                            sourceSize: Qt.size(root.albumCoverSize * 2, root.albumCoverSize * 2)
                            smooth: true
                        }

                        Rectangle {
                            visible: String(modelData.artUrl || "") === ""
                            width: 9
                            height: 2
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 5
                            anchors.bottomMargin: 5
                            radius: 1
                            color: "#b8ffffff"
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1
                            border.color: "#2effffff"
                        }
                    }
                }

                Item {
                    id: leadingVisual
                    visible: !parent.isCava && !parent.isAlbumArt && parent.hasLeadingVisual
                    width: parent.isBattery ? root.batteryIconWidth : (parent.hasIcon ? root.iconBoxSize : 0)
                    height: parent.isBattery ? Math.max(root.batteryIconHeight, valueText.implicitHeight) : root.iconBoxSize
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: root.iconVerticalOffset
                        visible: parent.parent.hasIcon && !parent.parent.isBattery
                        text: modelData.icon || ""
                        color: "white"
                        font.pixelSize: root.iconPixelSize
                        font.family: root.iconFontFamily
                    }

                    Item {
                        id: batteryShape
                        visible: parent.parent.isBattery
                        width: root.batteryIconWidth
                        height: root.batteryIconHeight
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property real level: Math.max(0, Math.min(100, Number(modelData.level || 0)))
                        readonly property bool charging: modelData.isCharging || false
                        readonly property bool roundedEnd: level >= 85
                        readonly property color bodyColor: {
                            if (charging)
                                return "white";
                            if (level <= 20)
                                return "#ff3b30";
                            return "white";
                        }
                        readonly property color emptyColor: Qt.rgba(1, 1, 1, 0.56)

                        Rectangle {
                            id: batteryBody
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - root.batteryTipWidth - 1
                            height: parent.height
                            radius: root.batteryOuterRadius
                            color: batteryShape.emptyColor
                            border.width: 0
                            clip: true

                            Rectangle {
                                id: batteryFill
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: 0
                                topLeftRadius: root.batteryOuterRadius
                                bottomLeftRadius: root.batteryOuterRadius
                                topRightRadius: batteryShape.roundedEnd ? root.batteryOuterRadius : 0
                                bottomRightRadius: batteryShape.roundedEnd ? root.batteryOuterRadius : 0
                                width: Math.max(root.batteryOuterRadius * 2, parent.width * (batteryShape.level / 100.0))
                                color: batteryShape.bodyColor

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 300 }
                                }
                            }

                            Row {
                                visible: batteryShape.charging
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: root.batteryChargingXOffset
                                anchors.verticalCenterOffset: root.batteryChargingYOffset
                                spacing: 2
                                z: 2

                                Text {
                                    text: batteryShape.level + ""
                                    color: "black"
                                    font.pixelSize: root.batteryFontSizeCharging
                                    font.family: root.textFontFamily
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.chargingIconGlyph
                                    color: "#242424"
                                    font.pixelSize: root.batteryBoltSize
                                    font.family: root.iconFontFamily
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                visible: !batteryShape.charging
                                anchors.centerIn: parent
                                text: batteryShape.level + ""
                                color: batteryShape.level <= 20 ? "white" : "black"
                                font.pixelSize: root.batteryFontSize
                                font.family: root.textFontFamily
                                font.weight: batteryShape.level <= 20 ? Font.Bold : Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                z: 2
                            }
                        }

                        Rectangle {
                            width: root.batteryTipWidth
                            height: root.batteryTipHeight
                            radius: Math.round(root.batteryTipWidth / 2)
                            color: batteryShape.level >= 100 ? batteryShape.bodyColor : batteryShape.emptyColor
                            anchors.left: batteryBody.right
                            anchors.leftMargin: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color {
                                ColorAnimation { duration: 300 }
                            }
                        }
                    }
                }

                Text {
                    id: valueText
                    visible: !parent.isCava && !parent.isBattery && !parent.isAlbumArt
                    anchors.left: leadingVisual.right
                    anchors.leftMargin: parent.hasLeadingVisual && !parent.isBattery ? root.iconSpacing : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.boundedTextWidth
                    text: modelData.text || ""
                    color: "white"
                    font.pixelSize: root.textPixelSize
                    font.family: root.textFontFamily
                    font.weight: Font.Bold
                    font.letterSpacing: -0.15
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    RecordingIndicator {
        id: timeRecordingIndicator
        active: root.recordingActive
            && root.showSecondaryText
            && root.timeText !== ""
            && root.clampedProgress < 0.001
        contentOpacity: 1 - root.clampedProgress
        x: root.timeRecordingDotX
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        visible: timeText !== "" && showSecondaryText
        x: timeX
        width: textWidth
        anchors.verticalCenter: parent.verticalCenter
        text: timeText
        color: "white"
        opacity: 1 - clampedProgress
        font.pixelSize: root.textPixelSize + 1
        font.family: timeFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.25
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
}
