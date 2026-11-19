import "./shims.js";
import "./postcss.js";
import "./asset-processor-rollup.js";
import { transformSync } from "@babel/core";
import BabelTransformModulesAmd from "@babel/plugin-transform-modules-amd";
import BabelPresetEnv from "@babel/preset-env";
import DecoratorTransforms from "decorator-transforms";
import EMBER_PACKAGE from "ember-source/package.json";
import { minify as terserMinify } from "terser";
import { browsers } from "../discourse/config/targets.js";
import babelTransformModuleRenames from "../discourse/lib/babel-transform-module-renames.js";

globalThis.emberVersion = function () {
  return EMBER_PACKAGE.version;
};

globalThis.transpile = function (source, options = {}) {
  const { moduleId, filename, skipModule, generateMap } = options;

  const plugins = [];
  if (moduleId && !skipModule) {
    plugins.push([BabelTransformModulesAmd, { noInterop: true }]);
  }
  plugins.push([DecoratorTransforms, { runEarly: true }]);
  plugins.push(babelTransformModuleRenames);

  try {
    const result = transformSync(source, {
      moduleId,
      filename,
      ast: false,
      plugins,
      presets: [
        [
          BabelPresetEnv,
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

globalThis.minify = terserMinify;
