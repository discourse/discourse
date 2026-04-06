import BabelPresetEnv from "@babel/preset-env";
import { rollup } from "@rollup/browser";
import { babel, getBabelOutputPlugin } from "@rollup/plugin-babel";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import colocatedBabelPlugin from "ember-cli-htmlbars/lib/colocated-babel-plugin";
import { precompile } from "ember-source/ember-template-compiler/index.js";
import EmberThisFallback from "ember-this-fallback";
import { memfs } from "memfs";
import transformActionSyntax from "discourse-plugins/transform-action-syntax";
import { browsers } from "../discourse/config/targets";
import babelTransformModuleRenames from "../discourse/lib/babel-transform-module-renames";
import AddThemeGlobals from "./add-theme-globals";
import BabelReplaceImports from "./babel-replace-imports";
import discourseColocation from "./rollup-plugins/discourse-colocation";
import discourseExternalLoader from "./rollup-plugins/discourse-external-loader";
import discourseFileSearch from "./rollup-plugins/discourse-file-search";
import discourseGjs from "./rollup-plugins/discourse-gjs";
import discourseHbs from "./rollup-plugins/discourse-hbs";
import discourseTerser from "./rollup-plugins/discourse-terser";
import discourseVirtualLoader from "./rollup-plugins/discourse-virtual-loader";
import buildEmberTemplateManipulatorPlugin from "./theme-hbs-ast-transforms";

let lastRollupResult;
let lastRollupError;

let caches = new Map();

async function performRollup(modules, opts) {
  let basePath = opts.pluginName
    ? `discourse/plugins/${opts.pluginName}/`
    : `theme-${opts.themeId}/`;

  const inputConfig = {};

  for (const key of Object.keys(opts.entrypoints)) {
    inputConfig[key] = `virtual:entrypoint:${key}`;
  }

  const { vol } = memfs(modules, basePath);

  const cache = opts.pluginName ? caches.get(opts.pluginName) : false;

  const result = await rollup({
    input: inputConfig,
    logLevel: "info",
    fs: vol.promises,
    cache,
    onLog(level, message) {
      if (String(message).startsWith("Circular dependency")) {
        return;
      }
      // eslint-disable-next-line no-console
      console.info(level, message);
    },
    plugins: [
      discourseFileSearch(),
      discourseVirtualLoader({
        isTheme: !!opts.themeId,
        basePath,
        entrypoints: opts.entrypoints,
        opts,
      }),
      discourseExternalLoader({ basePath }),
      discourseColocation({ basePath }),
      getBabelOutputPlugin({
        plugins: [BabelReplaceImports],
        compact: false,
      }),
      babel({
        extensions: [".js", ".gjs", ".hbs"],
        babelHelpers: "bundled",
        compact: false,
        plugins: [
          [DecoratorTransforms, { runEarly: true }],
          opts.themeId ? AddThemeGlobals : null,
          babelTransformModuleRenames,
          colocatedBabelPlugin,
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
        ].filter(Boolean),
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

  const bundle = await result.generate({
    format: "es",
    sourcemap: "hidden",
    entryFileNames: `${opts.filenamePrefix ?? ""}[name]${opts.filenameSuffix ?? ""}.js`,
    chunkFileNames: `${opts.filenamePrefix ?? ""}chunk.[hash:6]${opts.filenameSuffix ?? ""}.js`,
  });

  if (opts.pluginName) {
    caches.set(opts.pluginName, result.cache);
  }

  const chunks = Object.fromEntries(
    bundle.output
      .filter((c) => c.code)
      .map((chunk) => {
        return [
          chunk.fileName,
          {
            code: chunk.code,
            map: JSON.stringify(chunk.map),
            name: chunk.name,
            isEntry: chunk.isEntry,
            imports: chunk.imports.filter((i) =>
              bundle.output.find((c) => c.fileName === i)
            ),
          },
        ];
      })
  );

  return chunks;
}

globalThis.rollup = async function (modules, opts) {
  try {
    lastRollupResult = await performRollup(modules, opts);
  } catch (error) {
    lastRollupError = error;
  }
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
