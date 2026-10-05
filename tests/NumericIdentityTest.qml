import QtQuick

Item {
    Timer {
        interval: 1
        running: true
        onTriggered: {
            try {
                var request = new XMLHttpRequest();
                request.open("GET", Qt.application.arguments[Qt.application.arguments.length - 1], false);
                request.send();
                var records = JSON.parse(request.responseText);
                for (var i = 0; i < records.length; i++) {
                    var identity = String(JSON.parse(records[i].literal).id);
                    if (identity !== records[i].identity)
                        throw new Error("Native Qt identity mismatch: " + records[i].literal + " -> " + identity + "; registry VM expected " + records[i].identity);
                }
                console.log("PASS: native Qt JSON.parse/String agrees with registry identities for", records.length, "numeric cases");
                Qt.quit();
            } catch (error) {
                console.error(error);
                Qt.exit(1);
            }
        }
    }
}
