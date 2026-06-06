pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
}
