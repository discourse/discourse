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
import { dirname, join } from "path";
import { minify as terserMinify } from "terser";
import { browsers } from "../discourse/config/targets";
import AddThemeGlobals from "./add-theme-globals";
import BabelReplaceImports from "./babel-replace-imports";
import { Preprocessor } from "./content-tag";
import rollupVirtualImports from "./rollup-virtual-imports";

const thisFallbackPlugin = EmberThisFallback._buildPlugin({
  enableLogging: false,
  isTheme: true,
}).plugin;

const preprocessor = new Preprocessor();

import BindingsWasm from "./node_modules/@rollup/browser/dist/bindings_wasm_bg.wasm";

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
  const resultPromise = rollup({
    input: "virtual:main",
    logLevel: "info",
    onLog(level, message) {
      console.log(level, message);
    },
    plugins: [
      {
        name: "discourse-extensionsearch",
        async resolveId(source, context) {
          console.log(`Running extensionsearch ${source}`);

          if (source.match(/\.(js|gjs|hbs)$/)) {
            return null;
          }

          for (const ext of ["", ".js", ".gjs", ".hbs"]) {
            console.log(ext);
            let resolved;
            try {
              resolved = await this.resolve(
                `${source}${ext}`,
                context /*, {
                skipSelf: true,
              }*/
              );
            } catch (error) {
              if (!error.message.includes("Cannot access the file system")) {
                throw error;
              }
              console.log("caught");
            }
            console.log(`finished resolve, ${source}${ext}, `);
            console.log(JSON.stringify(resolved));
            if (resolved) {
              return resolved;
            }
          }

          return false;
        },
      },
      {
        name: "discourse-loader",
        resolveId(source, context) {
          if (rollupVirtualImports[source]) {
            return source;
          }

          console.log(source);
          console.log(Object.keys(modules));

          if (source.startsWith(".")) {
            if (!context) {
              throw new Error(
                `Unable to resolve relative import '${source}' without a context`
              );
            }
            source = join(dirname(context), source);
          }

          if (modules.hasOwnProperty(source)) {
            return source;
          }

          // for (const ext of ["", ".js", ".gjs", ".hbs"]) {
          //   const candidate = source + ext;
          //   if (modules.hasOwnProperty(candidate)) {
          //     return candidate;
          //   }
          // }
          // return false;
        },
        load(id) {
          if (rollupVirtualImports[id]) {
            return rollupVirtualImports[id](modules, opts);
          }
          if (modules.hasOwnProperty(id)) {
            return modules[id];
          }
        },
      },

      {
        name: "discourse-colocation",
        async resolveId(source, context) {
          if (source.endsWith(".js")) {
            let hbs;
            try {
              hbs = await this.resolve(source.replace(/.js$/, ".hbs"), context);
            } catch (error) {
              if (!error.message.includes("Cannot access the file system")) {
                throw error;
              }
            }

            let js;
            try {
              js = await this.resolve(source, context);
            } catch (error) {
              if (!error.message.includes("Cannot access the file system")) {
                throw error;
              }
            }

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
          // order: "pre",
          async handler(input, id) {
            if (id.endsWith(".js")) {
              let hbs;
              try {
                hbs = await this.resolve(id.replace(/.js$/, ".hbs"), id);
              } catch (error) {
                if (!error.message.includes("Cannot access the file system")) {
                  throw error;
                }
              }

              if (hbs) {
                const s = new MagicString(input);
                s.prepend(
                  `import template from '${hbs.id}';
const __COLOCATED_TEMPLATE__ = template;
`
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
        plugins: [BabelReplaceImports],
      }),
      babel({
        extensions: [".js", ".gjs", ".hbs"],
        babelHelpers: "bundled",
        plugins: [
          [DecoratorTransforms, { runEarly: true }],
          AddThemeGlobals,
          // "@embroider/addon-dev/template-colocation-plugin",
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
              transforms: [thisFallbackPlugin],
            },
          ],
          // TODO: widgetHbs (remove from d-calendar)
          // TODO: themem ast transforms
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
                map: { mappings: "" },
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
        sourcemapPathTransform: (relativeSourcePath) =>
          `theme-${opts.themeId}/${relativeSourcePath}`,
      });
    })
    .then(({ output }) => {
      lastRollupResult = {
        code: output[0].code,
        map: JSON.stringify(output[0].map),
      };
    })
    .catch((error) => {
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
