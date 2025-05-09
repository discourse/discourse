import { rollup } from "@rollup/browser";
import { babel } from "@rollup/plugin-babel";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import { precompile } from "ember-source/dist/ember-template-compiler";
import { dirname, relative } from "path";
import BabelReplaceImports from "./babel-replace-imports";
import { Preprocessor } from "./content-tag";

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
globalThis.rollup = function (modules, options) {
  const resultPromise = rollup({
    input: "main.js",
    logLevel: "info",
    onLog(level, message) {
      console.log(level, message);
    },
    plugins: [
      {
        name: "loader",
        resolve: {
          extensions: [".js", ".gjs"],
        },
        resolveId(source, context) {
          if (source.startsWith(".")) {
            source = relative(dirname(context), source);
          }
          console.log("resolveid", source, context);
          if (modules.hasOwnProperty(source)) {
            return source;
          }
        },
        load(id) {
          if (modules.hasOwnProperty(id)) {
            return modules[id];
          }
        },
      },
      babel({
        extensions: [".js", ".gjs"],
        babelHelpers: "bundled",
        plugins: [
          DecoratorTransforms,
          BabelReplaceImports,
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
        ],
      }),
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
    ],
  });

  resultPromise
    .then((bundle) => {
      return bundle.generate({ format: "es" });
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
