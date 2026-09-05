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
            && (scope === "All plugins" || (scope === "Installed" && p.local) || (scope === "Available" && !p.local));
    });
    filtered.sort(function(a,b) {
        if (sort === "Most stars" && (a.stars || 0) !== (b.stars || 0)) return (b.stars || 0) - (a.stars || 0);
        if (sort === "Recently listed" && a.listedAt !== b.listedAt) return String(b.listedAt || "").localeCompare(String(a.listedAt || ""));
        return String(a.name || a.id).localeCompare(String(b.name || b.id));
    });
    return filtered;
}
function safeLink(url) { return /^https:\/\/[^\s/@]+(?:\/[^\s]*)?$/.test(String(url || "")); }
