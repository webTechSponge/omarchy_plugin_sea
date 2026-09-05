import QtQuick
import Quickshell.Io
import "../js/CatalogModel.js" as Catalog

// The isolated Qt helper converts only approved
// marketplace images into a bounded, atomic PNG cache; browsing executes no
// downloaded plugin code. The parent owns the always-visible fallback art.
Item {
    id: preview
    property string source: ""
    property int fillMode: Image.PreserveAspectFit
    property int requestedWidth: 1000
    property bool fullResolution: false
    property bool requestFullResolution: false
    property bool loadFailed: false
    readonly property bool loading: conversion.running || nativeImage.status === Image.Loading
    readonly property bool failed: loadFailed || nativeImage.status === Image.Error
    readonly property real intrinsicWidth: nativeImage.implicitWidth
    readonly property real intrinsicHeight: nativeImage.implicitHeight
    property string imageSource: ""
    property string requestSource: ""
    readonly property bool ready: nativeImage.status === Image.Ready
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../bin/oma-plug-sea-preview").toString().replace(/^file:\/\//, ""))

    function load() {
        imageSource = "";
        loadFailed = false;
        if (!Catalog.safeLink(source)) { loadFailed = true; return; }
        if (!/\.webp(?:[?#]|$)/i.test(source)) { imageSource = source; return; }
        if (conversion.running) return;
        requestSource = source;
        requestFullResolution = fullResolution;
        conversion.command = fullResolution ? [helper, source, "original"] : [helper, source];
        conversion.running = true;
    }
    onSourceChanged: load()
    onFullResolutionChanged: load()
    Component.onCompleted: load()
    Process {
        id: conversion
        stdout: StdioCollector { id: output; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
                if (preview.requestSource !== preview.source || preview.requestFullResolution !== preview.fullResolution) { preview.load(); return; }
                if (code !== 0) { preview.loadFailed = true; return; }
                try {
                    var result = JSON.parse(output.text);
                    if (result.ok && typeof result.path === "string" && result.path.charAt(0) === "/" && /\.png$/.test(result.path))
                        preview.imageSource = "file://" + result.path;
                    else preview.loadFailed = true;
                } catch (e) { preview.loadFailed = true; }
            });
        }
    }
    Image {
        id: nativeImage
        anchors.fill: parent
        source: preview.imageSource
        sourceSize: preview.fullResolution ? Qt.size(-1, -1) : Qt.size(preview.requestedWidth, -1)
        asynchronous: true
        fillMode: preview.fillMode
        visible: status === Image.Ready
    }
}
