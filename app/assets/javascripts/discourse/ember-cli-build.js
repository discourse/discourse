"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const path = require("path");
const mergeTrees = require("broccoli-merge-trees");
const concat = require("broccoli-concat");
const { createI18nTree } = require("./lib/translation-plugin");
const { parsePluginClientSettings } = require("./lib/site-settings-plugin");
const discourseScss = require("./lib/discourse-scss");
const generateScriptsTree = require("./lib/scripts");
const funnel = require("broccoli-funnel");
const DeprecationSilencer = require("deprecation-silencer");
const generateWorkboxTree = require("./lib/workbox-tree-builder");
const { compatBuild } = require("@embroider/compat");
const { Webpack } = require("@embroider/webpack");

process.env.BROCCOLI_ENABLED_MEMOIZE = true;

module.exports = function (defaults) {
  const discourseRoot = path.resolve("../../../..");
  const vendorJs = discourseRoot + "/vendor/assets/javascripts/";

  // Silence deprecations which we are aware of - see `lib/deprecation-silencer.js`
  DeprecationSilencer.silence(console, "warn");
  DeprecationSilencer.silence(defaults.project.ui, "writeWarnLine");

  const isProduction = EmberApp.env().includes("production");

  const app = new EmberApp(defaults, {
    autoRun: false,
    "ember-qunit": {
      insertContentForTestBody: false,
    },
    sourcemaps: {
      // There seems to be a bug with broccoli-concat when sourcemaps are disabled
      // that causes the `app.import` statements below to fail in production mode.
      // This forces the use of `fast-sourcemap-concat` which works in production.
      enabled: true,
    },
    fingerprint: {
      // Handled by Rails asset pipeline
      enabled: false,
    },
    SRI: {
      // We don't use SRI in Rails. Disable here to match:
      enabled: false,
    },

    "ember-cli-deprecation-workflow": {
      enabled: true,
    },

    "ember-cli-terser": {
      enabled: isProduction,
      exclude: ["**/highlightjs/*", "**/javascripts/*"],
    },

    "ember-cli-babel": {
      throwUnlessParallelizable: true,
    },

    babel: {
      plugins: [require.resolve("deprecation-silencer")],
    },

    vendorFiles: {
      // Freedom patch - includes bug fix and async stack support
      // https://github.com/discourse/backburner.js/commits/discourse-patches
      backburner:
        "node_modules/@discourse/backburner.js/dist/named-amd/backburner.js",
    },
  });

  // TODO: remove me
  // Ember 3.28 still has some internal dependency on jQuery being a global,
  // for the time being we will bring it in vendor.js
  app.import("node_modules/jquery/dist/jquery.js", { prepend: true });

  // WARNING: We should only import scripts here if they are not in NPM.
  app.import(vendorJs + "bootbox.js");
  app.import("node_modules/ember-source/dist/ember-template-compiler.js", {
    type: "test",
  });
  app.import(discourseRoot + "/app/assets/javascripts/polyfills.js");

  app.import(
    discourseRoot +
      "/app/assets/javascripts/discourse/public/assets/scripts/module-shims.js"
  );

  const discoursePluginsTree = app.project
    .findAddonByName("discourse-plugins")
    .generatePluginsTree(app.tests);

  const adminTree = app.project.findAddonByName("admin").treeForAddonBundle();

  const wizardTree = app.project.findAddonByName("wizard").treeForAddonBundle();

  const testStylesheetTree = mergeTrees([
    discourseScss(`${discourseRoot}/app/assets/stylesheets`, "qunit.scss"),
    discourseScss(
      `${discourseRoot}/app/assets/stylesheets`,
      "qunit-custom.scss"
    ),
  ]);
  app.project.liveReloadFilterPatterns = [/.*\.scss/];

  const terserPlugin = app.project.findAddonByName("ember-cli-terser");
  const applyTerser = (tree) => terserPlugin.postprocessTree("all", tree);

  let extraPublicTrees = [
    createI18nTree(discourseRoot, vendorJs),
    parsePluginClientSettings(discourseRoot, vendorJs, app),
    funnel(`${discourseRoot}/public/javascripts`, { destDir: "javascripts" }),
    funnel(`${vendorJs}/highlightjs`, {
      files: ["highlight-test-bundle.min.js"],
      destDir: "assets/highlightjs",
    }),
    generateWorkboxTree(),
    concat(adminTree, {
      inputFiles: ["**/*.js"],
      outputFile: `assets/admin.js`,
    }),
    concat(wizardTree, {
      inputFiles: ["**/*.js"],
      outputFile: `assets/wizard.js`,
    }),
    generateScriptsTree(app),
    discoursePluginsTree,
    testStylesheetTree,
  ];

  const appTree = compatBuild(app, Webpack, {
    staticAppPaths: ["static"],
    packagerOptions: {
      webpackConfig: {
        devtool: "source-map",
        output: {
          publicPath: "auto",
        },
        externals: [
          function ({ request }, callback) {
            if (
              !request.includes("-embroider-implicit") &&
              // TODO: delete special case for jquery when removing app.import() above
              (request === "jquery" ||
                request.startsWith("admin/") ||
                request.startsWith("wizard/") ||
                request.startsWith("discourse/plugins/") ||
                request.startsWith("discourse/theme-"))
            ) {
              callback(null, request, "commonjs");
            } else {
              callback();
            }
          },
        ],
        module: {
          parser: {
            javascript: {
              exportsPresence: "error",
            },
          },
          rules: [
            {
              test: require.resolve("bootstrap/js/modal"),
              use: [
                {
                  loader: "imports-loader",
                  options: {
                    imports: {
                      moduleName: "jquery",
                      name: "jQuery",
                    },
                  },
                },
              ],
            },
          ],
        },
      },
    },
  });

  return mergeTrees([appTree, applyTerser(mergeTrees(extraPublicTrees))]);
};
