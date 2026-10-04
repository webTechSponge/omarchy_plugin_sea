.pragma library
// Count affordance colors, shared by cards and the detail header.
// Fixed literals: golden stars, red hearts, legible on dark and light themes.
var STAR_GOLD = "#C9A227";
var HEART_RED = "#E5484D";

function correlate(remote, local, engagement, current) {
    var byId = Object.create(null), seen = Object.create(null), result = [];
    (local || []).forEach(function(p) { byId[p.id] = p; });
    (remote || []).forEach(function(p) {
        var row = Object.assign({}, p);
        row.local = byId[p.id] || null;
        row.catalogCurrent = current !== false;
        row.localOnly = false;
        row.hearts = (engagement && typeof engagement[p.id] === "number") ? engagement[p.id] : null;
        var refusal = snapshotRefusal(row);
        row.installAvailable = refusal === "";
        row.installNote = refusal || "Install exactly the verified listing revision, detached and initially disabled; enabling requires a fresh snapshot/content check.";
        result.push(row); seen[p.id] = true;
    });
    (local || []).forEach(function(p) {
        if (seen[p.id] || p.firstParty) return;
        result.push({id:p.id, name:p.name || p.id, description:"Installed locally; absent from the community catalog.",
            author:"Local installation", version:p.version || "", category:"Local", tags:p.kinds || [],
            repo:p.repo || "", previewImage:"", previewThumbnail:"", installAvailable:false,
            verificationStatus:"Not listed", status:"local", local:p, localOnly:true, hearts:null});
    });
    return result;
}
function status(p) {
    if (p.local) return (p.local.enabled ? "Enabled" : "Installed · disabled") + (lifecycleWarning(p) ? " · Catalog: " + p.status : "");
    if (p.status && ["active", "available", "listed", "ok"].indexOf(String(p.status).toLowerCase()) < 0) return p.status;
    return installEligible(p) ? "Available" : "Installation unavailable";
}
function categories(rows) {
    var values = Object.create(null);
    rows.forEach(function(p) { if (p.category) values[p.category] = true; });
    return ["All categories"].concat(Object.keys(values).sort());
}
function filter(rows, query, category, scope, sort, direction) {
    var words = query.toLowerCase().trim().split(/\s+/).filter(function(w) { return w; });
    var filtered = rows.filter(function(p) {
        var haystack = [p.name,p.description,p.author,p.id,p.category,(p.tags || []).join(" ")].join(" ").toLowerCase();
        return words.every(function(w) { return haystack.indexOf(w) >= 0; })
            && (category === "All categories" || p.category === category)
            && (scope === "All plugins" || (scope === "Installed" && p.local) || (scope === "Available" && !p.local && installEligible(p)));
    });
    // Keep the legacy default for callers without an explicit direction.
    var sign = direction === "Ascending" ? 1 : direction === "Descending" ? -1 : sort === "Name" ? 1 : -1;
    filtered.sort(function(a,b) {
        if (sort === "Most hearts" && heartSort(a) !== heartSort(b)) return sign * (heartSort(a) - heartSort(b));
        if (sort === "Most stars" && starCount(a) !== starCount(b)) return sign * (starCount(a) - starCount(b));
        if (sort === "Recently listed" && a.listedAt !== b.listedAt) return sign * String(a.listedAt || "").localeCompare(String(b.listedAt || ""));
        var nameOrder = String(a.name || a.id).localeCompare(String(b.name || b.id));
        return (sort === "Name" ? sign : 1) * (nameOrder || String(a.id).localeCompare(String(b.id)));
    });
    return filtered;
}
function safeLink(url) { return /^https:\/\/[^\s/@]+(?:\/[^\s]*)?$/.test(String(url || "")); }
function safeGitHubLink(url) { return canonicalGitHub(url) !== ""; }

