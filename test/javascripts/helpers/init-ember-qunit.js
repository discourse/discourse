 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
var buildResolver = require('discourse-common/resolver').buildResolver;
window.setResolver(buildResolver('discourse').create({ namespace: Discourse }));
//@license-end
