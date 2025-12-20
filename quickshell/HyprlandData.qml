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

    // Accumulator for client data
    property string _clientsBuffer: ""

    // Process: Get window/client list
    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._clientsBuffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root._clientsBuffer) {
                try {
                    root.windowList = JSON.parse(root._clientsBuffer)
                    let tempWinByAddress = {};
                    for (var i = 0; i < root.windowList.length; ++i) {
                        var win = root.windowList[i];
                        tempWinByAddress[win.address] = win;
                    }
                    root.windowByAddress = tempWinByAddress;
                    root.addresses = root.windowList.map(win => win.address);
                    root.windowListUpdated();  // Notify listeners that data is ready
                } catch (e) {
                    console.error("[hypr-overview] Failed to parse clients:", e, root._clientsBuffer.substring(0, 100));
                }
            }
            root._clientsBuffer = "";
        }
    }

    // Accumulator for monitor data
    property string _monitorsBuffer: ""

    // Process: Get monitor list
    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._monitorsBuffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root._monitorsBuffer) {
                try {
                    root.monitors = JSON.parse(root._monitorsBuffer);
                } catch (e) {
                    console.error("[hypr-overview] Failed to parse monitors:", e);
                }
            }
            root._monitorsBuffer = "";
        }
    }

    // Accumulator for workspace data
    property string _workspacesBuffer: ""

    // Process: Get workspace list
    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._workspacesBuffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root._workspacesBuffer) {
                try {
                    root.workspaces = JSON.parse(root._workspacesBuffer);
                    let tempWorkspaceById = {};
                    for (var i = 0; i < root.workspaces.length; ++i) {
                        var ws = root.workspaces[i];
                        tempWorkspaceById[ws.id] = ws;
                    }
                    root.workspaceById = tempWorkspaceById;
                    root.workspaceIds = root.workspaces.map(ws => ws.id);
                } catch (e) {
                    console.error("[hypr-overview] Failed to parse workspaces:", e);
                }
            }
            root._workspacesBuffer = "";
        }
    }

    // Accumulator for active workspace data
    property string _activeWsBuffer: ""

    // Process: Get active workspace
    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._activeWsBuffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root._activeWsBuffer) {
                try {
                    root.activeWorkspace = JSON.parse(root._activeWsBuffer);
                } catch (e) {
                    console.error("[hypr-overview] Failed to parse active workspace:", e);
                }
            }
            root._activeWsBuffer = "";
        }
    }
}
