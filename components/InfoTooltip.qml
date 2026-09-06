import QtQuick
import qs.Commons
import qs.Ui as Ui

Ui.PanelToolTip {
    id: tip
    width: 340
    x: 0
    y: -height - 8
    margins: 12
    contentItem: Text {
        text: tip.text; textFormat: Text.PlainText; wrapMode: Text.WordWrap
        color: tip.panelForeground; font.family: tip.fontFamily; font.pixelSize: tip.fontSize
        padding: 12
    }
}
