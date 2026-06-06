pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * HyprlandData - Singleton service providing Hyprland window/workspace data
 *
 * Reactive adapter over Quickshell's Hyprland.* models (Quickshell >= 0.3.0).
 * Instead of polling `hyprctl -j` on every event (the old approach), this derives
 * its public data from the live ObjectModels Hyprland.toplevels / .workspaces /
 * .monitors. Each model entry carries a `lastIpcObject` holding the full hyprctl
 * JSON (geometry, floating, class, xwayland, stableId, reserved[], ...).
 *
 * Note: lastIpcObject only updates when Hyprland.refreshToplevels()/refreshWorkspaces()/
 * refreshMonitors() is called -- it is NOT auto-refreshed. We trigger those refreshes
 * on the relevant socket2 events and when the overview opens, then rebuild() recomputes
 * the derived maps once the per-object lastIpcObject signals fire (debounced).
 *
 * The public interface (windowList, windowByAddress, workspaces, activeWorkspace,
 * monitors, the helper functions, update*() and windowListUpdated()) is kept stable
 * so existing consumers don't need to change.
 */
Singleton {
    id: root

    // Window data (each entry is a hyprctl `clients` JSON object)
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var windowByStableId: ({})

    // Workspace data (each entry is a hyprctl `workspaces` JSON object)
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null

    // Monitor data (each entry is a hyprctl `monitors` JSON object)
    property var monitors: []

    // Signal for completion notification (consumers connect then call updateWindowList)
    signal windowListUpdated()

    /**
     * Normalize a window address to the `0x...` form that hyprctl emits.
     * HyprlandToplevel.address / socket2 event addresses may lack the prefix.
     */
    function normalizeAddr(addr) {
        if (!addr)
            return "";
        const s = String(addr);
        return s.startsWith("0x") ? s : `0x${s}`;
    }

    /**
     * Get the live HyprlandToplevel objects for a specific workspace.
     * @param workspace - workspace ID
     * @returns list of HyprlandToplevel entries (have .address, .wayland, .workspace)
     */
    function toplevelsForWorkspace(workspace) {
        return Hyprland.toplevels.values.filter(toplevel => toplevel.workspace?.id === workspace);
    }

    /**
     * Get hyprctl client data for a specific workspace.
     * @param workspace - workspace ID
     * @returns list of hyprctl client objects
     */
    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace?.id === workspace);
    }

    /**
     * Get hyprctl client data for a HyprlandToplevel entry.
     * @param toplevel - Hyprland.toplevels entry
     * @returns hyprctl client object or null
     */
    function clientForToplevel(toplevel) {
        if (!toplevel)
            return null;
        return root.windowByAddress[normalizeAddr(toplevel.address)] ?? null;
    }

    /**
     * Get hyprctl client data by stableId (stable per-window identity, Hyprland >= 0.54).
     * @param id - stableId
     * @returns hyprctl client object or null
     */
    function clientForStableId(id) {
        return root.windowByStableId[id] ?? null;
    }

    /**
     * Get hyprctl client data for a specific workspace by name (for special workspaces).
     * @param workspaceName - workspace name (e.g., "special:stash-quick")
     * @returns list of hyprctl client objects
     */
    function hyprlandClientsForWorkspaceName(workspaceName) {
        return root.windowList.filter(win => win.workspace?.name === workspaceName);
    }

    /**
     * Get the largest window in a workspace (useful for thumbnails).
     * @param workspaceId - workspace ID
     * @returns hyprctl client object or null
     */
    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = root.windowList.filter(w => w.workspace?.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    // --- Refresh shims (preserve the old polling-style interface) ---
    // Refreshing causes Quickshell to re-fetch lastIpcObject; rebuild() runs once the
    // per-object lastIpcObjectChanged signals fire (see Instantiators below).
    function updateWindowList() {
        Hyprland.refreshToplevels();
        markRefreshed();
    }

    function updateMonitors() {
        Hyprland.refreshMonitors();
        markRefreshed();
    }

    function updateWorkspaces() {
        Hyprland.refreshWorkspaces();
        markRefreshed();
    }

    function updateAll() {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        markRefreshed();
    }

    // --- Derivation ---
    function rebuild() {
        // Windows
        const tls = Hyprland.toplevels.values;
        let wl = [];
        let byAddr = ({});
        let byStable = ({});
        let addrs = [];
        for (let i = 0; i < tls.length; ++i) {
            const obj = tls[i].lastIpcObject;
            if (!obj || !obj.address)
                continue;
            wl.push(obj);
            byAddr[obj.address] = obj;
            addrs.push(obj.address);
            if (obj.stableId !== undefined && obj.stableId !== null)
                byStable[obj.stableId] = obj;
        }
        root.windowList = wl;
        root.windowByAddress = byAddr;
        root.windowByStableId = byStable;
        root.addresses = addrs;

        // Workspaces
        const wss = Hyprland.workspaces.values;
        let wsl = [];
        let wsById = ({});
        let wsIds = [];
        for (let i = 0; i < wss.length; ++i) {
            const obj = wss[i].lastIpcObject;
            if (!obj)
                continue;
            wsl.push(obj);
            wsById[obj.id] = obj;
            wsIds.push(obj.id);
        }
        root.workspaces = wsl;
        root.workspaceById = wsById;
        root.workspaceIds = wsIds;

        // Active workspace
        root.activeWorkspace = Hyprland.focusedWorkspace?.lastIpcObject ?? null;

        // Monitors
        const mons = Hyprland.monitors.values;
        let ml = [];
        for (let i = 0; i < mons.length; ++i) {
            const obj = mons[i].lastIpcObject;
            if (obj)
                ml.push(obj);
        }
        root.monitors = ml;

        root.windowListUpdated();
    }

    // Debounce: coalesce the burst of per-object lastIpcObjectChanged signals from a
    // single refresh into one rebuild + one windowListUpdated() emission.
    Timer {
        id: rebuildDebounce
        interval: 16
        repeat: false
        onTriggered: root.rebuild()
    }
    function scheduleRebuild() {
        rebuildDebounce.restart();
    }

    // Fallback: an unconditional rebuild a short time after any refresh() call, in case
    // the per-object lastIpcObjectChanged path (Instantiators below) doesn't fire. This
    // guarantees geometry is picked up after refreshToplevels/Workspaces/Monitors complete.
    Timer {
        id: postRefreshRebuild
        interval: 120
        repeat: false
        onTriggered: root.rebuild()
    }
    function markRefreshed() {
        postRefreshRebuild.restart();
    }

    // --- React to model membership changes (windows/workspaces/monitors added or removed) ---
    property var liveToplevels: Hyprland.toplevels.values
    property var liveWorkspaces: Hyprland.workspaces.values
    property var liveMonitors: Hyprland.monitors.values
    property var liveFocusedWs: Hyprland.focusedWorkspace
    onLiveToplevelsChanged: root.scheduleRebuild()
    onLiveWorkspacesChanged: root.scheduleRebuild()
    onLiveMonitorsChanged: root.scheduleRebuild()
    onLiveFocusedWsChanged: root.scheduleRebuild()

    // --- React to per-object lastIpcObject refreshes (geometry/workspace changes
    //     that don't change list membership, e.g. window moved or resized) ---
    Instantiator {
        model: Hyprland.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged() {
                root.scheduleRebuild();
            }
        }
    }
    Instantiator {
        model: Hyprland.workspaces
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged() {
                root.scheduleRebuild();
            }
        }
    }
    Instantiator {
        model: Hyprland.monitors
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged() {
                root.scheduleRebuild();
            }
        }
    }

    // --- Refresh geometry when the overview opens, so previews are positioned correctly ---
    Connections {
        target: OverviewState
        function onIsOpenChanged() {
            if (OverviewState.isOpen)
                root.updateAll();
        }
    }

    // --- Auto-refresh on Hyprland socket2 events, routed to the relevant data ---
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            // Noise: layer surfaces and screencast/screencastv2 (0.55) -- do not refresh.
            if (n === "openlayer" || n === "closelayer" || n === "screencast" || n === "screencastv2")
                return;

            if (n === "renameworkspace" || n.startsWith("workspace") || n.startsWith("createworkspace")
                    || n.startsWith("destroyworkspace") || n.startsWith("moveworkspace") || n.startsWith("activespecial")) {
                // Workspace lifecycle: refresh workspaces (and toplevels, since membership may shift).
                Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
            } else if (n.startsWith("monitor") || n.startsWith("focusedmon")) {
                Hyprland.refreshMonitors();
            } else {
                // Window-centric events: openwindow, closewindow, movewindow(v2), activewindow(v2),
                // windowtitle(v2), fullscreen, minimized, urgent, kill, changefloatingmode, ...
                Hyprland.refreshToplevels();
            }
            root.markRefreshed();
        }
    }

    // Initialize on load
    Component.onCompleted: {
        updateAll();
        rebuild();
        console.log("[hypr-overview] HyprlandData initialized (reactive models); usingLua =", Hyprland.usingLua);
    }
}
