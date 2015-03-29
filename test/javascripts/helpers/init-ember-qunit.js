/* global emq */

var resolver = require('discourse/ember/resolver').default;
emq.globalize();
emq.setResolver(resolver.create({ namespace: Discourse }));
