"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const resolve = require("path").resolve;
const mergeTrees = require("broccoli-merge-trees");
const concat = require("broccoli-concat");
const prettyTextEngine = require("./lib/pretty-text-engine");
const { createI18nTree } = require("./lib/translation-plugin");

module.exports = function (defaults) {
  let discourseRoot = resolve("../../../..");
  let vendorJs = discourseRoot + "/vendor/assets/javascripts/";

  let app = new EmberApp(defaults, {
    autoRun: false,
    "ember-qunit": {
      insertContentForTestBody: false,
    },
  });

  // WARNING: We should only import scripts here if they are not in NPM.
  // For example: our very specific version of bootstrap-modal.
  app.import(vendorJs + "bootbox.js");
  app.import(vendorJs + "bootstrap-modal.js");
  app.import(vendorJs + "jquery.ui.widget.js");
  app.import(vendorJs + "jquery.fileupload.js");
  app.import(vendorJs + "jquery.autoellipsis-1.0.10.js");

  return mergeTrees([
    createI18nTree(discourseRoot, vendorJs),
    app.toTree(),
    concat(app.options.adminTree, {
      outputFile: `assets/admin.js`,
    }),
    prettyTextEngine(vendorJs, "discourse-markdown"),
  ]);
};
