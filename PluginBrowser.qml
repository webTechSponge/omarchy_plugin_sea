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
    readonly property string runtimeFingerprint: "__OMA_PLUG_SEA_RUNTIME_FINGERPRINT__"
    property bool opened: false
    property int requestedWidth: 1120
    property int requestedHeight: 820
    property var catalog: []
    property var localPlugins: []
    property var rows: []
    property var filtered: []
    property var detail: null
    property string previewSource: ""
    function showPreview(source) {
        if (!Catalog.safeLink(source)) return;
        previewSource = source;
        Qt.callLater(function() { if (imageViewer.item) imageViewer.item.forceActiveFocus(); });
    }
    function closePreview() {
        previewSource = "";
        Qt.callLater(function() { pluginDetails.focusPreview(); });
    }
    property string query: ""
    property string category: "All categories"
    property string scope: "All plugins"
    property string sort: "Name"
    property string sortDirection: "Ascending"
    property var categoryOptions: ["All categories"]
    property string fetchedAt: ""
    property bool stale: false
    property string catalogError: ""
    property bool refreshNeeded: false
    property bool refreshing: false
    property bool checking: false
    property string checkError: ""
    property string checkedAt: ""
    property var engagement: ({})
    property bool engagementStale: false
    property string engagementError: ""
    property var hearted: ({})
    property bool heartPending: false
    property string heartError: ""
    property string pendingHeart: ""
    property var pendingHeartPrior: null
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
    readonly property bool busy: actionProcess.running || actionPending || heartProcess.running || heartPending
    readonly property string helperDir: decodeURIComponent(Qt.resolvedUrl("bin/").toString().replace(/^file:\/\//, ""))
    function open(payload) {
        try { var options = JSON.parse(payload || "{}"); requestedWidth = Math.max(620, Math.min(1600, Number(options.width) || 1120)); requestedHeight = Math.max(480, Math.min(1200, Number(options.height) || 820)); } catch (e) {}
        opened = true;
        if (catalog.length || fetchedAt) {
            checkCatalog();
            engagementProcess.running = true;
            heartedProcess.running = true;
            localState.requestRead();
        } else {
            checkAfterRefresh = true;
            refresh();
        }
        Qt.callLater(function() { if (root.previewSource && imageViewer.item) imageViewer.item.forceActiveFocus(); else if (root.detail) mainFocus.forceActiveFocus(); else search.forceActiveFocus(); });
    }
    function status(arg) { return JSON.stringify({runtimeFingerprint:runtimeFingerprint, opened:opened, search:query, category:category, scope:scope, sort:sort, sortDirection:sortDirection, count:filtered.length, selected:grid.currentIndex, detail:detail ? detail.id : null, preview:previewSource, previewReady:imageViewer.item ? imageViewer.item.ready : false, previewWidth:imageViewer.item ? imageViewer.item.intrinsicWidth : 0, previewHeight:imageViewer.item ? imageViewer.item.intrinsicHeight : 0, previewZoom:imageViewer.item ? imageViewer.item.effectiveZoom : 0, consent:pendingAction, busy:busy, stale:stale, refreshing:refreshing, refreshNeeded:refreshNeeded, checking:checking, checkError:checkError, checkedAt:checkedAt, lastCheckedAt:checkedAt, catalogError:catalogError, localError:localError, width:surface.width, height:surface.height, operationMessage:operationMessage}); }
    function close() { previewSource = ""; opened = false; }
    function dismiss() {
        if (busy) { operationMessage = "Please wait for the current action to finish."; return; }
        previewSource = "";
        opened = false;
        if (shell) shell.hide(manifest ? manifest.id : "webtechsponge.plugin-sea");
    }
    function back() {
        if (previewSource) { closePreview(); return; }
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
        if (detail && opened && !pendingAction && !previewSource) Qt.callLater(function() { mainFocus.forceActiveFocus(); });
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
        engagementProcess.running = true;
        heartedProcess.running = true;
        localState.requestRead();
    }
    function rebuild() {
        rows = Catalog.correlate(catalog, localPlugins, root.engagement);
        categoryOptions = Catalog.categories(rows);
        filtered = Catalog.filter(rows, query, category, scope, sort, sortDirection);
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
        pendingPlugin = JSON.parse(JSON.stringify(detail));
        pendingAction = action;
        Qt.callLater(function() { cancelButton.forceActiveFocus(); });
    }
    function consentText() {
        if (!pendingPlugin) return "";
        var p = pendingPlugin;
        if (pendingAction === "remove") return (Catalog.lifecycleWarning(p) ? Catalog.lifecycleWarning(p) + "\n\n" : "") + "Remove " + p.name + " (" + p.id + ") from this computer? The CLI will remove its installed directory. This cannot be undone through this window.";
        if (pendingAction === "heart") return "Send an anonymous heart for " + p.name + " (" + p.id + ") to the marketplace? The request is reported to the marketplace as an anonymous heart from the plugins.omarchy.org origin; the marketplace rate-limits hearts and records no account or identity alongside the heart.";
        return (Catalog.lifecycleWarning(p) ? Catalog.lifecycleWarning(p) + "\n\n" : "") + "Plugin: " + p.name + "\nExact ID: " + p.id + "\nSource: " + (Catalog.sourceUrl(p) || (p.local ? "Unknown installed origin; local directory: " + (p.local.localPath || "Not reported") : "Source not provided")) + "\nVerification: " + Catalog.verificationLabel(p) + "\n" + Catalog.provenanceNote(p) + "\nCatalog reviewed commit: " + (p.listingValidatedCommit || "Not provided") + "\n\nThis plugin runs UNSANDBOXED as your user when enabled. It can read and change your files and run commands. Catalog metadata is not installation authority or a security audit.\n\nThe Git CLI installs or updates mutable upstream HEAD, which can differ from the catalog's reviewed commit. " + (pendingAction === "install" ? "This installation will stay disabled so you can inspect its source first." : pendingAction === "update" ? "Updating an enabled plugin may execute the new code immediately. Approving allows the CLI's non-interactive update without an additional diff prompt." : "Approving explicitly authorizes running this plugin's code.");
    }
    function runAction(action, plugin) {
        if (busy || refreshing || checking) return;
        var args = [helperDir + "oma-plug-sea-action", action, plugin.id];
        if (action === "install" || action === "install-enable") args.push(plugin.repo);
        if (action === "update") args.push(Catalog.sourceUrl(plugin));
        if (["install", "install-enable", "enable", "update"].indexOf(action) >= 0) args.push("--consent-unsandboxed");
        if (action === "remove") args.push("--confirm-remove");
        pendingAction = "";
        diagnostics = "";
        operationMessage = action + " · " + plugin.name + " — waiting for the CLI and confirmed local state…";
        actionProcess.command = args;
        actionPending = true;
        localState.beginMutation();
        actionProcess.running = true;
    }
    function runHeart(plugin) {
        if (busy || refreshing || checking || !plugin || plugin.localOnly) return;
        var id = plugin.id;
        if (!id || hearted[id]) return;
        pendingAction = "";
        pendingHeart = id;
        pendingHeartPrior = (typeof engagement[id] === "number") ? engagement[id] : null;
        // Optimistic update: show the heart immediately; the exit handler
        // applies the server total on success or rolls back on failure.
        var next = Object.assign({}, engagement);
        next[id] = (typeof next[id] === "number" ? next[id] : 0) + 1;
        engagement = next;
        var marked = Object.assign({}, hearted);
        marked[id] = true;
        hearted = marked;
        heartPending = true;
        heartError = "";
        operationMessage = "Sending heart · " + (plugin.name || id) + "…";
        rebuild();
        heartProcess.command = [helperDir + "oma-plug-sea-engagement", "heart", id];
        heartProcess.running = true;
    }
    function rollbackHeart(keepHearted) {
        // Undo the optimistic +1 from runHeart: restore the exact prior
        // value (absent records go back to untracked, not zero).
        var id = pendingHeart;
        if (!id) return;
        var next = Object.assign({}, engagement);
        if (pendingHeartPrior == null) delete next[id];
        else next[id] = pendingHeartPrior;
        engagement = next;
        if (!keepHearted) {
            var marked = Object.assign({}, hearted);
            delete marked[id];
            hearted = marked;
        }
    }
    onQueryChanged: rebuild()
    onCategoryChanged: rebuild()
    onScopeChanged: rebuild()
    onSortChanged: rebuild()
    onSortDirectionChanged: rebuild()
    Timer { id: debounce; interval: 180; onTriggered: root.query = search.text }
    Timer {
        interval: 300000
        repeat: true
        running: root.opened
        onTriggered: root.checkCatalog()
    }
    Connections {
        target: root.pluginRegistry
        function onPluginsChanged() { if (root.opened) localState.requestRead(); }
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
        id: engagementProcess
        command: [root.helperDir + "oma-plug-sea-engagement", "refresh"]
        stdout: StdioCollector { id: engagementOutput; waitForEnd: true }
        stderr: StdioCollector { id: engagementStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
            var result = root.parseResult(engagementOutput.text, "Engagement stats failed. " + engagementStderr.text);
            if (result.ok && code === 0) {
                root.engagement = result.hearts || {};
                root.engagementStale = false;
                root.engagementError = "";
            } else {
                // A failed refresh never blocks the catalog. The stale fallback
                // still carries last-saved hearts from cache, so keep showing them.
                if (result.hearts && Object.keys(result.hearts).length) root.engagement = result.hearts;
                root.engagementStale = true;
                root.engagementError = result.error || "Engagement stats are unavailable.";
            }
            root.rebuild();
            });
        }
    }
    Process {
        id: heartProcess
        stdout: StdioCollector { id: heartOutput; waitForEnd: true }
        stderr: StdioCollector { id: heartStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
            var result = root.parseResult(heartOutput.text, "Heart failed. " + heartStderr.text);
            var id = result.id || root.pendingHeart;
            if (result.ok && code === 0) {
                // The server total wins when the envelope carries one.
                if (typeof result.hearts === "number") {
                    var next = Object.assign({}, root.engagement);
                    next[id] = result.hearts;
                    root.engagement = next;
                }
                root.operationMessage = "Heart recorded · " + id;
                root.heartError = "";
            } else if (result.already) {
                // Refused by the local duplicate guard: no heart was sent, so
                // drop the optimistic +1 but keep the hearted flag.
                root.rollbackHeart(true);
                root.operationMessage = "Already hearted · " + id + " — no heart was sent.";
                root.heartError = "";
            } else {
                root.rollbackHeart(false);
                root.heartError = result.error || "Heart failed.";
                root.operationMessage = "Heart failed · " + root.heartError;
            }
            root.pendingHeart = "";
            root.pendingHeartPrior = null;
            root.heartPending = false;
            root.rebuild();
            });
        }
    }
    Process {
        id: heartedProcess
        command: [root.helperDir + "oma-plug-sea-engagement", "hearts-state"]
        stdout: StdioCollector { id: heartedOutput; waitForEnd: true }
        stderr: StdioCollector { id: heartedStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
            var result = root.parseResult(heartedOutput.text, "");
            if (result.ok && code === 0 && result.hearted) root.hearted = result.hearted;
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
    LocalStateCoordinator {
        id: localState
        onReadRequested: localProcess.running = true
        onResultAccepted: function(result) {
            if (result.ok) root.localPlugins = result.plugins || [];
            root.localError = result.ok ? "" : result.error || "Cannot read local plugins. Is omarchy-shell running?";
            root.rebuild();
        }
    }
    Process {
        id: localProcess; command: [root.helperDir + "oma-plug-sea-local"]
        stdout: StdioCollector { id: localOutput; waitForEnd: true }
        stderr: StdioCollector { id: localStderr; waitForEnd: true }
        onExited: function(code) {
            Qt.callLater(function() {
            var result = root.parseResult(localOutput.text, "Local state unavailable. " + localStderr.text);
            if (code !== 0) result.ok = false;
            localState.completeRead(result);
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
            root.actionPending = false;
            localState.finishMutation();
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
                enabled: !root.pendingAction && !root.diagnosticVisible && !root.previewSource
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
                        Image {
                            visible: !!root.detail
                            Layout.preferredWidth: 42; Layout.preferredHeight: 42
                            source: Qt.resolvedUrl("assets/branding/icon-pluginsea-v4.png")
                            sourceSize: Qt.size(84, 84); fillMode: Image.PreserveAspectFit
                            Accessible.role: Accessible.Graphic; Accessible.name: "Omarchy Plugin Sea"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 4
                            Image {
                                id: brandWordmark; visible: !root.detail && status !== Image.Error
                                Layout.fillWidth: true; Layout.preferredHeight: Math.min(surface.height < 600 ? 60 : 92, width / 3)
                                source: Qt.resolvedUrl("assets/branding/wordmark-pluginsea-v4.png")
                                sourceSize.width: 1000; fillMode: Image.PreserveAspectFit
                                horizontalAlignment: Image.AlignLeft
                                Accessible.role: Accessible.Graphic; Accessible.name: "Omarchy Plugin Sea"
                            }
                            Text { visible: !!root.detail || brandWordmark.status === Image.Error; Layout.fillWidth: true; text: root.detail ? root.detail.name : "Omarchy Plugin Sea"; textFormat: Text.PlainText; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title + 4; font.bold: true; elide: Text.ElideRight }
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
                        Ui.Dropdown { Layout.preferredWidth: 175; label: "Sort"; showLabel: false; value: root.sort; options: [{value:"Name", label:"Sort: name"}, {value:"Most stars", label:"Sort: stars"}, {value:"Most hearts", label:"Sort: hearts"}, {value:"Recently listed", label:"Sort: date"}]; onChanged: function(value) { root.sort = value; } }
                        Ui.Button {
                            text: root.sortDirection === "Ascending" ? "↑" : "↓"
                            bordered: true; focusable: true
                            Accessible.name: "Sort direction: " + root.sortDirection
                            tooltipText: root.sortDirection + " order. Click to reverse."
                            onClicked: root.sortDirection = root.sortDirection === "Ascending" ? "Descending" : "Ascending"
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: root.filtered.length + " plugins"; color: Color.foreground; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.body }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (root.stale ? "OFFLINE / STALE · " : "COMMUNITY CATALOG · ") + (root.fetchedAt ? "Refreshed " + root.fetchedAt : catalogProcess.running ? "Loading catalog…" : "No catalog loaded") + (root.catalogError ? "\n" + root.catalogError : "") + (root.localError ? "\n" + root.localError : "") + (root.engagementStale ? "\n" + (root.engagementError || "Hearts unavailable; showing last saved engagement stats.") : "") + (root.refreshNeeded ? "\nNew catalog data is available. Select Refresh available to load it." : root.checkError ? "\nSource check failed: " + root.checkError : root.checking ? " · Checking source…" : root.checkedAt ? " · Source checked " + root.checkedAt : "")
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
                    PluginDetails {
                        id: pluginDetails; visible: !!root.detail; Layout.fillWidth: true; Layout.fillHeight: true
                        plugin: root.detail || ({}); busy: root.busy || root.refreshing || root.checking || !!root.localError
                        hearted: !!root.detail && !!root.hearted[root.detail.id]
                        onActionRequested: function(action) { root.requestAction(action); }
                        onPreviewRequested: function(source) { root.showPreview(source); }
                    }
                    RowLayout {
                        visible: !!root.operationMessage; Layout.fillWidth: true
                        Controls.BusyIndicator { visible: root.busy; running: root.busy; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                        Text { Layout.fillWidth: true; text: root.operationMessage; textFormat: Text.PlainText; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                        Ui.Button { visible: !!root.diagnostics; text: "Diagnostics"; focusable: true; onClicked: { root.diagnosticVisible = true; Qt.callLater(function() { cancelButton.forceActiveFocus(); }); } }
                    }
                    Text { Layout.fillWidth: true; text: "Browse safely. Review source before enabling unsandboxed community code.   ·   Ctrl+F search   F5 refresh   Esc back"; wrapMode: Text.WordWrap; color: Color.foreground; opacity: 0.45; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                }
            }
            Loader {
                id: imageViewer; anchors.fill: parent; active: root.opened && !!root.previewSource
                sourceComponent: ImageViewer {
                    source: root.previewSource; title: root.detail ? root.detail.name : "Preview"
                    onClosed: root.closePreview()
                }
                onLoaded: item.forceActiveFocus()
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
                        Ui.Button { visible: !root.diagnosticVisible; text: root.pendingAction === "install" ? "Accept · install disabled" : root.pendingAction === "remove" ? "Remove plugin" : root.pendingAction === "heart" ? "Send heart" : "Accept · " + root.pendingAction; bordered: true; focusable: true; onClicked: root.pendingAction === "heart" ? root.runHeart(root.pendingPlugin) : root.runAction(root.pendingAction, root.pendingPlugin); Keys.onEscapePressed: root.cancelModal() }
                    }
                }
            }
        }
    }
}
