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

process.env.BROCCOLI_ENABLED_MEMOIZE = true;

module.exports = function (defaults) {
  const discourseRoot = path.resolve("../../../..");
  const vendorJs = discourseRoot + "/vendor/assets/javascripts/";

  // Silence deprecations which we are aware of - see `lib/deprecation-silencer.js`
  DeprecationSilencer.silence(console, "warn");
  DeprecationSilencer.silence(defaults.project.ui, "writeWarnLine");

  const isEmbroider = process.env.USE_EMBROIDER === "1";
  const isProduction = EmberApp.env().includes("production");

  // This is more or less the same as the one in @embroider/test-setup
  const maybeEmbroider = (app, options) => {
    if (isEmbroider) {
      const { compatBuild } = require("@embroider/compat");
      const { Webpack } = require("@embroider/webpack");

      // https://github.com/embroider-build/embroider/issues/1581
      if (Array.isArray(options?.extraPublicTrees)) {
        options.extraPublicTrees = [
          app.addonPostprocessTree("all", mergeTrees(options.extraPublicTrees)),
        ];
      }

      return compatBuild(app, Webpack, options);
    } else {
      return app.toTree(options?.extraPublicTrees);
    }
  };

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
    autoImport: {
      forbidEval: true,
      insertScriptsAt: "ember-auto-import-scripts",
      webpack: {
        // Workarounds for https://github.com/ef4/ember-auto-import/issues/519 and https://github.com/ef4/ember-auto-import/issues/478
        devtool: isProduction ? false : "source-map", // Sourcemaps contain reference to the ephemeral broccoli cache dir, which changes on every deploy
        optimization: {
          moduleIds: "size", // Consistent module references https://github.com/ef4/ember-auto-import/issues/478#issuecomment-1000526638
        },
        resolve: {
          fallback: {
            // Sinon needs a `util` polyfill
            util: require.resolve("util/"),
            // Also for sinon
            timers: false,
            // For source-map-support
            path: require.resolve("path-browserify"),
            fs: false,
          },
        },
        module: {
          rules: [
            // Sinon/`util` polyfill accesses the `process` global,
            // so we need to provide a mock
            {
              test: require.resolve("util/"),
              use: [
                {
                  loader: "imports-loader",
                  options: {
                    additionalCode: "var process = { env: {} };",
                  },
                },
              ],
            },
          ],
        },
      },
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
      exclude:
        ["**/highlightjs/*", "**/javascripts/*"] +
        (isEmbroider ? [] : ["**/test-*.js", "**/core-tests*.js"]),
    },

    "ember-cli-babel": {
      throwUnlessParallelizable: true,
    },

    babel: {
      plugins: [require.resolve("deprecation-silencer")],
    },

    // Was previously true so that we could run theme tests in production
    // but we're moving away from that as part of the Embroider migration
    tests: isEmbroider ? !isProduction : true,

    vendorFiles: {
      // Freedom patch - includes bug fix and async stack support
      // https://github.com/discourse/backburner.js/commits/discourse-patches
      backburner:
        "node_modules/@discourse/backburner.js/dist/named-amd/backburner.js",
    },
  });

  // WARNING: We should only import scripts here if they are not in NPM.
  // For example: our very specific version of bootstrap-modal.
  app.import(vendorJs + "bootbox.js");
  app.import("node_modules/bootstrap/js/modal.js");
  app.import(vendorJs + "caret_position.js");
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
    .generatePluginsTree();

  const adminTree = app.project.findAddonByName("admin").treeForAddonBundle();

  const wizardTree = app.project.findAddonByName("wizard").treeForAddonBundle();

  const markdownItBundleTree = app.project
    .findAddonByName("pretty-text")
    .treeForMarkdownItBundle();

  const testStylesheetTree = mergeTrees([
    discourseScss(`${discourseRoot}/app/assets/stylesheets`, "qunit.scss"),
    discourseScss(
      `${discourseRoot}/app/assets/stylesheets`,
      "qunit-custom.scss"
    ),
  ]);
  app.project.liveReloadFilterPatterns = [/.*\.scss/];

  const extraPublicTrees = [
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
    concat(markdownItBundleTree, {
      inputFiles: ["**/*.js"],
      outputFile: `assets/markdown-it-bundle.js`,
    }),
    generateScriptsTree(app),
    discoursePluginsTree,
    testStylesheetTree,
  ];

  return maybeEmbroider(app, {
    extraPublicTrees,
    packagerOptions: {
      webpackConfig: {
        devtool: "source-map",
        externals: [
          function ({ request }, callback) {
            if (
              !request.includes("-embroider-implicit") &&
              (request.startsWith("admin/") ||
                request.startsWith("wizard/") ||
                (request.startsWith("pretty-text/engines/") &&
                  request !== "pretty-text/engines/discourse-markdown-it") ||
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
        },
        resolve: {
          fallback: {
            // For source-map-support
            path: require.resolve("path-browserify"),
            fs: false,
          },
        },
      },
    },
  });
};
