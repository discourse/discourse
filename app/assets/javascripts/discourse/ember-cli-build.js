"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const resolve = require("path").resolve;
const mergeTrees = require("broccoli-merge-trees");
const concat = require("broccoli-concat");
const babel = require("broccoli-babel-transpiler");
const path = require("path");
const funnel = require("broccoli-funnel");

function prettyTextEngine(vendorJs, engine) {
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
}

module.exports = function (defaults) {
  let discourseRoot = resolve("../../../..");
  let vendorJs = discourseRoot + "/vendor/assets/javascripts/";

  let app = new EmberApp(defaults, { autoRun: false });

  // WARNING: We should only import scripts here if they are not in NPM.
  // For example: our very specific version of bootstrap-modal.
  app.import(vendorJs + "bootbox.js");
  app.import(vendorJs + "bootstrap-modal.js");
  app.import(vendorJs + "jquery.ui.widget.js");
  app.import(vendorJs + "jquery.fileupload.js");
  app.import(vendorJs + "jquery.autoellipsis-1.0.10.js");

  return mergeTrees([
    app.toTree(),
    concat(app.options.adminTree, {
      outputFile: `assets/admin.js`,
    }),
    prettyTextEngine(vendorJs, "discourse-markdown"),
  ]);
};