// IDs correlate installation state, not repository identity or code provenance.
// Never use catalog origin as a substitute for an unknown installed Git origin.
function sourceUrl(p) {
    var value = p && p.local ? p.local.repo : p && p.repo;
    return typeof value === "string" ? value : "";
}
function canonicalGitHub(url) {
    if (typeof url !== "string") return "";
    var match = /^(?:https:\/\/github\.com\/|git@github\.com:|ssh:\/\/git@github\.com\/)([a-z0-9_.-]+)\/([a-z0-9._-]+)\/?$/i.exec(url);
    if (!match) return "";
    var owner = match[1].toLowerCase();
    var repo = match[2].replace(/\.git$/i, "").toLowerCase();
    if (!repo || url.indexOf("..") >= 0) return "";
    return "https://github.com/" + owner + "/" + repo;
}
function sourceMatches(p) {
    if (!p || !p.local || p.localOnly) return false;
    var installed = canonicalGitHub(sourceUrl(p));
    var listed = canonicalGitHub(p.repo);
    return installed !== "" && listed !== "" && installed === listed;
}
function snapshotRefusal(p) {
    if (!p || p.localOnly) return "No current community catalog snapshot is available for this local installation.";
    if (p.catalogCurrent === false) return "Catalog evidence is stale or unavailable. Refresh and review the current listing before installing or enabling.";
    if (typeof p.status !== "string" && p.status != null) return "Catalog status has an invalid type; installation is unavailable until upstream corrects it.";
    if (!/^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/?$/.test(String(p.repo || "")) || !canonicalGitHub(p.repo))
        return "Source is unavailable or unsupported; inspect upstream manually.";
    if (String(p.id || "").indexOf("omarchy.") === 0) return "Reserved platform plugins cannot be installed from the community catalog.";
    if (/yanked|quarantined|unavailable/.test(String(p.status || "").toLowerCase())) return "This catalog listing is blocked or unavailable.";
    if (p.installAvailable !== true) return p.installNote || "The catalog does not offer installation for this listing.";
    if (p.repositoryLayout !== "root-plugin" || p.manifestPath !== "manifest.json")
        return "Only root-plugin repositories with a root manifest.json support immutable installation.";
    if (!/^[0-9a-f]{40}$/.test(String(p.listingValidatedCommit || ""))) return "The catalog has no valid full immutable listing revision.";
    if (p.verificationSnapshotStatus !== "verified") return "The listing snapshot is not verified; installation is unavailable.";
    if (!/^[0-9a-f]{40}$/.test(String(p.verificationCommit || "")) || p.verificationCommit !== p.listingValidatedCommit)
        return "Snapshot verification does not match the immutable listing revision.";
    return "";
}
function installEligible(p) { return snapshotRefusal(p) === ""; }
function enableRefusal(p) {
    if (!p || !p.local) return "This plugin is not installed.";
    if (p.local.firstParty) return "";
    var snapshot = snapshotRefusal(p);
    if (snapshot) return snapshot;
    if (!/^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/?$/.test(sourceUrl(p)) || !canonicalGitHub(sourceUrl(p)))
        return "Installed Git origin is not a supported canonical HTTPS repository; enable must be managed externally.";
    if (!sourceMatches(p)) return "Installed Git origin differs from the catalog repository; enable must be managed externally.";
    if (sourceUrl(p) !== p.repo) return "Installed Git origin spelling does not exactly match the selected catalog HTTPS source; enable must be managed externally.";
    if (p.local.headCommit !== p.listingValidatedCommit) return "Installed revision does not match the current verified listing snapshot; enable must be managed externally.";
    if (p.local.detached !== true) return "Installed checkout is not detached at the verified snapshot; enable must be managed externally.";
    if (p.local.clean !== true) return "Installed checkout is dirty or its content state is unknown (including untracked and ignored files); enable must be managed externally.";
    return "";
}
function enableAvailable(p) { return enableRefusal(p) === ""; }
function verificationLabel(p) {
    if (!p) return "Snapshot unavailable";
    if (p.local && p.local.firstParty) return "Platform plugin";
    if (p.local) return enableAvailable(p) ? "Observed snapshot/content match" : "Installed snapshot/content unmatched";
    return installEligible(p) ? "Verified listing snapshot available" : "Snapshot installation unavailable";
}
function provenanceNote(p) {
    if (!p) return "";
    var boundary = "Catalog metadata is unsigned. A snapshot/content match is not a safety certification or sandbox.";
    if (p.local && p.local.firstParty) return "First-party enable is managed by the platform.";
    if (p.local) {
        var refusal = enableRefusal(p);
        return (refusal ? "In-app enable refused: " + refusal : "Observed origin, revision, detached state and clean content match the current listing snapshot. The backend rechecks immediately before enable.") + " " + boundary;
    }
    var snapshot = snapshotRefusal(p);
    return (snapshot ? "In-app install unavailable: " + snapshot : "Installation selects the exact verified listing revision, not mutable upstream HEAD.") + " " + boundary;
}
function revisionNote(p) {
    var listed = p.listingValidatedCommit || "";
    var upstream = p.upstreamObservedCommit || "";
    var installed = p.local ? p.local.headCommit || "" : "";
    return (upstream && listed && upstream !== listed ? "Observed upstream differs from the listing snapshot; installation still selects the verified listing revision. " : "")
        + (p.local && installed && listed && installed !== listed ? "Installed revision differs from the current listing snapshot. " : "")
        + (p.local ? "Observed checkout: " + (p.local.detached === true ? "detached" : p.local.detached === false ? "attached" : "detached state unknown") + " · " + (p.local.clean === true ? "clean (including untracked/ignored content)" : p.local.clean === false ? "dirty" : "content state unknown") + "." : "");
}
function externalUpdateGuidance(p) {
    if (!p.local || p.local.gitManaged !== true)
        return "Updates are managed outside this app. This installation is not a confirmed Git checkout; follow its documented installation or development workflow. Inspect replacement code before enabling externally.";
    return "Updates are managed outside this app. External `omarchy plugin update " + p.id
        + "` follows mutable upstream HEAD, outside this app's reviewed-snapshot install/enable path. Disable the plugin first: updating an enabled plugin may live-reload and execute new code immediately. Inspect the resulting code and revision before enabling externally. A changed checkout may no longer qualify for in-app enable.";
}

