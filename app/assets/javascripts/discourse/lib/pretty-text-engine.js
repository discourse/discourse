const mergeTrees = require("broccoli-merge-trees");
const funnel = require("broccoli-funnel");
const concat = require("broccoli-concat");
const WatchedDir = require("broccoli-source").WatchedDir;
const Funnel = require("broccoli-funnel");

module.exports = function prettyTextEngine(app) {
  let babelAddon = app.project.findAddonByName("ember-cli-babel");

  const sourceTree = new WatchedDir(
    "../pretty-text/engines/discourse-markdown"
  );
  const namespacedTree = new Funnel(sourceTree, {
    getDestinationPath: function (relativePath) {
      return `pretty-text/engines/discourse-markdown/${relativePath}`;
    },
  });

  const engineTree = babelAddon.transpileTree(namespacedTree);

  let markdownIt = funnel("../node_modules/markdown-it/dist", {
    files: ["markdown-it.js"],
  });
  return concat(mergeTrees([engineTree, markdownIt]), {
    inputFiles: ["**/*.js"],
    outputFile: `assets/markdown-it-bundle.js`,
  });
};
