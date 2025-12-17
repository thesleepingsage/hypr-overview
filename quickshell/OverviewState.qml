pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool isOpen: false

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
