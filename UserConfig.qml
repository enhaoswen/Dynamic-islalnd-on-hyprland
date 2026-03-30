import QtQuick

QtObject {
    id: userConfig

    property var scriptPaths: ({
        button_1: "~/.config/quickshell/wifi-menu.sh",
        button_2: "~/.config/quickshell/bluetooth-menu.sh",
        button_3: "~/.config/quickshell/wallpaper-switch.sh",
        button_4: "~/.config/quickshell/powermenu"
    })

    property var controlCenterActions: ([
        { icon: "", command: scriptPaths.button_1 },
        { icon: "", command: scriptPaths.button_2 },
        { icon: "󰋩", command: scriptPaths.button_3 },
        { icon: "󰣇", command: scriptPaths.button_4 }
    ])

    property var controlCenterIcons: ({
        "charging": "",
        "brightness": "󰃟",
        "volume": "󰕾"
    })

    property var statusIcons: ({
        "default": "🎧",
        "volume": "󰕾",
        "mute": "󰝟",
        "brightnessLow": "󰃞",
        "brightnessMedium": "󰃟",
        "brightnessHigh": "󰃠",
        "charging": "",
        "discharging": "",
        "capsLockOn": "",
        "capsLockOff": "",
        "bluetooth": "󰋋"
    })
}
