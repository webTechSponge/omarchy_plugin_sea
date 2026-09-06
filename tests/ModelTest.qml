import QtQuick
import "../js/CatalogModel.js" as Catalog
Item {
    property int assertions: 0
    function check(value, message) { if (!value) throw new Error(message); assertions += 1; }
    Timer { interval: 1; running: true; onTriggered: {
        try {
            var remote = [
                {id:"test.one",name:"Same",description:"Audio control",author:"Ada",category:"Tools",tags:["music"],stars:2,listedAt:"2026-08-01",installAvailable:true},
                {id:"test.two",name:"Same",description:"Window helper",author:"Ben",category:"Desktop",tags:["tiling"],stars:5,listedAt:"2026-09-01",installAvailable:true},
                {id:"constructor",name:"Prototype edge",category:"Tools",tags:[],installAvailable:false}
            ];
            var local = [{id:"test.two",name:"Renamed locally",enabled:false,firstParty:false}, {id:"test.local",name:"Local",enabled:true,firstParty:false}, {id:"omarchy.clock",enabled:true,firstParty:true}];
            var rows = Catalog.correlate(remote,local);
            check(rows.length === 4,"Local-only plugin retained, builtins omitted");
            check(!rows[0].local && rows[1].local.id === "test.two","Match canonical ID, never name");
            check(!rows[2].local,"Prototype-named ID is not installed");
            check(rows[3].localOnly && !rows[3].installAvailable,"Local-only state is explicit");
            check(Catalog.status(rows[1]) === "Installed · disabled","Disabled state");
            check(Catalog.status(rows[3]) === "Enabled","Enabled state");
            check(Catalog.filter(rows,"ada music","All categories","All plugins","Name").length === 1,"Search author and tags together");
            check(Catalog.filter(rows,"TEST.TWO","Desktop","All plugins","Name").length === 1,"Case insensitive ID and category filter");
            check(Catalog.filter(rows,"","All categories","Installed","Name").length === 2,"Installed filter");
            check(Catalog.filter(rows,"","All categories","Available","Most stars")[0].id === "test.one","Available filter and stars sort");
            check(Catalog.filter(rows,"","All categories","Available","Name").length === 1,"Available excludes manual or unavailable catalog entries");
            check(Catalog.filter(rows,"","All categories","All plugins","Recently listed")[0].id === "test.two","Date sort");
            check(Catalog.categories(rows).join("|") === "All categories|Desktop|Local|Tools","Categories unique and sorted");
            check(!Catalog.safeLink("file:///etc/passwd") && !Catalog.safeLink("javascript:alert(1)") && Catalog.safeLink("https://github.com/test/repo"),"Only HTTPS links");
            var listed = {id:"test.source", repo:"https://github.com/Original/Plugin.git/", verificationStatus:"Verified"};
            var matched = Catalog.correlate([listed], [{id:"test.source",repo:"git@github.com:original/plugin.git",enabled:true}])[0];
            var forked = Catalog.correlate([listed], [{id:"test.source",repo:"https://github.com/Fork/Plugin",enabled:true}])[0];
            var unknown = Catalog.correlate([listed], [{id:"test.source",enabled:true}])[0];
            var standalone = Catalog.correlate([], [{id:"test.source",repo:"https://github.com/Original/Plugin",enabled:true}])[0];
            check(Catalog.canonicalGitHub("HTTPS://GITHUB.COM/Owner/Repo.git/") === "https://github.com/owner/repo", "HTTPS origin normalization");
            check(Catalog.canonicalGitHub("git@github.com:Owner/Repo.git") === "https://github.com/owner/repo", "Git SSH shorthand origin normalization");
            check(Catalog.canonicalGitHub("ssh://git@github.com/Owner/Repo.git") === "https://github.com/owner/repo", "Git SSH URL origin normalization");
            ["http://github.com/owner/repo", "https://github.com.evil/owner/repo", "https://user@github.com/owner/repo", "https://github.com/owner/repo?ref=main", "https://github.com/owner/repo#readme", "https://github.com/owner/repo/tree/main", "https://github.com/owner/..", "https://github.com/owner/.git", "https://github.com/owner/repo%2fother", "ssh://root@github.com/owner/repo", "file:///tmp/repo", "", null].forEach(function(url) {
                check(Catalog.canonicalGitHub(url) === "", "Reject ambiguous/unsupported origin: " + url);
            });
            check(Catalog.sourceUrl(listed) === listed.repo, "Uninstalled source uses catalog repository");
            check(Catalog.sourceUrl(matched) === matched.local.repo, "Installed source retains actual raw Git origin");
            check(Catalog.sourceUrl(forked) === forked.local.repo, "Installed fork source never inherits catalog original");
            check(Catalog.sourceUrl(unknown) === "", "Unknown installed source never falls back to catalog original");
            check(Catalog.sourceUrl(standalone) === standalone.local.repo, "Local-only source retains installed origin");
            check(Catalog.sourceMatches(matched), "Canonical HTTPS and SSH repository origins match");
            check(!Catalog.sourceMatches(forked), "Same plugin ID does not imply same repository");
            check(!Catalog.sourceMatches(unknown), "Unknown installed source never matches");
            check(!Catalog.sourceMatches(standalone), "Local-only rows have no catalog provenance to match");
            check(!Catalog.sourceMatches(listed), "Uninstalled listing is not an installed source match");
            check(Catalog.verificationLabel(forked).indexOf("Verified") === -1 && Catalog.verificationLabel(forked).indexOf("differs") >= 0, "Fork cannot inherit original verified badge");
            check(Catalog.verificationLabel(unknown).indexOf("unknown") >= 0, "Unknown origin explicitly unverified");
            check(Catalog.verificationLabel(matched) === "Installed code unverified", "Matching origin does not verify installed revision");
            check(Catalog.verificationLabel(standalone).indexOf("unverified") >= 0, "Local-only installation explicitly unverified");
            check(Catalog.verificationLabel(listed) === "Catalog: Verified", "Uninstalled verification remains catalog-scoped");
            check(Catalog.provenanceNote(forked).indexOf("does not apply") >= 0, "Mismatch provenance explicitly disclaims catalog verification");
            check(Catalog.provenanceNote(unknown).indexOf("unknown") >= 0, "Missing provenance explicit");
            check(Catalog.provenanceNote(matched).indexOf("not the installed revision") >= 0, "Matching origin snapshot limitation explicit");
            check(forked.verificationStatus === "Verified" && forked.local.repo === "https://github.com/Fork/Plugin" && forked.id === listed.id, "Catalog presentation and ID correlation retained");
            var unknownCatalog = {local:{repo:"https://github.com/owner/repo"}, repo:""};
            check(!Catalog.sourceMatches(unknownCatalog) && Catalog.provenanceNote(unknownCatalog).indexOf("unknown") >= 0, "Unknown catalog origin is not claimed as a confirmed mismatch");
            console.log("PASS: " + assertions + " catalog model behavior assertions");
            Qt.exit(0);
        } catch (error) { console.error(error); Qt.exit(1); }
    } }
}
