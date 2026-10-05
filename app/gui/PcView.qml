import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import ComputerModel 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

CenteredGridView {
    property ComputerModel computerModel : createModel()

    id: pcGrid
    focus: true
    activeFocusOnTab: true
    topMargin: 20
    bottomMargin: 5
    cellWidth: 310; cellHeight: 330;
    objectName: qsTr("Computers")

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        currentIndex = -1
    }

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        // Setup signals on CM
        ComputerManager.computerAddCompleted.connect(addComplete)

        // Highlight the first item if a gamepad is connected
        if (currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            currentIndex = 0
        }
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    function pairingComplete(error)
    {
        // Close the PIN dialog
        pairDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTr("Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        return model
    }

    Row {
        anchors.centerIn: parent
        spacing: 5
        visible: pcGrid.count === 0

        BusyIndicator {
            id: searchSpinner
            visible: StreamingPreferences.enableMdns
            running: visible
        }

        Label {
            height: searchSpinner.height
            elide: Label.ElideRight
            text: StreamingPreferences.enableMdns ? qsTr("Searching for compatible hosts on your local network...")
                                                  : qsTr("Automatic PC discovery is disabled. Add your PC manually.")
            font.pointSize: 20
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

    model: computerModel

    delegate: NavigableItemDelegate {
        width: 300; height: 320;
        grid: pcGrid

        property alias pcContextMenu : pcContextMenuLoader.item

        Image {
            id: pcIcon
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/res/desktop_windows-48px.svg"
            sourceSize {
                width: 200
                height: 200
            }
        }

        Image {
            // TODO: Tooltip
            id: stateIcon
            anchors.horizontalCenter: pcIcon.horizontalCenter
            anchors.verticalCenter: pcIcon.verticalCenter
            anchors.verticalCenterOffset: !model.online ? -18 : -16
            visible: !model.statusUnknown && (!model.online || !model.paired)
            source: !model.online ? "qrc:/res/warning_FILL1_wght300_GRAD200_opsz24.svg" : "qrc:/res/baseline-lock-24px.svg"
            sourceSize {
                width: !model.online ? 75 : 70
                height: !model.online ? 75 : 70
            }
        }

        BusyIndicator {
            id: statusUnknownSpinner
            anchors.horizontalCenter: pcIcon.horizontalCenter
            anchors.verticalCenter: pcIcon.verticalCenter
            anchors.verticalCenterOffset: -15
            width: 75
            height: 75
            visible: model.statusUnknown
            running: visible
        }

        Label {
            id: pcNameText
            text: model.name

            width: parent.width
            anchors.top: pcIcon.bottom
            anchors.bottom: parent.bottom
            font.pointSize: 36
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        Loader {
            id: pcContextMenuLoader
            asynchronous: true
            sourceComponent: NavigableMenu {
                id: pcContextMenu
                initiator: pcContextMenuLoader.parent
                MenuItem {
                    text: qsTr("PC Status: %1").arg(model.online ? qsTr("Online") : qsTr("Offline"))
                    font.bold: true
                    enabled: false
                }
                NavigableMenuItem {
                    text: qsTr("View All Apps")
                    onTriggered: {
                        var component = Qt.createComponent("AppView.qml")
                        var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true})
                        stackView.push(appView)
                    }
                    visible: model.online && model.paired
                }
                NavigableMenuItem {
                    text: qsTr("Wake PC")
                    onTriggered: computerModel.wakeComputer(index)
                    visible: !model.online && model.wakeable
                }
                NavigableMenuItem {
                    text: qsTr("Test Network")
                    onTriggered: {
                        computerModel.testConnectionForComputer(index)
                        testConnectionDialog.open()
                    }
                }

                NavigableMenuItem {
                    text: qsTr("Rename PC")
                    onTriggered: {
                        renamePcDialog.pcIndex = index
                        renamePcDialog.originalName = model.name
                        renamePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("Stream Settings")
                    onTriggered: {
                        hostSettingsDialog.pcIndex = index
                        hostSettingsDialog.pcName = model.name
                        hostSettingsDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("Delete PC")
                    onTriggered: {
                        deletePcDialog.pcIndex = index
                        deletePcDialog.pcName = model.name
                        deletePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("View Details")
                    onTriggered: {
                        showPcDetailsDialog.pcDetails = model.details
                        showPcDetailsDialog.open()
                    }
                }
            }
        }

        onClicked: {
            if (model.online) {
                if (!model.serverSupported) {
                    errorDialog.text = qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(model.name)
                    errorDialog.helpText = ""
                    errorDialog.open()
                }
                else if (model.paired) {
                    // go to game view
                    var component = Qt.createComponent("AppView.qml")
                    var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name})
                    stackView.push(appView)
                }
                else {
                    var pin = computerModel.generatePinString()

                    // Kick off pairing in the background
                    computerModel.pairComputer(index, pin)

                    // Display the pairing dialog
                    pairDialog.pin = pin
                    pairDialog.open()
                }
            } else if (!model.online) {
                // Using open() here because it may be activated by keyboard
                pcContextMenu.open()
            }
        }

        onPressAndHold: {
            // popup() ensures the menu appears under the mouse cursor
            if (pcContextMenu.popup) {
                pcContextMenu.popup()
            }
            else {
                // Qt 5.9 doesn't have popup()
                pcContextMenu.open()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                parent.pressAndHold()
            }
        }

        Keys.onMenuPressed: {
            // We must use open() here so the menu is positioned on
            // the ItemDelegate and not where the mouse cursor is
            pcContextMenu.open()
        }

        Keys.onDeletePressed: {
            deletePcDialog.pcIndex = index
            deletePcDialog.pcName = model.name
            deletePcDialog.open()
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: pairDialog
        closePolicy: Popup.CloseOnEscape

        // don't allow edits to the rest of the window while open
        property string pin : "0000"
        text:qsTr("Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pin)+"\n\n"+
             qsTr("If your host PC is running Sunshine, navigate to the Sunshine web UI to enter the PIN.")
        standardButtons: Dialog.Cancel
        onRejected: {
            // FIXME: We should interrupt pairing here
        }
    }

    NavigableMessageDialog {
        id: deletePcDialog
        // don't allow edits to the rest of the window while open
        property int pcIndex : -1
        property string pcName : ""
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1;

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    renamePcDialog.accept()
                }

                Keys.onEnterPressed: {
                    renamePcDialog.accept()
                }
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails : "";
        text: showPcDetailsDialog.pcDetails
        imageSrc: "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }

    // Per-host overrides of the global stream settings. A value of 0 (or -1
    // for the display mode) means the global setting is used.
    NavigableDialog {
        id: hostSettingsDialog
        property int pcIndex : -1
        property string pcName : ""

        title: qsTr("Stream settings for %1").arg(pcName)
        standardButtons: Dialog.Save | Dialog.Cancel

        function isCustomResolution() {
            return hostResCombo.currentIndex >= 0 && hostResModel.get(hostResCombo.currentIndex).w < 0
        }

        function isInputValid() {
            return !isCustomResolution() || (hostResWidth.acceptableInput && hostResHeight.acceptableInput)
        }

        function updateSaveButton() {
            // standardButton() was added in Qt 5.10, so we must check for it first
            if (standardButton) {
                standardButton(Dialog.Save).enabled = isInputValid()
            }
        }

        function selectedWidth() {
            if (hostResCombo.currentIndex < 0) {
                return 0
            }
            var item = hostResModel.get(hostResCombo.currentIndex)
            return item.w >= 0 ? item.w : (parseInt(hostResWidth.text) || 0)
        }

        function selectedHeight() {
            if (hostResCombo.currentIndex < 0) {
                return 0
            }
            var item = hostResModel.get(hostResCombo.currentIndex)
            return item.h >= 0 ? item.h : (parseInt(hostResHeight.text) || 0)
        }

        function selectedFps() {
            return hostFpsCombo.currentIndex >= 0 ? hostFpsModel.get(hostFpsCombo.currentIndex).val : 0
        }

        // Mirrors HostStreamSettings::applyTo() for a bitrate that isn't overridden
        function automaticBitrate() {
            var overridesMode = (selectedWidth() > 0 && selectedHeight() > 0) || selectedFps() > 0
            if (overridesMode && StreamingPreferences.autoAdjustBitrate) {
                return StreamingPreferences.getDefaultBitrate(selectedWidth() || StreamingPreferences.width,
                                                              selectedHeight() || StreamingPreferences.height,
                                                              selectedFps() || StreamingPreferences.fps,
                                                              StreamingPreferences.enableYUV444)
            }
            return StreamingPreferences.bitrateKbps
        }

        onAboutToShow: {
            var settings = computerModel.getHostStreamSettings(pcIndex)

            hostResModel.setProperty(0, "text", qsTr("Use global setting (%1x%2)").arg(StreamingPreferences.width).arg(StreamingPreferences.height))
            var resIndex = 0
            if (settings.width > 0) {
                resIndex = hostResModel.count - 1
                for (var i = 1; i < hostResModel.count - 1; i++) {
                    if (hostResModel.get(i).w === settings.width && hostResModel.get(i).h === settings.height) {
                        resIndex = i
                        break
                    }
                }
            }
            hostResWidth.text = settings.width > 0 ? settings.width : ""
            hostResHeight.text = settings.height > 0 ? settings.height : ""
            hostResCombo.currentIndex = -1
            hostResCombo.currentIndex = resIndex

            hostFpsModel.setProperty(0, "text", qsTr("Use global setting (%1 FPS)").arg(StreamingPreferences.fps))
            var fpsIndex = -1
            for (var j = 0; j < hostFpsModel.count; j++) {
                if (hostFpsModel.get(j).val === settings.fps) {
                    fpsIndex = j
                    break
                }
            }
            if (fpsIndex < 0) {
                hostFpsModel.append({ text: qsTr("%1 FPS").arg(settings.fps), val: settings.fps })
                fpsIndex = hostFpsModel.count - 1
            }
            hostFpsCombo.currentIndex = -1
            hostFpsCombo.currentIndex = fpsIndex

            hostWindowModeCombo.currentIndex = 0
            for (var k = 0; k < hostWindowModeModel.count; k++) {
                if (hostWindowModeModel.get(k).val === settings.windowmode) {
                    hostWindowModeCombo.currentIndex = k
                    break
                }
            }

            hostBitrateCheck.checked = settings.bitrate > 0
            hostBitrateSlider.value = settings.bitrate > 0 ? settings.bitrate : automaticBitrate()

            hostResCombo.recalculateWidth()
            hostFpsCombo.recalculateWidth()
            hostWindowModeCombo.recalculateWidth()
            updateSaveButton()
        }

        onAccepted: {
            var width = 0
            var height = 0
            if (selectedWidth() > 0 && selectedHeight() > 0) {
                width = selectedWidth()
                height = selectedHeight()
            }

            computerModel.setHostStreamSettings(pcIndex, {
                "width": width,
                "height": height,
                "fps": selectedFps(),
                "bitrate": hostBitrateCheck.checked ? hostBitrateSlider.value : 0,
                "windowmode": hostWindowModeModel.get(hostWindowModeCombo.currentIndex).val
            })
        }

        ColumnLayout {
            spacing: 5

            Label {
                text: qsTr("Settings left on 'Use global setting' follow the main Settings page.")
                font.pointSize: 9
                wrapMode: Text.Wrap
                Layout.maximumWidth: 450
            }

            Label {
                text: qsTr("Resolution")
                font.bold: true
            }

            Row {
                spacing: 5

                AutoResizingComboBox {
                    id: hostResCombo
                    maximumWidth: 450
                    textRole: "text"
                    model: ListModel {
                        id: hostResModel
                        ListElement { text: "Use global setting"; w: 0; h: 0 }
                        ListElement { text: "1280x720"; w: 1280; h: 720 }
                        ListElement { text: "1920x1080"; w: 1920; h: 1080 }
                        ListElement { text: "1920x1200"; w: 1920; h: 1200 }
                        ListElement { text: "2560x1440"; w: 2560; h: 1440 }
                        ListElement { text: "3840x1080"; w: 3840; h: 1080 }
                        ListElement { text: "3840x2160"; w: 3840; h: 2160 }
                        ListElement { text: qsTr("Custom"); w: -1; h: -1 }
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0) {
                            hostSettingsDialog.updateSaveButton()
                        }
                    }
                }

                TextField {
                    id: hostResWidth
                    visible: hostSettingsDialog.isCustomResolution()
                    maximumLength: 5
                    inputMethodHints: Qt.ImhDigitsOnly
                    placeholderText: qsTr("Width")
                    validator: IntValidator{bottom:256; top:8192}
                    onTextChanged: hostSettingsDialog.updateSaveButton()
                }

                Label {
                    visible: hostResWidth.visible
                    text: "x"
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                    id: hostResHeight
                    visible: hostResWidth.visible
                    maximumLength: 5
                    inputMethodHints: Qt.ImhDigitsOnly
                    placeholderText: qsTr("Height")
                    validator: IntValidator{bottom:256; top:8192}
                    onTextChanged: hostSettingsDialog.updateSaveButton()
                }
            }

            Label {
                text: qsTr("Frame rate")
                font.bold: true
            }

            AutoResizingComboBox {
                id: hostFpsCombo
                maximumWidth: 450
                textRole: "text"
                model: ListModel {
                    id: hostFpsModel
                    ListElement { text: "Use global setting"; val: 0 }
                    ListElement { text: "30 FPS"; val: 30 }
                    ListElement { text: "60 FPS"; val: 60 }
                    ListElement { text: "90 FPS"; val: 90 }
                    ListElement { text: "120 FPS"; val: 120 }
                    ListElement { text: "144 FPS"; val: 144 }
                    ListElement { text: "240 FPS"; val: 240 }
                }
            }

            Label {
                text: hostBitrateCheck.checked ? qsTr("Video bitrate: %1 Mbps").arg(hostBitrateSlider.value / 1000.0)
                                               : qsTr("Video bitrate: automatic (%1 Mbps)").arg(hostSettingsDialog.automaticBitrate() / 1000.0)
                font.bold: true
            }

            CheckBox {
                id: hostBitrateCheck
                text: qsTr("Use a custom bitrate for this PC")
                onCheckedChanged: {
                    if (!checked) {
                        hostBitrateSlider.value = hostSettingsDialog.automaticBitrate()
                    }
                }
            }

            Slider {
                id: hostBitrateSlider
                enabled: hostBitrateCheck.checked
                stepSize: 500
                from: 500
                to: StreamingPreferences.unlockBitrate ? 500000 : 150000
                snapMode: "SnapOnRelease"
                Layout.preferredWidth: 450
            }

            Label {
                text: qsTr("Display mode")
                font.bold: true
                visible: SystemProperties.hasDesktopEnvironment
            }

            AutoResizingComboBox {
                id: hostWindowModeCombo
                visible: SystemProperties.hasDesktopEnvironment
                maximumWidth: 450
                textRole: "text"
                model: ListModel {
                    id: hostWindowModeModel
                    ListElement { text: qsTr("Use global setting"); val: -1 }
                    ListElement { text: qsTr("Fullscreen"); val: StreamingPreferences.WM_FULLSCREEN }
                    ListElement { text: qsTr("Borderless windowed"); val: StreamingPreferences.WM_FULLSCREEN_DESKTOP }
                    ListElement { text: qsTr("Windowed"); val: StreamingPreferences.WM_WINDOWED }
                }
            }
        }
    }

    ScrollBar.vertical: ScrollBar {}
}
