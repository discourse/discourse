var buildResolver = require('discourse-common/resolver').buildResolver;
window.setResolver(buildResolver('discourse').create({ namespace: Discourse }));
