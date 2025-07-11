import BabelPresetEnv from "@babel/preset-env";
// import templateColocationPlugin from "@embroider/addon-dev/template-colocation-plugin";
import { rollup } from "@rollup/browser";
import { babel, getBabelOutputPlugin } from "@rollup/plugin-babel";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import colocatedBabelPlugin from "ember-cli-htmlbars/lib/colocated-babel-plugin";
import { precompile } from "ember-source/dist/ember-template-compiler";
import EmberThisFallback from "ember-this-fallback";
import MagicString from "magic-string";
import { memfs } from "memfs";
import { basename, dirname, join } from "path";
// import { minify as terserMinify } from "terser";
import { WidgetHbsCompiler } from "discourse-widget-hbs/lib/widget-hbs-compiler";
import { browsers } from "../discourse/config/targets";
import AddThemeGlobals from "./add-theme-globals";
import BabelCrossThemeImport from "./babel-cross-theme-import";
import BabelReplaceImports from "./babel-replace-imports";
import { Preprocessor } from "./content-tag";
import rollupVirtualImports from "./rollup-virtual-imports";

const thisFallbackPlugin = EmberThisFallback._buildPlugin({
  enableLogging: false,
  isTheme: true,
}).plugin;

const preprocessor = new Preprocessor();

import BindingsWasm from "./node_modules/@rollup/browser/dist/bindings_wasm_bg.wasm";
import buildEmberTemplateManipulatorPlugin from "./theme-hbs-ast-transforms";

const oldInstantiate = WebAssembly.instantiate;
WebAssembly.instantiate = async function (bytes, bindings) {
  if (bytes === BindingsWasm) {
    const mod = new WebAssembly.Module(bytes);
    const instance = new WebAssembly.Instance(mod, bindings);
    return instance;
  } else {
    return oldInstantiate(...arguments);
  }
};

globalThis.fetch = function (url) {
  if (url.toString() === "http://example.com/bindings_wasm_bg.wasm") {
    return new Promise((resolve) => resolve(BindingsWasm));
  }
  throw "fetch not implemented";
};

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
      console.log(level, message);
    },
    plugins: [
      {
        name: "discourse-extensionsearch",
        async resolveId(source, context) {
          if (source.match(/\.\w+$/)) {
            // Already has an extension
            return null;
          }

          for (const ext of ["", ".js", ".gjs", ".hbs"]) {
            const resolved = await this.resolve(`${source}${ext}`, context);

            if (resolved) {
              return resolved;
            }
          }

          return null;
        },
      },
      {
        name: "discourse-virtual-loader",
        resolveId(source) {
          if (rollupVirtualImports[source]) {
            return `${themeBase}${source}`;
          }
        },
        load(id) {
          if (!id.startsWith(themeBase)) {
            return;
          }

          const fromBase = id.slice(themeBase.length);

          if (rollupVirtualImports[fromBase]) {
            return rollupVirtualImports[fromBase](modules, opts);
          }
        },
      },
      {
        name: "discourse-external-loader",
        async resolveId(source) {
          if (!source.startsWith(".")) {
            return { id: source, external: true };
          }
        },
      },
      {
        name: "discourse-colocation",
        async resolveId(source, context) {
          if (source.startsWith(".")) {
            source = join(dirname(context), source);
          }

          if (
            !(
              source.startsWith(`${themeBase}discourse/components/`) ||
              source.startsWith(`${themeBase}admin/components/`)
            )
          ) {
            return;
          }

          if (source.endsWith(".js")) {
            const hbs = await this.resolve(
              `./${basename(source).replace(/.js$/, ".hbs")}`,
              source
            );
            const js = await this.resolve(source, context);

            if (!js && hbs) {
              return {
                id: source,
                meta: {
                  "rollup-hbs-plugin": {
                    type: "template-only-component-js",
                  },
                },
              };
            }
          }
        },

        load(id) {
          if (
            this.getModuleInfo(id)?.meta?.["rollup-hbs-plugin"]?.type ===
            "template-only-component-js"
          ) {
            return {
              code: `import templateOnly from '@ember/component/template-only';\nexport default templateOnly();\n`,
            };
          }
        },

        transform: {
          async handler(input, id) {
            if (
              !id.startsWith(`${themeBase}discourse/components/`) &&
              !id.startsWith(`${themeBase}admin/components/`)
            ) {
              return;
            }

            if (id.endsWith(".js")) {
              const hbs = await this.resolve(
                `./${basename(id).replace(/.js$/, ".hbs")}`,
                id
              );

              if (hbs) {
                const s = new MagicString(input);
                s.prepend(
                  `import template from '${hbs.id}';\nconst __COLOCATED_TEMPLATE__ = template;\n`
                );

                return {
                  code: s.toString(),
                  map: s.generateMap({ hires: true }),
                };
              }
            }
          },
        },
      },

      getBabelOutputPlugin({
        plugins: [BabelReplaceImports, BabelCrossThemeImport],
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
                thisFallbackPlugin,
                buildEmberTemplateManipulatorPlugin(opts.themeId),
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
      {
        name: "discourse-hbs",
        transform: {
          order: "pre",
          handler(input, id) {
            if (id.endsWith(".hbs")) {
              return {
                code: `
                import { hbs } from 'ember-cli-htmlbars';
                export default hbs(${JSON.stringify(input)}, { moduleName: ${JSON.stringify(id)} });
              `,
                map: null,
              };
            }
          },
        },
      },
      {
        name: "discourse-gjs-transform",

        transform: {
          // Enforce running the gjs transform before any others like babel that expect valid JS
          order: "pre",
          handler(input, id) {
            if (!id.endsWith(".gjs")) {
              return null;
            }
            let { code, map } = preprocessor.process(input, {
              filename: id,
            });
            return {
              code,
              map,
            };
          },
        },
      },
      // {
      //   name: "discourse-terser",
      //   async renderChunk(code, chunk, outputOptions) {
      //     const defaultOptions = {
      //       sourceMap:
      //         outputOptions.sourcemap === true ||
      //         typeof outputOptions.sourcemap === "string",
      //     };

      //     defaultOptions.module = true;

      //     return await terserMinify(code, defaultOptions);
      //   },
      // },
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
      // eslint-disable-next-line no-console
      console.error(error);
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
