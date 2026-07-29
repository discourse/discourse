const { buildMacros } = require("@embroider/macros/babel");
const {
  setConfig: setWarpDriveConfig,
} = require("@warp-drive/core/build-config");
const StripTestSelectors = require("strip-test-selectors");

const macros = buildMacros({
  configure(macrosConfig) {
    macrosConfig.setGlobalConfig(__filename, "@embroider/core", {
      active: true,
    });
    // WarpDrive build config (previously wired via setConfig in ember-cli-build.js).
    // Feeds into our existing @embroider/macros config rather than a second
    // instance, which would duplicate the macros babel plugin.
    setWarpDriveConfig(macrosConfig, { compatWith: "5.9" });
  },
});

const PRODUCTION = process.env.EMBER_ENV === "production";

module.exports = {
  plugins: [
    [
      "babel-plugin-ember-template-compilation",
      {
        compilerPath: "ember-source/ember-template-compiler/index.js",
        enableLegacyModules: [
          "ember-cli-htmlbars",
          "ember-cli-htmlbars-inline-precompile",
          "htmlbars-inline-precompile",
        ],
        transforms: [
          ...macros.templateMacros,
          ...(PRODUCTION ? [StripTestSelectors] : []),
        ],
      },
    ],
    [
      "module:decorator-transforms",
      {
        runtime: {
          import: require.resolve("decorator-transforms/runtime-esm"),
        },
      },
    ],
    [
      "@babel/plugin-transform-runtime",
      {
        absoluteRuntime: __dirname,
        useESModules: true,
        regenerator: false,
      },
    ],
    [
      require.resolve("babel-plugin-debug-macros"),
      {
        flags: [
          {
            source: "@glimmer/env",
            flags: {
              DEBUG: !PRODUCTION,
              CI: !!process.env.CI,
            },
          },
        ],
        debugTools: {
          isDebug: !PRODUCTION,
          source: "@ember/debug",
          assertPredicateIndex: 1,
        },
        externalizeHelpers: {
          module: "@ember/debug",
        },
      },
      "@ember/debug stripping",
    ],
    ...macros.babelMacros,
  ],

  overrides: [
    {
      test: /\.(gts|ts|mts|cts)$/,
      plugins: [
        [
          require.resolve("@babel/plugin-transform-typescript"),
          { allowDeclareFields: true },
        ],
      ],
    },
  ],

  generatorOpts: {
    compact: false,
  },
};
