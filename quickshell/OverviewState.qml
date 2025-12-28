pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool isOpen: false

    // Board Mode v2: Mode management
    property string currentMode: Config.defaultMode  // "grid" | "board"
    property bool isFirstRun: !Config.modeChosen

    function setMode(mode) {
        if (mode !== "grid" && mode !== "board") {
            console.warn("[hypr-overview] Invalid mode:", mode)
            return
        }
        currentMode = mode
        Config.setDefaultMode(mode)
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
