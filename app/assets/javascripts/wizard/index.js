"use strict";

const calculateCacheKeyForTree = require("calculate-cache-key-for-tree");

module.exports = {
  name: require("./package").name,
  treeForAddon(tree) {
    let app = this._findHost();
    app.options.wizardTree = this._super.treeForAddon.call(this, tree);
    return;
  },

  cacheKeyForTree(tree) {
    return calculateCacheKeyForTree(tree, this);
  },

  isDevelopingAddon() {
    return true;
  },
};
