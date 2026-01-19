"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const path = require("path");
const mergeTrees = require("broccoli-merge-trees");
const generateScriptsTree = require("./lib/scripts");
const funnel = require("broccoli-funnel");
const DeprecationSilencer = require("deprecation-silencer");
const { compatBuild } = require("@embroider/compat");
const { Webpack } = require("@embroider/webpack");
const { StatsWriterPlugin } = require("webpack-stats-plugin");
const { RetryChunkLoadPlugin } = require("webpack-retry-chunk-load-plugin");
const withSideWatch = require("./lib/with-side-watch");
const crypto = require("crypto");
const commonBabelConfig = require("./lib/common-babel-config");
const TerserPlugin = require("terser-webpack-plugin");
const {
  CustomizeChunkUrlPlugin,
} = require("./lib/webpack-customize-chunk-url-plugin");
const { BroccoliMergeFiles } = require("broccoli-merge-files");

process.env.BROCCOLI_ENABLED_MEMOIZE = true;

function compatModulesFor(name) {
  return funnel(
    new BroccoliMergeFiles([name], {
      outputFileName: `${name}-compat-modules.js`,
      async merge(files) {
        const lines = [`const compatModules = {};`];

        let i = 1;
        for (const [filename] of files) {
          const withoutExtension = filename.replace(/\..*$/, "");
          lines.push(
            `import * as Module${i} from "./${withoutExtension}";`,
            `compatModules["./${withoutExtension}"] = Module${i};`
          );
          i++;
        }

        lines.push("export default compatModules;");

        return lines.join("\n");
      },
    }),
    { destDir: name }
  );
}

module.exports = function (defaults) {
  const discourseRoot = path.resolve("../..");

  // Silence deprecations which we are aware of - see `lib/deprecation-silencer.js`
  DeprecationSilencer.silence(console, "warn");
  DeprecationSilencer.silence(console, "log");
  DeprecationSilencer.silence(defaults.project.ui, "writeWarnLine");

  const isProduction = EmberApp.env().includes("production");

  const app = new EmberApp(defaults, {
    autoRun: false,
    "ember-qunit": {
      insertContentForTestBody: false,
    },
    "ember-template-imports": {
      inline_source_map: true,
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

    trees: {
      app: withSideWatch(
        mergeTrees([
          "app",
          funnel("admin", { destDir: "admin" }),
          compatModulesFor("admin"),
          funnel("select-kit", { destDir: "select-kit" }),
          compatModulesFor("select-kit"),
          funnel("float-kit", { destDir: "float-kit" }),
          compatModulesFor("float-kit"),
          funnel("truth-helpers", { destDir: "truth-helpers" }),
          compatModulesFor("truth-helpers"),
          funnel("dialog-holder", { destDir: "dialog-holder" }),
          compatModulesFor("dialog-holder"),
        ]),
        {
          watching: ["../discourse-markdown-it"],
        }
      ),
    },
  });

  // WARNING: We should only import scripts here if they are not in NPM.
  app.import(discourseRoot + "/frontend/polyfills.js");

  app.import(
    discourseRoot + "/frontend/discourse/public/assets/scripts/module-shims.js"
  );

  const discoursePluginsTree = app.project
    .findAddonByName("discourse-plugins")
    .generatePluginsTree(app.tests);

  app.project.liveReloadFilterPatterns = [/.*\.scss/];

  const terserPlugin = app.project.findAddonByName("ember-cli-terser");
  const applyTerser = (tree) => terserPlugin.postprocessTree("all", tree);

  const pluginTrees = applyTerser(discoursePluginsTree);

  if (process.env.SKIP_CORE_BUILD) {
    return pluginTrees;
  }

  let extraPublicTrees = [
    funnel(`${discourseRoot}/public/javascripts`, { destDir: "javascripts" }),
    applyTerser(generateScriptsTree(app)),
    pluginTrees,
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
    staticAppPaths: [
      "static",
      "admin",
      "select-kit",
      "float-kit",
      "truth-helpers",
      "dialog-holder",
    ],
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
          assetModuleFilename: `assets/chunk.[hash].${cachebusterHash}[ext][query]`,
        },
        optimization: {
          minimize: isProduction,
          minimizer: [
            new TerserPlugin({
              minify: TerserPlugin.swcMinify,
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
          "assets/media-optimization-bundle.js": {
            import: "./static/media-optimization-bundle",
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
              (request.startsWith("discourse/plugins/") ||
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
              chunks: true,
            },
            transform({ chunks, entrypoints }) {
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

              for (const chunk of chunks) {
                if (chunk.entry) {
                  continue;
                }
                for (const name of chunk.names) {
                  const outputName = `assets/chunk.${name}.js`;
                  output[outputName] ??= { assets: [] };
                  output[outputName].assets.push(...chunk.files);
                }
              }

              return JSON.stringify(output, null, 2);
            },
          }),
          new CustomizeChunkUrlPlugin(),
          new RetryChunkLoadPlugin({
            retryDelay: 200,
            maxRetries: 2,
          }),
        ],
        experiments: {
          asyncWebAssembly: true,
        },
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
