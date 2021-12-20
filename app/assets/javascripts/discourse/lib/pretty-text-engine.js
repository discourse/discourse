const babel = require("broccoli-babel-transpiler");
const mergeTrees = require("broccoli-merge-trees");
const funnel = require("broccoli-funnel");
const path = require("path");
const concat = require("broccoli-concat");

module.exports = function prettyTextEngine(vendorJs, engine) {
  let engineTree = babel(`../pretty-text/engines/${engine}`, {
    plugins: [
      "@babel/plugin-transform-modules-amd",
      "@babel/plugin-proposal-json-strings",
      "@babel/plugin-proposal-nullish-coalescing-operator",
      "@babel/plugin-proposal-logical-assignment-operators",
      "@babel/plugin-proposal-numeric-separator",
      "@babel/plugin-proposal-optional-catch-binding",
      "@babel/plugin-transform-dotall-regex",
      "@babel/plugin-proposal-unicode-property-regex",
      "@babel/plugin-transform-named-capturing-groups-regex",
      "@babel/plugin-proposal-object-rest-spread",
      "@babel/plugin-proposal-optional-chaining",
      "@babel/plugin-transform-arrow-functions",
      "@babel/plugin-transform-block-scoped-functions",
      "@babel/plugin-transform-block-scoping",
      "@babel/plugin-transform-computed-properties",
      "@babel/plugin-transform-destructuring",
      "@babel/plugin-transform-duplicate-keys",
      "@babel/plugin-transform-for-of",
      "@babel/plugin-transform-function-name",
      "@babel/plugin-transform-literals",
      "@babel/plugin-transform-object-super",
      "@babel/plugin-transform-parameters",
      "@babel/plugin-transform-shorthand-properties",
      "@babel/plugin-transform-spread",
      "@babel/plugin-transform-sticky-regex",
      "@babel/plugin-transform-template-literals",
      "@babel/plugin-transform-typeof-symbol",
      "@babel/plugin-transform-unicode-regex",
    ],
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
