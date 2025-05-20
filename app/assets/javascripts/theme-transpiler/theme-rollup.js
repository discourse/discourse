import BabelPresetEnv from "@babel/preset-env";
import { rollup } from "@rollup/browser";
import { babel, getBabelOutputPlugin } from "@rollup/plugin-babel";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import { precompile } from "ember-source/dist/ember-template-compiler";
import { dirname, join } from "path";
import { minify as terserMinify } from "terser";
import { browsers } from "../discourse/config/targets";
import AddThemeGlobals from "./add-theme-globals";
import BabelReplaceImports from "./babel-replace-imports";
import { Preprocessor } from "./content-tag";
import rollupVirtualImports from "./rollup-virtual-imports";

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
        name: "extensionsearch",
        async resolveId(source, context) {
          console.log(`Running extensionsearch ${source}`);
          for (const ext of ["", ".js", ".gjs", ".hbs"]) {
            console.log(ext);
            let resolved;
            try {
              resolved = await this.resolve(`${source}${ext}`, context, {
                skipSelf: true,
              });
            } catch {
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
        name: "loader",
        resolveId(source, context) {
          if (rollupVirtualImports[source]) {
            return source;
          }

          console.log(source);
          console.log(Object.keys(modules));

          if (source.startsWith(".")) {
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

      getBabelOutputPlugin({
        plugins: [BabelReplaceImports],
      }),
      babel({
        extensions: [".js", ".gjs", ".hbs"],
        babelHelpers: "bundled",
        plugins: [
          [DecoratorTransforms, { runEarly: true }],
          AddThemeGlobals,
          [
            HTMLBarsInlinePrecompile,
            {
              compiler: { precompile },
              enableLegacyModules: [
                "ember-cli-htmlbars",
                "ember-cli-htmlbars-inline-precompile",
                "htmlbars-inline-precompile",
              ],
            },
          ],
          // TODO: Ember this fallback
          // TODO: template colocation
          // TODO: widgetHbs (remove from d-calendar)
          // TODO: sourcemaps
          // TODO: connectors
          // TODO: should babel presetEnv be on output?
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
        name: "hbs",
        transform: {
          order: "pre",
          handler(input, id) {
            if (id.endsWith(".hbs")) {
              return `
              import { hbs } from 'ember-cli-htmlbars';
              export default hbs(${JSON.stringify(input)}, { moduleName: ${JSON.stringify(id)} });
            `;
            }
          },
        },
      },
      {
        name: "gjs-transform",

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
      {
        name: "terser",
        async renderChunk(code, chunk, outputOptions) {
          const defaultOptions = {
            sourceMap:
              outputOptions.sourcemap === true ||
              typeof outputOptions.sourcemap === "string",
          };

          defaultOptions.module = true;

          return await terserMinify(code, defaultOptions);
        },
      },
    ],
  });

  resultPromise
    .then((bundle) => {
      return bundle.generate({ format: "es", sourcemap: true });
    })
    .then(({ output }) => (lastRollupResult = output))
    .catch((error) => (lastRollupError = error));
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
