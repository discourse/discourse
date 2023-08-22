"use strict";

const calculateCacheKeyForTree = require("calculate-cache-key-for-tree");
const path = require("path");

module.exports = {
  name: require("./package").name,

  // return an empty tree here as we do not want the addon modules to be
  // included into vendor.js; instead, we will produce a separate bundle
  // (wizard.js) to be included via a script tag as needed
  treeForAddon() {
    return;
  },

  // custom method to produce the tree for wizard.js
  // called by ember-cli-build.js in discourse core
  treeForAddonBundle() {
    let addonTreePath = path.resolve(this.root, this.treePaths.addon);
    let addonTree = this.treeGenerator(addonTreePath);
    return this._super.treeForAddon.call(this, addonTree);
  },

  cacheKeyForTree(tree) {
    return calculateCacheKeyForTree(tree, this);
  },

  isDevelopingAddon() {
    return true;
  },
};
