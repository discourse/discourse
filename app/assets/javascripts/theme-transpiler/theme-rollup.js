import BabelPresetEnv from "@babel/preset-env";
import { rollup } from "@rollup/browser";
import { babel, getBabelOutputPlugin } from "@rollup/plugin-babel";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import colocatedBabelPlugin from "ember-cli-htmlbars/lib/colocated-babel-plugin";
import EmberThisFallback from "ember-this-fallback";
import { memfs } from "memfs";
import transformActionSyntax from "discourse-plugins/transform-action-syntax";
import { WidgetHbsCompiler } from "discourse-widget-hbs/lib/widget-hbs-compiler";
import { browsers } from "../discourse/config/targets";
import AddThemeGlobals from "./add-theme-globals";
import BabelReplaceImports from "./babel-replace-imports";
import { precompile } from "./node_modules/ember-source/dist/ember-template-compiler";
import discourseColocation from "./rollup-plugins/discourse-colocation";
import discourseExtensionSearch from "./rollup-plugins/discourse-extension-search";
import discourseExternalLoader from "./rollup-plugins/discourse-external-loader";
import discourseGjs from "./rollup-plugins/discourse-gjs";
import discourseHbs from "./rollup-plugins/discourse-hbs";
import discourseIndexSearch from "./rollup-plugins/discourse-index-search";
import discourseTerser from "./rollup-plugins/discourse-terser";
import discourseVirtualLoader from "./rollup-plugins/discourse-virtual-loader";
import buildEmberTemplateManipulatorPlugin from "./theme-hbs-ast-transforms";

let lastRollupResult;
let lastRollupError;
globalThis.rollup = function (modules, opts) {
  const themeBase = `theme-${opts.themeId}/`;

  const { vol } = memfs(modules, themeBase);

  const resultPromise = rollup({
    input: "virtual:main",
    logLevel: "info",
    fs: vol.promises,
    onLog(level, message) {
      // eslint-disable-next-line no-console
      console.info(level, message);
    },
    plugins: [
      discourseExtensionSearch(),
      discourseIndexSearch(),
      discourseVirtualLoader({
        themeBase,
        modules,
        opts,
      }),
      discourseExternalLoader(),
      discourseColocation({ themeBase }),
      getBabelOutputPlugin({
        plugins: [BabelReplaceImports],
      }),
      babel({
        extensions: [".js", ".gjs", ".hbs"],
        babelHelpers: "bundled",
        plugins: [
          [DecoratorTransforms, { runEarly: true }],
          AddThemeGlobals,
          colocatedBabelPlugin,
          WidgetHbsCompiler,
          [
            HTMLBarsInlinePrecompile,
            {
              compiler: { precompile },
              enableLegacyModules: [
                "ember-cli-htmlbars",
                "ember-cli-htmlbars-inline-precompile",
                "htmlbars-inline-precompile",
              ],
              transforms: [
                EmberThisFallback._buildPlugin({
                  enableLogging: false,
                  isTheme: true,
                }).plugin,
                buildEmberTemplateManipulatorPlugin(opts.themeId),
                transformActionSyntax,
              ],
            },
          ],
        ],
        presets: [
          [
            BabelPresetEnv,
            {
              modules: false,
              targets: { browsers },
            },
          ],
        ],
      }),
      discourseHbs(),
      discourseGjs(),
      discourseTerser({ opts }),
    ],
  });

  resultPromise
    .then((bundle) => {
      return bundle.generate({
        format: "es",
        sourcemap: "hidden",
      });
    })
    .then(({ output }) => {
      lastRollupResult = {
        code: output[0].code,
        map: JSON.stringify(output[0].map),
      };
    })
    .catch((error) => {
      lastRollupError = error;
    });
};

globalThis.getRollupResult = function () {
  const error = lastRollupError;
  const result = lastRollupResult;

  lastRollupError = lastRollupResult = null;

  if (error) {
    throw error;
  }
  return result;
};
