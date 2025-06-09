// This is executed in mini_racer to provide the JS logic for lib/discourse_js_processor.rb

import "./shims";
import "./postcss";
import { transform as babelTransform } from "@babel/standalone";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import colocatedBabelPlugin from "ember-cli-htmlbars/lib/colocated-babel-plugin";
import { precompile } from "ember-source/dist/ember-template-compiler";
import EmberThisFallback from "ember-this-fallback";
import { minify as terserMinify } from "terser";
import { WidgetHbsCompiler } from "discourse-widget-hbs/lib/widget-hbs-compiler";
import { browsers } from "../discourse/config/targets";
import { Preprocessor } from "./content-tag";

const thisFallbackPlugin = EmberThisFallback._buildPlugin({
  enableLogging: false,
  isTheme: true,
}).plugin;

function manipulateAstNodeForTheme(node, themeId) {
  // Magically add theme id as the first param for each of these helpers)
  if (
    node.path.parts &&
    ["theme-i18n", "theme-prefix", "theme-setting"].includes(node.path.parts[0])
  ) {
    if (node.params.length === 1) {
      node.params.unshift({
        type: "NumberLiteral",
        value: themeId,
        original: themeId,
        loc: { start: {}, end: {} },
      });
    }
  }
}

function buildEmberTemplateManipulatorPlugin(themeId) {
  return function () {
    return {
      name: "theme-template-manipulator",
      visitor: {
        SubExpression: (node) => manipulateAstNodeForTheme(node, themeId),
        MustacheStatement: (node) => manipulateAstNodeForTheme(node, themeId),
      },
    };
  };
}

function buildTemplateCompilerBabelPlugins({ extension, themeId }) {
  const compiler = { precompile };

  if (themeId && extension !== "gjs") {
    compiler.precompile = (src, opts) => {
      return precompile(src, {
        ...opts,
        plugins: {
          ast: [
            buildEmberTemplateManipulatorPlugin(themeId),
            thisFallbackPlugin,
          ],
        },
      });
    };
  }

  return [
    colocatedBabelPlugin,
    WidgetHbsCompiler,
    [
      HTMLBarsInlinePrecompile,
      {
        compiler,
        enableLegacyModules: [
          "ember-cli-htmlbars",
          "ember-cli-htmlbars-inline-precompile",
          "htmlbars-inline-precompile",
        ],
      },
    ],
  ];
}

globalThis.transpile = function (source, options = {}) {
  const { moduleId, filename, extension, skipModule, themeId } = options;

  if (extension === "gjs") {
    const preprocessor = new Preprocessor();
    source = preprocessor.process(source).code;
  }

  const plugins = [];
  plugins.push(...buildTemplateCompilerBabelPlugins({ extension, themeId }));
  if (moduleId && !skipModule) {
    plugins.push(["transform-modules-amd", { noInterop: true }]);
  }
  plugins.push([DecoratorTransforms, { runEarly: true }]);

  try {
    return babelTransform(source, {
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
    }).code;
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
