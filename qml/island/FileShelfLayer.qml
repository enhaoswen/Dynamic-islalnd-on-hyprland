pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import IslandBackend

FocusScope {
    id: root

    signal closeRequested

    property bool showCondition: false
    property bool dropPreviewOnly: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property int selectedIndex: FileShelf.count > 0 ? 0 : -1

    property bool reorderActive: false
    property bool reorderCommitting: false
    property int reorderSourceIndex: -1
    property int reorderTargetIndex: -1
    property real reorderStartContentX: 0
    property real reorderTranslationX: 0
    property real reorderPointerX: 0
    property string suppressedOpenUri: ""

    readonly property int visibleCapacity: 5
    readonly property real horizontalPadding: 18
    readonly property real cardWidth: 176
    readonly property real cardHeight: 176
    readonly property real overflowCellWidth: 196

    focus: showCondition && !dropPreviewOnly
    activeFocusOnTab: true
    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? StyleTokens.durationStandard : StyleTokens.durationFast
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (!showCondition)
            return;

        FileShelf.refresh();
        normalizeSelection();
        if (!dropPreviewOnly)
            grabKeyboardFocus();
    }

    onDropPreviewOnlyChanged: {
        if (showCondition && !dropPreviewOnly)
            grabKeyboardFocus();
    }

    Connections {
        target: FileShelf

        function onCountChanged() {
            root.normalizeSelection();
        }
    }

    function normalizeSelection() {
        if (FileShelf.count <= 0) {
            selectedIndex = -1;
            return;
        }
        selectedIndex = Math.max(0, Math.min(FileShelf.count - 1, selectedIndex));
    }

    function grabKeyboardFocus() {
        root.focus = true;
        root.forceActiveFocus();
    }

    function openCurrent() {
        if (FileShelf.count === 0 || selectedIndex < 0)
            return;

        const entry = FileShelf.get(selectedIndex);
        if (entry && entry.filePath)
            Quickshell.execDetached(["xdg-open", String(entry.filePath)]);
    }

    function removeCurrent() {
        if (FileShelf.count === 0 || selectedIndex < 0)
            return;
        removeAt(selectedIndex);
    }

    function removeAt(index) {
        if (index < 0 || index >= FileShelf.count || reorderActive)
            return;

        FileShelf.removeAt(index);
        selectedIndex = Math.min(index, FileShelf.count - 1);
        grabKeyboardFocus();
    }

    function moveSelection(offset) {
        if (FileShelf.count <= 0)
            return;
        selectedIndex = (selectedIndex + offset + FileShelf.count) % FileShelf.count;
        ensureSelectedVisible();
    }

    function ensureSelectedVisible() {
        if (selectedIndex < 0 || FileShelf.count <= visibleCapacity)
            return;
        const center = slotCenter(selectedIndex);
        trayViewport.contentX = Math.max(0, Math.min(
            trayViewport.contentWidth - trayViewport.width,
            center - trayViewport.width / 2));
    }

    function dragMimeData(fileUrl, filePath) {
        const url = String(fileUrl);
        return {
            "text/uri-list": url + "\r\n",
            "text/plain": String(filePath),
            "x-special/gnome-copied-files": "copy\n" + url + "\n"
        };
    }

    function slotStep() {
        if (FileShelf.count <= visibleCapacity)
            return trayViewport.width / Math.max(1, FileShelf.count + 1);
        return overflowCellWidth;
    }

    function slotCenter(index) {
        if (FileShelf.count <= visibleCapacity)
            return trayViewport.width * (index + 1) / Math.max(1, FileShelf.count + 1);
        return overflowCellWidth * index + overflowCellWidth / 2;
    }

    function beginReorder(index) {
        if (index < 0 || index >= FileShelf.count)
            return;
        reorderActive = true;
        reorderSourceIndex = index;
        reorderTargetIndex = index;
        reorderStartContentX = trayViewport.contentX;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        selectedIndex = index;
    }

    function updateReorder(translationX, pointerX) {
        if (!reorderActive)
            return;

        reorderTranslationX = translationX;
        reorderPointerX = pointerX;
        refreshReorderTarget();
    }

    function refreshReorderTarget() {
        if (!reorderActive)
            return;

        const contentDelta = trayViewport.contentX - reorderStartContentX;
        const columnDelta = Math.round((reorderTranslationX + contentDelta) / slotStep());
        reorderTargetIndex = Math.max(0, Math.min(
            FileShelf.count - 1, reorderSourceIndex + columnDelta));
    }

    function reorderShiftForIndex(index) {
        if (!reorderActive || index === reorderSourceIndex)
            return 0;
        if (reorderSourceIndex < reorderTargetIndex
                && index > reorderSourceIndex && index <= reorderTargetIndex)
            return -slotStep();
        if (reorderSourceIndex > reorderTargetIndex
                && index >= reorderTargetIndex && index < reorderSourceIndex)
            return slotStep();
        return 0;
    }

    function reorderVisualOffset() {
        if (!reorderActive)
            return 0;
        return reorderTranslationX + trayViewport.contentX - reorderStartContentX;
    }

    function finishReorder() {
        if (!reorderActive)
            return;

        const sourceIndex = reorderSourceIndex;
        const targetIndex = reorderTargetIndex;
        const positionChanged = sourceIndex !== targetIndex;
        // The displaced delegates are already visually in their final slots.
        // Disable their shift Behavior while the model indices are committed,
        // otherwise the new base position and old animated offset are applied
        // together for one frame and the delegate flies in from an outer edge.
        reorderCommitting = positionChanged;
        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;

        if (positionChanged)
            FileShelf.move(sourceIndex, targetIndex);
        selectedIndex = targetIndex;
        ensureSelectedVisible();
        if (positionChanged)
            reorderCommitReset.restart();
        suppressOpenReset.restart();
    }

    function cancelReorder() {
        if (!reorderActive)
            return;

        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        suppressOpenReset.restart();
    }

    Timer {
        id: reorderCommitReset
        interval: 0
        repeat: false
        onTriggered: root.reorderCommitting = false
    }

    Timer {
        id: suppressOpenReset
        interval: 0
        repeat: false
        onTriggered: root.suppressedOpenUri = ""
    }

    Timer {
        interval: 16
        repeat: true
        running: root.reorderActive && FileShelf.count > root.visibleCapacity

        onTriggered: {
            const edgeSize = 54;
            const maximumContentX = Math.max(0, trayViewport.contentWidth - trayViewport.width);
            let nextContentX = trayViewport.contentX;
            if (root.reorderPointerX < edgeSize)
                nextContentX = Math.max(0, nextContentX - 10);
            else if (root.reorderPointerX > trayViewport.width - edgeSize)
                nextContentX = Math.min(maximumContentX, nextContentX + 10);

            if (nextContentX !== trayViewport.contentX) {
                trayViewport.contentX = nextContentX;
                root.refreshReorderTarget();
            }
        }
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
        case Qt.Key_Tab:
            root.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_H:
        case Qt.Key_Backtab:
            root.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            root.removeCurrent();
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.openCurrent();
            event.accepted = true;
            break;
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.closeRequested()
    }

    Column {
        z: 2
        anchors.centerIn: parent
        spacing: 10
        visible: root.dropPreviewOnly || FileShelf.count === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf0ee"
            color: StyleTokens.textTertiary
            font.family: root.iconFontFamily
            font.pixelSize: 30
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.dropPreviewOnly
            text: "Drag files or folders onto Tide Island"
            color: StyleTokens.textSecondary
            font.family: root.textFontFamily
            font.pixelSize: 12
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.dropPreviewOnly
            text: "Drag a file to reorder it or drop it into another application"
            color: StyleTokens.textTertiary
            font.family: root.textFontFamily
            font.pixelSize: 10
        }
    }

    Flickable {
        id: trayViewport
        z: 2
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        visible: !root.dropPreviewOnly && FileShelf.count > 0
        clip: true
        contentWidth: FileShelf.count <= root.visibleCapacity
            ? width : FileShelf.count * root.overflowCellWidth
        contentHeight: height
        interactive: !root.reorderActive && FileShelf.count > root.visibleCapacity
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1800

        Repeater {
            model: FileShelf

            delegate: Item {
                id: fileDelegate

                required property int index
                required property string uri
                required property string filePath
                required property string fileName
                required property string displayName
                required property string iconName
                required property string fallbackIconName
                required property string iconSource
                required property bool directory

                readonly property bool selected: index === root.selectedIndex
                readonly property bool reorderSource: root.reorderActive
                    && index === root.reorderSourceIndex

                x: root.slotCenter(index) - width / 2
                y: Math.max(0, (trayViewport.height - height) / 2)
                width: root.cardWidth
                height: root.cardHeight
                z: reorderSource ? 12 : selected ? 4 : 2

                Item {
                    id: fileItem

                    anchors.centerIn: parent
                    width: parent.width
                    height: 166
                    scale: fileDrag.active ? 1.07
                        : fileArea.pressed ? 0.95
                        : (fileDelegate.selected || fileArea.containsMouse ? 1.035 : 1)

                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.proposedAction: Qt.CopyAction
                    Drag.hotSpot: Qt.point(width / 2, height / 2)
                    Drag.imageSource: systemIcon.source
                    Drag.mimeData: root.dragMimeData(fileDelegate.uri, fileDelegate.filePath)

                    transform: [
                        Translate {
                            x: fileDelegate.reorderSource ? root.reorderVisualOffset() : 0
                        },
                        Translate {
                            x: root.reorderShiftForIndex(fileDelegate.index)

                            Behavior on x {
                                enabled: !root.reorderCommitting
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                    ]

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    Item {
                        id: iconBox
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 122
                        height: 122

                        Image {
                            id: systemIcon
                            anchors.centerIn: parent
                            width: 108
                            height: 108
                            source: fileDelegate.iconSource !== ""
                                ? fileDelegate.iconSource
                                : Quickshell.iconPath(fileDelegate.fallbackIconName, true)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        Text {
                            anchors.centerIn: parent
                            z: 2
                            visible: systemIcon.status === Image.Error || systemIcon.source.toString() === ""
                            text: fileDelegate.directory ? "\uf07b" : "\uf15b"
                            color: StyleTokens.textSecondary
                            font.family: root.iconFontFamily
                            font.pixelSize: 68
                        }
                    }

                    Text {
                        anchors.top: iconBox.bottom
                        anchors.topMargin: 7
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        text: fileDelegate.displayName
                        color: fileDelegate.selected ? StyleTokens.textPrimary : StyleTokens.textDim
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: fileDelegate.selected ? Font.Medium : Font.Normal
                    }
                }

                MouseArea {
                    id: fileArea
                    z: 1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: fileDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onClicked: root.selectedIndex = fileDelegate.index
                    onDoubleClicked: {
                        if (root.suppressedOpenUri !== fileDelegate.uri)
                            Quickshell.execDetached(["xdg-open", fileDelegate.filePath]);
                    }
                }

                Rectangle {
                    id: deleteButton

                    z: 20
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.rightMargin: 16
                    width: 26
                    height: 26
                    radius: width / 2
                    color: "white"
                    opacity: (fileArea.containsMouse || deleteArea.containsMouse)
                        && !fileDrag.active && !root.reorderActive ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: 11
                        height: 11
                        rotation: 45

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 2
                            radius: 1
                            color: "#242424"
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 2
                            height: parent.height
                            radius: 1
                            color: "#242424"
                        }
                    }

                    MouseArea {
                        id: deleteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            mouse.accepted = true;
                            root.removeAt(fileDelegate.index);
                        }
                    }
                }

                DragHandler {
                    id: fileDrag

                    property bool exporting: false

                    target: null
                    acceptedButtons: Qt.LeftButton
                    xAxis.enabled: true
                    yAxis.enabled: true

                    function updateGesture() {
                        if (!active || exporting)
                            return;

                        const point = fileDelegate.mapToItem(
                            trayViewport, centroid.position.x, centroid.position.y);
                        const verticalExport = Math.abs(activeTranslation.y) >= 22
                            && Math.abs(activeTranslation.y) > Math.abs(activeTranslation.x);
                        const leftShelf = point.x < -12 || point.x > trayViewport.width + 12
                            || point.y < -12 || point.y > trayViewport.height + 12;
                        if (verticalExport || leftShelf) {
                            exporting = true;
                            root.cancelReorder();
                            // Start the native drag only after the gesture has
                            // been classified as an export. Starting it on
                            // press would steal horizontal motion from sorting.
                            fileItem.Drag.active = true;
                            return;
                        }
                        root.updateReorder(activeTranslation.x, point.x);
                    }

                    onActiveChanged: {
                        if (active) {
                            exporting = false;
                            root.suppressedOpenUri = fileDelegate.uri;
                            root.beginReorder(fileDelegate.index);
                            updateGesture();
                        } else if (fileDelegate.reorderSource) {
                            root.finishReorder();
                        } else {
                            fileItem.Drag.active = false;
                            exporting = false;
                        }
                    }

                    onActiveTranslationChanged: updateGesture()
                    onCentroidChanged: updateGesture()
                }
            }
        }
    }
}
