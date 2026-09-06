.pragma library

function correlate(remote, local) {
    var byId = Object.create(null), seen = Object.create(null), result = [];
    (local || []).forEach(function(p) { byId[p.id] = p; });
    (remote || []).forEach(function(p) {
        var row = Object.assign({}, p);
        row.local = byId[p.id] || null;
        row.localOnly = false;
        result.push(row); seen[p.id] = true;
    });
    (local || []).forEach(function(p) {
        if (seen[p.id] || p.firstParty) return;
        result.push({id:p.id, name:p.name || p.id, description:"Installed locally; absent from the community catalog.",
            author:"Local installation", version:p.version || "", category:"Local", tags:p.kinds || [],
            repo:p.repo || "", previewImage:"", previewThumbnail:"", installAvailable:false,
            verificationStatus:"Not listed", status:"local", local:p, localOnly:true});
    });
    return result;
}
function status(p) {
    if (p.local) return p.local.enabled ? "Enabled" : "Installed · disabled";
    if (p.status && ["active", "available", "listed", "ok"].indexOf(p.status) < 0) return p.status;
    return p.installAvailable ? "Available" : "Manual installation";
}
function categories(rows) {
    var values = Object.create(null);
    rows.forEach(function(p) { if (p.category) values[p.category] = true; });
    return ["All categories"].concat(Object.keys(values).sort());
}
function filter(rows, query, category, scope, sort) {
    var words = query.toLowerCase().trim().split(/\s+/).filter(function(w) { return w; });
    var filtered = rows.filter(function(p) {
        var haystack = [p.name,p.description,p.author,p.id,p.category,(p.tags || []).join(" ")].join(" ").toLowerCase();
        return words.every(function(w) { return haystack.indexOf(w) >= 0; })
            && (category === "All categories" || p.category === category)
            && (scope === "All plugins" || (scope === "Installed" && p.local) || (scope === "Available" && !p.local && p.installAvailable === true));
    });
    filtered.sort(function(a,b) {
        if (sort === "Most stars" && (a.stars || 0) !== (b.stars || 0)) return (b.stars || 0) - (a.stars || 0);
        if (sort === "Recently listed" && a.listedAt !== b.listedAt) return String(b.listedAt || "").localeCompare(String(a.listedAt || ""));
        return String(a.name || a.id).localeCompare(String(b.name || b.id));
    });
    return filtered;
}
function safeLink(url) { return /^https:\/\/[^\s/@]+(?:\/[^\s]*)?$/.test(String(url || "")); }

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
