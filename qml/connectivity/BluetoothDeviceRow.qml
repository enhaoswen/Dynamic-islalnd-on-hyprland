import QtQuick
import Quickshell.Bluetooth
import IslandBackend

Rectangle {
    id: root

    property var provider: null
    property var device: null
    property string section: "available"
    property string iconFontFamily: ""
    property string textFontFamily: ""

    readonly property bool hasProvider: provider !== null && provider !== undefined
    readonly property bool hasDevice: device !== null && device !== undefined
    readonly property bool paired: hasDevice && (device.paired || device.bonded)
    readonly property bool connected: hasDevice && device.connected
    readonly property bool pairing: hasDevice && device.pairing
    readonly property bool busy: pairing || (hasDevice
        && (device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting))
    readonly property string pendingPath: hasProvider ? provider.bluetoothPairAndConnectPath : ""
    readonly property bool anotherOperationActive: pendingPath.length > 0
        && hasDevice && pendingPath !== device.dbusPath
    readonly property bool canForget: paired && !connected && !busy && !anotherOperationActive
    readonly property bool canInteract: hasProvider && hasDevice && provider.bluetoothEnabled
        && !busy && !anotherOperationActive
    readonly property string actionText: {
        if (hasDevice && device.state === BluetoothDeviceState.Connecting) return "Connecting";
        if (hasDevice && device.state === BluetoothDeviceState.Disconnecting) return "Disconnecting";
        if (section === "connected") return "Disconnect";
        if (section === "paired") return "Connect";
        return pairing ? "Pairing" : "Pair";
    }
    readonly property string subtitleText: hasProvider && provider.bluetoothDeviceSubtitle
        ? provider.bluetoothDeviceSubtitle(device)
        : ""
    readonly property color iconColor: section === "available" ? StyleTokens.textTertiary : StyleTokens.accent

    width: parent ? parent.width : 0
    height: 56
    radius: 14
    color: primaryMouse.containsMouse && root.canInteract
        ? StyleTokens.moduleHover
        : StyleTokens.transparent
    opacity: root.busy ? 0.68 : 1
    clip: true

    Behavior on color {
        ColorAnimation { duration: StyleTokens.durationFast }
    }

    MouseArea {
        id: primaryMouse
        anchors.fill: parent
        enabled: root.canInteract
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            if (root.provider && root.provider.handleBluetoothDevicePressed)
                root.provider.handleBluetoothDevicePressed(root.device);
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasProvider ? root.provider.bluetoothGlyph : ""
            color: root.iconColor
            font.pixelSize: 14
            font.family: root.iconFontFamily
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 26
            anchors.top: parent.top
            anchors.right: actionRow.left
            anchors.rightMargin: 8
            text: root.hasProvider && root.provider.bluetoothDeviceName
                ? root.provider.bluetoothDeviceName(root.device)
                : ""
            color: StyleTokens.textPrimary
            font.pixelSize: 12
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 26
            anchors.bottom: parent.bottom
            anchors.right: actionRow.left
            anchors.rightMargin: 8
            text: root.subtitleText
            color: StyleTokens.textMuted
            font.pixelSize: 10
            font.family: root.textFontFamily
            elide: Text.ElideRight
        }

        Row {
            id: actionRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: "Forget"
                color: forgetMouse.containsMouse ? StyleTokens.error : StyleTokens.textTertiary
                font.pixelSize: 10
                font.family: root.textFontFamily
                font.weight: Font.Medium
                visible: root.canForget

                MouseArea {
                    id: forgetMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: root.canForget
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.provider && root.device)
                            root.provider.forgetBluetoothDevice(root.device);
                    }
                }
            }

            Text {
                id: actionLabel
                text: root.actionText
                color: root.connected ? StyleTokens.accentSoft : StyleTokens.textPrimary
                font.pixelSize: 11
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
            }
        }
    }

}
