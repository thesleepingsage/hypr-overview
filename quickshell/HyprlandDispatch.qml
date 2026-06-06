pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * HyprlandDispatch - Single source of truth for Hyprland dispatcher payloads.
 *
 * Hyprland 0.55 evaluates the socket `dispatch` request as Lua
 * (`return hl.dispatch(<input>)`) when the active config is Lua mode. The legacy
 * space-separated dispatcher strings (`movetoworkspacesilent 3,address:0x...`)
 * are invalid Lua and silently no-op there. This singleton emits the correct
 * payload for each operation, branching on `Hyprland.usingLua`:
 *   - usingLua  -> the new `hl.dsp.*` Lua form (compact, no inner spaces)
 *   - !usingLua -> the legacy string form (for users still on hyprlang configs)
 *
 * Returns payload STRINGS (not dispatch calls) so both transports reuse it:
 * widgets wrap with `Hyprland.dispatch(...)`, StashState feeds its
 * `hyprctl dispatch <payload>` Process. Addresses must be `0x`-prefixed
 * (callers normalize via HyprlandData.normalizeAddr).
 */
Singleton {
    id: root

    // Move a window to a workspace. silent=true => don't follow focus
    // (legacy movetoworkspacesilent; Lua follow=false).
    function moveToWorkspace(address, ws, silent) {
        return Hyprland.usingLua
            ? `hl.dsp.window.move({workspace="${ws}",follow=${!silent},window="address:${address}"})`
            : `movetoworkspace${silent ? "silent" : ""} ${ws},address:${address}`;
    }

    // Swap the operated window with a target window.
    // Legacy `swapwindow` takes only the target and acts on the focused window, so
    // `address` (the source) is intentionally unused in that branch; the Lua form
    // swaps the two windows explicitly. hy3 has no swap dispatcher — vanilla swap
    // routes through the layout's swap interface, which hy3 implements.
    function swapWindows(address, targetAddress) {
        return Hyprland.usingLua
            ? `hl.dsp.window.swap({target="address:${targetAddress}",window="address:${address}"})`
            : `swapwindow address:${targetAddress}`;
    }

    // Move a floating window to absolute pixel coordinates.
    function moveToPixel(address, x, y) {
        return Hyprland.usingLua
            ? `hl.dsp.window.move({x=${x},y=${y},relative=false,window="address:${address}"})`
            : `movewindowpixel exact ${x} ${y},address:${address}`;
    }

    // Focus a window by address.
    function focusWindow(address) {
        return Hyprland.usingLua
            ? `hl.dsp.focus({window="address:${address}"})`
            : `focuswindow address:${address}`;
    }

    // Close a window by address.
    function closeWindow(address) {
        return Hyprland.usingLua
            ? `hl.dsp.window.close({window="address:${address}"})`
            : `closewindow address:${address}`;
    }

    // Switch to a workspace. `selector` may be an id ("3"), "name:foo", or "special:bar".
    function focusWorkspace(selector) {
        return Hyprland.usingLua
            ? `hl.dsp.focus({workspace="${selector}"})`
            : `workspace ${selector}`;
    }

    // Warp the cursor to absolute compositor coordinates.
    function cursorMove(x, y) {
        return Hyprland.usingLua
            ? `hl.dsp.cursor.move({x=${x},y=${y}})`
            : `movecursor ${x} ${y}`;
    }

    // Swap two windows while keeping the cursor put.
    //
    // Hyprland's swap action (Actions::swapWith) hardcodes a cursor warp onto the
    // swapped window, with no per-call suppression. Cross-workspace moves are silent
    // and don't warp, so swap feels inconsistent. To match it we save the cursor
    // position (hyprctl cursorpos), dispatch the swap, then warp the cursor back.
    // Socket ordering guarantees the restore lands after swapWith's warp. The swap
    // always happens even if the read fails -- the restore is best-effort.
    //
    // `afterSwap` runs the caller's post-swap work (the windowListUpdated/snap-back
    // wiring) once the swap has been dispatched.
    property var _swapPending: null
    property string _cursorBuf: ""

    function swapWindowsPreservingCursor(srcAddr, targetAddr, afterSwap) {
        if (root._swapPending) {
            // A cursorpos read is already in flight (only reachable by two drag
            // releases inside the few-ms read window -- practically impossible with
            // one pointer). Don't clobber it; still run the caller's snap-back so the
            // dropped delegate's preview can't be stranded mid-drag.
            if (afterSwap)
                afterSwap();
            return;
        }
        root._swapPending = { src: srcAddr, target: targetAddr, afterSwap: afterSwap };
        root._cursorBuf = "";
        _cursorProc.running = true;
    }

    Process {
        id: _cursorProc
        command: ["hyprctl", "cursorpos"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._cursorBuf += data; }
        }
        onExited: (exitCode, exitStatus) => {
            const pending = root._swapPending;
            const buf = root._cursorBuf;
            root._swapPending = null;
            root._cursorBuf = "";
            if (!pending)
                return;

            // Dispatch the swap first (warps the cursor), then restore.
            const swapCmd = root.swapWindows(pending.src, pending.target);
            console.log(`[hypr-overview] SWAP: ${swapCmd}`);
            Hyprland.dispatch(swapCmd);

            // Parse "x, y" and warp the cursor back (best-effort).
            if (exitCode === 0) {
                const m = buf.match(/(-?\d+)\s*,\s*(-?\d+)/);
                if (m) {
                    Hyprland.dispatch(root.cursorMove(parseInt(m[1], 10), parseInt(m[2], 10)));
                }
            }

            if (pending.afterSwap)
                pending.afterSwap();
        }
    }
}
