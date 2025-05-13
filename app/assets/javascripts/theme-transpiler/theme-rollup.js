import BabelPresetEnv from "@babel/preset-env";
import { rollup } from "@rollup/browser";
import { babel } from "@rollup/plugin-babel";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import { precompile } from "ember-source/dist/ember-template-compiler";
import { dirname, join } from "path";
import { minify as terserMinify } from "terser";
import { browsers } from "../discourse/config/targets";
import AddThemeGlobals from "./add-theme-globals";
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

function generateMain(tree) {
  const initializers = Object.keys(tree).filter((key) =>
    key.includes("/initializers/")
  );

  let output = "export const initializers = {};\n";

  let i = 1;
  for (const initializer of initializers) {
    output += `import Init${i} from "${initializer}";\n`;
    output += `initializers["${initializer}"] = Init${i};\n`;
    i += 1;
  }

  return output;
}

let lastRollupResult;
let lastRollupError;
globalThis.rollup = function (modules, options) {
  const resultPromise = rollup({
    input: "virtual:main",
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
          if (source === "virtual:main") {
            return source;
          }

          if (source.startsWith(".")) {
            source = join(dirname(context), source);
          }

          for (const ext of ["", ".js", ".gjs"]) {
            const candidate = source + ext;
            if (modules.hasOwnProperty(candidate)) {
              return candidate;
            }
          }
          return false;
        },
        load(id) {
          if (id === "virtual:main") {
            return generateMain(modules);
          }
          if (modules.hasOwnProperty(id)) {
            return modules[id];
          }
        },
      },
      babel({
        extensions: [".js", ".gjs"],
        babelHelpers: "bundled",
        plugins: [
          [DecoratorTransforms, { runEarly: true }],
          // BabelReplaceImports,
          [
            HTMLBarsInlinePrecompile,
            {
              // compiler: { precompile },
              targetFormat: "hbs",
              // enableLegacyModules: [
              //   "ember-cli-htmlbars",
              //   "ember-cli-htmlbars-inline-precompile",
              //   "htmlbars-inline-precompile",
              // ],
            },
            "first-pass",
          ],
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
            "second-pass",
          ],
          // TODO: Ember this fallback
          // TODO: template colocation
          // TODO: themePrefix etc.
          // TODO: widgetHbs (remove from d-calendar)
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
