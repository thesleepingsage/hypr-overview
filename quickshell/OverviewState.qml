pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool isOpen: false

    // Board Mode v2: Mode management
    property string currentMode: "grid"  // "grid" | "board" - default until Config loads
    readonly property bool isFirstRun: !OverviewConfig.initialSetupDone

    // Initialize from Config after both singletons are ready
    Component.onCompleted: {
        currentMode = OverviewConfig.activeMode
    }

    function setMode(mode) {
        if (mode !== "grid" && mode !== "board") {
            console.warn("[hypr-overview] Invalid mode:", mode)
            return
        }
        currentMode = mode
        OverviewConfig.setActiveMode(mode)
        console.log("[hypr-overview] Mode set to:", mode)
    }

    function toggleMode() {
        setMode(currentMode === "grid" ? "board" : "grid")
    }

    function toggle(): void {
        isOpen = !isOpen
        console.log("[hypr-overview] toggle -> isOpen:", isOpen)
    }

    function open(): void {
        isOpen = true
        console.log("[hypr-overview] open")
    }

    function close(): void {
        isOpen = false
        console.log("[hypr-overview] close")
    }
}
