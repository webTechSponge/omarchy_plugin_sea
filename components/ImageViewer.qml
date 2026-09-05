import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

FocusScope {
    id: viewer
    property string source: ""
    property string title: "Preview"
    property bool fitToWindow: true
    property real zoom: 1
    readonly property bool ready: fullImage.ready
    readonly property bool loading: fullImage.loading
    readonly property bool failed: fullImage.failed
    readonly property real intrinsicWidth: fullImage.intrinsicWidth
    readonly property real intrinsicHeight: fullImage.intrinsicHeight
    readonly property real imageWidth: fullImage.ready ? fullImage.intrinsicWidth : 1
    readonly property real imageHeight: fullImage.ready ? fullImage.intrinsicHeight : 1
    readonly property real fitZoom: Math.min(1, viewport.width / Math.max(1, imageWidth), viewport.height / Math.max(1, imageHeight))
    readonly property real effectiveZoom: fitToWindow ? fitZoom : zoom
    signal closed()

    function centerImage() {
        Qt.callLater(function() {
            viewport.contentX = Math.max(0, (viewport.contentWidth - viewport.width) / 2);
            viewport.contentY = Math.max(0, (viewport.contentHeight - viewport.height) / 2);
        });
    }
    function fit() { fitToWindow = true; centerImage(); }
    function setZoom(value) {
        zoom = Math.max(0.05, Math.min(8, value));
        fitToWindow = false;
        centerImage();
    }
    onSourceChanged: fit()
    onVisibleChanged: if (visible) { fit(); forceActiveFocus(); }
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { closed(); event.accepted = true; }
        else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) { setZoom(effectiveZoom * 1.25); event.accepted = true; }
        else if (event.key === Qt.Key_Minus) { setZoom(effectiveZoom / 1.25); event.accepted = true; }
        else if (event.key === Qt.Key_0) { fit(); event.accepted = true; }
        else if (event.key === Qt.Key_1) { setZoom(1); event.accepted = true; }
    }

    Rectangle { anchors.fill: parent; color: Util.alpha(Color.menu.background, 1) }
    MouseArea { anchors.fill: parent; onClicked: viewer.forceActiveFocus() }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: viewer.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
            }
            Ui.Button { text: "Close ×"; bordered: true; focusable: true; onClicked: viewer.closed() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Ui.Button { text: "Fit"; bordered: true; focusable: true; onClicked: viewer.fit() }
            Ui.Button { text: "100%"; bordered: true; focusable: true; onClicked: viewer.setZoom(1) }
            Ui.Button { text: "−"; bordered: true; focusable: true; onClicked: viewer.setZoom(viewer.effectiveZoom / 1.25) }
            Ui.Button { text: "+"; bordered: true; focusable: true; onClicked: viewer.setZoom(viewer.effectiveZoom * 1.25) }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: fullImage.ready ? Math.round(viewer.effectiveZoom * 100) + "% · " + viewer.imageWidth + " × " + viewer.imageHeight : ""
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Util.alpha(Color.accent, 0.04)
            clip: true
            Flickable {
                id: viewport
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                contentWidth: Math.max(width, fullImage.width)
                contentHeight: Math.max(height, fullImage.height)
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.horizontal: Controls.ScrollBar { }
                Controls.ScrollBar.vertical: Controls.ScrollBar { }
                PreviewImage {
                    id: fullImage
                    source: viewer.source
                    fullResolution: true
                    width: Math.max(1, viewer.imageWidth * viewer.effectiveZoom)
                    height: Math.max(1, viewer.imageHeight * viewer.effectiveZoom)
                    x: Math.max(0, (viewport.width - width) / 2)
                    y: Math.max(0, (viewport.height - height) / 2)
                    fillMode: Image.Stretch
                    onReadyChanged: if (ready) viewer.centerImage()
                }
            }
            Text {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 32)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: !fullImage.ready
                text: fullImage.failed ? "Unable to load this preview. Close and reopen to retry." : "Loading full-size preview…"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Drag or scroll to pan · + / − zoom · 0 fit · 1 actual size · Esc close"
            wrapMode: Text.WordWrap
            color: Color.foreground
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }
}
