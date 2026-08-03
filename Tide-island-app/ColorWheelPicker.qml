import QtQuick
import QtQuick.Controls

Item {
    id: picker

    signal applied(string hexColor)
    signal cancelled()

    property real hue: 0
    property real saturation: 0
    property real value: 1

    readonly property string hexColor: picker.rgbToHex(picker.hsvToRgb(hue, saturation, value))

    implicitWidth: 300
    implicitHeight: 360

    function setColor(hex) {
        var rgb = picker.hexToRgb(hex)
        var hsv = picker.rgbToHsv(rgb.r, rgb.g, rgb.b)
        hue = hsv.h
        saturation = hsv.s
        value = hsv.v
    }

    property bool wheelPainted: false

    function hexToRgb(hex) {
        var clean = hex.indexOf("#") === 0 ? hex.substring(1) : hex
        if (clean.length !== 6)
            clean = "000000"
        return {
            r: parseInt(clean.substr(0, 2), 16),
            g: parseInt(clean.substr(2, 2), 16),
            b: parseInt(clean.substr(4, 2), 16)
        }
    }

    function rgbToHex(rgb) {
        function toHexPart(n) {
            var s = n.toString(16)
            return s.length === 1 ? "0" + s : s
        }
        return "#" + toHexPart(rgb.r) + toHexPart(rgb.g) + toHexPart(rgb.b)
    }

    function hsvToRgb(h, s, v) {
        var r, g, b
        var i = Math.floor(h * 6)
        var f = h * 6 - i
        var p = v * (1 - s)
        var q = v * (1 - f * s)
        var t = v * (1 - (1 - f) * s)
        switch (i % 6) {
            case 0: r = v; g = t; b = p; break
            case 1: r = q; g = v; b = p; break
            case 2: r = p; g = v; b = t; break
            case 3: r = p; g = q; b = v; break
            case 4: r = t; g = p; b = v; break
            case 5: r = v; g = p; b = q; break
            default: r = 0; g = 0; b = 0
        }
        return { r: Math.round(r * 255), g: Math.round(g * 255), b: Math.round(b * 255) }
    }

    function hsvToRgbColor(h, s, v) {
        var rgb = picker.hsvToRgb(h, s, v)
        return Qt.rgba(rgb.r / 255, rgb.g / 255, rgb.b / 255, 1)
    }

    function rgbToHsv(r, g, b) {
        r /= 255; g /= 255; b /= 255
        var max = Math.max(r, g, b)
        var min = Math.min(r, g, b)
        var d = max - min
        var h = 0
        if (d !== 0) {
            if (max === r) h = ((g - b) / d) % 6
            else if (max === g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h = h / 6
            if (h < 0) h += 1
        }
        var s = max === 0 ? 0 : d / max
        var v = max
        return { h: h, s: s, v: v }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Text {
            text: "Choose Background Color"
            font.family: Theme.textFontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Theme.textColor
        }

        Row {
            spacing: 16

            Item {
                id: wheelArea
                width: 200
                height: 200

                Canvas {
                    id: wheelCanvas
                    anchors.fill: parent

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onVisibleChanged: {
                        if (visible) requestPaint()
                    }

                    onPaint: {
                        if (width === 0 || height === 0) return
                        
                        var ctx = getContext("2d")
                        var w = width
                        var h = height
                        var cx = w / 2
                        var cy = h / 2
                        var radius = Math.min(cx, cy) - 2

                        ctx.clearRect(0, 0, w, h)

                        for (var i = 0; i < 360; i++) {
                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            
                            var startAngle = (i - 0.5) * Math.PI / 180
                            var endAngle = (i + 1.5) * Math.PI / 180
                            
                            ctx.arc(cx, cy, radius, startAngle, endAngle, false)
                            ctx.closePath()
                            
                            ctx.fillStyle = picker.hsvToRgbColor(i / 360, 1, 1).toString()
                            ctx.fill()
                        }

                        var gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius)
                        gradient.addColorStop(0, "rgba(255, 255, 255, 1.0)")
                        gradient.addColorStop(1, "rgba(255, 255, 255, 0.0)")

                        ctx.beginPath()
                        ctx.arc(cx, cy, radius, 0, 2 * Math.PI, false)
                        ctx.fillStyle = gradient
                        ctx.fill()
                    }
                }

                Rectangle {
                    id: wheelHandle
                    width: 14
                    height: 14
                    radius: 7
                    border.width: 2
                    border.color: "#ffffff"
                    color: "transparent"
                    x: wheelArea.width / 2 + picker.saturation * (wheelArea.width / 2 - 2) * Math.cos(picker.hue * 2 * Math.PI) - width / 2
                    y: wheelArea.height / 2 + picker.saturation * (wheelArea.height / 2 - 2) * Math.sin(picker.hue * 2 * Math.PI) - height / 2
                }

                MouseArea {
                    id: wheelMouse
                    anchors.fill: parent

                    function updateFromPos(mx, my) {
                        var cx = wheelArea.width / 2
                        var cy = wheelArea.height / 2
                        var dx = mx - cx
                        var dy = my - cy
                        var radius = Math.min(cx, cy) - 2
                        var dist = Math.sqrt(dx * dx + dy * dy)
                        var angle = Math.atan2(dy, dx)
                        if (angle < 0) angle += 2 * Math.PI
                        picker.hue = angle / (2 * Math.PI)
                        picker.saturation = Math.min(1, dist / radius)
                    }

                    onPressed: function(mouse) { updateFromPos(mouse.x, mouse.y) }
                    onPositionChanged: function(mouse) { if (pressed) updateFromPos(mouse.x, mouse.y) }
                }
            }

            Rectangle {
                id: valueSlider
                width: 24
                height: 200
                radius: 6
                border.width: 1
                border.color: Theme.inputBorderColor

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: picker.hsvToRgbColor(picker.hue, picker.saturation, 1) }
                    GradientStop { position: 1.0; color: "#000000" }
                }

                Rectangle {
                    width: parent.width + 6
                    height: 4
                    radius: 2
                    color: "transparent"
                    border.width: 2
                    border.color: "#ffffff"
                    x: -3
                    y: (1 - picker.value) * (parent.height - height)
                }

                MouseArea {
                    anchors.fill: parent

                    function updateFromY(my) {
                        var clamped = Math.max(0, Math.min(height, my))
                        picker.value = 1 - clamped / height
                    }

                    onPressed: function(mouse) { updateFromY(mouse.y) }
                    onPositionChanged: function(mouse) { if (pressed) updateFromY(mouse.y) }
                }
            }
        }

        Row {
            spacing: 12

            Rectangle {
                width: 40
                height: 40
                radius: 8
                color: picker.hexColor
                border.width: 1
                border.color: Theme.inputBorderColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: picker.hexColor
                font.family: Theme.textFontFamily
                font.pixelSize: 14
                color: Theme.textColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            spacing: 10
            anchors.right: parent.right

            Rectangle {
                width: 80
                height: 34
                radius: 7
                color: Theme.mutedButtonColor
                border.width: 1
                border.color: Theme.inputBorderColor

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.mutedButtonTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.cancelled()
                }
            }

            Rectangle {
                width: 80
                height: 34
                radius: 7
                color: Theme.buttonColor

                Text {
                    anchors.centerIn: parent
                    text: "Apply"
                    color: Theme.buttonTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.applied(picker.hexColor)
                }
            }
        }
    }
}
