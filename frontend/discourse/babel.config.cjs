const {
  babelCompatSupport,
  templateCompatSupport,
} = require("@embroider/compat/babel");
const { templateColocationPluginPath } = require("@embroider/core");
let path = require("path");
const {
  WidgetHbsCompiler,
} = require("discourse-widget-hbs/lib/widget-hbs-compiler");

// Enable template colocation in our other root namespaces (e.g. select-kit, etc.)
const unrestrictedTemplateColocationPlugin = [
  templateColocationPluginPath,
  {
    appRoot: path.join(process.cwd(), ".."),
    templateExtensions: [".hbs", ".hbs.js"],
    packageGuard: false,
  },
  "unrestricted-template-colocation",
];

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
        transforms: [...templateCompatSupport()],
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
    ...babelCompatSupport(),
    unrestrictedTemplateColocationPlugin,
    WidgetHbsCompiler,
  ],

  generatorOpts: {
    compact: false,
  },
};
