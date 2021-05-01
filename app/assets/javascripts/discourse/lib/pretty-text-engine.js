const babel = require("broccoli-babel-transpiler");
const mergeTrees = require("broccoli-merge-trees");
const funnel = require("broccoli-funnel");
const path = require("path");
const concat = require("broccoli-concat");

module.exports = function prettyTextEngine(vendorJs, engine) {
  let engineTree = babel(`../pretty-text/engines/${engine}`, {
    plugins: ["@babel/plugin-transform-modules-amd"],
    moduleIds: true,

    getModuleId(name) {
      return `pretty-text/engines/${engine}/${path.basename(name)}`;
    },
  });

  let markdownIt = funnel(vendorJs, { files: ["markdown-it.js"] });
  return concat(mergeTrees([engineTree, markdownIt]), {
    outputFile: `assets/${engine}.js`,
  });
};
