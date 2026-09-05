import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui as Ui
import "components"
import "js/CatalogModel.js" as Catalog

Item {
    id: root
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    property bool opened: false
    property int requestedWidth: 1120
    property int requestedHeight: 820
    property var catalog: []
    property var localPlugins: []
    property var rows: []
    property var filtered: []
    property var detail: null
    property string query: ""
    property string category: "All categories"
    property string scope: "All plugins"
    property string sort: "Name"
    property var categoryOptions: ["All categories"]
    property string fetchedAt: ""
    property bool stale: false
    property string catalogError: ""
    property bool refreshNeeded: false
    property bool refreshing: false
    property bool checking: false
    property string checkError: ""
    property string checkedAt: ""
    property bool refreshQueued: false
    property bool checkAfterRefresh: false
    property int catalogGeneration: 0
    property int checkGeneration: 0
    property string localError: ""
    property string operationMessage: ""
    property string diagnostics: ""
    property bool diagnosticVisible: false
    property string pendingAction: ""
    property var pendingPlugin: null
    property bool actionPending: false
    readonly property bool busy: actionProcess.running || actionPending
    readonly property string helperDir: decodeURIComponent(Qt.resolvedUrl("bin/").toString().replace(/^file:\/\//, ""))
    function open(payload) {
        try { var options = JSON.parse(payload || "{}"); requestedWidth = Math.max(620, Math.min(1600, Number(options.width) || 1120)); requestedHeight = Math.max(480, Math.min(1200, Number(options.height) || 820)); } catch (e) {}
        opened = true;
        if (catalog.length || fetchedAt) {
            checkCatalog();
            if (!localProcess.running && !busy) localProcess.running = true;
        } else {
            checkAfterRefresh = true;
            refresh();
        }
        Qt.callLater(function() { if (root.detail) mainFocus.forceActiveFocus(); else search.forceActiveFocus(); });
    }
    function status(arg) { return JSON.stringify({opened:opened, search:query, category:category, scope:scope, sort:sort, count:filtered.length, selected:grid.currentIndex, detail:detail ? detail.id : null, consent:pendingAction, busy:busy, stale:stale, refreshing:refreshing, refreshNeeded:refreshNeeded, checking:checking, checkError:checkError, checkedAt:checkedAt, lastCheckedAt:checkedAt, catalogError:catalogError, localError:localError, width:surface.width, height:surface.height, operationMessage:operationMessage}); }
    function close() { opened = false; }
    function dismiss() {
        if (busy) { operationMessage = "Please wait for the current action to finish."; return; }
        opened = false;
        if (shell) shell.hide(manifest ? manifest.id : "local.oma-plug-sea");
    }
    function back() {
        if (pendingAction || diagnosticVisible) { cancelModal(); return; }
        if (detail) { detail = null; Qt.callLater(function() { grid.forceActiveFocus(); }); }
        else if (search.text) search.text = "";
        else dismiss();
    }
    function cancelModal() {
        pendingAction = "";
        diagnosticVisible = false;
        Qt.callLater(function() { mainFocus.forceActiveFocus(); });
    }
    onDetailChanged: {
        if (detail && opened && !pendingAction) Qt.callLater(function() { mainFocus.forceActiveFocus(); });
    }
    function parseResult(output, fallback) {
        try { return JSON.parse(output); }
        catch (e) { return {ok:false, error:fallback, plugins:[]}; }
    }
    // Checks never replace the visible model. An explicit refresh waits for an
    // in-flight check; generation changes prevent its old result from winning.
    function pollCatalog(arg) { checkCatalog(); return checking ? "checking" : "idle"; }
    function checkCatalog() {
        if (!opened || busy || refreshing || checking || pendingAction) return;
        checking = true;
        checkGeneration = catalogGeneration;
        checkProcess.running = true;
    }
    function refresh() {
        if (busy || refreshing || refreshQueued) return;
        catalogGeneration++;
        if (checking) { refreshQueued = true; return; }
        refreshing = true;
        catalogProcess.command = [helperDir + "oma-plug-sea-catalog", "refresh"];
        catalogProcess.running = true;
        if (!localProcess.running) localProcess.running = true;
    }
    function rebuild() {
        rows = Catalog.correlate(catalog, localPlugins);
        categoryOptions = Catalog.categories(rows);
        filtered = Catalog.filter(rows, query, category, scope, sort);
        if (detail) {
            var id = detail.id;
            var match = rows.filter(function(p) { return p.id === id; });
            detail = match.length ? match[0] : null;
        }
        grid.currentIndex = filtered.length ? Math.max(0, Math.min(grid.currentIndex, filtered.length - 1)) : -1;
    }
    function requestAction(action) {
        if (busy || refreshing || checking || !detail) return;
        if (action === "disable") { runAction(action, detail); return; }
        pendingPlugin = detail;
        pendingAction = action;
        Qt.callLater(function() { cancelButton.forceActiveFocus(); });
    }
    function consentText() {
        if (!pendingPlugin) return "";
        var p = pendingPlugin;
        if (pendingAction === "remove") return "Remove " + p.name + " (" + p.id + ") from this computer? The CLI will remove its installed directory. This cannot be undone through this window.";
        return "Plugin: " + p.name + "\nExact ID: " + p.id + "\nSource: " + ((p.local && p.local.repo) || p.repo || "Local plugin directory") + "\nVerification: " + (p.verificationStatus || "Not verified") + "\nReviewed listing commit: " + (p.listingValidatedCommit || "Not provided") + "\n\nThis plugin runs UNSANDBOXED as your user when enabled. It can read and change your files and run commands. Catalog metadata is not installation authority or a security audit.\n\nThe Git CLI installs or updates mutable upstream HEAD, which can differ from the catalog's reviewed commit. " + (pendingAction === "install" ? "This installation will stay disabled so you can inspect its source first." : pendingAction === "update" ? "Updating an enabled plugin may execute the new code immediately. Approving allows the CLI's non-interactive update without an additional diff prompt." : "Approving explicitly authorizes running this plugin's code.");
    }
    function runAction(action, plugin) {
        if (busy || refreshing || checking) return;
        var args = [helperDir + "oma-plug-sea-action", action, plugin.id];
        if (action === "install" || action === "install-enable") args.push(plugin.repo);
        if (["install", "install-enable", "enable", "update"].indexOf(action) >= 0) args.push("--consent-unsandboxed");
        if (action === "remove") args.push("--confirm-remove");
        pendingAction = "";
        diagnostics = "";
        operationMessage = action + " · " + plugin.name + " — waiting for the CLI and confirmed local state…";
        actionProcess.command = args;
        actionPending = true;
        actionProcess.running = true;
    }
    onQueryChanged: rebuild()
    onCategoryChanged: rebuild()
    onScopeChanged: rebuild()
    onSortChanged: rebuild()
    Timer { id: debounce; interval: 180; onTriggered: root.query = search.text }
    Timer {
        interval: 300000
        repeat: true
        running: root.opened
        onTriggered: root.checkCatalog()
    }
    Connections {
        target: root.pluginRegistry
        function onPluginsChanged() { if (root.opened && !root.busy && !localProcess.running) localProcess.running = true; }
    }
    Process {
        id: catalogProcess
        stdout: StdioCollector { id: catalogOutput; waitForEnd: true }
        stderr: StdioCollector { id: catalogStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
            var result = root.parseResult(catalogOutput.text, "Catalog helper failed. " + catalogStderr.text);
            if (result.plugins && (result.plugins.length || result.ok)) root.catalog = result.plugins;
            root.catalogError = result.error || (code ? "Catalog refresh failed." : "");
            root.stale = !!result.stale || !result.ok;
            root.fetchedAt = result.fetchedAt || root.fetchedAt;
            if (result.ok && code === 0 && !result.stale) {
                root.refreshNeeded = false;
                root.checkError = "";
            }
            root.rebuild();
            root.refreshing = false;
            if (root.checkAfterRefresh) {
                root.checkAfterRefresh = false;
                root.checkCatalog();
            }
            });
        }
    }
    Process {
        id: checkProcess
        command: [root.helperDir + "oma-plug-sea-catalog", "check"]
        stdout: StdioCollector { id: checkOutput; waitForEnd: true }
        stderr: StdioCollector { id: checkStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
                var result = root.parseResult(checkOutput.text, "Source check failed. " + checkStderr.text);
                if (root.checkGeneration === root.catalogGeneration) {
                    if (result.ok && code === 0) {
                        root.refreshNeeded = !!result.refreshNeeded;
                        root.checkError = "";
                    } else {
                        // A failed poll cannot revoke a previously detected update.
                        root.checkError = result.error || "Could not check the catalog source.";
                    }
                    root.checkedAt = result.checkedAt || root.checkedAt;
                }
                root.checking = false;
                if (root.refreshQueued) {
                    root.refreshQueued = false;
                    root.refresh();
                }
            });
        }
    }
    Process {
        id: localProcess; command: [root.helperDir + "oma-plug-sea-local"]
        stdout: StdioCollector { id: localOutput; waitForEnd: true }
        stderr: StdioCollector { id: localStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
            var result = root.parseResult(localOutput.text, "Local state unavailable. " + localStderr.text);
            if (result.ok) root.localPlugins = result.plugins || [];
            root.localError = result.ok ? "" : result.error || "Cannot read local plugins. Is omarchy-shell running?";
            root.rebuild();
            });
        }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput; waitForEnd: true }
        stderr: StdioCollector { id: actionStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
            var result = root.parseResult(actionOutput.text, "Action failed. " + actionStderr.text);
            root.operationMessage = result.ok && code === 0 ? "Completed · " + result.action + " · " + result.id + " (local state confirmed)" : "Action failed · " + (result.error || "The CLI did not confirm success.");
            root.diagnostics = [result.stdout || "", result.stderr || "", actionStderr.text || ""].filter(function(t) { return t; }).join("\n");
            if (result.plugins) root.localPlugins = result.plugins;
            root.rebuild();
            if (!localProcess.running) localProcess.running = true;
            root.actionPending = false;
            });
        }
    }
    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "oma-plug-sea"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        Rectangle { anchors.fill: parent; color: Color.menu.scrim }
        MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
        Ui.BorderSurface {
            id: surface
            width: Math.min(parent.width - 40, root.requestedWidth)
            height: Math.min(parent.height - 52, root.requestedHeight)
            anchors.centerIn: parent
            color: Util.alpha(Color.menu.background, 1)
            borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, 2)
            radius: Style.cornerRadius
            MouseArea { anchors.fill: parent; onClicked: {} }
            FocusScope {
                id: mainFocus
                anchors.fill: parent; anchors.margins: 24
                enabled: !root.pendingAction && !root.diagnosticVisible
                Keys.onEscapePressed: root.back()
                Keys.onPressed: function(event) {
                    if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_F) { root.detail = null; search.forceActiveFocus(); event.accepted = true; }
                    if (event.key === Qt.Key_F5) { root.refresh(); event.accepted = true; }
                }
                ColumnLayout {
                    anchors.fill: parent; spacing: 14
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Ui.Button { visible: !!root.detail; text: "← Back"; focusable: true; bordered: true; onClicked: root.back() }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 4
                            Text { Layout.fillWidth: true; text: root.detail ? root.detail.name : "Omarchy Plugin Sea"; textFormat: Text.PlainText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title + 4; font.bold: true; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: root.detail ? root.detail.id : "Discover community plugins for your desktop"; textFormat: Text.PlainText; color: Color.foreground; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.body }
                        }
                        Ui.Button {
                            text: root.refreshing || root.refreshQueued ? "Refreshing…" : root.refreshNeeded ? "Refresh available" : root.checking ? "Checking…" : root.checkError || root.catalogError ? "Retry refresh" : "Refresh"
                            foreground: root.refreshNeeded ? Color.accent : Color.foreground
                            background: root.refreshNeeded ? Util.alpha(Color.accent, 0.14) : "transparent"
                            tooltipText: root.refreshNeeded ? "The source catalog changed. Refresh to load it without changing your filters." : "Checks the catalog source on open and every 5 minutes. F5 refreshes now."
                            bordered: true; focusable: true
                            enabled: !root.busy && !root.refreshing && !root.refreshQueued
                            onClicked: root.refresh()
                        }
                        Ui.Button { text: "Close ×"; focusable: true; enabled: !root.busy; onClicked: root.dismiss() }
                    }
                    RowLayout {
                        visible: !root.detail; Layout.fillWidth: true; spacing: 12
                        Ui.TextField { id: search; Layout.fillWidth: true; placeholderText: "Search names, authors, tags…"; onTextChanged: debounce.restart(); Keys.onDownPressed: { grid.forceActiveFocus(); grid.currentIndex = Math.max(0, grid.currentIndex); } onAccepted: { debounce.stop(); root.query = search.text; if (root.filtered.length) root.detail = root.filtered[Math.max(0, grid.currentIndex)]; } }
                        Ui.Dropdown { Layout.preferredWidth: 170; label: "Category"; showLabel: false; value: root.category; options: root.categoryOptions; onChanged: function(value) { root.category = value; } }
                    }
                    RowLayout {
                        visible: !root.detail; Layout.fillWidth: true; spacing: 12
                        Ui.Dropdown { Layout.preferredWidth: 165; label: "State"; showLabel: false; value: root.scope; options: ["All plugins", "Installed", "Available"]; onChanged: function(value) { root.scope = value; } }
                        Ui.Dropdown { Layout.preferredWidth: 175; label: "Sort"; showLabel: false; value: root.sort; options: ["Name", "Most stars", "Recently listed"]; onChanged: function(value) { root.sort = value; } }
                        Item { Layout.fillWidth: true }
                        Text { text: root.filtered.length + " plugins"; color: Color.foreground; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.body }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (root.stale ? "OFFLINE / STALE · " : "COMMUNITY CATALOG · ") + (root.fetchedAt ? "Refreshed " + root.fetchedAt : catalogProcess.running ? "Loading catalog…" : "No catalog loaded") + (root.catalogError ? "\n" + root.catalogError : "") + (root.localError ? "\n" + root.localError : "") + (root.refreshNeeded ? "\nNew catalog data is available. Select Refresh available to load it." : root.checkError ? "\nSource check failed: " + root.checkError : root.checking ? " · Checking source…" : root.checkedAt ? " · Source checked " + root.checkedAt : "")
                        textFormat: Text.PlainText; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                        color: root.stale || root.localError || root.refreshNeeded || root.checkError ? Color.accent : Color.foreground; opacity: 0.65; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
                    }
                    GridView {
                        id: grid; visible: !root.detail; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        cellWidth: width / Math.max(1, Math.floor(width / 280)); cellHeight: 306
                        model: root.filtered; currentIndex: 0; keyNavigationEnabled: true; activeFocusOnTab: true
                        highlightMoveDuration: 0
                        Controls.ScrollBar.vertical: Controls.ScrollBar {}
                        Keys.onReturnPressed: if (currentIndex >= 0) root.detail = root.filtered[currentIndex]
                        Keys.onEnterPressed: if (currentIndex >= 0) root.detail = root.filtered[currentIndex]
                        Keys.onSpacePressed: if (currentIndex >= 0) root.detail = root.filtered[currentIndex]
                        delegate: PluginCard {
                            required property var modelData
                            required property int index
                            plugin: modelData; width: grid.cellWidth - 12; height: grid.cellHeight - 12
                            selected: grid.currentIndex === index && grid.activeFocus
                            onActivated: { grid.currentIndex = index; root.detail = modelData; }
                        }
                        Text { anchors.centerIn: parent; visible: root.filtered.length === 0; width: Math.min(parent.width - 32, 430); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: catalogProcess.running ? "Finding community plugins…" : root.catalogError && !root.catalog.length ? "The catalog is unavailable. Refresh to retry. Installed plugins remain available through the Installed filter." : "No plugins match your filters.\nTry another search or category."; color: Color.foreground; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.heading }
                    }
                    PluginDetails { visible: !!root.detail; Layout.fillWidth: true; Layout.fillHeight: true; plugin: root.detail || ({}); busy: root.busy || root.refreshing || root.checking || !!root.localError; onActionRequested: function(action) { root.requestAction(action); } }
                    RowLayout {
                        visible: !!root.operationMessage; Layout.fillWidth: true
                        Controls.BusyIndicator { visible: root.busy; running: root.busy; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                        Text { Layout.fillWidth: true; text: root.operationMessage; textFormat: Text.PlainText; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                        Ui.Button { visible: !!root.diagnostics; text: "Diagnostics"; focusable: true; onClicked: { root.diagnosticVisible = true; Qt.callLater(function() { cancelButton.forceActiveFocus(); }); } }
                    }
                    Text { Layout.fillWidth: true; text: "Browse safely. Review source before enabling unsandboxed community code.   ·   Ctrl+F search   F5 refresh   Esc back"; wrapMode: Text.WordWrap; color: Color.foreground; opacity: 0.45; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                }
            }
            Rectangle {
                anchors.fill: parent; visible: !!root.pendingAction || root.diagnosticVisible; color: Util.alpha(Color.menu.background, 1)
                Keys.onEscapePressed: root.cancelModal()
                MouseArea { anchors.fill: parent; onClicked: {} }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 32; spacing: 18
                    Text { text: root.diagnosticVisible ? "Action diagnostics" : root.pendingAction === "remove" ? "Confirm removal" : "Review and consent"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                    Controls.ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
                        TextEdit { width: parent.width; text: root.diagnosticVisible ? root.diagnostics : root.consentText(); textFormat: TextEdit.PlainText; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.heading }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Ui.Button { id: cancelButton; text: root.diagnosticVisible ? "Close" : "Cancel"; bordered: true; focusable: true; onClicked: root.cancelModal(); Keys.onEscapePressed: root.cancelModal() }
                        Ui.Button { visible: !root.diagnosticVisible; text: root.pendingAction === "install" ? "Accept · install disabled" : root.pendingAction === "remove" ? "Remove plugin" : "Accept · " + root.pendingAction; bordered: true; focusable: true; onClicked: root.runAction(root.pendingAction, root.pendingPlugin); Keys.onEscapePressed: root.cancelModal() }
                    }
                }
            }
        }
    }
}
