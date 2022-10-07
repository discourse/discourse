/* global Babel:true */

// This is executed in mini_racer to provide the JS logic for lib/discourse_js_processor.rb

const makeEmberTemplateCompilerPlugin =
  require("babel-plugin-ember-template-compilation").default;
const precompile = require("ember-template-compiler").precompile;
const Handlebars = require("handlebars").default;

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

function buildTemplateCompilerBabelPlugins({ themeId }) {
  let compileFunction = precompile;
  if (themeId) {
    compileFunction = (src, opts) => {
      return precompile(src, {
        ...opts,
        plugins: {
          ast: [buildEmberTemplateManipulatorPlugin(themeId)],
        },
      });
    };
  }

  return [
    require("widget-hbs-compiler").WidgetHbsCompiler,
    [
      makeEmberTemplateCompilerPlugin(() => compileFunction),
      { enableLegacyModules: ["ember-cli-htmlbars"] },
    ],
  ];
}

function buildThemeRawHbsTemplateManipulatorPlugin(themeId) {
  return function (ast) {
    ["SubExpression", "MustacheStatement"].forEach((pass) => {
      let visitor = new Handlebars.Visitor();
      visitor.mutating = true;
      visitor[pass] = (node) => manipulateAstNodeForTheme(node, themeId);
      visitor.accept(ast);
    });
  };
}

exports.compileRawTemplate = function (source, themeId) {
  try {
    const RawHandlebars = require("raw-handlebars").default;
    const plugins = [];
    if (themeId) {
      plugins.push(buildThemeRawHbsTemplateManipulatorPlugin(themeId));
    }
    return RawHandlebars.precompile(source, false, { plugins }).toString();
  } catch (error) {
    // Workaround for https://github.com/rubyjs/mini_racer/issues/262
    error.message = JSON.stringify(error.message);
    throw error;
  }
};

exports.transpile = function (
  source,
  { moduleId, filename, skipModule, themeId, commonPlugins } = {}
) {
  const plugins = [];
  plugins.push(...buildTemplateCompilerBabelPlugins({ themeId }));
  if (moduleId && !skipModule) {
    plugins.push(["transform-modules-amd", { noInterop: true }]);
  }
  plugins.push(...commonPlugins);

  try {
    return Babel.transform(source, {
      moduleId,
      filename,
      ast: false,
      plugins,
    }).code;
  } catch (error) {
    // Workaround for https://github.com/rubyjs/mini_racer/issues/262
    error.message = JSON.stringify(error.message);
    throw error;
  }
};
