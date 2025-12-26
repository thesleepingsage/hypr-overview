// hypr-overview standalone entry point
// Run with: qs --path ~/.config/quickshell/hypr-overview
//
// This file creates:
// 1. One "controller" Overview (screen: null) for IPC and global shortcuts
// 2. One Overview per screen for the actual visual overlay

import QtQuick
import Quickshell

Scope {
    id: root

    // Controller instance - handles IPC and global shortcuts only (no visual)
    // The Overview component checks `screen === null` to enable IPC handlers
    Overview {
        id: controller
        // screen: null (default) - this instance only handles IPC
    }

    // Per-screen instances - these show the actual overview overlay
    Variants {
        model: Quickshell.screens

        Overview {
            required property var modelData
            screen: modelData
        }
    }
}
