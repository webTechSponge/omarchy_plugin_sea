import QtQuick
import qs.Commons
import qs.Ui as Ui
import "../js/CatalogModel.js" as Catalog

Ui.BorderSurface {
    id: card
    required property var plugin
    property bool selected: false
    signal activated()
    color: selected || mouse.containsMouse ? Util.alpha(Color.accent, 0.09) : Util.alpha(Color.foreground, 0.025)
    borderSpec: Border.flat(selected || activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.18), selected || activeFocus ? 2 : 1)
    radius: Style.cornerRadius
    activeFocusOnTab: true
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()
    Column {
        z: 1
        anchors.fill: parent; anchors.margins: 14; spacing: 8
        Rectangle {
            width: parent.width; height: 98; color: Util.alpha(Color.accent, 0.065); clip: true
            Text { anchors.centerIn: parent; text: String(card.plugin.name || "P").substring(0,2).toUpperCase(); color: Color.accent; font.family: Style.font.family; font.pixelSize: 30; opacity: 0.7 }
            PreviewImage { anchors.fill: parent; source: card.plugin.previewThumbnail || card.plugin.previewImage || ""; fillMode: Image.PreserveAspectCrop; requestedWidth: 600 }
        }
        Row {
            width: parent.width; spacing: 8
            Text { width: parent.width - starCount.width - parent.spacing; text: card.plugin.name || card.plugin.id; textFormat: Text.PlainText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
            Text {
                id: starCount; text: "★ " + (card.plugin.localOnly ? "—" : Catalog.starCount(card.plugin).toLocaleString(Qt.locale(), "f", 0))
                color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
                HoverHandler { id: starsHover }
                InfoTooltip { parent: starCount; visible: starsHover.hovered; text: card.plugin.localOnly ? "No catalog star count is available for this local plugin." : "GitHub repository stars reported by the catalog. This count may be shared by plugins in the same repository and can lag behind GitHub. Stars indicate interest, not safety or quality." }
            }
        }
        Text { width: parent.width; text: (card.plugin.author || "Community") + (card.plugin.version ? "  ·  v" + card.plugin.version : ""); textFormat: Text.PlainText; color: Color.foreground; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        Text { width: parent.width; height: 40; text: card.plugin.description || "No description provided."; textFormat: Text.PlainText; color: Color.foreground; opacity: 0.85; font.family: Style.font.family; font.pixelSize: Style.font.body; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
        Text {
            id: availabilityLabel
            HoverHandler { id: availabilityHover }
            InfoTooltip { parent: availabilityLabel; visible: availabilityHover.hovered; text: Catalog.availabilityHelp(card.plugin) }
            width: parent.width; text: Catalog.status(card.plugin) + "  ·  " + (card.plugin.category || "Community"); textFormat: Text.PlainText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        Text {
            id: catalogLabel
            HoverHandler { id: catalogHover }
            InfoTooltip { parent: catalogLabel; visible: catalogHover.hovered; text: Catalog.verificationLabel(card.plugin) + "\n\n" + Catalog.provenanceNote(card.plugin) + "\n\nVerified means the catalog reported checks on a particular snapshot. It is not a security audit or a guarantee that the code you install is safe." }
            width: parent.width; text: Catalog.verificationLabel(card.plugin); textFormat: Text.PlainText; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { card.forceActiveFocus(); card.activated(); } }
}
