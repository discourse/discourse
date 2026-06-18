const { buildMacros } = require("@embroider/macros/babel");
const StripTestSelectors = require("strip-test-selectors");

const macros = buildMacros({
  configure(macrosConfig) {
    macrosConfig.setGlobalConfig(__filename, "@embroider/core", {
      active: true,
    });
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

  generatorOpts: {
    compact: false,
  },
};
