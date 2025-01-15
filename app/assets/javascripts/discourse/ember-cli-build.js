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
const { compatBuild } = require("@embroider/compat");
const { Webpack } = require("@embroider/webpack");
const { StatsWriterPlugin } = require("webpack-stats-plugin");
const { RetryChunkLoadPlugin } = require("webpack-retry-chunk-load-plugin");
const withSideWatch = require("./lib/with-side-watch");
const RawHandlebarsCompiler = require("discourse-hbr/raw-handlebars-compiler");
const crypto = require("crypto");
const commonBabelConfig = require("./lib/common-babel-config");
const TerserPlugin = require("terser-webpack-plugin");

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

    ...commonBabelConfig(),

    vendorFiles: {
      // Freedom patch - includes bug fix and async stack support
      // https://github.com/discourse/backburner.js/commits/discourse-patches
      backburner:
        "node_modules/@discourse/backburner.js/dist/named-amd/backburner.js",
    },

    trees: {
      app: RawHandlebarsCompiler(
        withSideWatch("app", {
          watching: ["../discourse-markdown-it", "../truth-helpers"],
        })
      ),
    },
  });

  // WARNING: We should only import scripts here if they are not in NPM.
  app.import(discourseRoot + "/app/assets/javascripts/polyfills.js");

  app.import(
    discourseRoot +
      "/app/assets/javascripts/discourse/public/assets/scripts/module-shims.js"
  );

  const discoursePluginsTree = app.project
    .findAddonByName("discourse-plugins")
    .generatePluginsTree(app.tests);

  const adminTree = app.project.findAddonByName("admin").treeForAddonBundle();

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
    applyTerser(
      concat(adminTree, {
        inputFiles: ["**/*.js"],
        outputFile: `assets/admin.js`,
      })
    ),
    applyTerser(generateScriptsTree(app)),
    applyTerser(discoursePluginsTree),
    testStylesheetTree,
  ];

  const assetCachebuster = process.env["DISCOURSE_ASSET_URL_SALT"] || "";
  const cachebusterHash = crypto
    .createHash("md5")
    .update(assetCachebuster)
    .digest("hex")
    .slice(0, 8);

  const appTree = compatBuild(app, Webpack, {
    staticEmberSource: true,
    splitAtRoutes: ["wizard"],
    staticAppPaths: ["static"],
    packagerOptions: {
      webpackConfig: {
        devtool:
          process.env.CHEAP_SOURCE_MAPS === "1"
            ? "cheap-source-map"
            : "source-map",
        output: {
          publicPath: "auto",
          filename: `assets/chunk.[chunkhash].${cachebusterHash}.js`,
          chunkFilename: `assets/chunk.[chunkhash].${cachebusterHash}.js`,
        },
        optimization: {
          minimize: isProduction,
          minimizer: [
            new TerserPlugin({
              minify: TerserPlugin.swcMinify,
              terserOptions: {
                compress: {
                  // Stop swc unwrapping 'unnecessary' IIFE wrappers which are added by Babel
                  // to workaround a bug in Safari 15 class fields.
                  inline: false,
                  reduce_funcs: false,
                },
              },
            }),
          ],
        },
        cache: isProduction
          ? false
          : {
              type: "memory",
              maxGenerations: 1,
            },
        entry: {
          "assets/discourse.js/features/markdown-it.js": {
            import: "./static/markdown-it",
            dependOn: "assets/discourse.js",
            runtime: false,
          },
        },
        externals: [
          function ({ context, request }, callback) {
            if (
              context.includes("discourse-markdown-it/src") &&
              request.startsWith("discourse/")
            ) {
              // v1 ember apps can't be imported from addons. Workaround via commonjs.
              // Won't be necessary once we move to a v2 app.
              callback(null, request, "commonjs");
            } else if (
              !request.includes("-embroider-implicit") &&
              (request.startsWith("admin/") ||
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
        plugins: [
          // The server use this output to map each asset to its chunks
          new StatsWriterPlugin({
            filename: "assets.json",
            stats: {
              all: false,
              entrypoints: true,
            },
            transform({ entrypoints }) {
              let names = Object.keys(entrypoints);
              let output = {};

              for (let name of names.sort()) {
                let assets = entrypoints[name].assets.map(
                  (asset) => asset.name
                );

                let parent = names.find((parentName) =>
                  name.startsWith(parentName + "/")
                );

                if (parent) {
                  name = name.slice(parent.length + 1);
                  output[parent][name] = { assets };
                } else {
                  output[name] = { assets };
                }
              }

              return JSON.stringify(output, null, 2);
            },
          }),
          new RetryChunkLoadPlugin({
            retryDelay: 200,
            maxRetries: 2,
            chunks: ["assets/discourse.js"],
          }),
        ],
      },
    },
    skipBabel: [
      {
        package: "qunit",
      },
      {
        package: "sinon",
      },
      {
        package: "@json-editor/json-editor",
      },
      {
        package: "ace-builds",
      },
    ],
  });

  return mergeTrees([appTree, mergeTrees(extraPublicTrees)]);
};
