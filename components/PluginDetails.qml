import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "../js/CatalogModel.js" as Catalog

ColumnLayout {
    id: detail
    required property var plugin
    property bool busy: false
    signal actionRequested(string action)
    signal previewRequested(string source)
    function focusPreview() { previewTarget.forceActiveFocus(); }
    readonly property string installedSourceLink: Catalog.canonicalGitHub(Catalog.sourceUrl(plugin)) || Catalog.sourceUrl(plugin)
    spacing: 14
    Controls.ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        Column {
            width: parent.width; spacing: 14
            Rectangle {
                id: previewTarget
                width: parent.width; height: Math.min(230, width * 0.31); color: Util.alpha(Color.accent, 0.07); clip: true
                activeFocusOnTab: detailPreview.ready
                border.width: activeFocus || previewMouse.containsMouse ? 2 : 0
                border.color: Color.accent
                function activate() { if (detailPreview.ready) detail.previewRequested(detailPreview.source); }
                Keys.onReturnPressed: activate()
                Keys.onEnterPressed: activate()
                Keys.onSpacePressed: activate()
                Text { anchors.centerIn: parent; visible: !detailPreview.ready; text: "No preview available"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family }
                PreviewImage { id: detailPreview; anchors.fill: parent; source: detail.plugin.previewImage || detail.plugin.previewThumbnail || ""; fillMode: Image.PreserveAspectFit; requestedWidth: 1200 }
                Rectangle {
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                    width: previewHint.implicitWidth + 16; height: previewHint.implicitHeight + 10
                    visible: detailPreview.ready; color: Util.alpha(Color.menu.background, 0.9)
                    Text { id: previewHint; anchors.centerIn: parent; text: "⤢ View full size"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                }
                MouseArea {
                    id: previewMouse; anchors.fill: parent; enabled: detailPreview.ready
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { previewTarget.forceActiveFocus(); previewTarget.activate(); }
                }
            }
            Text {
                width: parent.width; visible: text.length > 0
                text: Catalog.lifecycleWarning(detail.plugin); textFormat: Text.PlainText
                wrapMode: Text.WordWrap; color: Color.accent
                font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
            }
            Text { width: parent.width; text: detail.plugin.description || "No description provided."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.heading }
            Text { width: parent.width; text: "PLUGIN ID   " + detail.plugin.id + "\nPUBLISHER   " + (detail.plugin.author || "Not provided") + "\nVERSION   " + (detail.plugin.version || "Not provided") + (detail.plugin.local ? "  ·  installed " + (detail.plugin.local.version || "unknown") : "") + "\nCATEGORY   " + (detail.plugin.category || "Community") + "\nTAGS   " + (detail.plugin.tags || []).join(", ") + "\nSOURCE TYPE   " + (detail.plugin.sourceType || "Local") + "\nSTARS   " + (detail.plugin.stars || 0) + "\nLISTED   " + (detail.plugin.listedAt || "Not reported") + (detail.plugin.local ? "\nPLUGIN KINDS   " + (detail.plugin.local.kinds || []).join(", ") + "\nLOCAL DIRECTORY   " + (detail.plugin.local.localPath || "Not reported") : "") + "\nSTATE   " + Catalog.status(detail.plugin) + (detail.plugin.local ? "\nINSTALLED SOURCE   " : "\nSOURCE   ") + (Catalog.sourceUrl(detail.plugin) || "Unknown; inspect the local directory") + (detail.plugin.local && !detail.plugin.localOnly ? "\nCATALOG SOURCE   " + (detail.plugin.repo || "Not provided") : ""); textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: Color.foreground; opacity: 0.75; font.family: Style.font.family; font.pixelSize: Style.font.body; lineHeight: 1.5 }
            Text { width: parent.width; text: Catalog.provenanceNote(detail.plugin) + "\nCatalog listing verification: " + (detail.plugin.verificationStatus || "Not verified") + " · " + (detail.plugin.verificationCoverage || "No security audit") + "\nCompatibility / upstream check: " + (detail.plugin.upstreamCheckStatus || "Not reported") + "\nCatalog reviewed commit: " + (detail.plugin.listingValidatedCommit || "Not provided") + "\nCatalog observed upstream commit: " + (detail.plugin.upstreamObservedCommit || "Not provided") + "\nUpdate availability is unknown until the CLI checks the repository."; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: Color.foreground; opacity: 0.65; font.family: Style.font.family; font.pixelSize: Style.font.body; lineHeight: 1.4 }
            Text { width: parent.width; text: "Community plugins run unsandboxed as your user. Catalog checks describe a snapshot; the Git installer clones mutable HEAD, which may differ from the reviewed commit. Read the source before enabling." + (detail.plugin.installNote ? "\n" + detail.plugin.installNote : "") + (detail.plugin.local && detail.plugin.local.defaultSection ? "\nBar widget placement: " + detail.plugin.local.defaultSection + " (manifest default)." : ""); textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body; lineHeight: 1.35 }
        }
    }
    Flow {
        Layout.fillWidth: true; Layout.preferredHeight: childrenRect.height; spacing: 10
        Ui.Button { text: detail.plugin.local ? "View installed source ↗" : "View source ↗"; bordered: true; focusable: true; enabled: Catalog.safeLink(detail.installedSourceLink); opacity: enabled ? 1 : 0.4; onClicked: Qt.openUrlExternally(detail.installedSourceLink) }
        Ui.Button { visible: !!detail.plugin.local && !detail.plugin.localOnly && !Catalog.sourceMatches(detail.plugin); text: "Catalog source ↗"; bordered: true; focusable: true; enabled: Catalog.safeLink(detail.plugin.repo); onClicked: Qt.openUrlExternally(detail.plugin.repo) }
        Ui.Button { visible: !detail.plugin.local && !!detail.plugin.installAvailable; text: "Install disabled"; bordered: true; focusable: true; enabled: !detail.busy; onClicked: detail.actionRequested("install") }
        Ui.Button { visible: !detail.plugin.local && !!detail.plugin.installAvailable; text: "Install & enable"; bordered: true; focusable: true; enabled: !detail.busy; onClicked: detail.actionRequested("install-enable") }
        Ui.Button { visible: !!detail.plugin.local && !detail.plugin.local.enabled; text: "Enable"; bordered: true; focusable: true; enabled: !detail.busy; onClicked: detail.actionRequested("enable") }
        Ui.Button { visible: !!detail.plugin.local && !!detail.plugin.local.enabled && detail.plugin.local.canDisable !== false && detail.plugin.id !== "local.oma-plug-sea"; text: "Disable"; bordered: true; focusable: true; enabled: !detail.busy; onClicked: detail.actionRequested("disable") }
        Ui.Button { visible: !!detail.plugin.local && !!detail.plugin.local.gitManaged && !detail.plugin.local.firstParty; text: "Check & update"; bordered: true; focusable: true; enabled: !detail.busy; onClicked: detail.actionRequested("update") }
        Ui.Button { visible: !!detail.plugin.local && !detail.plugin.local.firstParty && detail.plugin.id !== "local.oma-plug-sea"; text: "Remove"; bordered: true; focusable: true; enabled: !detail.busy; onClicked: detail.actionRequested("remove") }
    }
}
