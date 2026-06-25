.pragma library
.import "Http.js" as Http
.import "Mappers.js" as M

/*
 * Communities = the app's regional sources and creator "Homepages".
 * `get-communities` returns groups { globals, locals, foreigns, independents };
 * we flatten them (de-duped by id) into a single labelled list for the
 * Homepage directory.
 */
function getCommunities(baseUrl, onOk, onErr) {
    Http.get(baseUrl, "/general/get-communities", null, null, function (data) {
        var groups = [
            ["globals", "Global"],
            ["locals", "Local"],
            ["foreigns", "International"],
            ["independents", "Independent"]
        ];
        var seen = {};
        var out = [];
        for (var g = 0; g < groups.length; g++) {
            var arr = data[groups[g][0]] || [];
            for (var i = 0; i < arr.length; i++) {
                var c = M.toCommunity(arr[i]);
                if (c.id === undefined || c.id === null || seen[c.id])
                    continue;
                seen[c.id] = true;
                c.group = groups[g][1];
                out.push(c);
            }
        }
        onOk(out);
    }, onErr);
}
