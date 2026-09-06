import QtQuick

// Keep an in-flight read owned until its deferred completion is consumed.
// Mutations invalidate older reads and always schedule a subsequent fresh read.
QtObject {
    id: state
    property int generation: 0
    property int readGeneration: -1
    property bool readActive: false
    property bool mutationActive: false
    property bool queued: false
    signal readRequested()
    signal resultAccepted(var result)

    function requestRead() {
        queued = true;
        pump();
    }
    function pump() {
        if (!queued || readActive || mutationActive) return;
        queued = false;
        readGeneration = generation;
        readActive = true;
        readRequested();
    }
    function beginMutation() {
        generation++;
        mutationActive = true;
        queued = true;
    }
    function finishMutation() {
        mutationActive = false;
        requestRead();
    }
    function completeRead(result) {
        if (!readActive) return;
        var current = readGeneration === generation && !mutationActive;
        readActive = false;
        if (current) resultAccepted(result);
        pump();
    }
}
