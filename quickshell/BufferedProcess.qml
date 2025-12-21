pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * BufferedProcess - Reusable component for running processes that output JSON
 * Accumulates stdout into a buffer, parses JSON on completion, and emits result
 */
Item {
    id: root

    // Configuration
    property var command: []
    property string logPrefix: "[BufferedProcess]"

    // Output
    property var result: null
    property bool hasResult: false

    // State
    property bool running: false
    property string _buffer: ""

    // Signals
    signal completed(var data)
    signal failed(string error)

    // Start the process
    function start() {
        _buffer = "";
        hasResult = false;
        result = null;
        _process.running = true;
    }

    // Alias for compatibility
    onRunningChanged: {
        if (running) start();
    }

    Process {
        id: _process
        command: root.command

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._buffer += data;
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.running = false;

            if (exitCode !== 0 || !root._buffer) {
                root.failed(`${root.logPrefix} Process exited with code ${exitCode}`);
                root._buffer = "";
                return;
            }

            try {
                root.result = JSON.parse(root._buffer);
                root.hasResult = true;
                root.completed(root.result);
            } catch (e) {
                console.error(`${root.logPrefix} Failed to parse JSON:`, e);
                root.failed(`JSON parse error: ${e}`);
            }

            root._buffer = "";
        }
    }
}
