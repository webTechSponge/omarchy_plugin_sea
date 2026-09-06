.pragma library
// Count affordance colors, shared by cards and the detail header.
// Fixed literals: golden stars, red hearts, legible on dark and light themes.
var STAR_GOLD = "#C9A227";
var HEART_RED = "#E5484D";

function correlate(remote, local, engagement) {
    var byId = Object.create(null), seen = Object.create(null), result = [];
    (local || []).forEach(function(p) { byId[p.id] = p; });
    (remote || []).forEach(function(p) {
        var row = Object.assign({}, p);
        row.local = byId[p.id] || null;
        row.localOnly = false;
        row.hearts = (engagement && typeof engagement[p.id] === "number") ? engagement[p.id] : null;
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
    if (p.status && ["active", "available", "listed", "ok"].indexOf(p.status) < 0) return p.status;
    return p.installAvailable ? "Available" : "Manual installation";
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
            && (scope === "All plugins" || (scope === "Installed" && p.local) || (scope === "Available" && !p.local && p.installAvailable === true));
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
    var match = /^(?:https:\/\/github\.com\/|git@github\.com:|ssh:\/\/git@github\.com\/)([a-z0-9-]+)\/([a-z0-9._-]+)\/?$/i.exec(url);
    if (!match) return "";
    var owner = match[1].toLowerCase();
    var repo = match[2].replace(/\.git$/i, "").toLowerCase();
    if (!repo || repo === "." || repo === "..") return "";
    return "https://github.com/" + owner + "/" + repo;
}
function sourceMatches(p) {
    if (!p || !p.local || p.localOnly) return false;
    var installed = canonicalGitHub(sourceUrl(p));
    var listed = canonicalGitHub(p.repo);
    return installed !== "" && listed !== "" && installed === listed;
}
function verificationLabel(p) {
    if (!p) return "Unverified";
    if (!p.local) return "Catalog: " + (p.verificationStatus || "Not verified");
    if (p.localOnly) return "Local installation · unverified";
    if (!sourceUrl(p)) return "Installed source unknown · unverified";
    if (!canonicalGitHub(sourceUrl(p))) return "Installed source unmatched · unverified";
    if (!canonicalGitHub(p.repo)) return "Catalog source unknown · installed code unverified";
    if (!sourceMatches(p)) return "Installed source differs · unverified";
    return "Installed code unverified";
}
function provenanceNote(p) {
    if (!p || !p.local)
        return "Catalog checks cover a listed snapshot, not current repository contents or installed code.";
    if (p.localOnly)
        return "Installed locally; no catalog record. This installation has not been verified by the catalog.";
    if (!canonicalGitHub(sourceUrl(p)))
        return "Installed Git origin is unknown or unsupported. Catalog verification does not apply to this installation.";
    if (!canonicalGitHub(p.repo))
        return "Catalog repository origin is unknown or unsupported. Catalog verification does not apply to this installation.";
    if (!sourceMatches(p))
        return "Installed Git origin differs from the catalog repository. Catalog verification does not apply to this installation.";
    return "Installed Git origin matches the catalog repository. Catalog checks cover a listed snapshot, not the installed revision.";
}

// Catalog lifecycle is independent of local installation and source matching.
function lifecycleWarning(p) {
    if (!p || p.localOnly || typeof p.status !== "string") return "";
    var value = p.status.toLowerCase();
    var kind = /quarantined|yanked|unavailable/.exec(value);
    if (!kind) return "";
    return "Catalog warning: this listing is " + value + ". "
        + (kind[0] === "quarantined" ? "It has been isolated by the catalog. " : kind[0] === "yanked" ? "It has been withdrawn from the catalog. " : "It is not currently available from the catalog. ")
        + "Check the source and catalog explanation before enabling or updating. "
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
        : p.installAvailable ? "Available means this listing supports installation through this app. It does not mean the plugin is already installed or has been verified safe. Install disabled to inspect its source before enabling."
        : "This listing cannot currently be installed through this app. Open its details for the author's source and any manual setup instructions.";
    return message + (lifecycleWarning(p) ? "\n\n" + lifecycleWarning(p) : "");
}
