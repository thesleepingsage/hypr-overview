pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * HyprlandData - Singleton service providing Hyprland window/workspace data
 * Adapted from end-4/dots-hyprland for hypr-overview
 */
Singleton {
    id: root

    // Window data
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})

    // Workspace data
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null

    // Monitor data
    property var monitors: []

    // Signals for completion notification
    signal windowListUpdated()

    /**
     * Get all toplevels (windows) for a specific workspace
     * @param workspace - workspace ID
     * @returns list of ToplevelManager entries
     */
    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = root.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    /**
     * Get hyprctl client data for a specific workspace
     * @param workspace - workspace ID
     * @returns list of hyprctl client objects
     */
    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    /**
     * Get hyprctl client data for a ToplevelManager entry
     * @param toplevel - ToplevelManager.toplevels entry
     * @returns hyprctl client object or null
     */
    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    /**
     * Get hyprctl client data for a specific workspace by name (for special workspaces)
     * @param workspaceName - workspace name (e.g., "special:stash-quick")
     * @returns list of hyprctl client objects
     */
    function hyprlandClientsForWorkspaceName(workspaceName) {
        return root.windowList.filter(win => win.workspace.name === workspaceName);
    }

    /**
     * Get the largest window in a workspace (useful for thumbnails)
     * @param workspaceId - workspace ID
     * @returns hyprctl client object or null
     */
    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = root.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    // Update functions
    function updateWindowList() {
        getClients.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateWorkspaces();
    }

    // Initialize on load
    Component.onCompleted: {
        updateAll();
        console.log("[hypr-overview] HyprlandData initialized");
    }

    // Auto-refresh on Hyprland events (except noise events)
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["openlayer", "closelayer", "screencast"].includes(event.name)) return;
            updateAll()
        }
    }

    // --- Buffered Process Components (using extracted pattern) ---

    BufferedProcess {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        logPrefix: "[hypr-overview:clients]"

        onCompleted: (data) => {
            root.windowList = data;
            let tempWinByAddress = {};
            for (var i = 0; i < root.windowList.length; ++i) {
                var win = root.windowList[i];
                tempWinByAddress[win.address] = win;
            }
            root.windowByAddress = tempWinByAddress;
            root.addresses = root.windowList.map(win => win.address);
            root.windowListUpdated();
        }
    }

    BufferedProcess {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        logPrefix: "[hypr-overview:monitors]"

        onCompleted: (data) => {
            root.monitors = data;
        }
    }

    BufferedProcess {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        logPrefix: "[hypr-overview:workspaces]"

        onCompleted: (data) => {
            root.workspaces = data;
            let tempWorkspaceById = {};
            for (var i = 0; i < root.workspaces.length; ++i) {
                var ws = root.workspaces[i];
                tempWorkspaceById[ws.id] = ws;
            }
            root.workspaceById = tempWorkspaceById;
            root.workspaceIds = root.workspaces.map(ws => ws.id);
        }
    }

    BufferedProcess {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        logPrefix: "[hypr-overview:activeWs]"

        onCompleted: (data) => {
            root.activeWorkspace = data;
        }
    }
}
