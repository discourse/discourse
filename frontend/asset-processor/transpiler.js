import "./shims";
import "./postcss";
import "./asset-processor-rollup";
import { transform as babelTransform } from "@babel/standalone";
import DecoratorTransforms from "decorator-transforms";
import EMBER_PACKAGE from "ember-source/package.json";
import { minify as terserMinify } from "terser";
import { browsers } from "../discourse/config/targets";
import babelTransformModuleRenames from "../discourse/lib/babel-transform-module-renames";

globalThis.emberVersion = function () {
  return EMBER_PACKAGE.version;
};

globalThis.transpile = function (source, options = {}) {
  const { moduleId, filename, skipModule, generateMap } = options;

  const plugins = [];
  if (moduleId && !skipModule) {
    plugins.push(["transform-modules-amd", { noInterop: true, moduleId }]);
  }
  plugins.push([DecoratorTransforms, { runEarly: true }]);
  plugins.push(babelTransformModuleRenames);

  try {
    const result = babelTransform(source, {
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

globalThis.minify = terserMinify;
