"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const resolve = require("path").resolve;
const mergeTrees = require("broccoli-merge-trees");
const concat = require("broccoli-concat");
const prettyTextEngine = require("./lib/pretty-text-engine");
const { createI18nTree } = require("./lib/translation-plugin");
const discourseScss = require("./lib/discourse-scss");
const funnel = require("broccoli-funnel");
const AssetRev = require("broccoli-asset-rev");

module.exports = function (defaults) {
  let discourseRoot = resolve("../../../..");
  let vendorJs = discourseRoot + "/vendor/assets/javascripts/";

  let app = new EmberApp(defaults, {
    autoRun: false,
    "ember-qunit": {
      insertContentForTestBody: false,
    },
    sourcemaps: {
      // There seems to be a bug with brocolli-concat when sourcemaps are disabled
      // that causes the `app.import` statements below to fail in production mode.
      // This forces the use of `fast-sourcemap-concat` which works in production.
      enabled: true,
    },
    autoImport: {
      forbidEval: true,
    },
    fingerprint: {
      // Disabled here, but handled manually below when in production mode.
      // This is so we can apply a single AssetRev operation over the application and our additional trees
      enabled: false,
    },
    SRI: {
      // We don't use SRI in Rails. Disable here to match:
      enabled: false,
    },
  });

  // WARNING: We should only import scripts here if they are not in NPM.
  // For example: our very specific version of bootstrap-modal.
  app.import(vendorJs + "bootbox.js");
  app.import(vendorJs + "bootstrap-modal.js");
  app.import(vendorJs + "jquery.ui.widget.js");
  app.import(vendorJs + "caret_position.js");
  app.import("node_modules/ember-source/dist/ember-template-compiler.js", {
    type: "test",
  });
  app.import(discourseRoot + "/app/assets/javascripts/polyfills.js");

  const mergedTree = mergeTrees([
    discourseScss(`${discourseRoot}/app/assets/stylesheets`, "testem.scss"),
    createI18nTree(discourseRoot, vendorJs),
    app.toTree(),
    funnel(`${discourseRoot}/public/javascripts`, { destDir: "javascripts" }),
    funnel(`${vendorJs}/highlightjs`, {
      files: ["highlight-test-bundle.min.js"],
      destDir: "assets/highlightjs",
    }),
    concat(mergeTrees([app.options.adminTree]), {
      outputFile: `assets/admin.js`,
    }),
    prettyTextEngine(vendorJs, "discourse-markdown"),
    concat("public/assets/scripts", {
      outputFile: `assets/start-discourse.js`,
      headerFiles: [`start-app.js`],
      inputFiles: [`discourse-boot.js`],
    }),
  ]);

  const isProduction = EmberApp.env().includes("production");
  if (isProduction) {
    return new AssetRev(mergedTree, {
      exclude: [
        "javascripts/**/*",
        "assets/test-i18n*",
        "assets/highlightjs",
        "assets/testem.css",
      ],
    });
  } else {
    return mergedTree;
  }
};
