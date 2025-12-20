// hypr-overview - Workspace overview component
// Phase 3: Multi-monitor per-screen component with GlobalShortcut + HyprlandFocusGrab

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root

    // Screen this overview is displayed on (set by parent ScreenState)
    property var screen: null

    // Visibility controlled by OverviewState singleton
    property bool isVisible: OverviewState.isOpen

    // Monitor for this screen
    readonly property HyprlandMonitor monitor: root.screen ? Hyprland.monitorFor(root.screen) : null
    readonly property bool monitorIsFocused: Hyprland.focusedMonitor?.id === root.monitor?.id

    // IPC handler for overview control - only create when in shell.qml context (no screen)
    IpcHandler {
        enabled: root.screen === null
        target: "overview"

        function toggle(): void {
            OverviewState.toggle()
        }

        function open(): void {
            OverviewState.open()
        }

        function close(): void {
            OverviewState.close()
        }

        // Stash operations
        function stashWorkspace(): void {
            StashState.stashWorkspace("quick")
        }

        function stashWorkspaceTo(trayName: string): void {
            StashState.stashWorkspace(trayName)
        }

        function unstashAll(trayName: string): void {
            StashState.unstashAll(trayName || "quick")
        }
    }

    // GlobalShortcut for keybind integration - only create when in shell.qml context (no screen)
    // Note: GlobalShortcut doesn't support 'enabled', so we use Loader
    Loader {
        active: root.screen === null
        sourceComponent: GlobalShortcut {
            name: "overviewToggle"
            description: "Toggle workspace overview"

            onPressed: {
                OverviewState.toggle()
            }
        }
    }

    // Stash shortcuts
    Loader {
        active: root.screen === null
        sourceComponent: GlobalShortcut {
            name: "stashWorkspace"
            description: "Stash all windows from current workspace to quick tray"

            onPressed: {
                StashState.stashWorkspace("quick")
            }
        }
    }

    Loader {
        active: root.screen === null
        sourceComponent: GlobalShortcut {
            name: "unstashQuick"
            description: "Restore all windows from quick stash tray"

            onPressed: {
                StashState.unstashAll("quick")
            }
        }
    }

    // Refresh data when overview opens
    onIsVisibleChanged: {
        if (root.screen === null) return
        console.log("[hypr-overview] Overview visibility changed:", isVisible, "on screen:", screen?.name ?? "unknown")
        if (isVisible) {
            HyprlandData.updateAll()
            if (root.monitorIsFocused) {
                focusGrabTimer.start()
            }
        }
    }

    // Only create panel when we have a valid screen (not the shell.qml instance which is just for IPC)
    PanelWindow {
        id: panel
        visible: root.isVisible && root.screen !== null
        screen: root.screen ?? Quickshell.screens[0]

        // Layer shell configuration
        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Full screen overlay
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Semi-transparent backdrop
        color: Qt.rgba(0, 0, 0, OverviewConfig.backdropOpacity)

        // Focus grab for click-outside-to-close behavior
        HyprlandFocusGrab {
            id: focusGrab
            windows: [panel]
            active: false

            onCleared: {
                if (!active) {
                    OverviewState.close()
                }
            }
        }

        // Timer to delay focus grab activation (race condition workaround from end-4)
        Timer {
            id: focusGrabTimer
            interval: 50
            repeat: false
            onTriggered: {
                if (root.monitorIsFocused && root.isVisible) {
                    focusGrab.active = true
                }
            }
        }

        // Deactivate focus grab when overview closes
        Connections {
            target: OverviewState
            function onIsOpenChanged() {
                if (!OverviewState.isOpen) {
                    focusGrab.active = false
                }
            }
        }

        // Backdrop MouseArea + keyboard handling
        MouseArea {
            id: backdropArea
            anchors.fill: parent
            focus: root.isVisible
            onClicked: OverviewState.close()

            // Keyboard handling
            Keys.onEscapePressed: OverviewState.close()
            Keys.onLeftPressed: navigateWorkspace(-1, 0)
            Keys.onRightPressed: navigateWorkspace(1, 0)
            Keys.onUpPressed: navigateWorkspace(0, -1)
            Keys.onDownPressed: navigateWorkspace(0, 1)
            Keys.onReturnPressed: OverviewState.close()
        }

        // Center the overview widget
        OverviewWidget {
            id: overviewWidget
            anchors.centerIn: parent
            panelWindow: panel
        }

        function navigateWorkspace(dx, dy) {
            const monitor = Hyprland.monitorFor(panel.screen)
            const currentWs = monitor.activeWorkspace?.id ?? 1
            const rows = OverviewConfig.rows
            const cols = OverviewConfig.columns

            // Calculate current position in grid
            const currentRow = Math.floor((currentWs - 1) / cols) % rows
            const currentCol = (currentWs - 1) % cols

            // Calculate new position
            let newRow = currentRow + dy
            let newCol = currentCol + dx

            // Wrap around
            if (newCol < 0) newCol = cols - 1
            if (newCol >= cols) newCol = 0
            if (newRow < 0) newRow = rows - 1
            if (newRow >= rows) newRow = 0

            // Calculate new workspace ID
            const workspaceGroup = Math.floor((currentWs - 1) / (rows * cols))
            const newWs = workspaceGroup * (rows * cols) + newRow * cols + newCol + 1

            Hyprland.dispatch(`workspace ${newWs}`)
        }
    }
}
