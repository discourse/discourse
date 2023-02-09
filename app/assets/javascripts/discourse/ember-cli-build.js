"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const resolve = require("path").resolve;
const mergeTrees = require("broccoli-merge-trees");
const concat = require("broccoli-concat");
const prettyTextEngine = require("./lib/pretty-text-engine");
const { createI18nTree } = require("./lib/translation-plugin");
const { parsePluginClientSettings } = require("./lib/site-settings-plugin");
const discourseScss = require("./lib/discourse-scss");
const generateScriptsTree = require("./lib/scripts");
const funnel = require("broccoli-funnel");

const SILENCED_WARN_PREFIXES = [
  "Setting the `jquery-integration` optional feature flag",
  "The Ember Classic edition has been deprecated",
  "Setting the `template-only-glimmer-components` optional feature flag to `false`",
  "DEPRECATION: Invoking the `<LinkTo>` component with positional arguments is deprecated",
];

module.exports = function (defaults) {
  let discourseRoot = resolve("../../../..");
  let vendorJs = discourseRoot + "/vendor/assets/javascripts/";

  // Silence the warnings listed in SILENCED_WARN_PREFIXES
  const ui = defaults.project.ui;
  const oldWriteWarning = ui.writeWarnLine.bind(ui);
  ui.writeWarnLine = (message, ...args) => {
    if (!SILENCED_WARN_PREFIXES.some((prefix) => message.startsWith(prefix))) {
      return oldWriteWarning(message, ...args);
    }
  };

  // Silence warnings which go straight to console.warn (e.g. template compiler deprecations)
  /* eslint-disable no-console */
  const oldConsoleWarn = console.warn.bind(console);
  console.warn = (message, ...args) => {
    if (!SILENCED_WARN_PREFIXES.some((prefix) => message.startsWith(prefix))) {
      return oldConsoleWarn(message, ...args);
    }
  };
  /* eslint-enable no-console */

  const isProduction = EmberApp.env().includes("production");
  const isTest = EmberApp.env().includes("test");

  let app = new EmberApp(defaults, {
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
      alias: {
        "virtual-dom": "@discourse/virtual-dom",
      },
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

    "ember-cli-terser": {
      enabled: isProduction,
      exclude: [
        "**/test-*.js",
        "**/core-tests*.js",
        "**/highlightjs/*",
        "**/javascripts/*",
      ],
    },

    // We need to build tests in prod for theme tests
    tests: true,

    vendorFiles: {
      // Freedom patch - includes bug fix and async stack support
      // https://github.com/discourse/backburner.js/commits/discourse-patches
      backburner:
        "node_modules/@discourse/backburner.js/dist/named-amd/backburner.js",
    },
  });

  // Patching a private method is not great, but there's no other way for us to tell
  // Ember CLI that we want the tests alone in a package without helpers/fixtures, since
  // we re-use those in the theme tests.
  app._defaultPackager.packageApplicationTests = function (tree) {
    let appTestTrees = []
      .concat(
        this.packageEmberCliInternalFiles(),
        this.packageTestApplicationConfig(),
        tree
      )
      .filter(Boolean);

    appTestTrees = mergeTrees(appTestTrees, {
      overwrite: true,
      annotation: "TreeMerger (appTestTrees)",
    });

    let tests = concat(appTestTrees, {
      inputFiles: ["**/tests/**/*-test.js"],
      headerFiles: ["vendor/ember-cli/tests-prefix.js"],
      footerFiles: ["vendor/ember-cli/app-config.js"],
      outputFile: "/assets/core-tests.js",
      annotation: "Concat: Core Tests",
      sourceMapConfig: false,
    });

    let testHelpers = concat(appTestTrees, {
      inputFiles: [
        "**/tests/test-boot-ember-cli.js",
        "**/tests/helpers/**/*.js",
        "**/tests/fixtures/**/*.js",
        "**/tests/setup-tests.js",
      ],
      outputFile: "/assets/test-helpers.js",
      annotation: "Concat: Test Helpers",
      sourceMapConfig: false,
    });

    if (isTest) {
      return mergeTrees([
        tests,
        testHelpers,
        discourseScss(`${discourseRoot}/app/assets/stylesheets`, "qunit.scss"),
        discourseScss(
          `${discourseRoot}/app/assets/stylesheets`,
          "qunit-custom.scss"
        ),
      ]);
    } else {
      return mergeTrees([tests, testHelpers]);
    }
  };

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

  const terserPlugin = app.project.findAddonByName("ember-cli-terser");
  const applyTerser = (tree) => terserPlugin.postprocessTree("all", tree);

  return mergeTrees([
    createI18nTree(discourseRoot, vendorJs),
    parsePluginClientSettings(discourseRoot, vendorJs, app),
    app.toTree(),
    funnel(`${discourseRoot}/public/javascripts`, { destDir: "javascripts" }),
    funnel(`${vendorJs}/highlightjs`, {
      files: ["highlight-test-bundle.min.js"],
      destDir: "assets/highlightjs",
    }),
    applyTerser(
      concat(mergeTrees([app.options.adminTree]), {
        inputFiles: ["**/*.js"],
        outputFile: `assets/admin.js`,
      })
    ),
    applyTerser(
      concat(mergeTrees([app.options.wizardTree]), {
        inputFiles: ["**/*.js"],
        outputFile: `assets/wizard.js`,
      })
    ),
    applyTerser(prettyTextEngine(app)),
    generateScriptsTree(app),
    applyTerser(discoursePluginsTree),
  ]);
};
