import "./shims";
import "./postcss";
import "./theme-rollup";
import { transform as babelTransform } from "@babel/standalone";
import DecoratorTransforms from "decorator-transforms";
import EMBER_PACKAGE from "ember-source/package.json";
import { minify as terserMinify } from "terser";
import { browsers } from "../discourse/config/targets";

globalThis.emberVersion = function () {
  return EMBER_PACKAGE.version;
};

globalThis.transpile = function (source, options = {}) {
  const { moduleId, filename, skipModule, generateMap } = options;

  const plugins = [];
  if (moduleId && !skipModule) {
    plugins.push(["transform-modules-amd", { noInterop: true }]);
  }
  plugins.push([DecoratorTransforms, { runEarly: true }]);

  try {
    const result = babelTransform(source, {
      moduleId,
      filename,
      ast: false,
      plugins,
      presets: [
        [
          "env",
          {
            modules: false,
            targets: {
              browsers,
            },
          },
        ],
      ],
      sourceMaps: generateMap,
    });
    if (generateMap) {
      return {
        code: result.code,
        map: JSON.stringify(result.map),
      };
    } else {
      return result.code;
    }
  } catch (error) {
    // Workaround for https://github.com/rubyjs/mini_racer/issues/262
    error.message = JSON.stringify(error.message);
    throw error;
  }
};

// mini_racer doesn't have native support for getting the result of an async operation.
// To work around that, we provide a getMinifyResult which can be used to fetch the result
// in a followup method call.
let lastMinifyError, lastMinifyResult;

globalThis.minify = async function (sources, options) {
  lastMinifyError = lastMinifyResult = null;
  try {
    lastMinifyResult = await terserMinify(sources, options);
  } catch (e) {
    lastMinifyError = e;
  }
};

globalThis.getMinifyResult = function () {
  const error = lastMinifyError;
  const result = lastMinifyResult;

  lastMinifyError = lastMinifyResult = null;

  if (error) {
    throw error.toString();
  }
  return result;
};
