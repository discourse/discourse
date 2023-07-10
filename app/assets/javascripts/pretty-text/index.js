"use strict";

const Funnel = require("broccoli-funnel");
const mergeTrees = require("broccoli-merge-trees");
const path = require("path");

module.exports = {
  name: require("./package").name,

  // custom method to produce the tree for markdown-it-bundle.js
  // called by ember-cli-build.js in discourse core
  //
  // code in here is only needed by the editor and we do not want them included
  // into the main addon/vendor bundle; instead, it'll be included via a script
  // tag as needed
  treeForMarkdownItBundle() {
    return mergeTrees([this._treeForEngines(), this._treeForMarkdownIt()]);
  },

  // treat the JS code in /engines like any other JS code in the /addon folder
  _treeForEngines() {
    let enginesTreePath = path.resolve(this.root, "engines");
    let enginesTree = this.treeGenerator(enginesTreePath);

    // we started at /engines, if we just call treeForAddon, the modules will
    // be under pretty-text/*, but we want pretty-text/engines/*
    let namespacedTree = new Funnel(enginesTree, {
      destDir: "engines",
    });

    return this.treeForAddon.call(this, namespacedTree);
  },

  _treeForMarkdownIt() {
    let markdownIt = require.resolve("markdown-it/dist/markdown-it.js");

    return new Funnel(path.dirname(markdownIt), {
      files: ["markdown-it.js"],
    });
  },

  isDevelopingAddon() {
    return true;
  },
};
