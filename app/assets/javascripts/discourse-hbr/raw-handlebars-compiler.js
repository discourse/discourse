"use strict";

const Filter = require("broccoli-filter");
const Handlebars = require("handlebars");

const RawHandlebars = Handlebars.create();

function buildPath(blk, args) {
  let result = {
    type: "PathExpression",
    data: false,
    depth: blk.path.depth,
    loc: blk.path.loc,
  };

  // Server side precompile doesn't have jquery.extend
  Object.keys(args).forEach(function (a) {
    result[a] = args[a];
  });

  return result;
}

function replaceGet(ast) {
  let visitor = new Handlebars.Visitor();
  visitor.mutating = true;

  visitor.MustacheStatement = function (mustache) {
    if (!(mustache.params.length || mustache.hash)) {
      mustache.params[0] = mustache.path;
      mustache.path = buildPath(mustache, {
        parts: ["get"],
        original: "get",
        strict: true,
        falsy: true,
      });
    }
    return Handlebars.Visitor.prototype.MustacheStatement.call(this, mustache);
  };

  // rewrite `each x as |y|` as each y in x`
  // This allows us to use the same syntax in all templates
  visitor.BlockStatement = function (block) {
    if (block.path.original === "each" && block.params.length === 1) {
      let paramName = block.program.blockParams[0];
      block.params = [
        buildPath(block, { original: paramName }),
        { type: "CommentStatement", value: "in" },
        block.params[0],
      ];
      delete block.program.blockParams;
    }

    return Handlebars.Visitor.prototype.BlockStatement.call(this, block);
  };

  visitor.accept(ast);
}

RawHandlebars.Compiler = function () {};
RawHandlebars.Compiler.prototype = Object.create(Handlebars.Compiler.prototype);
RawHandlebars.Compiler.prototype.compiler = RawHandlebars.Compiler;

RawHandlebars.JavaScriptCompiler = function () {};

RawHandlebars.JavaScriptCompiler.prototype = Object.create(
  Handlebars.JavaScriptCompiler.prototype
);
RawHandlebars.JavaScriptCompiler.prototype.compiler =
  RawHandlebars.JavaScriptCompiler;
RawHandlebars.JavaScriptCompiler.prototype.namespace = "RawHandlebars";

RawHandlebars.precompile = function (value, asObject) {
  let ast = Handlebars.parse(value);
  replaceGet(ast);

  let options = {
    knownHelpers: {
      get: true,
    },
    data: true,
    stringParams: true,
  };

  asObject = asObject === undefined ? true : asObject;

  let environment = new RawHandlebars.Compiler().compile(ast, options);
  return new RawHandlebars.JavaScriptCompiler().compile(
    environment,
    options,
    undefined,
    asObject
  );
};

RawHandlebars.compile = function (string) {
  let ast = Handlebars.parse(string);
  replaceGet(ast);

  // this forces us to rewrite helpers
  let options = { data: true, stringParams: true };
  let environment = new RawHandlebars.Compiler().compile(ast, options);
  let templateSpec = new RawHandlebars.JavaScriptCompiler().compile(
    environment,
    options,
    undefined,
    true
  );

  let t = RawHandlebars.template(templateSpec);
  t.isMethod = false;

  return t;
};
function TemplateCompiler(inputTree, options) {
  if (!(this instanceof TemplateCompiler)) {
    return new TemplateCompiler(inputTree, options);
  }

  Filter.call(this, inputTree, options); // this._super()

  this.options = options || {};
  this.inputTree = inputTree;
}

TemplateCompiler.prototype = Object.create(Filter.prototype);
TemplateCompiler.prototype.constructor = TemplateCompiler;
TemplateCompiler.prototype.extensions = ["hbr"];
TemplateCompiler.prototype.targetExtension = "js";

TemplateCompiler.prototype.registerPlugins = function registerPlugins() {};

TemplateCompiler.prototype.initializeFeatures =
  function initializeFeatures() {};

TemplateCompiler.prototype.processString = function (string, relativePath) {
  let filename;

  const pluginName = relativePath.match(/^discourse\/plugins\/([^\/]+)\//)?.[1];

  if (pluginName) {
    filename = relativePath
      .replace(`discourse/plugins/${pluginName}/`, "")
      .replace(/^(discourse\/)?raw-templates\//, "javascripts/");
  } else {
    filename = relativePath.replace(/^raw-templates\//, "");
  }

  filename = filename.replace(/\.hbr$/, "");
  const hasModernReplacement = string.includes(
    "{{!-- has-modern-replacement --}}"
  );

  return `
    import { template as compiler } from "discourse/lib/raw-handlebars";
    import { addRawTemplate } from "discourse/lib/raw-templates";

    let template = compiler(${this.precompile(string, false)});

    addRawTemplate("${filename}", template, {
      core: ${!pluginName},
      pluginName: ${JSON.stringify(pluginName)},
      hasModernReplacement: ${hasModernReplacement},
    });

    export default template;
  `;
};

TemplateCompiler.prototype.precompile = function (value, asObject) {
  return RawHandlebars.precompile(value, asObject);
};

module.exports = TemplateCompiler;
