import QtQuick
import "../js/CatalogModel.js" as Catalog
Item {
    function check(value, message) { if (!value) throw new Error(message); }
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
            check(Catalog.filter(rows,"","All categories","All plugins","Recently listed")[0].id === "test.two","Date sort");
            check(Catalog.categories(rows).join("|") === "All categories|Desktop|Local|Tools","Categories unique and sorted");
            check(!Catalog.safeLink("file:///etc/passwd") && !Catalog.safeLink("javascript:alert(1)") && Catalog.safeLink("https://github.com/test/repo"),"Only HTTPS links");
            console.log("PASS: 13 catalog model behavior assertions");
            Qt.exit(0);
        } catch (error) { console.error(error); Qt.exit(1); }
    } }
}
