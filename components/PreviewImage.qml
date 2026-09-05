import QtQuick
import Quickshell.Io
import "../js/CatalogModel.js" as Catalog

// Qt's WebP plugin is optional on Omarchy. The helper converts only approved
// marketplace images into a bounded, atomic PNG cache; browsing executes no
// downloaded plugin code. The parent owns the always-visible fallback art.
Item {
    id: preview
    property string source: ""
    property int fillMode: Image.PreserveAspectFit
    property int requestedWidth: 1000
    property string imageSource: ""
    property string requestSource: ""
    readonly property bool ready: nativeImage.status === Image.Ready
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../bin/oma-plug-sea-preview").toString().replace(/^file:\/\//, ""))

    function load() {
        imageSource = "";
        if (!Catalog.safeLink(source)) return;
        if (!/\.webp(?:[?#]|$)/i.test(source)) { imageSource = source; return; }
        if (conversion.running) return;
        requestSource = source;
        conversion.command = [helper, source];
        conversion.running = true;
    }
    onSourceChanged: load()
    Component.onCompleted: load()
    Process {
        id: conversion
        stdout: StdioCollector { id: output; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
                if (preview.requestSource !== preview.source) { preview.load(); return; }
                if (code !== 0) return;
                try {
                    var result = JSON.parse(output.text);
                    if (result.ok && typeof result.path === "string" && result.path.charAt(0) === "/" && /\.png$/.test(result.path))
                        preview.imageSource = "file://" + result.path;
                } catch (e) { /* Keep the parent's preview fallback. */ }
            });
        }
    }
    Image {
        id: nativeImage
        anchors.fill: parent
        source: preview.imageSource
        sourceSize.width: preview.requestedWidth
        asynchronous: true
        fillMode: preview.fillMode
        visible: status === Image.Ready
    }
}
