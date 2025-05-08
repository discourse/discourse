// import { JSDOM } from "jsdom";
import "core-js/actual/url";
import patch from "./text-decoder-shim";
patch();

import getRandomValues from "polyfill-crypto.getrandomvalues";
globalThis.crypto = { getRandomValues };

import { rollup } from "@rollup/browser";
import { babel } from "@rollup/plugin-babel";
import DecoratorTransforms from "decorator-transforms";

const CONSOLE_PREFIX = "[DiscourseJsProcessor] ";
globalThis.window = {};

const oldConsole = globalThis.console;
globalThis.console = {
  log(...args) {
    globalThis.rails?.logger.info(CONSOLE_PREFIX + args.join(" "));
    oldConsole.log(...args);
  },
  warn(...args) {
    globalThis.rails?.logger.warn(CONSOLE_PREFIX + args.join(" "));
    oldConsole.warn(...args);
  },
  error(...args) {
    globalThis.rails?.logger.error(CONSOLE_PREFIX + args.join(" "));
    oldConsole.error(...args);
  },
};

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
        resolveId(source) {
          console.log("resolveid");
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
        plugins: [DecoratorTransforms],
      }),
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