// Catalog lifecycle is independent of local installation and source matching.
function lifecycleWarning(p) {
    if (!p || p.localOnly || typeof p.status !== "string") return "";
    var value = p.status.toLowerCase();
    var kind = /quarantined|yanked|unavailable/.exec(value);
    if (!kind) return "";
    return "Catalog warning: this listing is " + value + ". "
        + (kind[0] === "quarantined" ? "It has been isolated by the catalog. " : kind[0] === "yanked" ? "It has been withdrawn from the catalog. " : "It is not currently available from the catalog. ")
        + "In-app installation and enable are unavailable for this listing. "
        + (p.local ? "You can still disable or remove the installed plugin. " : "")
        + (p.local && !sourceMatches(p) ? "This warning refers to the listing with the same ID; its source is not confirmed to match this installation." : "");
}

function starCount(p) {
    return typeof p.stars === "number" && isFinite(p.stars) ? Math.max(0, Math.floor(p.stars)) : 0;
}
function heartCount(p) {
    return typeof p.hearts === "number" && isFinite(p.hearts) ? Math.max(0, Math.floor(p.hearts)) : 0;
}
// Sorting key: an absent engagement record (null) sorts below any tracked
// count so untracked plugins fall last in descending order.
function heartSort(p) {
    return p.hearts == null ? -1 : heartCount(p);
}
function availabilityHelp(p) {
    var message = p.local
        ? (p.local.enabled ? "Installed and enabled: this plugin can run code as your user." : "Installed but disabled: its files are on this computer, but it is not enabled in the shell.")
        : installEligible(p) ? "Available means the exact verified listing snapshot can be installed through this app. It is not a safety certification. Install disabled to inspect the source before enabling."
        : "This listing cannot currently be installed through this app. " + snapshotRefusal(p);
    return message + (lifecycleWarning(p) ? "\n\n" + lifecycleWarning(p) : "");
}
