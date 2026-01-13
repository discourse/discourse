const { buildMacros } = require("@embroider/macros/babel");

const macros = buildMacros({
  configure(macrosConfig) {
    macrosConfig.setGlobalConfig(__filename, "@embroider/core", {
      active: true,
    });
  },
});

module.exports = {
  plugins: [
    [
      "babel-plugin-ember-template-compilation",
      {
        compilerPath: "ember-source/dist/ember-template-compiler.js",
        enableLegacyModules: [
          "ember-cli-htmlbars",
          "ember-cli-htmlbars-inline-precompile",
          "htmlbars-inline-precompile",
        ],
        transforms: [...macros.templateMacros],
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
    ...macros.babelMacros,
  ],

  generatorOpts: {
    compact: false,
  },
};
