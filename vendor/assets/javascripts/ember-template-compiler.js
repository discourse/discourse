/*!
 * @overview  Ember - JavaScript Application Framework
 * @copyright Copyright 2011-2015 Tilde Inc. and contributors
 *            Portions Copyright 2006-2011 Strobe Inc.
 *            Portions Copyright 2008-2011 Apple Inc. All rights reserved.
 * @license   Licensed under MIT license
 *            See https://raw.github.com/emberjs/ember.js/master/LICENSE
 * @version   1.11.3
 */

(function() {
var enifed, requireModule, eriuqer, requirejs, Ember;
var mainContext = this;

(function() {

  Ember = this.Ember = this.Ember || {};
  if (typeof Ember === 'undefined') { Ember = {}; };
  function UNDEFINED() { }

  if (typeof Ember.__loader === 'undefined') {
    var registry = {};
    var seen = {};

    enifed = function(name, deps, callback) {
      var value = { };

      if (!callback) {
        value.deps = [];
        value.callback = deps;
      } else {
        value.deps = deps;
        value.callback = callback;
      }

        registry[name] = value;
    };

    requirejs = eriuqer = requireModule = function(name) {
      var s = seen[name];

      if (s !== undefined) { return seen[name]; }
      if (s === UNDEFINED) { return undefined;  }

      seen[name] = {};

      if (!registry[name]) {
        throw new Error('Could not find module ' + name);
      }

      var mod = registry[name];
      var deps = mod.deps;
      var callback = mod.callback;
      var reified = [];
      var exports;
      var length = deps.length;

      for (var i=0; i<length; i++) {
        if (deps[i] === 'exports') {
          reified.push(exports = {});
        } else {
          reified.push(requireModule(resolve(deps[i], name)));
        }
      }

      var value = length === 0 ? callback.call(this) : callback.apply(this, reified);

      return seen[name] = exports || (value === undefined ? UNDEFINED : value);
    };

    function resolve(child, name) {
      if (child.charAt(0) !== '.') {
        return child;
      }
      var parts = child.split('/');
      var parentBase = name.split('/').slice(0, -1);

      for (var i=0, l=parts.length; i<l; i++) {
        var part = parts[i];

        if (part === '..') {
          parentBase.pop();
        } else if (part === '.') {
          continue;
        } else {
          parentBase.push(part);
        }
      }

      return parentBase.join('/');
    }

    requirejs._eak_seen = registry;

    Ember.__loader = {
      define: enifed,
      require: eriuqer,
      registry: registry
    };
  } else {
    enifed = Ember.__loader.define;
    requirejs = eriuqer = requireModule = Ember.__loader.require;
  }
})();

enifed('ember-metal/core', ['exports'], function (exports) {

  'use strict';

  exports.K = K;

  /*globals Ember:true,ENV,EmberENV */

  /**
  @module ember
  @submodule ember-metal
  */

  /**
    All Ember methods and functions are defined inside of this namespace. You
    generally should not add new properties to this namespace as it may be
    overwritten by future versions of Ember.

    You can also use the shorthand `Em` instead of `Ember`.

    Ember-Runtime is a framework that provides core functions for Ember including
    cross-platform functions, support for property observing and objects. Its
    focus is on small size and performance. You can use this in place of or
    along-side other cross-platform libraries such as jQuery.

    The core Runtime framework is based on the jQuery API with a number of
    performance optimizations.

    @class Ember
    @static
    @version 1.11.3
  */

  if ('undefined' === typeof Ember) {
    // Create core object. Make it act like an instance of Ember.Namespace so that
    // objects assigned to it are given a sane string representation.
    Ember = {};
  }

  // Default imports, exports and lookup to the global object;
  var global = mainContext || {}; // jshint ignore:line
  Ember.imports = Ember.imports || global;
  Ember.lookup  = Ember.lookup  || global;
  var emExports   = Ember.exports = Ember.exports || global;

  // aliases needed to keep minifiers from removing the global context
  emExports.Em = emExports.Ember = Ember;

  // Make sure these are set whether Ember was already defined or not

  Ember.isNamespace = true;

  Ember.toString = function() { return "Ember"; };


  /**
    @property VERSION
    @type String
    @default '1.11.3'
    @static
  */
  Ember.VERSION = '1.11.3';

  /**
    Standard environmental variables. You can define these in a global `EmberENV`
    variable before loading Ember to control various configuration settings.

    For backwards compatibility with earlier versions of Ember the global `ENV`
    variable will be used if `EmberENV` is not defined.

    @property ENV
    @type Hash
  */

  if (Ember.ENV) {
    // do nothing if Ember.ENV is already setup
    Ember.assert('Ember.ENV should be an object.', 'object' !== typeof Ember.ENV);
  } else if ('undefined' !== typeof EmberENV) {
    Ember.ENV = EmberENV;
  } else if ('undefined' !== typeof ENV) {
    Ember.ENV = ENV;
  } else {
    Ember.ENV = {};
  }

  Ember.config = Ember.config || {};

  // We disable the RANGE API by default for performance reasons
  if ('undefined' === typeof Ember.ENV.DISABLE_RANGE_API) {
    Ember.ENV.DISABLE_RANGE_API = true;
  }

  /**
    Hash of enabled Canary features. Add to this before creating your application.

    You can also define `EmberENV.FEATURES` if you need to enable features flagged at runtime.

    @class FEATURES
    @namespace Ember
    @static
    @since 1.1.0
  */

  Ember.FEATURES = Ember.ENV.FEATURES;

  if (!Ember.FEATURES) {
    Ember.FEATURES = {"features-stripped-test":false,"ember-routing-named-substates":true,"mandatory-setter":true,"ember-htmlbars-component-generation":false,"ember-htmlbars-component-helper":true,"ember-htmlbars-inline-if-helper":true,"ember-htmlbars-attribute-syntax":true,"ember-routing-transitioning-classes":true,"new-computed-syntax":false,"ember-testing-checkbox-helpers":false,"ember-metal-stream":false,"ember-htmlbars-each-with-index":true,"ember-application-instance-initializers":false,"ember-application-initializer-context":false,"ember-router-willtransition":true,"ember-application-visit":false}; //jshint ignore:line
  }

  /**
    Test that a feature is enabled. Parsed by Ember's build tools to leave
    experimental features out of beta/stable builds.

    You can define the following configuration options:

    * `EmberENV.ENABLE_ALL_FEATURES` - force all features to be enabled.
    * `EmberENV.ENABLE_OPTIONAL_FEATURES` - enable any features that have not been explicitly
      enabled/disabled.

    @method isEnabled
    @param {String} feature
    @return {Boolean}
    @for Ember.FEATURES
    @since 1.1.0
  */

  Ember.FEATURES.isEnabled = function(feature) {
    var featureValue = Ember.FEATURES[feature];

    if (Ember.ENV.ENABLE_ALL_FEATURES) {
      return true;
    } else if (featureValue === true || featureValue === false || featureValue === undefined) {
      return featureValue;
    } else if (Ember.ENV.ENABLE_OPTIONAL_FEATURES) {
      return true;
    } else {
      return false;
    }
  };

  // ..........................................................
  // BOOTSTRAP
  //

  /**
    Determines whether Ember should enhance some built-in object prototypes to
    provide a more friendly API. If enabled, a few methods will be added to
    `Function`, `String`, and `Array`. `Object.prototype` will not be enhanced,
    which is the one that causes most trouble for people.

    In general we recommend leaving this option set to true since it rarely
    conflicts with other code. If you need to turn it off however, you can
    define an `EmberENV.EXTEND_PROTOTYPES` config to disable it.

    @property EXTEND_PROTOTYPES
    @type Boolean
    @default true
    @for Ember
  */
  Ember.EXTEND_PROTOTYPES = Ember.ENV.EXTEND_PROTOTYPES;

  if (typeof Ember.EXTEND_PROTOTYPES === 'undefined') {
    Ember.EXTEND_PROTOTYPES = true;
  }

  /**
    Determines whether Ember logs a full stack trace during deprecation warnings

    @property LOG_STACKTRACE_ON_DEPRECATION
    @type Boolean
    @default true
  */
  Ember.LOG_STACKTRACE_ON_DEPRECATION = (Ember.ENV.LOG_STACKTRACE_ON_DEPRECATION !== false);

  /**
    Determines whether Ember should add ECMAScript 5 Array shims to older browsers.

    @property SHIM_ES5
    @type Boolean
    @default Ember.EXTEND_PROTOTYPES
  */
  Ember.SHIM_ES5 = (Ember.ENV.SHIM_ES5 === false) ? false : Ember.EXTEND_PROTOTYPES;

  /**
    Determines whether Ember logs info about version of used libraries

    @property LOG_VERSION
    @type Boolean
    @default true
  */
  Ember.LOG_VERSION = (Ember.ENV.LOG_VERSION === false) ? false : true;

  /**
    Empty function. Useful for some operations. Always returns `this`.

    @method K
    @private
    @return {Object}
  */
  function K() { return this; }
  Ember.K = K;
  //TODO: ES6 GLOBAL TODO

  // Stub out the methods defined by the ember-debug package in case it's not loaded

  if ('undefined' === typeof Ember.assert) { Ember.assert = K; }
  if ('undefined' === typeof Ember.warn) { Ember.warn = K; }
  if ('undefined' === typeof Ember.debug) { Ember.debug = K; }
  if ('undefined' === typeof Ember.runInDebug) { Ember.runInDebug = K; }
  if ('undefined' === typeof Ember.deprecate) { Ember.deprecate = K; }
  if ('undefined' === typeof Ember.deprecateFunc) {
    Ember.deprecateFunc = function(_, func) { return func; };
  }

  exports['default'] = Ember;

});
enifed('ember-template-compiler', ['exports', 'ember-metal/core', 'ember-template-compiler/system/precompile', 'ember-template-compiler/system/compile', 'ember-template-compiler/system/template', 'ember-template-compiler/plugins', 'ember-template-compiler/plugins/transform-each-in-to-hash', 'ember-template-compiler/plugins/transform-with-as-to-hash', 'ember-template-compiler/compat'], function (exports, _Ember, precompile, compile, template, plugins, TransformEachInToHash, TransformWithAsToHash) {

  'use strict';

  plugins.registerPlugin('ast', TransformWithAsToHash['default']);
  plugins.registerPlugin('ast', TransformEachInToHash['default']);

  exports._Ember = _Ember['default'];
  exports.precompile = precompile['default'];
  exports.compile = compile['default'];
  exports.template = template['default'];
  exports.registerPlugin = plugins.registerPlugin;

});
enifed('ember-template-compiler/compat', ['ember-metal/core', 'ember-template-compiler/compat/precompile', 'ember-template-compiler/system/compile', 'ember-template-compiler/system/template'], function (Ember, precompile, compile, template) {

	'use strict';

	var EmberHandlebars = Ember['default'].Handlebars = Ember['default'].Handlebars || {};

	EmberHandlebars.precompile = precompile['default'];
	EmberHandlebars.compile = compile['default'];
	EmberHandlebars.template = template['default'];

});
enifed('ember-template-compiler/compat/precompile', ['exports', 'ember-template-compiler/system/compile_options'], function (exports, compileOptions) {

  'use strict';

  /**
  @module ember
  @submodule ember-template-compiler
  */
  var compile, compileSpec;

  exports['default'] = function(string) {
    if ((!compile || !compileSpec) && Ember.__loader.registry['htmlbars-compiler/compiler']) {
      var Compiler = requireModule('htmlbars-compiler/compiler');

      compile = Compiler.compile;
      compileSpec = Compiler.compileSpec;
    }

    if (!compile || !compileSpec) {
      throw new Error('Cannot call `precompile` without the template compiler loaded. Please load `ember-template-compiler.js` prior to calling `precompile`.');
    }

    var asObject = arguments[1] === undefined ? true : arguments[1];
    var compileFunc = asObject ? compile : compileSpec;

    return compileFunc(string, compileOptions['default']());
  }

});
enifed('ember-template-compiler/plugins', ['exports'], function (exports) {

  'use strict';

  exports.registerPlugin = registerPlugin;

  /**
  @module ember
  @submodule ember-template-compiler
  */

  /**
   @private
   @property helpers
  */
  var plugins = {
    ast: []
  };

  /**
    Adds an AST plugin to be used by Ember.HTMLBars.compile.

    @private
    @method registerASTPlugin
  */
  function registerPlugin(type, Plugin) {
    if (!plugins[type]) {
      throw new Error('Attempting to register "' + Plugin + '" as "' + type + '" which is not a valid HTMLBars plugin type.');
    }

    plugins[type].push(Plugin);
  }

  exports['default'] = plugins;

});
enifed('ember-template-compiler/plugins/transform-each-in-to-hash', ['exports'], function (exports) {

  'use strict';

  /**
  @module ember
  @submodule ember-htmlbars
  */


  /**
    An HTMLBars AST transformation that replaces all instances of

    ```handlebars
    {{#each item in items}}
    {{/each}}
    ```

    with

    ```handlebars
    {{#each items keyword="item"}}
    {{/each}}
    ```

    @class TransformEachInToHash
    @private
  */
  function TransformEachInToHash() {
    // set later within HTMLBars to the syntax package
    this.syntax = null;
  }

  /**
    @private
    @method transform
    @param {AST} The AST to be transformed.
  */
  TransformEachInToHash.prototype.transform = function TransformEachInToHash_transform(ast) {
    var pluginContext = this;
    var walker = new pluginContext.syntax.Walker();
    var b = pluginContext.syntax.builders;

    walker.visit(ast, function(node) {
      if (pluginContext.validate(node)) {

        if (node.program && node.program.blockParams.length) {
          throw new Error('You cannot use keyword (`{{each foo in bar}}`) and block params (`{{each bar as |foo|}}`) at the same time.');
        }

        var removedParams = node.sexpr.params.splice(0, 2);
        var keyword = removedParams[0].original;

        // TODO: This may not be necessary.
        if (!node.sexpr.hash) {
          node.sexpr.hash = b.hash();
        }

        node.sexpr.hash.pairs.push(b.pair(
          'keyword',
          b.string(keyword)
        ));
      }
    });

    return ast;
  };

  TransformEachInToHash.prototype.validate = function TransformEachInToHash_validate(node) {
    return (node.type === 'BlockStatement' || node.type === 'MustacheStatement') &&
      node.sexpr.path.original === 'each' &&
      node.sexpr.params.length === 3 &&
      node.sexpr.params[1].type === 'PathExpression' &&
      node.sexpr.params[1].original === 'in';
  };

  exports['default'] = TransformEachInToHash;

});
enifed('ember-template-compiler/plugins/transform-with-as-to-hash', ['exports'], function (exports) {

  'use strict';

  /**
  @module ember
  @submodule ember-htmlbars
  */

  /**
    An HTMLBars AST transformation that replaces all instances of

    ```handlebars
    {{#with foo.bar as bar}}
    {{/with}}
    ```

    with

    ```handlebars
    {{#with foo.bar as |bar|}}
    {{/with}}
    ```

    @private
    @class TransformWithAsToHash
  */
  function TransformWithAsToHash() {
    // set later within HTMLBars to the syntax package
    this.syntax = null;
  }

  /**
    @private
    @method transform
    @param {AST} The AST to be transformed.
  */
  TransformWithAsToHash.prototype.transform = function TransformWithAsToHash_transform(ast) {
    var pluginContext = this;
    var walker = new pluginContext.syntax.Walker();

    walker.visit(ast, function(node) {
      if (pluginContext.validate(node)) {

        if (node.program && node.program.blockParams.length) {
          throw new Error('You cannot use keyword (`{{with foo as bar}}`) and block params (`{{with foo as |bar|}}`) at the same time.');
        }

        var removedParams = node.sexpr.params.splice(1, 2);
        var keyword = removedParams[1].original;
        node.program.blockParams = [keyword];
      }
    });

    return ast;
  };

  TransformWithAsToHash.prototype.validate = function TransformWithAsToHash_validate(node) {
    return node.type === 'BlockStatement' &&
      node.sexpr.path.original === 'with' &&
      node.sexpr.params.length === 3 &&
      node.sexpr.params[1].type === 'PathExpression' &&
      node.sexpr.params[1].original === 'as';
  };

  exports['default'] = TransformWithAsToHash;

});
enifed('ember-template-compiler/system/compile', ['exports', 'ember-template-compiler/system/compile_options', 'ember-template-compiler/system/template'], function (exports, compileOptions, template) {

  'use strict';

  /**
  @module ember
  @submodule ember-template-compiler
  */

  var compile;
  exports['default'] = function(templateString) {
    if (!compile && Ember.__loader.registry['htmlbars-compiler/compiler']) {
      compile = requireModule('htmlbars-compiler/compiler').compile;
    }

    if (!compile) {
      throw new Error('Cannot call `compile` without the template compiler loaded. Please load `ember-template-compiler.js` prior to calling `compile`.');
    }

    var templateSpec = compile(templateString, compileOptions['default']());

    return template['default'](templateSpec);
  }

});
enifed('ember-template-compiler/system/compile_options', ['exports', 'ember-metal/core', 'ember-template-compiler/plugins'], function (exports, Ember, plugins) {

  'use strict';

  /**
  @module ember
  @submodule ember-template-compiler
  */

  exports['default'] = function() {
    var disableComponentGeneration = true;
    
    return {
      revision: 'Ember@1.11.3',

      disableComponentGeneration: disableComponentGeneration,

      plugins: plugins['default']
    };
  }

});
enifed('ember-template-compiler/system/precompile', ['exports', 'ember-template-compiler/system/compile_options'], function (exports, compileOptions) {

  'use strict';

  /**
  @module ember
  @submodule ember-template-compiler
  */

  var compileSpec;

  /**
    Uses HTMLBars `compile` function to process a string into a compiled template string.
    The returned string must be passed through `Ember.HTMLBars.template`.

    This is not present in production builds.

    @private
    @method precompile
    @param {String} templateString This is the string to be compiled by HTMLBars.
  */
  exports['default'] = function(templateString) {
    if (!compileSpec && Ember.__loader.registry['htmlbars-compiler/compiler']) {
      compileSpec = requireModule('htmlbars-compiler/compiler').compileSpec;
    }

    if (!compileSpec) {
      throw new Error('Cannot call `compileSpec` without the template compiler loaded. Please load `ember-template-compiler.js` prior to calling `compileSpec`.');
    }

    return compileSpec(templateString, compileOptions['default']());
  }

});
enifed('ember-template-compiler/system/template', ['exports'], function (exports) {

  'use strict';

  /**
  @module ember
  @submodule ember-template-compiler
  */

  /**
    Augments the default precompiled output of an HTMLBars template with
    additional information needed by Ember.

    @private
    @method template
    @param {Function} templateSpec This is the compiled HTMLBars template spec.
  */

  exports['default'] = function(templateSpec) {
    templateSpec.isTop = true;
    templateSpec.isMethod = false;

    return templateSpec;
  }

});
enifed("htmlbars-compiler",
  ["./htmlbars-compiler/compiler","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var compile = __dependency1__.compile;
    var compileSpec = __dependency1__.compileSpec;
    var template = __dependency1__.template;

    __exports__.compile = compile;
    __exports__.compileSpec = compileSpec;
    __exports__.template = template;
  });
enifed("htmlbars-compiler/compiler",
  ["../htmlbars-syntax/parser","./template-compiler","exports"],
  function(__dependency1__, __dependency2__, __exports__) {
    "use strict";
    /*jshint evil:true*/
    var preprocess = __dependency1__.preprocess;
    var TemplateCompiler = __dependency2__["default"];

    /*
     * Compile a string into a template spec string. The template spec is a string
     * representation of a template. Usually, you would use compileSpec for
     * pre-compilation of a template on the server.
     *
     * Example usage:
     *
     *     var templateSpec = compileSpec("Howdy {{name}}");
     *     // This next step is basically what plain compile does
     *     var template = new Function("return " + templateSpec)();
     *
     * @method compileSpec
     * @param {String} string An HTMLBars template string
     * @return {TemplateSpec} A template spec string
     */
    function compileSpec(string, options) {
      var ast = preprocess(string, options);
      var compiler = new TemplateCompiler(options);
      var program = compiler.compile(ast);
      return program;
    }

    __exports__.compileSpec = compileSpec;/*
     * @method template
     * @param {TemplateSpec} templateSpec A precompiled template
     * @return {Template} A template spec string
     */
    function template(templateSpec) {
      return new Function("return " + templateSpec)();
    }

    __exports__.template = template;/*
     * Compile a string into a template rendering function
     *
     * Example usage:
     *
     *     // Template is the hydration portion of the compiled template
     *     var template = compile("Howdy {{name}}");
     *
     *     // Template accepts three arguments:
     *     //
     *     //   1. A context object
     *     //   2. An env object
     *     //   3. A contextualElement (optional, document.body is the default)
     *     //
     *     // The env object *must* have at least these two properties:
     *     //
     *     //   1. `hooks` - Basic hooks for rendering a template
     *     //   2. `dom` - An instance of DOMHelper
     *     //
     *     import {hooks} from 'htmlbars-runtime';
     *     import {DOMHelper} from 'morph';
     *     var context = {name: 'whatever'},
     *         env = {hooks: hooks, dom: new DOMHelper()},
     *         contextualElement = document.body;
     *     var domFragment = template(context, env, contextualElement);
     *
     * @method compile
     * @param {String} string An HTMLBars template string
     * @param {Object} options A set of options to provide to the compiler
     * @return {Template} A function for rendering the template
     */
    function compile(string, options) {
      return template(compileSpec(string, options));
    }

    __exports__.compile = compile;
  });
enifed("htmlbars-compiler/fragment-javascript-compiler",
  ["./utils","../htmlbars-util/quoting","exports"],
  function(__dependency1__, __dependency2__, __exports__) {
    "use strict";
    var processOpcodes = __dependency1__.processOpcodes;
    var string = __dependency2__.string;

    var svgNamespace = "http://www.w3.org/2000/svg",
    // http://www.w3.org/html/wg/drafts/html/master/syntax.html#html-integration-point
        svgHTMLIntegrationPoints = {'foreignObject':true, 'desc':true, 'title':true};


    function FragmentJavaScriptCompiler() {
      this.source = [];
      this.depth = -1;
    }

    __exports__["default"] = FragmentJavaScriptCompiler;

    FragmentJavaScriptCompiler.prototype.compile = function(opcodes, options) {
      this.source.length = 0;
      this.depth = -1;
      this.indent = (options && options.indent) || "";
      this.namespaceFrameStack = [{namespace: null, depth: null}];
      this.domNamespace = null;

      this.source.push('function build(dom) {\n');
      processOpcodes(this, opcodes);
      this.source.push(this.indent+'}');

      return this.source.join('');
    };

    FragmentJavaScriptCompiler.prototype.createFragment = function() {
      var el = 'el'+(++this.depth);
      this.source.push(this.indent+'  var '+el+' = dom.createDocumentFragment();\n');
    };

    FragmentJavaScriptCompiler.prototype.createElement = function(tagName) {
      var el = 'el'+(++this.depth);
      if (tagName === 'svg') {
        this.pushNamespaceFrame({namespace: svgNamespace, depth: this.depth});
      }
      this.ensureNamespace();
      this.source.push(this.indent+'  var '+el+' = dom.createElement('+string(tagName)+');\n');
      if (svgHTMLIntegrationPoints[tagName]) {
        this.pushNamespaceFrame({namespace: null, depth: this.depth});
      }
    };

    FragmentJavaScriptCompiler.prototype.createText = function(str) {
      var el = 'el'+(++this.depth);
      this.source.push(this.indent+'  var '+el+' = dom.createTextNode('+string(str)+');\n');
    };

    FragmentJavaScriptCompiler.prototype.createComment = function(str) {
      var el = 'el'+(++this.depth);
      this.source.push(this.indent+'  var '+el+' = dom.createComment('+string(str)+');\n');
    };

    FragmentJavaScriptCompiler.prototype.returnNode = function() {
      var el = 'el'+this.depth;
      this.source.push(this.indent+'  return '+el+';\n');
    };

    FragmentJavaScriptCompiler.prototype.setAttribute = function(name, value, namespace) {
      var el = 'el'+this.depth;
      if (namespace) {
        this.source.push(this.indent+'  dom.setAttributeNS('+el+','+string(namespace)+','+string(name)+','+string(value)+');\n');
      } else {
        this.source.push(this.indent+'  dom.setAttribute('+el+','+string(name)+','+string(value)+');\n');
      }
    };

    FragmentJavaScriptCompiler.prototype.appendChild = function() {
      if (this.depth === this.getCurrentNamespaceFrame().depth) {
        this.popNamespaceFrame();
      }
      var child = 'el'+(this.depth--);
      var el = 'el'+this.depth;
      this.source.push(this.indent+'  dom.appendChild('+el+', '+child+');\n');
    };

    FragmentJavaScriptCompiler.prototype.getCurrentNamespaceFrame = function() {
      return this.namespaceFrameStack[this.namespaceFrameStack.length-1];
    };

    FragmentJavaScriptCompiler.prototype.pushNamespaceFrame = function(frame) {
      this.namespaceFrameStack.push(frame);
    };

    FragmentJavaScriptCompiler.prototype.popNamespaceFrame = function() {
      return this.namespaceFrameStack.pop();
    };

    FragmentJavaScriptCompiler.prototype.ensureNamespace = function() {
      var correctNamespace = this.getCurrentNamespaceFrame().namespace;
      if (this.domNamespace !== correctNamespace) {
        this.source.push(this.indent+'  dom.setNamespace('+(correctNamespace ? string(correctNamespace) : 'null')+');\n');
        this.domNamespace = correctNamespace;
      }
    };
  });
enifed("htmlbars-compiler/fragment-opcode-compiler",
  ["./template-visitor","./utils","../htmlbars-util","../htmlbars-util/array-utils","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __exports__) {
    "use strict";
    var TemplateVisitor = __dependency1__["default"];
    var processOpcodes = __dependency2__.processOpcodes;
    var getAttrNamespace = __dependency3__.getAttrNamespace;
    var forEach = __dependency4__.forEach;

    function FragmentOpcodeCompiler() {
      this.opcodes = [];
    }

    __exports__["default"] = FragmentOpcodeCompiler;

    FragmentOpcodeCompiler.prototype.compile = function(ast) {
      var templateVisitor = new TemplateVisitor();
      templateVisitor.visit(ast);

      processOpcodes(this, templateVisitor.actions);

      return this.opcodes;
    };

    FragmentOpcodeCompiler.prototype.opcode = function(type, params) {
      this.opcodes.push([type, params]);
    };

    FragmentOpcodeCompiler.prototype.text = function(text) {
      this.opcode('createText', [text.chars]);
      this.opcode('appendChild');
    };

    FragmentOpcodeCompiler.prototype.comment = function(comment) {
      this.opcode('createComment', [comment.value]);
      this.opcode('appendChild');
    };

    FragmentOpcodeCompiler.prototype.openElement = function(element) {
      this.opcode('createElement', [element.tag]);
      forEach(element.attributes, this.attribute, this);
    };

    FragmentOpcodeCompiler.prototype.closeElement = function() {
      this.opcode('appendChild');
    };

    FragmentOpcodeCompiler.prototype.startProgram = function() {
      this.opcodes.length = 0;
      this.opcode('createFragment');
    };

    FragmentOpcodeCompiler.prototype.endProgram = function() {
      this.opcode('returnNode');
    };

    FragmentOpcodeCompiler.prototype.mustache = function() {
      this.pushMorphPlaceholderNode();
    };

    FragmentOpcodeCompiler.prototype.component = function() {
      this.pushMorphPlaceholderNode();
    };

    FragmentOpcodeCompiler.prototype.block = function() {
      this.pushMorphPlaceholderNode();
    };

    FragmentOpcodeCompiler.prototype.pushMorphPlaceholderNode = function() {
      this.opcode('createComment', [""]);
      this.opcode('appendChild');
    };

    FragmentOpcodeCompiler.prototype.attribute = function(attr) {
      if (attr.value.type === 'TextNode') {
        var namespace = getAttrNamespace(attr.name);
        this.opcode('setAttribute', [attr.name, attr.value.chars, namespace]);
      }
    };

    FragmentOpcodeCompiler.prototype.setNamespace = function(namespace) {
      this.opcode('setNamespace', [namespace]);
    };
  });
enifed("htmlbars-compiler/hydration-javascript-compiler",
  ["./utils","../htmlbars-util/quoting","exports"],
  function(__dependency1__, __dependency2__, __exports__) {
    "use strict";
    var processOpcodes = __dependency1__.processOpcodes;
    var string = __dependency2__.string;
    var array = __dependency2__.array;

    function HydrationJavaScriptCompiler() {
      this.stack = [];
      this.source = [];
      this.mustaches = [];
      this.parents = [['fragment']];
      this.parentCount = 0;
      this.morphs = [];
      this.fragmentProcessing = [];
      this.hooks = undefined;
    }

    __exports__["default"] = HydrationJavaScriptCompiler;

    var prototype = HydrationJavaScriptCompiler.prototype;

    prototype.compile = function(opcodes, options) {
      this.stack.length = 0;
      this.mustaches.length = 0;
      this.source.length = 0;
      this.parents.length = 1;
      this.parents[0] = ['fragment'];
      this.morphs.length = 0;
      this.fragmentProcessing.length = 0;
      this.parentCount = 0;
      this.indent = (options && options.indent) || "";
      this.hooks = {};
      this.hasOpenBoundary = false;
      this.hasCloseBoundary = false;

      processOpcodes(this, opcodes);

      if (this.hasOpenBoundary) {
        this.source.unshift(this.indent+"  dom.insertBoundary(fragment, 0);\n");
      }

      if (this.hasCloseBoundary) {
        this.source.unshift(this.indent+"  dom.insertBoundary(fragment, null);\n");
      }

      var i, l;
      if (this.morphs.length) {
        var morphs = "";
        for (i = 0, l = this.morphs.length; i < l; ++i) {
          var morph = this.morphs[i];
          morphs += this.indent+'  var '+morph[0]+' = '+morph[1]+';\n';
        }
        this.source.unshift(morphs);
      }

      if (this.fragmentProcessing.length) {
        var processing = "";
        for (i = 0, l = this.fragmentProcessing.length; i < l; ++i) {
          processing += this.indent+'  '+this.fragmentProcessing[i]+'\n';
        }
        this.source.unshift(processing);
      }

      return this.source.join('');
    };

    prototype.prepareArray = function(length) {
      var values = [];

      for (var i = 0; i < length; i++) {
        values.push(this.stack.pop());
      }

      this.stack.push('[' + values.join(', ') + ']');
    };

    prototype.prepareObject = function(size) {
      var pairs = [];

      for (var i = 0; i < size; i++) {
        pairs.push(this.stack.pop() + ': ' + this.stack.pop());
      }

      this.stack.push('{' + pairs.join(', ') + '}');
    };

    prototype.pushRaw = function(value) {
      this.stack.push(value);
    };

    prototype.openBoundary = function() {
      this.hasOpenBoundary = true;
    };

    prototype.closeBoundary = function() {
      this.hasCloseBoundary = true;
    };

    prototype.pushLiteral = function(value) {
      if (typeof value === 'string') {
        this.stack.push(string(value));
      } else {
        this.stack.push(value.toString());
      }
    };

    prototype.pushHook = function(name, args) {
      this.hooks[name] = true;
      this.stack.push(name + '(' + args.join(', ') + ')');
    };

    prototype.pushGetHook = function(path) {
      this.pushHook('get', [
        'env',
        'context',
        string(path)
      ]);
    };

    prototype.pushSexprHook = function() {
      this.pushHook('subexpr', [
        'env',
        'context',
        this.stack.pop(), // path
        this.stack.pop(), // params
        this.stack.pop() // hash
      ]);
    };

    prototype.pushConcatHook = function() {
      this.pushHook('concat', [
        'env',
        this.stack.pop() // parts
      ]);
    };

    prototype.printHook = function(name, args) {
      this.hooks[name] = true;
      this.source.push(this.indent + '  ' + name + '(' + args.join(', ') + ');\n');
    };

    prototype.printSetHook = function(name, index) {
      this.printHook('set', [
        'env',
        'context',
        string(name),
        'blockArguments[' + index + ']'
      ]);
    };

    prototype.printBlockHook = function(morphNum, templateId, inverseId) {
      this.printHook('block', [
        'env',
        'morph' + morphNum,
        'context',
        this.stack.pop(), // path
        this.stack.pop(), // params
        this.stack.pop(), // hash
        templateId === null ? 'null' : 'child' + templateId,
        inverseId === null ? 'null' : 'child' + inverseId
      ]);
    };

    prototype.printInlineHook = function(morphNum) {
      this.printHook('inline', [
        'env',
        'morph' + morphNum,
        'context',
        this.stack.pop(), // path
        this.stack.pop(), // params
        this.stack.pop() // hash
      ]);
    };

    prototype.printContentHook = function(morphNum) {
      this.printHook('content', [
        'env',
        'morph' + morphNum,
        'context',
        this.stack.pop() // path
      ]);
    };

    prototype.printComponentHook = function(morphNum, templateId) {
      this.printHook('component', [
        'env',
        'morph' + morphNum,
        'context',
        this.stack.pop(), // path
        this.stack.pop(), // attrs
        templateId === null ? 'null' : 'child' + templateId
      ]);
    };

    prototype.printAttributeHook = function(attrMorphNum, elementNum) {
      this.printHook('attribute', [
        'env',
        'attrMorph' + attrMorphNum,
        'element' + elementNum,
        this.stack.pop(), // name
        this.stack.pop() // value
      ]);
    };

    prototype.printElementHook = function(elementNum) {
      this.printHook('element', [
        'env',
        'element' + elementNum,
        'context',
        this.stack.pop(), // path
        this.stack.pop(), // params
        this.stack.pop() // hash
      ]);
    };

    prototype.createMorph = function(morphNum, parentPath, startIndex, endIndex, escaped) {
      var isRoot = parentPath.length === 0;
      var parent = this.getParent();

      var morphMethod = escaped ? 'createMorphAt' : 'createUnsafeMorphAt';
      var morph = "dom."+morphMethod+"("+parent+
        ","+(startIndex === null ? "-1" : startIndex)+
        ","+(endIndex === null ? "-1" : endIndex)+
        (isRoot ? ",contextualElement)" : ")");

      this.morphs.push(['morph' + morphNum, morph]);
    };

    prototype.createAttrMorph = function(attrMorphNum, elementNum, name, escaped, namespace) {
      var morphMethod = escaped ? 'createAttrMorph' : 'createUnsafeAttrMorph';
      var morph = "dom."+morphMethod+"(element"+elementNum+", '"+name+(namespace ? "', '"+namespace : '')+"')";
      this.morphs.push(['attrMorph' + attrMorphNum, morph]);
    };

    prototype.repairClonedNode = function(blankChildTextNodes, isElementChecked) {
      var parent = this.getParent(),
          processing = 'if (this.cachedFragment) { dom.repairClonedNode('+parent+','+
                       array(blankChildTextNodes)+
                       ( isElementChecked ? ',true' : '' )+
                       '); }';
      this.fragmentProcessing.push(
        processing
      );
    };

    prototype.shareElement = function(elementNum){
      var elementNodesName = "element" + elementNum;
      this.fragmentProcessing.push('var '+elementNodesName+' = '+this.getParent()+';');
      this.parents[this.parents.length-1] = [elementNodesName];
    };

    prototype.consumeParent = function(i) {
      var newParent = this.lastParent().slice();
      newParent.push(i);

      this.parents.push(newParent);
    };

    prototype.popParent = function() {
      this.parents.pop();
    };

    prototype.getParent = function() {
      var last = this.lastParent().slice();
      var frag = last.shift();

      if (!last.length) {
        return frag;
      }

      return 'dom.childAt(' + frag + ', [' + last.join(', ') + '])';
    };

    prototype.lastParent = function() {
      return this.parents[this.parents.length-1];
    };
  });
enifed("htmlbars-compiler/hydration-opcode-compiler",
  ["./template-visitor","./utils","../htmlbars-util","../htmlbars-util/array-utils","../htmlbars-syntax/utils","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __dependency5__, __exports__) {
    "use strict";
    var TemplateVisitor = __dependency1__["default"];
    var processOpcodes = __dependency2__.processOpcodes;
    var getAttrNamespace = __dependency3__.getAttrNamespace;
    var forEach = __dependency4__.forEach;
    var isHelper = __dependency5__.isHelper;

    function unwrapMustache(mustache) {
      if (isHelper(mustache.sexpr)) {
        return mustache.sexpr;
      } else {
        return mustache.sexpr.path;
      }
    }

    function detectIsElementChecked(element){
      for (var i=0, len=element.attributes.length;i<len;i++) {
        if (element.attributes[i].name === 'checked') {
          return true;
        }
      }
      return false;
    }

    function HydrationOpcodeCompiler() {
      this.opcodes = [];
      this.paths = [];
      this.templateId = 0;
      this.currentDOMChildIndex = 0;
      this.morphs = [];
      this.morphNum = 0;
      this.attrMorphNum = 0;
      this.element = null;
      this.elementNum = -1;
    }

    __exports__["default"] = HydrationOpcodeCompiler;

    HydrationOpcodeCompiler.prototype.compile = function(ast) {
      var templateVisitor = new TemplateVisitor();
      templateVisitor.visit(ast);

      processOpcodes(this, templateVisitor.actions);

      return this.opcodes;
    };

    HydrationOpcodeCompiler.prototype.accept = function(node) {
      this[node.type](node);
    };

    HydrationOpcodeCompiler.prototype.opcode = function(type) {
      var params = [].slice.call(arguments, 1);
      this.opcodes.push([type, params]);
    };

    HydrationOpcodeCompiler.prototype.startProgram = function(program, c, blankChildTextNodes) {
      this.opcodes.length = 0;
      this.paths.length = 0;
      this.morphs.length = 0;
      this.templateId = 0;
      this.currentDOMChildIndex = -1;
      this.morphNum = 0;
      this.attrMorphNum = 0;

      var blockParams = program.blockParams || [];

      for (var i = 0; i < blockParams.length; i++) {
        this.opcode('printSetHook', blockParams[i], i);
      }

      if (blankChildTextNodes.length > 0) {
        this.opcode('repairClonedNode', blankChildTextNodes);
      }
    };

    HydrationOpcodeCompiler.prototype.endProgram = function() {
      distributeMorphs(this.morphs, this.opcodes);
    };

    HydrationOpcodeCompiler.prototype.text = function() {
      ++this.currentDOMChildIndex;
    };

    HydrationOpcodeCompiler.prototype.comment = function() {
      ++this.currentDOMChildIndex;
    };

    HydrationOpcodeCompiler.prototype.openElement = function(element, pos, len, mustacheCount, blankChildTextNodes) {
      distributeMorphs(this.morphs, this.opcodes);
      ++this.currentDOMChildIndex;

      this.element = this.currentDOMChildIndex;

      this.opcode('consumeParent', this.currentDOMChildIndex);

      // If our parent reference will be used more than once, cache its reference.
      if (mustacheCount > 1) {
        this.opcode('shareElement', ++this.elementNum);
        this.element = null; // Set element to null so we don't cache it twice
      }

      var isElementChecked = detectIsElementChecked(element);
      if (blankChildTextNodes.length > 0 || isElementChecked) {
        this.opcode( 'repairClonedNode',
                     blankChildTextNodes,
                     isElementChecked );
      }

      this.paths.push(this.currentDOMChildIndex);
      this.currentDOMChildIndex = -1;

      forEach(element.attributes, this.attribute, this);
      forEach(element.modifiers, this.elementModifier, this);
    };

    HydrationOpcodeCompiler.prototype.closeElement = function() {
      distributeMorphs(this.morphs, this.opcodes);
      this.opcode('popParent');
      this.currentDOMChildIndex = this.paths.pop();
    };

    HydrationOpcodeCompiler.prototype.mustache = function(mustache, childIndex, childCount) {
      this.pushMorphPlaceholderNode(childIndex, childCount);
      
      var sexpr = mustache.sexpr;

      var morphNum = this.morphNum++;
      var start = this.currentDOMChildIndex;
      var end = this.currentDOMChildIndex;
      this.morphs.push([morphNum, this.paths.slice(), start, end, mustache.escaped]);

      if (isHelper(sexpr)) {
        prepareSexpr(this, sexpr);
        this.opcode('printInlineHook', morphNum);
      } else {
        preparePath(this, sexpr.path);
        this.opcode('printContentHook', morphNum);
      }
    };

    HydrationOpcodeCompiler.prototype.block = function(block, childIndex, childCount) {
      this.pushMorphPlaceholderNode(childIndex, childCount);

      var sexpr = block.sexpr;

      var morphNum = this.morphNum++;
      var start = this.currentDOMChildIndex;
      var end = this.currentDOMChildIndex;
      this.morphs.push([morphNum, this.paths.slice(), start, end, true]);

      var templateId = this.templateId++;
      var inverseId = block.inverse === null ? null : this.templateId++;

      prepareSexpr(this, sexpr);
      this.opcode('printBlockHook', morphNum, templateId, inverseId);
    };

    HydrationOpcodeCompiler.prototype.component = function(component, childIndex, childCount) {
      this.pushMorphPlaceholderNode(childIndex, childCount);

      var program = component.program || {};
      var blockParams = program.blockParams || [];

      var morphNum = this.morphNum++;
      var start = this.currentDOMChildIndex;
      var end = this.currentDOMChildIndex;
      this.morphs.push([morphNum, this.paths.slice(), start, end, true]);

      var attrs = component.attributes;
      for (var i = attrs.length - 1; i >= 0; i--) {
        var name = attrs[i].name;
        var value = attrs[i].value;

        // TODO: Introduce context specific AST nodes to avoid switching here.
        if (value.type === 'TextNode') {
          this.opcode('pushLiteral', value.chars);
        } else if (value.type === 'MustacheStatement') {
          this.accept(unwrapMustache(value));
        } else if (value.type === 'ConcatStatement') {
          prepareParams(this, value.parts);
          this.opcode('pushConcatHook');
        }

        this.opcode('pushLiteral', name);
      }

      this.opcode('prepareObject', attrs.length);
      this.opcode('pushLiteral', component.tag);
      this.opcode('printComponentHook', morphNum, this.templateId++, blockParams.length);
    };

    HydrationOpcodeCompiler.prototype.attribute = function(attr) {
      var value = attr.value;
      var escaped = true;
      var namespace = getAttrNamespace(attr.name);

      // TODO: Introduce context specific AST nodes to avoid switching here.
      if (value.type === 'TextNode') {
        return;
      } else if (value.type === 'MustacheStatement') {
        escaped = value.escaped;
        this.accept(unwrapMustache(value));
      } else if (value.type === 'ConcatStatement') {
        prepareParams(this, value.parts);
        this.opcode('pushConcatHook');
      }

      this.opcode('pushLiteral', attr.name);

      if (this.element !== null) {
        this.opcode('shareElement', ++this.elementNum);
        this.element = null;
      }

      var attrMorphNum = this.attrMorphNum++;
      this.opcode('createAttrMorph', attrMorphNum, this.elementNum, attr.name, escaped, namespace);
      this.opcode('printAttributeHook', attrMorphNum, this.elementNum);
    };

    HydrationOpcodeCompiler.prototype.elementModifier = function(modifier) {
      prepareSexpr(this, modifier.sexpr);

      // If we have a helper in a node, and this element has not been cached, cache it
      if (this.element !== null) {
        this.opcode('shareElement', ++this.elementNum);
        this.element = null; // Reset element so we don't cache it more than once
      }

      this.opcode('printElementHook', this.elementNum);
    };

    HydrationOpcodeCompiler.prototype.pushMorphPlaceholderNode = function(childIndex, childCount) {
      if (this.paths.length === 0) {
        if (childIndex === 0) {
          this.opcode('openBoundary');
        }
        if (childIndex === childCount - 1) {
          this.opcode('closeBoundary');
        }
      }
      this.comment();
    };

    HydrationOpcodeCompiler.prototype.SubExpression = function(sexpr) {
      prepareSexpr(this, sexpr);
      this.opcode('pushSexprHook');
    };

    HydrationOpcodeCompiler.prototype.PathExpression = function(path) {
      this.opcode('pushGetHook', path.original);
    };

    HydrationOpcodeCompiler.prototype.StringLiteral = function(node) {
      this.opcode('pushLiteral', node.value);
    };

    HydrationOpcodeCompiler.prototype.BooleanLiteral = function(node) {
      this.opcode('pushLiteral', node.value);
    };

    HydrationOpcodeCompiler.prototype.NumberLiteral = function(node) {
      this.opcode('pushLiteral', node.value);
    };

    function preparePath(compiler, path) {
      compiler.opcode('pushLiteral', path.original);
    }

    function prepareParams(compiler, params) {
      for (var i = params.length - 1; i >= 0; i--) {
        var param = params[i];
        compiler[param.type](param);
      }

      compiler.opcode('prepareArray', params.length);
    }

    function prepareHash(compiler, hash) {
      var pairs = hash.pairs;

      for (var i = pairs.length - 1; i >= 0; i--) {
        var key = pairs[i].key;
        var value = pairs[i].value;

        compiler[value.type](value);
        compiler.opcode('pushLiteral', key);
      }

      compiler.opcode('prepareObject', pairs.length);
    }

    function prepareSexpr(compiler, sexpr) {
      prepareHash(compiler, sexpr.hash);
      prepareParams(compiler, sexpr.params);
      preparePath(compiler, sexpr.path);
    }

    function distributeMorphs(morphs, opcodes) {
      if (morphs.length === 0) {
        return;
      }

      // Splice morphs after the most recent shareParent/consumeParent.
      var o;
      for (o = opcodes.length - 1; o >= 0; --o) {
        var opcode = opcodes[o][0];
        if (opcode === 'shareElement' || opcode === 'consumeParent'  || opcode === 'popParent') {
          break;
        }
      }

      var spliceArgs = [o + 1, 0];
      for (var i = 0; i < morphs.length; ++i) {
        spliceArgs.push(['createMorph', morphs[i].slice()]);
      }
      opcodes.splice.apply(opcodes, spliceArgs);
      morphs.length = 0;
    }
  });
enifed("htmlbars-compiler/template-compiler",
  ["./fragment-opcode-compiler","./fragment-javascript-compiler","./hydration-opcode-compiler","./hydration-javascript-compiler","./template-visitor","./utils","../htmlbars-util/quoting","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __dependency5__, __dependency6__, __dependency7__, __exports__) {
    "use strict";
    var FragmentOpcodeCompiler = __dependency1__["default"];
    var FragmentJavaScriptCompiler = __dependency2__["default"];
    var HydrationOpcodeCompiler = __dependency3__["default"];
    var HydrationJavaScriptCompiler = __dependency4__["default"];
    var TemplateVisitor = __dependency5__["default"];
    var processOpcodes = __dependency6__.processOpcodes;
    var repeat = __dependency7__.repeat;

    function TemplateCompiler(options) {
      this.options = options || {};
      this.revision = this.options.revision || "HTMLBars@v0.11.2";
      this.fragmentOpcodeCompiler = new FragmentOpcodeCompiler();
      this.fragmentCompiler = new FragmentJavaScriptCompiler();
      this.hydrationOpcodeCompiler = new HydrationOpcodeCompiler();
      this.hydrationCompiler = new HydrationJavaScriptCompiler();
      this.templates = [];
      this.childTemplates = [];
    }

    __exports__["default"] = TemplateCompiler;

    TemplateCompiler.prototype.compile = function(ast) {
      var templateVisitor = new TemplateVisitor();
      templateVisitor.visit(ast);

      processOpcodes(this, templateVisitor.actions);

      return this.templates.pop();
    };

    TemplateCompiler.prototype.startProgram = function(program, childTemplateCount, blankChildTextNodes) {
      this.fragmentOpcodeCompiler.startProgram(program, childTemplateCount, blankChildTextNodes);
      this.hydrationOpcodeCompiler.startProgram(program, childTemplateCount, blankChildTextNodes);

      this.childTemplates.length = 0;
      while(childTemplateCount--) {
        this.childTemplates.push(this.templates.pop());
      }
    };

    TemplateCompiler.prototype.getChildTemplateVars = function(indent) {
      var vars = '';
      if (this.childTemplates) {
        for (var i = 0; i < this.childTemplates.length; i++) {
          vars += indent + 'var child' + i + ' = ' + this.childTemplates[i] + ';\n';
        }
      }
      return vars;
    };

    TemplateCompiler.prototype.getHydrationHooks = function(indent, hooks) {
      var hookVars = [];
      for (var hook in hooks) {
        hookVars.push(hook + ' = hooks.' + hook);
      }

      if (hookVars.length > 0) {
        return indent + 'var hooks = env.hooks, ' + hookVars.join(', ') + ';\n';
      } else {
        return '';
      }
    };

    TemplateCompiler.prototype.endProgram = function(program, programDepth) {
      this.fragmentOpcodeCompiler.endProgram(program);
      this.hydrationOpcodeCompiler.endProgram(program);

      var indent = repeat("  ", programDepth);
      var options = {
        indent: indent + "    "
      };

      // function build(dom) { return fragment; }
      var fragmentProgram = this.fragmentCompiler.compile(
        this.fragmentOpcodeCompiler.opcodes,
        options
      );

      // function hydrate(fragment) { return mustaches; }
      var hydrationProgram = this.hydrationCompiler.compile(
        this.hydrationOpcodeCompiler.opcodes,
        options
      );

      var blockParams = program.blockParams || [];

      var templateSignature = 'context, env, contextualElement';
      if (blockParams.length > 0) {
        templateSignature += ', blockArguments';
      }

      var template =
        '(function() {\n' +
        this.getChildTemplateVars(indent + '  ') +
        indent+'  return {\n' +
        indent+'    isHTMLBars: true,\n' +
        indent+'    revision: "' + this.revision + '",\n' +
        indent+'    blockParams: ' + blockParams.length + ',\n' +
        indent+'    cachedFragment: null,\n' +
        indent+'    hasRendered: false,\n' +
        indent+'    build: ' + fragmentProgram + ',\n' +
        indent+'    render: function render(' + templateSignature + ') {\n' +
        indent+'      var dom = env.dom;\n' +
        this.getHydrationHooks(indent + '      ', this.hydrationCompiler.hooks) +
        indent+'      dom.detectNamespace(contextualElement);\n' +
        indent+'      var fragment;\n' +
        indent+'      if (env.useFragmentCache && dom.canClone) {\n' +
        indent+'        if (this.cachedFragment === null) {\n' +
        indent+'          fragment = this.build(dom);\n' +
        indent+'          if (this.hasRendered) {\n' +
        indent+'            this.cachedFragment = fragment;\n' +
        indent+'          } else {\n' +
        indent+'            this.hasRendered = true;\n' +
        indent+'          }\n' +
        indent+'        }\n' +
        indent+'        if (this.cachedFragment) {\n' +
        indent+'          fragment = dom.cloneNode(this.cachedFragment, true);\n' +
        indent+'        }\n' +
        indent+'      } else {\n' +
        indent+'        fragment = this.build(dom);\n' +
        indent+'      }\n' +
        hydrationProgram +
        indent+'      return fragment;\n' +
        indent+'    }\n' +
        indent+'  };\n' +
        indent+'}())';

      this.templates.push(template);
    };

    TemplateCompiler.prototype.openElement = function(element, i, l, r, c, b) {
      this.fragmentOpcodeCompiler.openElement(element, i, l, r, c, b);
      this.hydrationOpcodeCompiler.openElement(element, i, l, r, c, b);
    };

    TemplateCompiler.prototype.closeElement = function(element, i, l, r) {
      this.fragmentOpcodeCompiler.closeElement(element, i, l, r);
      this.hydrationOpcodeCompiler.closeElement(element, i, l, r);
    };

    TemplateCompiler.prototype.component = function(component, i, l, s) {
      this.fragmentOpcodeCompiler.component(component, i, l, s);
      this.hydrationOpcodeCompiler.component(component, i, l, s);
    };

    TemplateCompiler.prototype.block = function(block, i, l, s) {
      this.fragmentOpcodeCompiler.block(block, i, l, s);
      this.hydrationOpcodeCompiler.block(block, i, l, s);
    };

    TemplateCompiler.prototype.text = function(string, i, l, r) {
      this.fragmentOpcodeCompiler.text(string, i, l, r);
      this.hydrationOpcodeCompiler.text(string, i, l, r);
    };

    TemplateCompiler.prototype.comment = function(string, i, l, r) {
      this.fragmentOpcodeCompiler.comment(string, i, l, r);
      this.hydrationOpcodeCompiler.comment(string, i, l, r);
    };

    TemplateCompiler.prototype.mustache = function (mustache, i, l, s) {
      this.fragmentOpcodeCompiler.mustache(mustache, i, l, s);
      this.hydrationOpcodeCompiler.mustache(mustache, i, l, s);
    };

    TemplateCompiler.prototype.setNamespace = function(namespace) {
      this.fragmentOpcodeCompiler.setNamespace(namespace);
    };
  });
enifed("htmlbars-compiler/template-visitor",
  ["exports"],
  function(__exports__) {
    "use strict";
    var push = Array.prototype.push;

    function Frame() {
      this.parentNode = null;
      this.children = null;
      this.childIndex = null;
      this.childCount = null;
      this.childTemplateCount = 0;
      this.mustacheCount = 0;
      this.actions = [];
    }

    /**
     * Takes in an AST and outputs a list of actions to be consumed
     * by a compiler. For example, the template
     *
     *     foo{{bar}}<div>baz</div>
     *
     * produces the actions
     *
     *     [['startProgram', [programNode, 0]],
     *      ['text', [textNode, 0, 3]],
     *      ['mustache', [mustacheNode, 1, 3]],
     *      ['openElement', [elementNode, 2, 3, 0]],
     *      ['text', [textNode, 0, 1]],
     *      ['closeElement', [elementNode, 2, 3],
     *      ['endProgram', [programNode]]]
     *
     * This visitor walks the AST depth first and backwards. As
     * a result the bottom-most child template will appear at the
     * top of the actions list whereas the root template will appear
     * at the bottom of the list. For example,
     *
     *     <div>{{#if}}foo{{else}}bar<b></b>{{/if}}</div>
     *
     * produces the actions
     *
     *     [['startProgram', [programNode, 0]],
     *      ['text', [textNode, 0, 2, 0]],
     *      ['openElement', [elementNode, 1, 2, 0]],
     *      ['closeElement', [elementNode, 1, 2]],
     *      ['endProgram', [programNode]],
     *      ['startProgram', [programNode, 0]],
     *      ['text', [textNode, 0, 1]],
     *      ['endProgram', [programNode]],
     *      ['startProgram', [programNode, 2]],
     *      ['openElement', [elementNode, 0, 1, 1]],
     *      ['block', [blockNode, 0, 1]],
     *      ['closeElement', [elementNode, 0, 1]],
     *      ['endProgram', [programNode]]]
     *
     * The state of the traversal is maintained by a stack of frames.
     * Whenever a node with children is entered (either a ProgramNode
     * or an ElementNode) a frame is pushed onto the stack. The frame
     * contains information about the state of the traversal of that
     * node. For example,
     *
     *   - index of the current child node being visited
     *   - the number of mustaches contained within its child nodes
     *   - the list of actions generated by its child nodes
     */

    function TemplateVisitor() {
      this.frameStack = [];
      this.actions = [];
      this.programDepth = -1;
    }

    // Traversal methods

    TemplateVisitor.prototype.visit = function(node) {
      this[node.type](node);
    };

    TemplateVisitor.prototype.Program = function(program) {
      this.programDepth++;

      var parentFrame = this.getCurrentFrame();
      var programFrame = this.pushFrame();

      programFrame.parentNode = program;
      programFrame.children = program.body;
      programFrame.childCount = program.body.length;
      programFrame.blankChildTextNodes = [];
      programFrame.actions.push(['endProgram', [program, this.programDepth]]);

      for (var i = program.body.length - 1; i >= 0; i--) {
        programFrame.childIndex = i;
        this.visit(program.body[i]);
      }

      programFrame.actions.push(['startProgram', [
        program, programFrame.childTemplateCount,
        programFrame.blankChildTextNodes.reverse()
      ]]);
      this.popFrame();

      this.programDepth--;

      // Push the completed template into the global actions list
      if (parentFrame) { parentFrame.childTemplateCount++; }
      push.apply(this.actions, programFrame.actions.reverse());
    };

    TemplateVisitor.prototype.ElementNode = function(element) {
      var parentFrame = this.getCurrentFrame();
      var elementFrame = this.pushFrame();

      elementFrame.parentNode = element;
      elementFrame.children = element.children;
      elementFrame.childCount = element.children.length;
      elementFrame.mustacheCount += element.modifiers.length;
      elementFrame.blankChildTextNodes = [];

      var actionArgs = [
        element,
        parentFrame.childIndex,
        parentFrame.childCount
      ];

      elementFrame.actions.push(['closeElement', actionArgs]);

      for (var i = element.attributes.length - 1; i >= 0; i--) {
        this.visit(element.attributes[i]);
      }

      for (i = element.children.length - 1; i >= 0; i--) {
        elementFrame.childIndex = i;
        this.visit(element.children[i]);
      }

      elementFrame.actions.push(['openElement', actionArgs.concat([
        elementFrame.mustacheCount, elementFrame.blankChildTextNodes.reverse() ])]);
      this.popFrame();

      // Propagate the element's frame state to the parent frame
      if (elementFrame.mustacheCount > 0) { parentFrame.mustacheCount++; }
      parentFrame.childTemplateCount += elementFrame.childTemplateCount;
      push.apply(parentFrame.actions, elementFrame.actions);
    };

    TemplateVisitor.prototype.AttrNode = function(attr) {
      if (attr.value.type !== 'TextNode') {
        this.getCurrentFrame().mustacheCount++;
      }
    };

    TemplateVisitor.prototype.TextNode = function(text) {
      var frame = this.getCurrentFrame();
      if (text.chars === '') {
        frame.blankChildTextNodes.push(domIndexOf(frame.children, text));
      }
      frame.actions.push(['text', [text, frame.childIndex, frame.childCount]]);
    };

    TemplateVisitor.prototype.BlockStatement = function(node) {
      var frame = this.getCurrentFrame();

      frame.mustacheCount++;
      frame.actions.push(['block', [node, frame.childIndex, frame.childCount]]);

      if (node.inverse) { this.visit(node.inverse); }
      if (node.program) { this.visit(node.program); }
    };

    TemplateVisitor.prototype.ComponentNode = function(node) {
      var frame = this.getCurrentFrame();

      frame.mustacheCount++;
      frame.actions.push(['component', [node, frame.childIndex, frame.childCount]]);

      if (node.program) { this.visit(node.program); }
    };


    TemplateVisitor.prototype.PartialStatement = function(node) {
      var frame = this.getCurrentFrame();
      frame.mustacheCount++;
      frame.actions.push(['mustache', [node, frame.childIndex, frame.childCount]]);
    };

    TemplateVisitor.prototype.CommentStatement = function(text) {
      var frame = this.getCurrentFrame();
      frame.actions.push(['comment', [text, frame.childIndex, frame.childCount]]);
    };

    TemplateVisitor.prototype.MustacheStatement = function(mustache) {
      var frame = this.getCurrentFrame();
      frame.mustacheCount++;
      frame.actions.push(['mustache', [mustache, frame.childIndex, frame.childCount]]);
    };

    // Frame helpers

    TemplateVisitor.prototype.getCurrentFrame = function() {
      return this.frameStack[this.frameStack.length - 1];
    };

    TemplateVisitor.prototype.pushFrame = function() {
      var frame = new Frame();
      this.frameStack.push(frame);
      return frame;
    };

    TemplateVisitor.prototype.popFrame = function() {
      return this.frameStack.pop();
    };

    __exports__["default"] = TemplateVisitor;


    // Returns the index of `domNode` in the `nodes` array, skipping
    // over any nodes which do not represent DOM nodes.
    function domIndexOf(nodes, domNode) {
      var index = -1;

      for (var i = 0; i < nodes.length; i++) {
        var node = nodes[i];

        if (node.type !== 'TextNode' && node.type !== 'ElementNode') {
          continue;
        } else {
          index++;
        }

        if (node === domNode) {
          return index;
        }
      }

      return -1;
    }
  });
enifed("htmlbars-compiler/utils",
  ["exports"],
  function(__exports__) {
    "use strict";
    function processOpcodes(compiler, opcodes) {
      for (var i=0, l=opcodes.length; i<l; i++) {
        var method = opcodes[i][0];
        var params = opcodes[i][1];
        if (params) {
          compiler[method].apply(compiler, params);
        } else {
          compiler[method].call(compiler);
        }
      }
    }

    __exports__.processOpcodes = processOpcodes;
  });
enifed("htmlbars-runtime",
  ["htmlbars-runtime/hooks","htmlbars-runtime/helpers","exports"],
  function(__dependency1__, __dependency2__, __exports__) {
    "use strict";
    var hooks = __dependency1__["default"];
    var helpers = __dependency2__["default"];

    __exports__.hooks = hooks;
    __exports__.helpers = helpers;
  });
enifed("htmlbars-runtime/helpers",
  ["exports"],
  function(__exports__) {
    "use strict";
    function partial(params, hash, options, env) {
      var template = env.partials[params[0]];
      return template.render(this, env, options.morph.contextualElement);
    }

    __exports__.partial = partial;__exports__["default"] = {
      partial: partial
    };
  });
enifed("htmlbars-runtime/hooks",
  ["exports"],
  function(__exports__) {
    "use strict";
    function block(env, morph, context, path, params, hash, template, inverse) {
      var options = {
        morph: morph,
        template: template,
        inverse: inverse
      };

      var helper = lookupHelper(env, context, path);
      var value = helper.call(context, params, hash, options, env);

      morph.setContent(value);
    }

    __exports__.block = block;function inline(env, morph, context, path, params, hash) {
      var helper = lookupHelper(env, context, path);
      var value = helper.call(context, params, hash, { morph: morph }, env);

      morph.setContent(value);
    }

    __exports__.inline = inline;function content(env, morph, context, path) {
      var helper = lookupHelper(env, context, path);

      var value;
      if (helper) {
        value = helper.call(context, [], {}, { morph: morph }, env);
      } else {
        value = get(env, context, path);
      }

      morph.setContent(value);
    }

    __exports__.content = content;function element(env, domElement, context, path, params, hash) {
      var helper = lookupHelper(env, context, path);
      if (helper) {
        helper.call(context, params, hash, { element: domElement }, env);
      }
    }

    __exports__.element = element;function attribute(env, attrMorph, domElement, name, value) {
      attrMorph.setContent(value);
    }

    __exports__.attribute = attribute;function subexpr(env, context, helperName, params, hash) {
      var helper = lookupHelper(env, context, helperName);
      if (helper) {
        return helper.call(context, params, hash, {}, env);
      } else {
        return get(env, context, helperName);
      }
    }

    __exports__.subexpr = subexpr;function get(env, context, path) {
      if (path === '') {
        return context;
      }

      var keys = path.split('.');
      var value = context;
      for (var i = 0; i < keys.length; i++) {
        if (value) {
          value = value[keys[i]];
        } else {
          break;
        }
      }
      return value;
    }

    __exports__.get = get;function set(env, context, name, value) {
      context[name] = value;
    }

    __exports__.set = set;function component(env, morph, context, tagName, attrs, template) {
      var helper = lookupHelper(env, context, tagName);

      var value;
      if (helper) {
        var options = {
          morph: morph,
          template: template
        };

        value = helper.call(context, [], attrs, options, env);
      } else {
        value = componentFallback(env, morph, context, tagName, attrs, template);
      }

      morph.setContent(value);
    }

    __exports__.component = component;function concat(env, params) {
      var value = "";
      for (var i = 0, l = params.length; i < l; i++) {
        value += params[i];
      }
      return value;
    }

    __exports__.concat = concat;function componentFallback(env, morph, context, tagName, attrs, template) {
      var element = env.dom.createElement(tagName);
      for (var name in attrs) {
        element.setAttribute(name, attrs[name]);
      }
      element.appendChild(template.render(context, env, morph.contextualElement));
      return element;
    }

    function lookupHelper(env, context, helperName) {
      return env.helpers[helperName];
    }

    __exports__["default"] = {
      content: content,
      block: block,
      inline: inline,
      component: component,
      element: element,
      attribute: attribute,
      subexpr: subexpr,
      concat: concat,
      get: get,
      set: set
    };
  });
enifed("htmlbars-syntax",
  ["./htmlbars-syntax/walker","./htmlbars-syntax/builders","./htmlbars-syntax/parser","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __exports__) {
    "use strict";
    var Walker = __dependency1__["default"];
    var builders = __dependency2__["default"];
    var parse = __dependency3__.preprocess;

    __exports__.Walker = Walker;
    __exports__.builders = builders;
    __exports__.parse = parse;
  });
enifed("htmlbars-syntax/builders",
  ["exports"],
  function(__exports__) {
    "use strict";
    // Statements

    function buildMustache(sexpr, raw) {
      return {
        type: "MustacheStatement",
        sexpr: sexpr,
        escaped: !raw
      };
    }

    __exports__.buildMustache = buildMustache;function buildBlock(sexpr, program, inverse) {
      return {
        type: "BlockStatement",
        sexpr: sexpr,
        program: program || null,
        inverse: inverse || null
      };
    }

    __exports__.buildBlock = buildBlock;function buildPartial(sexpr, indent) {
      return {
        type: "PartialStatement",
        sexpr: sexpr,
        indent: indent
      };
    }

    __exports__.buildPartial = buildPartial;function buildComment(value) {
      return {
        type: "CommentStatement",
        value: value
      };
    }

    __exports__.buildComment = buildComment;function buildConcat(parts) {
      return {
        type: "ConcatStatement",
        parts: parts || []
      };
    }

    __exports__.buildConcat = buildConcat;function buildElementModifier(sexpr) {
      return {
        type: "ElementModifierStatement",
        sexpr: sexpr
      };
    }

    __exports__.buildElementModifier = buildElementModifier;// Nodes

    function buildElement(tag, attributes, modifiers, children) {
      return {
        type: "ElementNode",
        tag: tag,
        attributes: attributes || [],
        modifiers: modifiers || [],
        children: children || []
      };
    }

    __exports__.buildElement = buildElement;function buildComponent(tag, attributes, program) {
      return {
        type: "ComponentNode",
        tag: tag,
        attributes: attributes,
        program: program
      };
    }

    __exports__.buildComponent = buildComponent;function buildAttr(name, value) {
      return {
        type: "AttrNode",
        name: name,
        value: value
      };
    }

    __exports__.buildAttr = buildAttr;function buildText(chars) {
      return {
        type: "TextNode",
        chars: chars
      };
    }

    __exports__.buildText = buildText;// Expressions

    function buildSexpr(path, params, hash) {
      return {
        type: "SubExpression",
        path: path,
        params: params || [],
        hash: hash || buildHash([])
      };
    }

    __exports__.buildSexpr = buildSexpr;function buildPath(original) {
      return {
        type: "PathExpression",
        original: original,
        parts: original.split('.')
      };
    }

    __exports__.buildPath = buildPath;function buildString(value) {
      return {
        type: "StringLiteral",
        value: value,
        original: value
      };
    }

    __exports__.buildString = buildString;function buildBoolean(value) {
      return {
        type: "BooleanLiteral",
        value: value,
        original: value
      };
    }

    __exports__.buildBoolean = buildBoolean;function buildNumber(value) {
      return {
        type: "NumberLiteral",
        value: value,
        original: value
      };
    }

    __exports__.buildNumber = buildNumber;// Miscellaneous

    function buildHash(pairs) {
      return {
        type: "Hash",
        pairs: pairs || []
      };
    }

    __exports__.buildHash = buildHash;function buildPair(key, value) {
      return {
        type: "HashPair",
        key: key,
        value: value
      };
    }

    __exports__.buildPair = buildPair;function buildProgram(body, blockParams) {
      return {
        type: "Program",
        body: body || [],
        blockParams: blockParams || []
      };
    }

    __exports__.buildProgram = buildProgram;__exports__["default"] = {
      mustache: buildMustache,
      block: buildBlock,
      partial: buildPartial,
      comment: buildComment,
      element: buildElement,
      elementModifier: buildElementModifier,
      component: buildComponent,
      attr: buildAttr,
      text: buildText,
      sexpr: buildSexpr,
      path: buildPath,
      string: buildString,
      "boolean": buildBoolean,
      number: buildNumber,
      concat: buildConcat,
      hash: buildHash,
      pair: buildPair,
      program: buildProgram
    };
  });
enifed("htmlbars-syntax/handlebars/compiler/ast",
  ["../exception","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var Exception = __dependency1__["default"];

    var AST = {
      Program: function(statements, blockParams, strip, locInfo) {
        this.loc = locInfo;
        this.type = 'Program';
        this.body = statements;

        this.blockParams = blockParams;
        this.strip = strip;
      },

      MustacheStatement: function(sexpr, escaped, strip, locInfo) {
        this.loc = locInfo;
        this.type = 'MustacheStatement';

        this.sexpr = sexpr;
        this.escaped = escaped;

        this.strip = strip;
      },

      BlockStatement: function(sexpr, program, inverse, openStrip, inverseStrip, closeStrip, locInfo) {
        this.loc = locInfo;

        this.type = 'BlockStatement';
        this.sexpr = sexpr;
        this.program  = program;
        this.inverse  = inverse;

        this.openStrip = openStrip;
        this.inverseStrip = inverseStrip;
        this.closeStrip = closeStrip;
      },

      PartialStatement: function(sexpr, strip, locInfo) {
        this.loc = locInfo;
        this.type = 'PartialStatement';
        this.sexpr = sexpr;
        this.indent = '';

        this.strip = strip;
      },

      ContentStatement: function(string, locInfo) {
        this.loc = locInfo;
        this.type = 'ContentStatement';
        this.original = this.value = string;
      },

      CommentStatement: function(comment, strip, locInfo) {
        this.loc = locInfo;
        this.type = 'CommentStatement';
        this.value = comment;

        this.strip = strip;
      },

      SubExpression: function(path, params, hash, locInfo) {
        this.loc = locInfo;

        this.type = 'SubExpression';
        this.path = path;
        this.params = params || [];
        this.hash = hash;
      },

      PathExpression: function(data, depth, parts, original, locInfo) {
        this.loc = locInfo;
        this.type = 'PathExpression';

        this.data = data;
        this.original = original;
        this.parts    = parts;
        this.depth    = depth;
      },

      StringLiteral: function(string, locInfo) {
        this.loc = locInfo;
        this.type = 'StringLiteral';
        this.original =
          this.value = string;
      },

      NumberLiteral: function(number, locInfo) {
        this.loc = locInfo;
        this.type = 'NumberLiteral';
        this.original =
          this.value = Number(number);
      },

      BooleanLiteral: function(bool, locInfo) {
        this.loc = locInfo;
        this.type = 'BooleanLiteral';
        this.original =
          this.value = bool === 'true';
      },

      Hash: function(pairs, locInfo) {
        this.loc = locInfo;
        this.type = 'Hash';
        this.pairs = pairs;
      },
      HashPair: function(key, value, locInfo) {
        this.loc = locInfo;
        this.type = 'HashPair';
        this.key = key;
        this.value = value;
      }
    };


    // Must be exported as an object rather than the root of the module as the jison lexer
    // most modify the object to operate properly.
    __exports__["default"] = AST;
  });
enifed("htmlbars-syntax/handlebars/compiler/base",
  ["./parser","./ast","./whitespace-control","./helpers","../utils","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __dependency5__, __exports__) {
    "use strict";
    var parser = __dependency1__["default"];
    var AST = __dependency2__["default"];
    var WhitespaceControl = __dependency3__["default"];
    var Helpers = __dependency4__;
    var extend = __dependency5__.extend;

    __exports__.parser = parser;

    var yy = {};
    extend(yy, Helpers, AST);

    function parse(input, options) {
      // Just return if an already-compile AST was passed in.
      if (input.type === 'Program') { return input; }

      parser.yy = yy;

      // Altering the shared object here, but this is ok as parser is a sync operation
      yy.locInfo = function(locInfo) {
        return new yy.SourceLocation(options && options.srcName, locInfo);
      };

      var strip = new WhitespaceControl();
      return strip.accept(parser.parse(input));
    }

    __exports__.parse = parse;
  });
enifed("htmlbars-syntax/handlebars/compiler/helpers",
  ["../exception","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var Exception = __dependency1__["default"];

    function SourceLocation(source, locInfo) {
      this.source = source;
      this.start = {
        line: locInfo.first_line,
        column: locInfo.first_column
      };
      this.end = {
        line: locInfo.last_line,
        column: locInfo.last_column
      };
    }

    __exports__.SourceLocation = SourceLocation;function stripFlags(open, close) {
      return {
        open: open.charAt(2) === '~',
        close: close.charAt(close.length-3) === '~'
      };
    }

    __exports__.stripFlags = stripFlags;function stripComment(comment) {
      return comment.replace(/^\{\{~?\!-?-?/, '')
                    .replace(/-?-?~?\}\}$/, '');
    }

    __exports__.stripComment = stripComment;function preparePath(data, parts, locInfo) {
      /*jshint -W040 */
      locInfo = this.locInfo(locInfo);

      var original = data ? '@' : '',
          dig = [],
          depth = 0,
          depthString = '';

      for(var i=0,l=parts.length; i<l; i++) {
        var part = parts[i].part;
        original += (parts[i].separator || '') + part;

        if (part === '..' || part === '.' || part === 'this') {
          if (dig.length > 0) {
            throw new Exception('Invalid path: ' + original, {loc: locInfo});
          } else if (part === '..') {
            depth++;
            depthString += '../';
          }
        } else {
          dig.push(part);
        }
      }

      return new this.PathExpression(data, depth, dig, original, locInfo);
    }

    __exports__.preparePath = preparePath;function prepareMustache(sexpr, open, strip, locInfo) {
      /*jshint -W040 */
      // Must use charAt to support IE pre-10
      var escapeFlag = open.charAt(3) || open.charAt(2),
          escaped = escapeFlag !== '{' && escapeFlag !== '&';

      return new this.MustacheStatement(sexpr, escaped, strip, this.locInfo(locInfo));
    }

    __exports__.prepareMustache = prepareMustache;function prepareRawBlock(openRawBlock, content, close, locInfo) {
      /*jshint -W040 */
      if (openRawBlock.sexpr.path.original !== close) {
        var errorNode = {loc: openRawBlock.sexpr.loc};

        throw new Exception(openRawBlock.sexpr.path.original + " doesn't match " + close, errorNode);
      }

      locInfo = this.locInfo(locInfo);
      var program = new this.Program([content], null, {}, locInfo);

      return new this.BlockStatement(
          openRawBlock.sexpr, program, undefined,
          {}, {}, {},
          locInfo);
    }

    __exports__.prepareRawBlock = prepareRawBlock;function prepareBlock(openBlock, program, inverseAndProgram, close, inverted, locInfo) {
      /*jshint -W040 */
      // When we are chaining inverse calls, we will not have a close path
      if (close && close.path && openBlock.sexpr.path.original !== close.path.original) {
        var errorNode = {loc: openBlock.sexpr.loc};

        throw new Exception(openBlock.sexpr.path.original + ' doesn\'t match ' + close.path.original, errorNode);
      }

      program.blockParams = openBlock.blockParams;

      var inverse,
          inverseStrip;

      if (inverseAndProgram) {
        if (inverseAndProgram.chain) {
          inverseAndProgram.program.body[0].closeStrip = close.strip || close.openStrip;
        }

        inverseStrip = inverseAndProgram.strip;
        inverse = inverseAndProgram.program;
      }

      if (inverted) {
        inverted = inverse;
        inverse = program;
        program = inverted;
      }

      return new this.BlockStatement(
          openBlock.sexpr, program, inverse,
          openBlock.strip, inverseStrip, close && (close.strip || close.openStrip),
          this.locInfo(locInfo));
    }

    __exports__.prepareBlock = prepareBlock;
  });
enifed("htmlbars-syntax/handlebars/compiler/parser",
  ["exports"],
  function(__exports__) {
    "use strict";
    /* jshint ignore:start */
    /* istanbul ignore next */
    /* Jison generated parser */
    var handlebars = (function(){
    var parser = {trace: function trace() { },
    yy: {},
    symbols_: {"error":2,"root":3,"program":4,"EOF":5,"program_repetition0":6,"statement":7,"mustache":8,"block":9,"rawBlock":10,"partial":11,"content":12,"COMMENT":13,"CONTENT":14,"openRawBlock":15,"END_RAW_BLOCK":16,"OPEN_RAW_BLOCK":17,"sexpr":18,"CLOSE_RAW_BLOCK":19,"openBlock":20,"block_option0":21,"closeBlock":22,"openInverse":23,"block_option1":24,"OPEN_BLOCK":25,"openBlock_option0":26,"CLOSE":27,"OPEN_INVERSE":28,"openInverse_option0":29,"openInverseChain":30,"OPEN_INVERSE_CHAIN":31,"openInverseChain_option0":32,"inverseAndProgram":33,"INVERSE":34,"inverseChain":35,"inverseChain_option0":36,"OPEN_ENDBLOCK":37,"path":38,"OPEN":39,"OPEN_UNESCAPED":40,"CLOSE_UNESCAPED":41,"OPEN_PARTIAL":42,"helperName":43,"sexpr_repetition0":44,"sexpr_option0":45,"dataName":46,"param":47,"STRING":48,"NUMBER":49,"BOOLEAN":50,"OPEN_SEXPR":51,"CLOSE_SEXPR":52,"hash":53,"hash_repetition_plus0":54,"hashSegment":55,"ID":56,"EQUALS":57,"blockParams":58,"OPEN_BLOCK_PARAMS":59,"blockParams_repetition_plus0":60,"CLOSE_BLOCK_PARAMS":61,"DATA":62,"pathSegments":63,"SEP":64,"$accept":0,"$end":1},
    terminals_: {2:"error",5:"EOF",13:"COMMENT",14:"CONTENT",16:"END_RAW_BLOCK",17:"OPEN_RAW_BLOCK",19:"CLOSE_RAW_BLOCK",25:"OPEN_BLOCK",27:"CLOSE",28:"OPEN_INVERSE",31:"OPEN_INVERSE_CHAIN",34:"INVERSE",37:"OPEN_ENDBLOCK",39:"OPEN",40:"OPEN_UNESCAPED",41:"CLOSE_UNESCAPED",42:"OPEN_PARTIAL",48:"STRING",49:"NUMBER",50:"BOOLEAN",51:"OPEN_SEXPR",52:"CLOSE_SEXPR",56:"ID",57:"EQUALS",59:"OPEN_BLOCK_PARAMS",61:"CLOSE_BLOCK_PARAMS",62:"DATA",64:"SEP"},
    productions_: [0,[3,2],[4,1],[7,1],[7,1],[7,1],[7,1],[7,1],[7,1],[12,1],[10,3],[15,3],[9,4],[9,4],[20,4],[23,4],[30,4],[33,2],[35,3],[35,1],[22,3],[8,3],[8,3],[11,3],[18,3],[18,1],[47,1],[47,1],[47,1],[47,1],[47,1],[47,3],[53,1],[55,3],[58,3],[43,1],[43,1],[43,1],[46,2],[38,1],[63,3],[63,1],[6,0],[6,2],[21,0],[21,1],[24,0],[24,1],[26,0],[26,1],[29,0],[29,1],[32,0],[32,1],[36,0],[36,1],[44,0],[44,2],[45,0],[45,1],[54,1],[54,2],[60,1],[60,2]],
    performAction: function anonymous(yytext,yyleng,yylineno,yy,yystate,$$,_$) {

    var $0 = $$.length - 1;
    switch (yystate) {
    case 1: return $$[$0-1]; 
    break;
    case 2:this.$ = new yy.Program($$[$0], null, {}, yy.locInfo(this._$));
    break;
    case 3:this.$ = $$[$0];
    break;
    case 4:this.$ = $$[$0];
    break;
    case 5:this.$ = $$[$0];
    break;
    case 6:this.$ = $$[$0];
    break;
    case 7:this.$ = $$[$0];
    break;
    case 8:this.$ = new yy.CommentStatement(yy.stripComment($$[$0]), yy.stripFlags($$[$0], $$[$0]), yy.locInfo(this._$));
    break;
    case 9:this.$ = new yy.ContentStatement($$[$0], yy.locInfo(this._$));
    break;
    case 10:this.$ = yy.prepareRawBlock($$[$0-2], $$[$0-1], $$[$0], this._$);
    break;
    case 11:this.$ = { sexpr: $$[$0-1] };
    break;
    case 12:this.$ = yy.prepareBlock($$[$0-3], $$[$0-2], $$[$0-1], $$[$0], false, this._$);
    break;
    case 13:this.$ = yy.prepareBlock($$[$0-3], $$[$0-2], $$[$0-1], $$[$0], true, this._$);
    break;
    case 14:this.$ = { sexpr: $$[$0-2], blockParams: $$[$0-1], strip: yy.stripFlags($$[$0-3], $$[$0]) };
    break;
    case 15:this.$ = { sexpr: $$[$0-2], blockParams: $$[$0-1], strip: yy.stripFlags($$[$0-3], $$[$0]) };
    break;
    case 16:this.$ = { sexpr: $$[$0-2], blockParams: $$[$0-1], strip: yy.stripFlags($$[$0-3], $$[$0]) };
    break;
    case 17:this.$ = { strip: yy.stripFlags($$[$0-1], $$[$0-1]), program: $$[$0] };
    break;
    case 18:
        var inverse = yy.prepareBlock($$[$0-2], $$[$0-1], $$[$0], $$[$0], false, this._$),
            program = new yy.Program([inverse], null, {}, yy.locInfo(this._$));
        program.chained = true;

        this.$ = { strip: $$[$0-2].strip, program: program, chain: true };
      
    break;
    case 19:this.$ = $$[$0];
    break;
    case 20:this.$ = {path: $$[$0-1], strip: yy.stripFlags($$[$0-2], $$[$0])};
    break;
    case 21:this.$ = yy.prepareMustache($$[$0-1], $$[$0-2], yy.stripFlags($$[$0-2], $$[$0]), this._$);
    break;
    case 22:this.$ = yy.prepareMustache($$[$0-1], $$[$0-2], yy.stripFlags($$[$0-2], $$[$0]), this._$);
    break;
    case 23:this.$ = new yy.PartialStatement($$[$0-1], yy.stripFlags($$[$0-2], $$[$0]), yy.locInfo(this._$));
    break;
    case 24:this.$ = new yy.SubExpression($$[$0-2], $$[$0-1], $$[$0], yy.locInfo(this._$));
    break;
    case 25:this.$ = new yy.SubExpression($$[$0], null, null, yy.locInfo(this._$));
    break;
    case 26:this.$ = $$[$0];
    break;
    case 27:this.$ = new yy.StringLiteral($$[$0], yy.locInfo(this._$));
    break;
    case 28:this.$ = new yy.NumberLiteral($$[$0], yy.locInfo(this._$));
    break;
    case 29:this.$ = new yy.BooleanLiteral($$[$0], yy.locInfo(this._$));
    break;
    case 30:this.$ = $$[$0];
    break;
    case 31:this.$ = $$[$0-1];
    break;
    case 32:this.$ = new yy.Hash($$[$0], yy.locInfo(this._$));
    break;
    case 33:this.$ = new yy.HashPair($$[$0-2], $$[$0], yy.locInfo(this._$));
    break;
    case 34:this.$ = $$[$0-1];
    break;
    case 35:this.$ = $$[$0];
    break;
    case 36:this.$ = new yy.StringLiteral($$[$0], yy.locInfo(this._$)), yy.locInfo(this._$);
    break;
    case 37:this.$ = new yy.NumberLiteral($$[$0], yy.locInfo(this._$));
    break;
    case 38:this.$ = yy.preparePath(true, $$[$0], this._$);
    break;
    case 39:this.$ = yy.preparePath(false, $$[$0], this._$);
    break;
    case 40: $$[$0-2].push({part: $$[$0], separator: $$[$0-1]}); this.$ = $$[$0-2]; 
    break;
    case 41:this.$ = [{part: $$[$0]}];
    break;
    case 42:this.$ = [];
    break;
    case 43:$$[$0-1].push($$[$0]);
    break;
    case 56:this.$ = [];
    break;
    case 57:$$[$0-1].push($$[$0]);
    break;
    case 60:this.$ = [$$[$0]];
    break;
    case 61:$$[$0-1].push($$[$0]);
    break;
    case 62:this.$ = [$$[$0]];
    break;
    case 63:$$[$0-1].push($$[$0]);
    break;
    }
    },
    table: [{3:1,4:2,5:[2,42],6:3,13:[2,42],14:[2,42],17:[2,42],25:[2,42],28:[2,42],39:[2,42],40:[2,42],42:[2,42]},{1:[3]},{5:[1,4]},{5:[2,2],7:5,8:6,9:7,10:8,11:9,12:10,13:[1,11],14:[1,18],15:16,17:[1,21],20:14,23:15,25:[1,19],28:[1,20],31:[2,2],34:[2,2],37:[2,2],39:[1,12],40:[1,13],42:[1,17]},{1:[2,1]},{5:[2,43],13:[2,43],14:[2,43],17:[2,43],25:[2,43],28:[2,43],31:[2,43],34:[2,43],37:[2,43],39:[2,43],40:[2,43],42:[2,43]},{5:[2,3],13:[2,3],14:[2,3],17:[2,3],25:[2,3],28:[2,3],31:[2,3],34:[2,3],37:[2,3],39:[2,3],40:[2,3],42:[2,3]},{5:[2,4],13:[2,4],14:[2,4],17:[2,4],25:[2,4],28:[2,4],31:[2,4],34:[2,4],37:[2,4],39:[2,4],40:[2,4],42:[2,4]},{5:[2,5],13:[2,5],14:[2,5],17:[2,5],25:[2,5],28:[2,5],31:[2,5],34:[2,5],37:[2,5],39:[2,5],40:[2,5],42:[2,5]},{5:[2,6],13:[2,6],14:[2,6],17:[2,6],25:[2,6],28:[2,6],31:[2,6],34:[2,6],37:[2,6],39:[2,6],40:[2,6],42:[2,6]},{5:[2,7],13:[2,7],14:[2,7],17:[2,7],25:[2,7],28:[2,7],31:[2,7],34:[2,7],37:[2,7],39:[2,7],40:[2,7],42:[2,7]},{5:[2,8],13:[2,8],14:[2,8],17:[2,8],25:[2,8],28:[2,8],31:[2,8],34:[2,8],37:[2,8],39:[2,8],40:[2,8],42:[2,8]},{18:22,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{18:31,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{4:32,6:3,13:[2,42],14:[2,42],17:[2,42],25:[2,42],28:[2,42],31:[2,42],34:[2,42],37:[2,42],39:[2,42],40:[2,42],42:[2,42]},{4:33,6:3,13:[2,42],14:[2,42],17:[2,42],25:[2,42],28:[2,42],34:[2,42],37:[2,42],39:[2,42],40:[2,42],42:[2,42]},{12:34,14:[1,18]},{18:35,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{5:[2,9],13:[2,9],14:[2,9],16:[2,9],17:[2,9],25:[2,9],28:[2,9],31:[2,9],34:[2,9],37:[2,9],39:[2,9],40:[2,9],42:[2,9]},{18:36,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{18:37,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{18:38,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{27:[1,39]},{19:[2,56],27:[2,56],41:[2,56],44:40,48:[2,56],49:[2,56],50:[2,56],51:[2,56],52:[2,56],56:[2,56],59:[2,56],62:[2,56]},{19:[2,25],27:[2,25],41:[2,25],52:[2,25],59:[2,25]},{19:[2,35],27:[2,35],41:[2,35],48:[2,35],49:[2,35],50:[2,35],51:[2,35],52:[2,35],56:[2,35],59:[2,35],62:[2,35]},{19:[2,36],27:[2,36],41:[2,36],48:[2,36],49:[2,36],50:[2,36],51:[2,36],52:[2,36],56:[2,36],59:[2,36],62:[2,36]},{19:[2,37],27:[2,37],41:[2,37],48:[2,37],49:[2,37],50:[2,37],51:[2,37],52:[2,37],56:[2,37],59:[2,37],62:[2,37]},{56:[1,30],63:41},{19:[2,39],27:[2,39],41:[2,39],48:[2,39],49:[2,39],50:[2,39],51:[2,39],52:[2,39],56:[2,39],59:[2,39],62:[2,39],64:[1,42]},{19:[2,41],27:[2,41],41:[2,41],48:[2,41],49:[2,41],50:[2,41],51:[2,41],52:[2,41],56:[2,41],59:[2,41],62:[2,41],64:[2,41]},{41:[1,43]},{21:44,30:46,31:[1,48],33:47,34:[1,49],35:45,37:[2,44]},{24:50,33:51,34:[1,49],37:[2,46]},{16:[1,52]},{27:[1,53]},{26:54,27:[2,48],58:55,59:[1,56]},{27:[2,50],29:57,58:58,59:[1,56]},{19:[1,59]},{5:[2,21],13:[2,21],14:[2,21],17:[2,21],25:[2,21],28:[2,21],31:[2,21],34:[2,21],37:[2,21],39:[2,21],40:[2,21],42:[2,21]},{19:[2,58],27:[2,58],38:63,41:[2,58],45:60,46:67,47:61,48:[1,64],49:[1,65],50:[1,66],51:[1,68],52:[2,58],53:62,54:69,55:70,56:[1,71],59:[2,58],62:[1,28],63:29},{19:[2,38],27:[2,38],41:[2,38],48:[2,38],49:[2,38],50:[2,38],51:[2,38],52:[2,38],56:[2,38],59:[2,38],62:[2,38],64:[1,42]},{56:[1,72]},{5:[2,22],13:[2,22],14:[2,22],17:[2,22],25:[2,22],28:[2,22],31:[2,22],34:[2,22],37:[2,22],39:[2,22],40:[2,22],42:[2,22]},{22:73,37:[1,74]},{37:[2,45]},{4:75,6:3,13:[2,42],14:[2,42],17:[2,42],25:[2,42],28:[2,42],31:[2,42],34:[2,42],37:[2,42],39:[2,42],40:[2,42],42:[2,42]},{37:[2,19]},{18:76,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{4:77,6:3,13:[2,42],14:[2,42],17:[2,42],25:[2,42],28:[2,42],37:[2,42],39:[2,42],40:[2,42],42:[2,42]},{22:78,37:[1,74]},{37:[2,47]},{5:[2,10],13:[2,10],14:[2,10],17:[2,10],25:[2,10],28:[2,10],31:[2,10],34:[2,10],37:[2,10],39:[2,10],40:[2,10],42:[2,10]},{5:[2,23],13:[2,23],14:[2,23],17:[2,23],25:[2,23],28:[2,23],31:[2,23],34:[2,23],37:[2,23],39:[2,23],40:[2,23],42:[2,23]},{27:[1,79]},{27:[2,49]},{56:[1,81],60:80},{27:[1,82]},{27:[2,51]},{14:[2,11]},{19:[2,24],27:[2,24],41:[2,24],52:[2,24],59:[2,24]},{19:[2,57],27:[2,57],41:[2,57],48:[2,57],49:[2,57],50:[2,57],51:[2,57],52:[2,57],56:[2,57],59:[2,57],62:[2,57]},{19:[2,59],27:[2,59],41:[2,59],52:[2,59],59:[2,59]},{19:[2,26],27:[2,26],41:[2,26],48:[2,26],49:[2,26],50:[2,26],51:[2,26],52:[2,26],56:[2,26],59:[2,26],62:[2,26]},{19:[2,27],27:[2,27],41:[2,27],48:[2,27],49:[2,27],50:[2,27],51:[2,27],52:[2,27],56:[2,27],59:[2,27],62:[2,27]},{19:[2,28],27:[2,28],41:[2,28],48:[2,28],49:[2,28],50:[2,28],51:[2,28],52:[2,28],56:[2,28],59:[2,28],62:[2,28]},{19:[2,29],27:[2,29],41:[2,29],48:[2,29],49:[2,29],50:[2,29],51:[2,29],52:[2,29],56:[2,29],59:[2,29],62:[2,29]},{19:[2,30],27:[2,30],41:[2,30],48:[2,30],49:[2,30],50:[2,30],51:[2,30],52:[2,30],56:[2,30],59:[2,30],62:[2,30]},{18:83,38:25,43:23,46:24,48:[1,26],49:[1,27],56:[1,30],62:[1,28],63:29},{19:[2,32],27:[2,32],41:[2,32],52:[2,32],55:84,56:[1,85],59:[2,32]},{19:[2,60],27:[2,60],41:[2,60],52:[2,60],56:[2,60],59:[2,60]},{19:[2,41],27:[2,41],41:[2,41],48:[2,41],49:[2,41],50:[2,41],51:[2,41],52:[2,41],56:[2,41],57:[1,86],59:[2,41],62:[2,41],64:[2,41]},{19:[2,40],27:[2,40],41:[2,40],48:[2,40],49:[2,40],50:[2,40],51:[2,40],52:[2,40],56:[2,40],59:[2,40],62:[2,40],64:[2,40]},{5:[2,12],13:[2,12],14:[2,12],17:[2,12],25:[2,12],28:[2,12],31:[2,12],34:[2,12],37:[2,12],39:[2,12],40:[2,12],42:[2,12]},{38:87,56:[1,30],63:29},{30:46,31:[1,48],33:47,34:[1,49],35:89,36:88,37:[2,54]},{27:[2,52],32:90,58:91,59:[1,56]},{37:[2,17]},{5:[2,13],13:[2,13],14:[2,13],17:[2,13],25:[2,13],28:[2,13],31:[2,13],34:[2,13],37:[2,13],39:[2,13],40:[2,13],42:[2,13]},{13:[2,14],14:[2,14],17:[2,14],25:[2,14],28:[2,14],31:[2,14],34:[2,14],37:[2,14],39:[2,14],40:[2,14],42:[2,14]},{56:[1,93],61:[1,92]},{56:[2,62],61:[2,62]},{13:[2,15],14:[2,15],17:[2,15],25:[2,15],28:[2,15],34:[2,15],37:[2,15],39:[2,15],40:[2,15],42:[2,15]},{52:[1,94]},{19:[2,61],27:[2,61],41:[2,61],52:[2,61],56:[2,61],59:[2,61]},{57:[1,86]},{38:63,46:67,47:95,48:[1,64],49:[1,65],50:[1,66],51:[1,68],56:[1,30],62:[1,28],63:29},{27:[1,96]},{37:[2,18]},{37:[2,55]},{27:[1,97]},{27:[2,53]},{27:[2,34]},{56:[2,63],61:[2,63]},{19:[2,31],27:[2,31],41:[2,31],48:[2,31],49:[2,31],50:[2,31],51:[2,31],52:[2,31],56:[2,31],59:[2,31],62:[2,31]},{19:[2,33],27:[2,33],41:[2,33],52:[2,33],56:[2,33],59:[2,33]},{5:[2,20],13:[2,20],14:[2,20],17:[2,20],25:[2,20],28:[2,20],31:[2,20],34:[2,20],37:[2,20],39:[2,20],40:[2,20],42:[2,20]},{13:[2,16],14:[2,16],17:[2,16],25:[2,16],28:[2,16],31:[2,16],34:[2,16],37:[2,16],39:[2,16],40:[2,16],42:[2,16]}],
    defaultActions: {4:[2,1],45:[2,45],47:[2,19],51:[2,47],55:[2,49],58:[2,51],59:[2,11],77:[2,17],88:[2,18],89:[2,55],91:[2,53],92:[2,34]},
    parseError: function parseError(str, hash) {
        throw new Error(str);
    },
    parse: function parse(input) {
        var self = this, stack = [0], vstack = [null], lstack = [], table = this.table, yytext = "", yylineno = 0, yyleng = 0, recovering = 0, TERROR = 2, EOF = 1;
        this.lexer.setInput(input);
        this.lexer.yy = this.yy;
        this.yy.lexer = this.lexer;
        this.yy.parser = this;
        if (typeof this.lexer.yylloc == "undefined")
            this.lexer.yylloc = {};
        var yyloc = this.lexer.yylloc;
        lstack.push(yyloc);
        var ranges = this.lexer.options && this.lexer.options.ranges;
        if (typeof this.yy.parseError === "function")
            this.parseError = this.yy.parseError;
        function popStack(n) {
            stack.length = stack.length - 2 * n;
            vstack.length = vstack.length - n;
            lstack.length = lstack.length - n;
        }
        function lex() {
            var token;
            token = self.lexer.lex() || 1;
            if (typeof token !== "number") {
                token = self.symbols_[token] || token;
            }
            return token;
        }
        var symbol, preErrorSymbol, state, action, a, r, yyval = {}, p, len, newState, expected;
        while (true) {
            state = stack[stack.length - 1];
            if (this.defaultActions[state]) {
                action = this.defaultActions[state];
            } else {
                if (symbol === null || typeof symbol == "undefined") {
                    symbol = lex();
                }
                action = table[state] && table[state][symbol];
            }
            if (typeof action === "undefined" || !action.length || !action[0]) {
                var errStr = "";
                if (!recovering) {
                    expected = [];
                    for (p in table[state])
                        if (this.terminals_[p] && p > 2) {
                            expected.push("'" + this.terminals_[p] + "'");
                        }
                    if (this.lexer.showPosition) {
                        errStr = "Parse error on line " + (yylineno + 1) + ":\n" + this.lexer.showPosition() + "\nExpecting " + expected.join(", ") + ", got '" + (this.terminals_[symbol] || symbol) + "'";
                    } else {
                        errStr = "Parse error on line " + (yylineno + 1) + ": Unexpected " + (symbol == 1?"end of input":"'" + (this.terminals_[symbol] || symbol) + "'");
                    }
                    this.parseError(errStr, {text: this.lexer.match, token: this.terminals_[symbol] || symbol, line: this.lexer.yylineno, loc: yyloc, expected: expected});
                }
            }
            if (action[0] instanceof Array && action.length > 1) {
                throw new Error("Parse Error: multiple actions possible at state: " + state + ", token: " + symbol);
            }
            switch (action[0]) {
            case 1:
                stack.push(symbol);
                vstack.push(this.lexer.yytext);
                lstack.push(this.lexer.yylloc);
                stack.push(action[1]);
                symbol = null;
                if (!preErrorSymbol) {
                    yyleng = this.lexer.yyleng;
                    yytext = this.lexer.yytext;
                    yylineno = this.lexer.yylineno;
                    yyloc = this.lexer.yylloc;
                    if (recovering > 0)
                        recovering--;
                } else {
                    symbol = preErrorSymbol;
                    preErrorSymbol = null;
                }
                break;
            case 2:
                len = this.productions_[action[1]][1];
                yyval.$ = vstack[vstack.length - len];
                yyval._$ = {first_line: lstack[lstack.length - (len || 1)].first_line, last_line: lstack[lstack.length - 1].last_line, first_column: lstack[lstack.length - (len || 1)].first_column, last_column: lstack[lstack.length - 1].last_column};
                if (ranges) {
                    yyval._$.range = [lstack[lstack.length - (len || 1)].range[0], lstack[lstack.length - 1].range[1]];
                }
                r = this.performAction.call(yyval, yytext, yyleng, yylineno, this.yy, action[1], vstack, lstack);
                if (typeof r !== "undefined") {
                    return r;
                }
                if (len) {
                    stack = stack.slice(0, -1 * len * 2);
                    vstack = vstack.slice(0, -1 * len);
                    lstack = lstack.slice(0, -1 * len);
                }
                stack.push(this.productions_[action[1]][0]);
                vstack.push(yyval.$);
                lstack.push(yyval._$);
                newState = table[stack[stack.length - 2]][stack[stack.length - 1]];
                stack.push(newState);
                break;
            case 3:
                return true;
            }
        }
        return true;
    }
    };
    /* Jison generated lexer */
    var lexer = (function(){
    var lexer = ({EOF:1,
    parseError:function parseError(str, hash) {
            if (this.yy.parser) {
                this.yy.parser.parseError(str, hash);
            } else {
                throw new Error(str);
            }
        },
    setInput:function (input) {
            this._input = input;
            this._more = this._less = this.done = false;
            this.yylineno = this.yyleng = 0;
            this.yytext = this.matched = this.match = '';
            this.conditionStack = ['INITIAL'];
            this.yylloc = {first_line:1,first_column:0,last_line:1,last_column:0};
            if (this.options.ranges) this.yylloc.range = [0,0];
            this.offset = 0;
            return this;
        },
    input:function () {
            var ch = this._input[0];
            this.yytext += ch;
            this.yyleng++;
            this.offset++;
            this.match += ch;
            this.matched += ch;
            var lines = ch.match(/(?:\r\n?|\n).*/g);
            if (lines) {
                this.yylineno++;
                this.yylloc.last_line++;
            } else {
                this.yylloc.last_column++;
            }
            if (this.options.ranges) this.yylloc.range[1]++;

            this._input = this._input.slice(1);
            return ch;
        },
    unput:function (ch) {
            var len = ch.length;
            var lines = ch.split(/(?:\r\n?|\n)/g);

            this._input = ch + this._input;
            this.yytext = this.yytext.substr(0, this.yytext.length-len-1);
            //this.yyleng -= len;
            this.offset -= len;
            var oldLines = this.match.split(/(?:\r\n?|\n)/g);
            this.match = this.match.substr(0, this.match.length-1);
            this.matched = this.matched.substr(0, this.matched.length-1);

            if (lines.length-1) this.yylineno -= lines.length-1;
            var r = this.yylloc.range;

            this.yylloc = {first_line: this.yylloc.first_line,
              last_line: this.yylineno+1,
              first_column: this.yylloc.first_column,
              last_column: lines ?
                  (lines.length === oldLines.length ? this.yylloc.first_column : 0) + oldLines[oldLines.length - lines.length].length - lines[0].length:
                  this.yylloc.first_column - len
              };

            if (this.options.ranges) {
                this.yylloc.range = [r[0], r[0] + this.yyleng - len];
            }
            return this;
        },
    more:function () {
            this._more = true;
            return this;
        },
    less:function (n) {
            this.unput(this.match.slice(n));
        },
    pastInput:function () {
            var past = this.matched.substr(0, this.matched.length - this.match.length);
            return (past.length > 20 ? '...':'') + past.substr(-20).replace(/\n/g, "");
        },
    upcomingInput:function () {
            var next = this.match;
            if (next.length < 20) {
                next += this._input.substr(0, 20-next.length);
            }
            return (next.substr(0,20)+(next.length > 20 ? '...':'')).replace(/\n/g, "");
        },
    showPosition:function () {
            var pre = this.pastInput();
            var c = new Array(pre.length + 1).join("-");
            return pre + this.upcomingInput() + "\n" + c+"^";
        },
    next:function () {
            if (this.done) {
                return this.EOF;
            }
            if (!this._input) this.done = true;

            var token,
                match,
                tempMatch,
                index,
                col,
                lines;
            if (!this._more) {
                this.yytext = '';
                this.match = '';
            }
            var rules = this._currentRules();
            for (var i=0;i < rules.length; i++) {
                tempMatch = this._input.match(this.rules[rules[i]]);
                if (tempMatch && (!match || tempMatch[0].length > match[0].length)) {
                    match = tempMatch;
                    index = i;
                    if (!this.options.flex) break;
                }
            }
            if (match) {
                lines = match[0].match(/(?:\r\n?|\n).*/g);
                if (lines) this.yylineno += lines.length;
                this.yylloc = {first_line: this.yylloc.last_line,
                               last_line: this.yylineno+1,
                               first_column: this.yylloc.last_column,
                               last_column: lines ? lines[lines.length-1].length-lines[lines.length-1].match(/\r?\n?/)[0].length : this.yylloc.last_column + match[0].length};
                this.yytext += match[0];
                this.match += match[0];
                this.matches = match;
                this.yyleng = this.yytext.length;
                if (this.options.ranges) {
                    this.yylloc.range = [this.offset, this.offset += this.yyleng];
                }
                this._more = false;
                this._input = this._input.slice(match[0].length);
                this.matched += match[0];
                token = this.performAction.call(this, this.yy, this, rules[index],this.conditionStack[this.conditionStack.length-1]);
                if (this.done && this._input) this.done = false;
                if (token) return token;
                else return;
            }
            if (this._input === "") {
                return this.EOF;
            } else {
                return this.parseError('Lexical error on line '+(this.yylineno+1)+'. Unrecognized text.\n'+this.showPosition(),
                        {text: "", token: null, line: this.yylineno});
            }
        },
    lex:function lex() {
            var r = this.next();
            if (typeof r !== 'undefined') {
                return r;
            } else {
                return this.lex();
            }
        },
    begin:function begin(condition) {
            this.conditionStack.push(condition);
        },
    popState:function popState() {
            return this.conditionStack.pop();
        },
    _currentRules:function _currentRules() {
            return this.conditions[this.conditionStack[this.conditionStack.length-1]].rules;
        },
    topState:function () {
            return this.conditionStack[this.conditionStack.length-2];
        },
    pushState:function begin(condition) {
            this.begin(condition);
        }});
    lexer.options = {};
    lexer.performAction = function anonymous(yy,yy_,$avoiding_name_collisions,YY_START) {


    function strip(start, end) {
      return yy_.yytext = yy_.yytext.substr(start, yy_.yyleng-end);
    }


    var YYSTATE=YY_START
    switch($avoiding_name_collisions) {
    case 0:
                                       if(yy_.yytext.slice(-2) === "\\\\") {
                                         strip(0,1);
                                         this.begin("mu");
                                       } else if(yy_.yytext.slice(-1) === "\\") {
                                         strip(0,1);
                                         this.begin("emu");
                                       } else {
                                         this.begin("mu");
                                       }
                                       if(yy_.yytext) return 14;
                                     
    break;
    case 1:return 14;
    break;
    case 2:
                                       this.popState();
                                       return 14;
                                     
    break;
    case 3:
                                      yy_.yytext = yy_.yytext.substr(5, yy_.yyleng-9);
                                      this.popState();
                                      return 16;
                                     
    break;
    case 4: return 14; 
    break;
    case 5:
      this.popState();
      return 13;

    break;
    case 6:return 51;
    break;
    case 7:return 52;
    break;
    case 8: return 17; 
    break;
    case 9:
                                      this.popState();
                                      this.begin('raw');
                                      return 19;
                                     
    break;
    case 10:return 42;
    break;
    case 11:return 25;
    break;
    case 12:return 37;
    break;
    case 13:this.popState(); return 34;
    break;
    case 14:this.popState(); return 34;
    break;
    case 15:return 28;
    break;
    case 16:return 31;
    break;
    case 17:return 40;
    break;
    case 18:return 39;
    break;
    case 19:
      this.unput(yy_.yytext);
      this.popState();
      this.begin('com');

    break;
    case 20:
      this.popState();
      return 13;

    break;
    case 21:return 39;
    break;
    case 22:return 57;
    break;
    case 23:return 56;
    break;
    case 24:return 56;
    break;
    case 25:return 64;
    break;
    case 26:// ignore whitespace
    break;
    case 27:this.popState(); return 41;
    break;
    case 28:this.popState(); return 27;
    break;
    case 29:yy_.yytext = strip(1,2).replace(/\\"/g,'"'); return 48;
    break;
    case 30:yy_.yytext = strip(1,2).replace(/\\'/g,"'"); return 48;
    break;
    case 31:return 62;
    break;
    case 32:return 50;
    break;
    case 33:return 50;
    break;
    case 34:return 49;
    break;
    case 35:return 59;
    break;
    case 36:return 61;
    break;
    case 37:return 56;
    break;
    case 38:yy_.yytext = strip(1,2); return 56;
    break;
    case 39:return 'INVALID';
    break;
    case 40:return 5;
    break;
    }
    };
    lexer.rules = [/^(?:[^\x00]*?(?=(\{\{)))/,/^(?:[^\x00]+)/,/^(?:[^\x00]{2,}?(?=(\{\{|\\\{\{|\\\\\{\{|$)))/,/^(?:\{\{\{\{\/[^\s!"#%-,\.\/;->@\[-\^`\{-~]+(?=[=}\s\/.])\}\}\}\})/,/^(?:[^\x00]*?(?=(\{\{\{\{\/)))/,/^(?:[\s\S]*?--(~)?\}\})/,/^(?:\()/,/^(?:\))/,/^(?:\{\{\{\{)/,/^(?:\}\}\}\})/,/^(?:\{\{(~)?>)/,/^(?:\{\{(~)?#)/,/^(?:\{\{(~)?\/)/,/^(?:\{\{(~)?\^\s*(~)?\}\})/,/^(?:\{\{(~)?\s*else\s*(~)?\}\})/,/^(?:\{\{(~)?\^)/,/^(?:\{\{(~)?\s*else\b)/,/^(?:\{\{(~)?\{)/,/^(?:\{\{(~)?&)/,/^(?:\{\{(~)?!--)/,/^(?:\{\{(~)?![\s\S]*?\}\})/,/^(?:\{\{(~)?)/,/^(?:=)/,/^(?:\.\.)/,/^(?:\.(?=([=~}\s\/.)|])))/,/^(?:[\/.])/,/^(?:\s+)/,/^(?:\}(~)?\}\})/,/^(?:(~)?\}\})/,/^(?:"(\\["]|[^"])*")/,/^(?:'(\\[']|[^'])*')/,/^(?:@)/,/^(?:true(?=([~}\s)])))/,/^(?:false(?=([~}\s)])))/,/^(?:-?[0-9]+(?:\.[0-9]+)?(?=([~}\s)])))/,/^(?:as\s+\|)/,/^(?:\|)/,/^(?:([^\s!"#%-,\.\/;->@\[-\^`\{-~]+(?=([=~}\s\/.)|]))))/,/^(?:\[[^\]]*\])/,/^(?:.)/,/^(?:$)/];
    lexer.conditions = {"mu":{"rules":[6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40],"inclusive":false},"emu":{"rules":[2],"inclusive":false},"com":{"rules":[5],"inclusive":false},"raw":{"rules":[3,4],"inclusive":false},"INITIAL":{"rules":[0,1,40],"inclusive":true}};
    return lexer;})()
    parser.lexer = lexer;
    function Parser () { this.yy = {}; }Parser.prototype = parser;parser.Parser = Parser;
    return new Parser;
    })();__exports__["default"] = handlebars;
    /* jshint ignore:end */
  });
enifed("htmlbars-syntax/handlebars/compiler/visitor",
  ["exports"],
  function(__exports__) {
    "use strict";
    function Visitor() {}

    Visitor.prototype = {
      constructor: Visitor,

      accept: function(object) {
        return object && this[object.type](object);
      },

      Program: function(program) {
        var body = program.body,
            i, l;

        for(i=0, l=body.length; i<l; i++) {
          this.accept(body[i]);
        }
      },

      MustacheStatement: function(mustache) {
        this.accept(mustache.sexpr);
      },

      BlockStatement: function(block) {
        this.accept(block.sexpr);
        this.accept(block.program);
        this.accept(block.inverse);
      },

      PartialStatement: function(partial) {
        this.accept(partial.partialName);
        this.accept(partial.context);
        this.accept(partial.hash);
      },

      ContentStatement: function(content) {},
      CommentStatement: function(comment) {},

      SubExpression: function(sexpr) {
        var params = sexpr.params, paramStrings = [], hash;

        this.accept(sexpr.path);
        for(var i=0, l=params.length; i<l; i++) {
          this.accept(params[i]);
        }
        this.accept(sexpr.hash);
      },

      PathExpression: function(path) {},

      StringLiteral: function(string) {},
      NumberLiteral: function(number) {},
      BooleanLiteral: function(bool) {},

      Hash: function(hash) {
        var pairs = hash.pairs;

        for(var i=0, l=pairs.length; i<l; i++) {
          this.accept(pairs[i]);
        }
      },
      HashPair: function(pair) {
        this.accept(pair.value);
      }
    };

    __exports__["default"] = Visitor;
  });
enifed("htmlbars-syntax/handlebars/compiler/whitespace-control",
  ["./visitor","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var Visitor = __dependency1__["default"];

    function WhitespaceControl() {
    }
    WhitespaceControl.prototype = new Visitor();

    WhitespaceControl.prototype.Program = function(program) {
      var isRoot = !this.isRootSeen;
      this.isRootSeen = true;

      var body = program.body;
      for (var i = 0, l = body.length; i < l; i++) {
        var current = body[i],
            strip = this.accept(current);

        if (!strip) {
          continue;
        }

        var _isPrevWhitespace = isPrevWhitespace(body, i, isRoot),
            _isNextWhitespace = isNextWhitespace(body, i, isRoot),

            openStandalone = strip.openStandalone && _isPrevWhitespace,
            closeStandalone = strip.closeStandalone && _isNextWhitespace,
            inlineStandalone = strip.inlineStandalone && _isPrevWhitespace && _isNextWhitespace;

        if (strip.close) {
          omitRight(body, i, true);
        }
        if (strip.open) {
          omitLeft(body, i, true);
        }

        if (inlineStandalone) {
          omitRight(body, i);

          if (omitLeft(body, i)) {
            // If we are on a standalone node, save the indent info for partials
            if (current.type === 'PartialStatement') {
              // Pull out the whitespace from the final line
              current.indent = (/([ \t]+$)/).exec(body[i-1].original)[1];
            }
          }
        }
        if (openStandalone) {
          omitRight((current.program || current.inverse).body);

          // Strip out the previous content node if it's whitespace only
          omitLeft(body, i);
        }
        if (closeStandalone) {
          // Always strip the next node
          omitRight(body, i);

          omitLeft((current.inverse || current.program).body);
        }
      }

      return program;
    };
    WhitespaceControl.prototype.BlockStatement = function(block) {
      this.accept(block.program);
      this.accept(block.inverse);

      // Find the inverse program that is involed with whitespace stripping.
      var program = block.program || block.inverse,
          inverse = block.program && block.inverse,
          firstInverse = inverse,
          lastInverse = inverse;

      if (inverse && inverse.chained) {
        firstInverse = inverse.body[0].program;

        // Walk the inverse chain to find the last inverse that is actually in the chain.
        while (lastInverse.chained) {
          lastInverse = lastInverse.body[lastInverse.body.length-1].program;
        }
      }

      var strip = {
        open: block.openStrip.open,
        close: block.closeStrip.close,

        // Determine the standalone candiacy. Basically flag our content as being possibly standalone
        // so our parent can determine if we actually are standalone
        openStandalone: isNextWhitespace(program.body),
        closeStandalone: isPrevWhitespace((firstInverse || program).body)
      };

      if (block.openStrip.close) {
        omitRight(program.body, null, true);
      }

      if (inverse) {
        var inverseStrip = block.inverseStrip;

        if (inverseStrip.open) {
          omitLeft(program.body, null, true);
        }

        if (inverseStrip.close) {
          omitRight(firstInverse.body, null, true);
        }
        if (block.closeStrip.open) {
          omitLeft(lastInverse.body, null, true);
        }

        // Find standalone else statments
        if (isPrevWhitespace(program.body)
            && isNextWhitespace(firstInverse.body)) {

          omitLeft(program.body);
          omitRight(firstInverse.body);
        }
      } else {
        if (block.closeStrip.open) {
          omitLeft(program.body, null, true);
        }
      }

      return strip;
    };

    WhitespaceControl.prototype.MustacheStatement = function(mustache) {
      return mustache.strip;
    };

    WhitespaceControl.prototype.PartialStatement = 
        WhitespaceControl.prototype.CommentStatement = function(node) {
      var strip = node.strip || {};
      return {
        inlineStandalone: true,
        open: strip.open,
        close: strip.close
      };
    };


    function isPrevWhitespace(body, i, isRoot) {
      if (i === undefined) {
        i = body.length;
      }

      // Nodes that end with newlines are considered whitespace (but are special
      // cased for strip operations)
      var prev = body[i-1],
          sibling = body[i-2];
      if (!prev) {
        return isRoot;
      }

      if (prev.type === 'ContentStatement') {
        return (sibling || !isRoot ? (/\r?\n\s*?$/) : (/(^|\r?\n)\s*?$/)).test(prev.original);
      }
    }
    function isNextWhitespace(body, i, isRoot) {
      if (i === undefined) {
        i = -1;
      }

      var next = body[i+1],
          sibling = body[i+2];
      if (!next) {
        return isRoot;
      }

      if (next.type === 'ContentStatement') {
        return (sibling || !isRoot ? (/^\s*?\r?\n/) : (/^\s*?(\r?\n|$)/)).test(next.original);
      }
    }

    // Marks the node to the right of the position as omitted.
    // I.e. {{foo}}' ' will mark the ' ' node as omitted.
    //
    // If i is undefined, then the first child will be marked as such.
    //
    // If mulitple is truthy then all whitespace will be stripped out until non-whitespace
    // content is met.
    function omitRight(body, i, multiple) {
      var current = body[i == null ? 0 : i + 1];
      if (!current || current.type !== 'ContentStatement' || (!multiple && current.rightStripped)) {
        return;
      }

      var original = current.value;
      current.value = current.value.replace(multiple ? (/^\s+/) : (/^[ \t]*\r?\n?/), '');
      current.rightStripped = current.value !== original;
    }

    // Marks the node to the left of the position as omitted.
    // I.e. ' '{{foo}} will mark the ' ' node as omitted.
    //
    // If i is undefined then the last child will be marked as such.
    //
    // If mulitple is truthy then all whitespace will be stripped out until non-whitespace
    // content is met.
    function omitLeft(body, i, multiple) {
      var current = body[i == null ? body.length - 1 : i - 1];
      if (!current || current.type !== 'ContentStatement' || (!multiple && current.leftStripped)) {
        return;
      }

      // We omit the last node if it's whitespace only and not preceeded by a non-content node.
      var original = current.value;
      current.value = current.value.replace(multiple ? (/\s+$/) : (/[ \t]+$/), '');
      current.leftStripped = current.value !== original;
      return current.leftStripped;
    }

    __exports__["default"] = WhitespaceControl;
  });
enifed("htmlbars-syntax/handlebars/exception",
  ["exports"],
  function(__exports__) {
    "use strict";

    var errorProps = ['description', 'fileName', 'lineNumber', 'message', 'name', 'number', 'stack'];

    function Exception(message, node) {
      var loc = node && node.loc,
          line,
          column;
      if (loc) {
        line = loc.start.line;
        column = loc.start.column;

        message += ' - ' + line + ':' + column;
      }

      var tmp = Error.prototype.constructor.call(this, message);

      // Unfortunately errors are not enumerable in Chrome (at least), so `for prop in tmp` doesn't work.
      for (var idx = 0; idx < errorProps.length; idx++) {
        this[errorProps[idx]] = tmp[errorProps[idx]];
      }

      if (loc) {
        this.lineNumber = line;
        this.column = column;
      }
    }

    Exception.prototype = new Error();

    __exports__["default"] = Exception;
  });
enifed("htmlbars-syntax/handlebars/safe-string",
  ["exports"],
  function(__exports__) {
    "use strict";
    // Build out our basic SafeString type
    function SafeString(string) {
      this.string = string;
    }

    SafeString.prototype.toString = SafeString.prototype.toHTML = function() {
      return "" + this.string;
    };

    __exports__["default"] = SafeString;
  });
enifed("htmlbars-syntax/handlebars/utils",
  ["./safe-string","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    /*jshint -W004 */
    var SafeString = __dependency1__["default"];

    var escape = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#x27;",
      "`": "&#x60;"
    };

    var badChars = /[&<>"'`]/g;
    var possible = /[&<>"'`]/;

    function escapeChar(chr) {
      return escape[chr];
    }

    function extend(obj /* , ...source */) {
      for (var i = 1; i < arguments.length; i++) {
        for (var key in arguments[i]) {
          if (Object.prototype.hasOwnProperty.call(arguments[i], key)) {
            obj[key] = arguments[i][key];
          }
        }
      }

      return obj;
    }

    __exports__.extend = extend;var toString = Object.prototype.toString;
    __exports__.toString = toString;
    // Sourced from lodash
    // https://github.com/bestiejs/lodash/blob/master/LICENSE.txt
    var isFunction = function(value) {
      return typeof value === 'function';
    };
    // fallback for older versions of Chrome and Safari
    /* istanbul ignore next */
    if (isFunction(/x/)) {
      isFunction = function(value) {
        return typeof value === 'function' && toString.call(value) === '[object Function]';
      };
    }
    var isFunction;
    __exports__.isFunction = isFunction;
    /* istanbul ignore next */
    var isArray = Array.isArray || function(value) {
      return (value && typeof value === 'object') ? toString.call(value) === '[object Array]' : false;
    };
    __exports__.isArray = isArray;

    function escapeExpression(string) {
      // don't escape SafeStrings, since they're already safe
      if (string && string.toHTML) {
        return string.toHTML();
      } else if (string == null) {
        return "";
      } else if (!string) {
        return string + '';
      }

      // Force a string conversion as this will be done by the append regardless and
      // the regex test will do this transparently behind the scenes, causing issues if
      // an object's to string has escaped characters in it.
      string = "" + string;

      if(!possible.test(string)) { return string; }
      return string.replace(badChars, escapeChar);
    }

    __exports__.escapeExpression = escapeExpression;function isEmpty(value) {
      if (!value && value !== 0) {
        return true;
      } else if (isArray(value) && value.length === 0) {
        return true;
      } else {
        return false;
      }
    }

    __exports__.isEmpty = isEmpty;function appendContextPath(contextPath, id) {
      return (contextPath ? contextPath + '.' : '') + id;
    }

    __exports__.appendContextPath = appendContextPath;
  });
enifed("htmlbars-syntax/node-handlers",
  ["./builders","../htmlbars-util/array-utils","./utils","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __exports__) {
    "use strict";
    var buildProgram = __dependency1__.buildProgram;
    var buildBlock = __dependency1__.buildBlock;
    var buildHash = __dependency1__.buildHash;
    var forEach = __dependency2__.forEach;
    var appendChild = __dependency3__.appendChild;

    var nodeHandlers = {

      Program: function(program) {
        var body = [];
        var node = buildProgram(body, program.blockParams);
        var i, l = program.body.length;

        this.elementStack.push(node);

        if (l === 0) { return this.elementStack.pop(); }

        for (i = 0; i < l; i++) {
          this.acceptNode(program.body[i]);
        }

        this.acceptToken(this.tokenizer.tokenizeEOF());

        // Ensure that that the element stack is balanced properly.
        var poppedNode = this.elementStack.pop();
        if (poppedNode !== node) {
          throw new Error("Unclosed element `" + poppedNode.tag + "` (on line " + poppedNode.loc.start.line + ").");
        }

        return node;
      },

      BlockStatement: function(block) {
        delete block.inverseStrip;
        delete block.openString;
        delete block.closeStrip;

        if (this.tokenizer.state === 'comment') {
          this.tokenizer.addChar('{{' + this.sourceForMustache(block) + '}}');
          return;
        }

        switchToHandlebars(this);
        this.acceptToken(block);

        var sexpr = this.acceptNode(block.sexpr);
        var program = block.program ? this.acceptNode(block.program) : null;
        var inverse = block.inverse ? this.acceptNode(block.inverse) : null;

        var node = buildBlock(sexpr, program, inverse);
        var parentProgram = this.currentElement();
        appendChild(parentProgram, node);
      },

      MustacheStatement: function(mustache) {
        delete mustache.strip;

        if (this.tokenizer.state === 'comment') {
          this.tokenizer.addChar('{{' + this.sourceForMustache(mustache) + '}}');
          return;
        }

        this.acceptNode(mustache.sexpr);
        switchToHandlebars(this);
        this.acceptToken(mustache);

        return mustache;
      },

      ContentStatement: function(content) {
        var changeLines = 0;
        if (content.rightStripped) {
          changeLines = leadingNewlineDifference(content.original, content.value);
        }

        this.tokenizer.line = this.tokenizer.line + changeLines;

        var tokens = this.tokenizer.tokenizePart(content.value);

        return forEach(tokens, this.acceptToken, this);
      },

      CommentStatement: function(comment) {
        return comment;
      },

      PartialStatement: function(partial) {
        appendChild(this.currentElement(), partial);
        return partial;
      },

      SubExpression: function(sexpr) {
        delete sexpr.isHelper;

        this.acceptNode(sexpr.path);

        if (sexpr.params) {
          for (var i = 0; i < sexpr.params.length; i++) {
            this.acceptNode(sexpr.params[i]);
          }
        } else {
          sexpr.params = [];
        }

        if (sexpr.hash) {
          this.acceptNode(sexpr.hash);
        } else {
          sexpr.hash = buildHash();
        }

        return sexpr;
      },

      PathExpression: function(path) {
        delete path.data;
        delete path.depth;

        return path;
      },

      Hash: function(hash) {
        for (var i = 0; i < hash.pairs.length; i++) {
          this.acceptNode(hash.pairs[i].value);
        }

        return hash;
      },

      StringLiteral: function() {},
      BooleanLiteral: function() {},
      NumberLiteral: function() {}
    };

    function switchToHandlebars(processor) {
      var token = processor.tokenizer.token;

      if (token && token.type === 'Chars') {
        processor.acceptToken(token);
        processor.tokenizer.token = null;
      }
    }

    function leadingNewlineDifference(original, value) {
      if (value === '') {
        // if it is empty, just return the count of newlines
        // in original
        return original.split("\n").length - 1;
      }

      // otherwise, return the number of newlines prior to
      // `value`
      var difference = original.split(value)[0];
      var lines = difference.split(/\n/);

      return lines.length - 1;
    }

    __exports__["default"] = nodeHandlers;
  });
enifed("htmlbars-syntax/parser",
  ["./handlebars/compiler/base","./tokenizer","../simple-html-tokenizer/entity-parser","../simple-html-tokenizer/char-refs/full","./node-handlers","./token-handlers","../htmlbars-syntax","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __dependency5__, __dependency6__, __dependency7__, __exports__) {
    "use strict";
    var parse = __dependency1__.parse;
    var Tokenizer = __dependency2__.Tokenizer;
    var EntityParser = __dependency3__["default"];
    var fullCharRefs = __dependency4__["default"];
    var nodeHandlers = __dependency5__["default"];
    var tokenHandlers = __dependency6__["default"];

    // this should be:
    // `import * from "../htmlbars-syntax";
    //
    // But this version of the transpiler does not support it properly
    var syntax = __dependency7__;

    var splitLines;
    // IE8 throws away blank pieces when splitting strings with a regex
    // So we split using a string instead as appropriate
    if ("foo\n\nbar".split(/\n/).length === 2) {
      splitLines = function(str) {
         var clean = str.replace(/\r\n?/g, '\n');
         return clean.split('\n');
      };
    } else {
      splitLines = function(str) {
        return str.split(/(?:\r\n?|\n)/g);
      };
    }

    function preprocess(html, options) {
      var ast = (typeof html === 'object') ? html : parse(html);
      var combined = new HTMLProcessor(html, options).acceptNode(ast);

      if (options && options.plugins && options.plugins.ast) {
        for (var i = 0, l = options.plugins.ast.length; i < l; i++) {
          var plugin = new options.plugins.ast[i]();

          plugin.syntax = syntax;

          combined = plugin.transform(combined);
        }
      }

      return combined;
    }

    __exports__.preprocess = preprocess;function HTMLProcessor(source, options) {
      this.options = options || {};
      this.elementStack = [];
      this.tokenizer = new Tokenizer('', new EntityParser(fullCharRefs));
      this.nodeHandlers = nodeHandlers;
      this.tokenHandlers = tokenHandlers;

      if (typeof source === 'string') {
        this.source = splitLines(source);
      }
    }

    HTMLProcessor.prototype.acceptNode = function(node) {
      return this.nodeHandlers[node.type].call(this, node);
    };

    HTMLProcessor.prototype.acceptToken = function(token) {
      if (token) {
        return this.tokenHandlers[token.type].call(this, token);
      }
    };

    HTMLProcessor.prototype.currentElement = function() {
      return this.elementStack[this.elementStack.length - 1];
    };

    HTMLProcessor.prototype.sourceForMustache = function(mustache) {
      var firstLine = mustache.loc.start.line - 1;
      var lastLine = mustache.loc.end.line - 1;
      var currentLine = firstLine - 1;
      var firstColumn = mustache.loc.start.column + 2;
      var lastColumn = mustache.loc.end.column - 2;
      var string = [];
      var line;

      if (!this.source) {
        return '{{' + mustache.path.id.original + '}}';
      }

      while (currentLine < lastLine) {
        currentLine++;
        line = this.source[currentLine];

        if (currentLine === firstLine) {
          if (firstLine === lastLine) {
            string.push(line.slice(firstColumn, lastColumn));
          } else {
            string.push(line.slice(firstColumn));
          }
        } else if (currentLine === lastLine) {
          string.push(line.slice(0, lastColumn));
        } else {
          string.push(line);
        }
      }

      return string.join('\n');
    };
  });
enifed("htmlbars-syntax/token-handlers",
  ["../htmlbars-util/array-utils","./builders","./utils","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __exports__) {
    "use strict";
    var forEach = __dependency1__.forEach;
    var buildProgram = __dependency2__.buildProgram;
    var buildComponent = __dependency2__.buildComponent;
    var buildElement = __dependency2__.buildElement;
    var buildComment = __dependency2__.buildComment;
    var buildText = __dependency2__.buildText;
    var appendChild = __dependency3__.appendChild;
    var parseComponentBlockParams = __dependency3__.parseComponentBlockParams;

    // The HTML elements in this list are speced by
    // http://www.w3.org/TR/html-markup/syntax.html#syntax-elements,
    // and will be forced to close regardless of if they have a
    // self-closing /> at the end.
    var voidTagNames = "area base br col command embed hr img input keygen link meta param source track wbr";
    var voidMap = {};

    forEach(voidTagNames.split(" "), function(tagName) {
      voidMap[tagName] = true;
    });

    // Except for `mustache`, all tokens are only allowed outside of
    // a start or end tag.
    var tokenHandlers = {
      Comment: function(token) {
        var current = this.currentElement();
        var comment = buildComment(token.chars);
        appendChild(current, comment);
      },

      Chars: function(token) {
        var current = this.currentElement();
        var text = buildText(token.chars);
        appendChild(current, text);
      },

      StartTag: function(tag) {
        var element = buildElement(tag.tagName, tag.attributes, tag.modifiers || [], []);
        element.loc = {
          start: { line: tag.firstLine, column: tag.firstColumn},
          end: { line: null, column: null}
        };

        this.elementStack.push(element);
        if (voidMap.hasOwnProperty(tag.tagName) || tag.selfClosing) {
          tokenHandlers.EndTag.call(this, tag);
        }
      },

      BlockStatement: function(/*block*/) {
        if (this.tokenizer.state === 'comment') {
          return;
        } else if (this.tokenizer.state !== 'data') {
          throw new Error("A block may only be used inside an HTML element or another block.");
        }
      },

      MustacheStatement: function(mustache) {
        var tokenizer = this.tokenizer;

        switch(tokenizer.state) {
          // Tag helpers
          case "tagName":
            tokenizer.addElementModifier(mustache);
            tokenizer.state = "beforeAttributeName";
            return;
          case "beforeAttributeName":
            tokenizer.addElementModifier(mustache);
            return;
          case "attributeName":
          case "afterAttributeName":
            tokenizer.finalizeAttributeValue();
            tokenizer.addElementModifier(mustache);
            tokenizer.state = "beforeAttributeName";
            return;
          case "afterAttributeValueQuoted":
            tokenizer.addElementModifier(mustache);
            tokenizer.state = "beforeAttributeName";
            return;

          // Attribute values
          case "beforeAttributeValue":
            tokenizer.markAttributeQuoted(false);
            tokenizer.addToAttributeValue(mustache);
            tokenizer.state = 'attributeValueUnquoted';
            return;
          case "attributeValueDoubleQuoted":
          case "attributeValueSingleQuoted":
          case "attributeValueUnquoted":
            tokenizer.addToAttributeValue(mustache);
            return;

          // TODO: Only append child when the tokenizer state makes
          // sense to do so, otherwise throw an error.
          default:
            appendChild(this.currentElement(), mustache);
        }
      },

      EndTag: function(tag) {
        var element = this.elementStack.pop();
        var parent = this.currentElement();
        var disableComponentGeneration = this.options.disableComponentGeneration === true;

        validateEndTag(tag, element);

        if (disableComponentGeneration || element.tag.indexOf("-") === -1) {
          appendChild(parent, element);
        } else {
          var program = buildProgram(element.children);
          parseComponentBlockParams(element, program);
          var component = buildComponent(element.tag, element.attributes, program);
          appendChild(parent, component);
        }

      }

    };

    function validateEndTag(tag, element) {
      var error;

      if (voidMap[tag.tagName] && element.tag === undefined) {
        // For void elements, we check element.tag is undefined because endTag is called by the startTag token handler in
        // the normal case, so checking only voidMap[tag.tagName] would lead to an error being thrown on the opening tag.
        error = "Invalid end tag " + formatEndTagInfo(tag) + " (void elements cannot have end tags).";
      } else if (element.tag === undefined) {
        error = "Closing tag " + formatEndTagInfo(tag) + " without an open tag.";
      } else if (element.tag !== tag.tagName) {
        error = "Closing tag " + formatEndTagInfo(tag) + " did not match last open tag `" + element.tag + "` (on line " +
                element.loc.start.line + ").";
      }

      if (error) { throw new Error(error); }
    }

    function formatEndTagInfo(tag) {
      return "`" + tag.tagName + "` (on line " + tag.lastLine + ")";
    }

    __exports__["default"] = tokenHandlers;
  });
enifed("htmlbars-syntax/tokenizer",
  ["../simple-html-tokenizer","./utils","../htmlbars-util/array-utils","./builders","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __exports__) {
    "use strict";
    var Tokenizer = __dependency1__.Tokenizer;
    var isHelper = __dependency2__.isHelper;
    var map = __dependency3__.map;
    var builders = __dependency4__["default"];

    Tokenizer.prototype.createAttribute = function(char) {
      if (this.token.type === 'EndTag') {
        throw new Error('Invalid end tag: closing tag must not have attributes, in ' + formatTokenInfo(this) + '.');
      }
      this.currentAttribute = builders.attr(char.toLowerCase(), [], null);
      this.token.attributes.push(this.currentAttribute);
      this.state = 'attributeName';
    };

    Tokenizer.prototype.markAttributeQuoted = function(value) {
      this.currentAttribute.quoted = value;
    };

    Tokenizer.prototype.addToAttributeName = function(char) {
      this.currentAttribute.name += char;
    };

    Tokenizer.prototype.addToAttributeValue = function(char) {
      var value = this.currentAttribute.value;

      if (!this.currentAttribute.quoted && char === '/') {
        throw new Error("A space is required between an unquoted attribute value and `/`, in " + formatTokenInfo(this) +
                        '.');
      }
      if (!this.currentAttribute.quoted && value.length > 0 &&
          (char.type === 'MustacheStatement' || value[0].type === 'MustacheStatement')) {
        throw new Error("Unquoted attribute value must be a single string or mustache (on line " + this.line + ")");
      }

      if (typeof char === 'object') {
        if (char.type === 'MustacheStatement') {
          value.push(char);
        } else {
          throw new Error("Unsupported node in attribute value: " + char.type);
        }
      } else {
        if (value.length > 0 && value[value.length - 1].type === 'TextNode') {
          value[value.length - 1].chars += char;
        } else {
          value.push(builders.text(char));
        }
      }
    };

    Tokenizer.prototype.finalizeAttributeValue = function() {
      if (this.currentAttribute) {
        this.currentAttribute.value = prepareAttributeValue(this.currentAttribute);
        delete this.currentAttribute.quoted;
        delete this.currentAttribute;
      }
    };

    Tokenizer.prototype.addElementModifier = function(mustache) {
      if (!this.token.modifiers) {
        this.token.modifiers = [];
      }

      var modifier = builders.elementModifier(mustache.sexpr);
      this.token.modifiers.push(modifier);
    };

    function prepareAttributeValue(attr) {
      var parts = attr.value;
      var length = parts.length;

      if (length === 0) {
        return builders.text('');
      } else if (length === 1 && parts[0].type === "TextNode") {
        return parts[0];
      } else if (!attr.quoted) {
        return parts[0];
      } else {
        return builders.concat(map(parts, prepareConcatPart));
      }
    }

    function prepareConcatPart(node) {
      switch (node.type) {
        case 'TextNode': return builders.string(node.chars);
        case 'MustacheStatement': return unwrapMustache(node);
        default:
          throw new Error("Unsupported node in quoted attribute value: " + node.type);
      }
    }

    function formatTokenInfo(tokenizer) {
      return '`' + tokenizer.token.tagName + '` (on line ' + tokenizer.line + ')';
    }

    function unwrapMustache(mustache) {
      if (isHelper(mustache.sexpr)) {
        return mustache.sexpr;
      } else {
        return mustache.sexpr.path;
      }
    }

    __exports__.unwrapMustache = unwrapMustache;__exports__.Tokenizer = Tokenizer;
  });
enifed("htmlbars-syntax/utils",
  ["../htmlbars-util/array-utils","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var indexOfArray = __dependency1__.indexOfArray;
    // Regex to validate the identifier for block parameters. 
    // Based on the ID validation regex in Handlebars.

    var ID_INVERSE_PATTERN = /[!"#%-,\.\/;->@\[-\^`\{-~]/;

    // Checks the component's attributes to see if it uses block params.
    // If it does, registers the block params with the program and
    // removes the corresponding attributes from the element.

    function parseComponentBlockParams(element, program) {
      var l = element.attributes.length;
      var attrNames = [];

      for (var i = 0; i < l; i++) {
        attrNames.push(element.attributes[i].name);
      }

      var asIndex = indexOfArray(attrNames, 'as');

      if (asIndex !== -1 && l > asIndex && attrNames[asIndex + 1].charAt(0) === '|') {
        // Some basic validation, since we're doing the parsing ourselves
        var paramsString = attrNames.slice(asIndex).join(' ');
        if (paramsString.charAt(paramsString.length - 1) !== '|' || paramsString.match(/\|/g).length !== 2) {
          throw new Error('Invalid block parameters syntax: \'' + paramsString + '\'');
        }

        var params = [];
        for (i = asIndex + 1; i < l; i++) {
          var param = attrNames[i].replace(/\|/g, '');
          if (param !== '') {
            if (ID_INVERSE_PATTERN.test(param)) {
              throw new Error('Invalid identifier for block parameters: \'' + param + '\' in \'' + paramsString + '\'');
            }
            params.push(param);
          }
        }

        if (params.length === 0) {
          throw new Error('Cannot use zero block parameters: \'' + paramsString + '\'');
        }

        element.attributes = element.attributes.slice(0, asIndex);
        program.blockParams = params;
      }
    }

    __exports__.parseComponentBlockParams = parseComponentBlockParams;function childrenFor(node) {
      if (node.type === 'Program') {
        return node.body;
      }
      if (node.type === 'ElementNode') {
        return node.children;
      }
    }

    __exports__.childrenFor = childrenFor;function appendChild(parent, node) {
      childrenFor(parent).push(node);
    }

    __exports__.appendChild = appendChild;function isHelper(sexpr) {
      return (sexpr.params && sexpr.params.length > 0) ||
        (sexpr.hash && sexpr.hash.pairs.length > 0);
    }

    __exports__.isHelper = isHelper;
  });
enifed("htmlbars-syntax/walker",
  ["exports"],
  function(__exports__) {
    "use strict";
    function Walker(order) {
      this.order = order;
      this.stack = [];
    }

    __exports__["default"] = Walker;

    Walker.prototype.visit = function(node, callback) {
      if (!node) {
        return;
      }

      this.stack.push(node);

      if (this.order === 'post') {
        this.children(node, callback);
        callback(node, this);
      } else {
        callback(node, this);
        this.children(node, callback);
      }

      this.stack.pop();
    };

    var visitors = {
      Program: function(walker, node, callback) {
        for (var i = 0; i < node.body.length; i++) {
          walker.visit(node.body[i], callback);
        }
      },

      ElementNode: function(walker, node, callback) {
        for (var i = 0; i < node.children.length; i++) {
          walker.visit(node.children[i], callback);
        }
      },

      BlockStatement: function(walker, node, callback) {
        walker.visit(node.program, callback);
        walker.visit(node.inverse, callback);
      },

      ComponentNode: function(walker, node, callback) {
        walker.visit(node.program, callback);
      }
    };

    Walker.prototype.children = function(node, callback) {
      var visitor = visitors[node.type];
      if (visitor) {
        visitor(this, node, callback);
      }
    };
  });
enifed("htmlbars-test-helpers",
  ["exports"],
  function(__exports__) {
    "use strict";
    function equalInnerHTML(fragment, html) {
      var actualHTML = normalizeInnerHTML(fragment.innerHTML);
      QUnit.push(actualHTML === html, actualHTML, html);
    }

    __exports__.equalInnerHTML = equalInnerHTML;function equalHTML(node, html) {
      var fragment;
      if (!node.nodeType && node.length) {
        fragment = document.createDocumentFragment();
        while (node[0]) {
          fragment.appendChild(node[0]);
        }
      } else {
        fragment = node;
      }

      var div = document.createElement("div");
      div.appendChild(fragment.cloneNode(true));

      equalInnerHTML(div, html);
    }

    __exports__.equalHTML = equalHTML;// detect weird IE8 html strings
    var ie8InnerHTMLTestElement = document.createElement('div');
    ie8InnerHTMLTestElement.setAttribute('id', 'womp');
    var ie8InnerHTML = (ie8InnerHTMLTestElement.outerHTML.indexOf('id=womp') > -1);

    // detect side-effects of cloning svg elements in IE9-11
    var ieSVGInnerHTML = (function () {
      if (!document.createElementNS) {
        return false;
      }
      var div = document.createElement('div');
      var node = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      div.appendChild(node);
      var clone = div.cloneNode(true);
      return clone.innerHTML === '<svg xmlns="http://www.w3.org/2000/svg" />';
    })();

    function normalizeInnerHTML(actualHTML) {
      if (ie8InnerHTML) {
        // drop newlines in IE8
        actualHTML = actualHTML.replace(/\r\n/gm, '');
        // downcase ALLCAPS tags in IE8
        actualHTML = actualHTML.replace(/<\/?[A-Z\-]+/gi, function(tag){
          return tag.toLowerCase();
        });
        // quote ids in IE8
        actualHTML = actualHTML.replace(/id=([^ >]+)/gi, function(match, id){
          return 'id="'+id+'"';
        });
        // IE8 adds ':' to some tags
        // <keygen> becomes <:keygen>
        actualHTML = actualHTML.replace(/<(\/?):([^ >]+)/gi, function(match, slash, tag){
          return '<'+slash+tag;
        });

        // Normalize the style attribute
        actualHTML = actualHTML.replace(/style="(.+?)"/gi, function(match, val){
          return 'style="'+val.toLowerCase()+';"';
        });

      }
      if (ieSVGInnerHTML) {
        // Replace `<svg xmlns="http://www.w3.org/2000/svg" height="50%" />` with `<svg height="50%"></svg>`, etc.
        // drop namespace attribute
        actualHTML = actualHTML.replace(/ xmlns="[^"]+"/, '');
        // replace self-closing elements
        actualHTML = actualHTML.replace(/<([^ >]+) [^\/>]*\/>/gi, function(tag, tagName) {
          return tag.slice(0, tag.length - 3) + '></' + tagName + '>';
        });
      }

      return actualHTML;
    }

    __exports__.normalizeInnerHTML = normalizeInnerHTML;// detect weird IE8 checked element string
    var checkedInput = document.createElement('input');
    checkedInput.setAttribute('checked', 'checked');
    var checkedInputString = checkedInput.outerHTML;
    function isCheckedInputHTML(element) {
      equal(element.outerHTML, checkedInputString);
    }

    __exports__.isCheckedInputHTML = isCheckedInputHTML;// check which property has the node's text content
    var textProperty = document.createElement('div').textContent === undefined ? 'innerText' : 'textContent';
    function getTextContent(el) {
      // textNode
      if (el.nodeType === 3) {
        return el.nodeValue;
      } else {
        return el[textProperty];
      }
    }

    __exports__.getTextContent = getTextContent;// IE8 does not have Object.create, so use a polyfill if needed.
    // Polyfill based on Mozilla's (MDN)
    function createObject(obj) {
      if (typeof Object.create === 'function') {
        return Object.create(obj);
      } else {
        var Temp = function() {};
        Temp.prototype = obj;
        return new Temp();
      }
    }
    __exports__.createObject = createObject;
  });
enifed("htmlbars-util",
  ["./htmlbars-util/safe-string","./htmlbars-util/handlebars/utils","./htmlbars-util/namespaces","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __exports__) {
    "use strict";
    var SafeString = __dependency1__["default"];
    var escapeExpression = __dependency2__.escapeExpression;
    var getAttrNamespace = __dependency3__.getAttrNamespace;

    __exports__.SafeString = SafeString;
    __exports__.escapeExpression = escapeExpression;
    __exports__.getAttrNamespace = getAttrNamespace;
  });
enifed("htmlbars-util/array-utils",
  ["exports"],
  function(__exports__) {
    "use strict";
    function forEach(array, callback, binding) {
      var i, l;
      if (binding === undefined) {
        for (i = 0, l = array.length; i < l; i++) {
          callback(array[i], i, array);
        }
      } else {
        for (i = 0, l = array.length; i < l; i++) {
          callback.call(binding, array[i], i, array);
        }
      }
    }

    __exports__.forEach = forEach;function map(array, callback) {
      var output = [];
      var i, l;

      for (i = 0, l = array.length; i < l; i++) {
        output.push(callback(array[i], i, array));
      }

      return output;
    }

    __exports__.map = map;var getIdx;
    if (Array.prototype.indexOf) {
      getIdx = function(array, obj, from){
        return array.indexOf(obj, from);
      };
    } else {
      getIdx = function(array, obj, from) {
        if (from === undefined || from === null) {
          from = 0;
        } else if (from < 0) {
          from = Math.max(0, array.length + from);
        }
        for (var i = from, l= array.length; i < l; i++) {
          if (array[i] === obj) {
            return i;
          }
        }
        return -1;
      };
    }

    var indexOfArray = getIdx;
    __exports__.indexOfArray = indexOfArray;
  });
enifed("htmlbars-util/handlebars/safe-string",
  ["exports"],
  function(__exports__) {
    "use strict";
    // Build out our basic SafeString type
    function SafeString(string) {
      this.string = string;
    }

    SafeString.prototype.toString = SafeString.prototype.toHTML = function() {
      return "" + this.string;
    };

    __exports__["default"] = SafeString;
  });
enifed("htmlbars-util/handlebars/utils",
  ["./safe-string","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    /*jshint -W004 */
    var SafeString = __dependency1__["default"];

    var escape = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#x27;",
      "`": "&#x60;"
    };

    var badChars = /[&<>"'`]/g;
    var possible = /[&<>"'`]/;

    function escapeChar(chr) {
      return escape[chr];
    }

    function extend(obj /* , ...source */) {
      for (var i = 1; i < arguments.length; i++) {
        for (var key in arguments[i]) {
          if (Object.prototype.hasOwnProperty.call(arguments[i], key)) {
            obj[key] = arguments[i][key];
          }
        }
      }

      return obj;
    }

    __exports__.extend = extend;var toString = Object.prototype.toString;
    __exports__.toString = toString;
    // Sourced from lodash
    // https://github.com/bestiejs/lodash/blob/master/LICENSE.txt
    var isFunction = function(value) {
      return typeof value === 'function';
    };
    // fallback for older versions of Chrome and Safari
    /* istanbul ignore next */
    if (isFunction(/x/)) {
      isFunction = function(value) {
        return typeof value === 'function' && toString.call(value) === '[object Function]';
      };
    }
    var isFunction;
    __exports__.isFunction = isFunction;
    /* istanbul ignore next */
    var isArray = Array.isArray || function(value) {
      return (value && typeof value === 'object') ? toString.call(value) === '[object Array]' : false;
    };
    __exports__.isArray = isArray;

    function escapeExpression(string) {
      // don't escape SafeStrings, since they're already safe
      if (string && string.toHTML) {
        return string.toHTML();
      } else if (string == null) {
        return "";
      } else if (!string) {
        return string + '';
      }

      // Force a string conversion as this will be done by the append regardless and
      // the regex test will do this transparently behind the scenes, causing issues if
      // an object's to string has escaped characters in it.
      string = "" + string;

      if(!possible.test(string)) { return string; }
      return string.replace(badChars, escapeChar);
    }

    __exports__.escapeExpression = escapeExpression;function isEmpty(value) {
      if (!value && value !== 0) {
        return true;
      } else if (isArray(value) && value.length === 0) {
        return true;
      } else {
        return false;
      }
    }

    __exports__.isEmpty = isEmpty;function appendContextPath(contextPath, id) {
      return (contextPath ? contextPath + '.' : '') + id;
    }

    __exports__.appendContextPath = appendContextPath;
  });
enifed("htmlbars-util/namespaces",
  ["exports"],
  function(__exports__) {
    "use strict";
    // ref http://dev.w3.org/html5/spec-LC/namespaces.html
    var defaultNamespaces = {
      html: 'http://www.w3.org/1999/xhtml',
      mathml: 'http://www.w3.org/1998/Math/MathML',
      svg: 'http://www.w3.org/2000/svg',
      xlink: 'http://www.w3.org/1999/xlink',
      xml: 'http://www.w3.org/XML/1998/namespace'
    };

    function getAttrNamespace(attrName) {
      var namespace;

      var colonIndex = attrName.indexOf(':');
      if (colonIndex !== -1) {
        var prefix = attrName.slice(0, colonIndex);
        namespace = defaultNamespaces[prefix];
      }

      return namespace || null;
    }

    __exports__.getAttrNamespace = getAttrNamespace;
  });
enifed("htmlbars-util/object-utils",
  ["exports"],
  function(__exports__) {
    "use strict";
    function merge(options, defaults) {
      for (var prop in defaults) {
        if (options.hasOwnProperty(prop)) { continue; }
        options[prop] = defaults[prop];
      }
      return options;
    }

    __exports__.merge = merge;
  });
enifed("htmlbars-util/quoting",
  ["exports"],
  function(__exports__) {
    "use strict";
    function escapeString(str) {
      str = str.replace(/\\/g, "\\\\");
      str = str.replace(/"/g, '\\"');
      str = str.replace(/\n/g, "\\n");
      return str;
    }

    __exports__.escapeString = escapeString;

    function string(str) {
      return '"' + escapeString(str) + '"';
    }

    __exports__.string = string;

    function array(a) {
      return "[" + a + "]";
    }

    __exports__.array = array;

    function hash(pairs) {
      return "{" + pairs.join(", ") + "}";
    }

    __exports__.hash = hash;function repeat(chars, times) {
      var str = "";
      while (times--) {
        str += chars;
      }
      return str;
    }

    __exports__.repeat = repeat;
  });
enifed("htmlbars-util/safe-string",
  ["./handlebars/safe-string","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var SafeString = __dependency1__["default"];

    __exports__["default"] = SafeString;
  });
enifed("simple-html-tokenizer",
  ["./simple-html-tokenizer/tokenizer","./simple-html-tokenizer/tokenize","./simple-html-tokenizer/generator","./simple-html-tokenizer/generate","./simple-html-tokenizer/tokens","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __dependency4__, __dependency5__, __exports__) {
    "use strict";
    /*jshint boss:true*/
    var Tokenizer = __dependency1__["default"];
    var tokenize = __dependency2__["default"];
    var Generator = __dependency3__["default"];
    var generate = __dependency4__["default"];
    var StartTag = __dependency5__.StartTag;
    var EndTag = __dependency5__.EndTag;
    var Chars = __dependency5__.Chars;
    var Comment = __dependency5__.Comment;

    __exports__.Tokenizer = Tokenizer;
    __exports__.tokenize = tokenize;
    __exports__.Generator = Generator;
    __exports__.generate = generate;
    __exports__.StartTag = StartTag;
    __exports__.EndTag = EndTag;
    __exports__.Chars = Chars;
    __exports__.Comment = Comment;
  });
enifed("simple-html-tokenizer/char-refs/full",
  ["exports"],
  function(__exports__) {
    "use strict";
    __exports__["default"] = {
      AElig: [198],
      AMP: [38],
      Aacute: [193],
      Abreve: [258],
      Acirc: [194],
      Acy: [1040],
      Afr: [120068],
      Agrave: [192],
      Alpha: [913],
      Amacr: [256],
      And: [10835],
      Aogon: [260],
      Aopf: [120120],
      ApplyFunction: [8289],
      Aring: [197],
      Ascr: [119964],
      Assign: [8788],
      Atilde: [195],
      Auml: [196],
      Backslash: [8726],
      Barv: [10983],
      Barwed: [8966],
      Bcy: [1041],
      Because: [8757],
      Bernoullis: [8492],
      Beta: [914],
      Bfr: [120069],
      Bopf: [120121],
      Breve: [728],
      Bscr: [8492],
      Bumpeq: [8782],
      CHcy: [1063],
      COPY: [169],
      Cacute: [262],
      Cap: [8914],
      CapitalDifferentialD: [8517],
      Cayleys: [8493],
      Ccaron: [268],
      Ccedil: [199],
      Ccirc: [264],
      Cconint: [8752],
      Cdot: [266],
      Cedilla: [184],
      CenterDot: [183],
      Cfr: [8493],
      Chi: [935],
      CircleDot: [8857],
      CircleMinus: [8854],
      CirclePlus: [8853],
      CircleTimes: [8855],
      ClockwiseContourIntegral: [8754],
      CloseCurlyDoubleQuote: [8221],
      CloseCurlyQuote: [8217],
      Colon: [8759],
      Colone: [10868],
      Congruent: [8801],
      Conint: [8751],
      ContourIntegral: [8750],
      Copf: [8450],
      Coproduct: [8720],
      CounterClockwiseContourIntegral: [8755],
      Cross: [10799],
      Cscr: [119966],
      Cup: [8915],
      CupCap: [8781],
      DD: [8517],
      DDotrahd: [10513],
      DJcy: [1026],
      DScy: [1029],
      DZcy: [1039],
      Dagger: [8225],
      Darr: [8609],
      Dashv: [10980],
      Dcaron: [270],
      Dcy: [1044],
      Del: [8711],
      Delta: [916],
      Dfr: [120071],
      DiacriticalAcute: [180],
      DiacriticalDot: [729],
      DiacriticalDoubleAcute: [733],
      DiacriticalGrave: [96],
      DiacriticalTilde: [732],
      Diamond: [8900],
      DifferentialD: [8518],
      Dopf: [120123],
      Dot: [168],
      DotDot: [8412],
      DotEqual: [8784],
      DoubleContourIntegral: [8751],
      DoubleDot: [168],
      DoubleDownArrow: [8659],
      DoubleLeftArrow: [8656],
      DoubleLeftRightArrow: [8660],
      DoubleLeftTee: [10980],
      DoubleLongLeftArrow: [10232],
      DoubleLongLeftRightArrow: [10234],
      DoubleLongRightArrow: [10233],
      DoubleRightArrow: [8658],
      DoubleRightTee: [8872],
      DoubleUpArrow: [8657],
      DoubleUpDownArrow: [8661],
      DoubleVerticalBar: [8741],
      DownArrow: [8595],
      DownArrowBar: [10515],
      DownArrowUpArrow: [8693],
      DownBreve: [785],
      DownLeftRightVector: [10576],
      DownLeftTeeVector: [10590],
      DownLeftVector: [8637],
      DownLeftVectorBar: [10582],
      DownRightTeeVector: [10591],
      DownRightVector: [8641],
      DownRightVectorBar: [10583],
      DownTee: [8868],
      DownTeeArrow: [8615],
      Downarrow: [8659],
      Dscr: [119967],
      Dstrok: [272],
      ENG: [330],
      ETH: [208],
      Eacute: [201],
      Ecaron: [282],
      Ecirc: [202],
      Ecy: [1069],
      Edot: [278],
      Efr: [120072],
      Egrave: [200],
      Element: [8712],
      Emacr: [274],
      EmptySmallSquare: [9723],
      EmptyVerySmallSquare: [9643],
      Eogon: [280],
      Eopf: [120124],
      Epsilon: [917],
      Equal: [10869],
      EqualTilde: [8770],
      Equilibrium: [8652],
      Escr: [8496],
      Esim: [10867],
      Eta: [919],
      Euml: [203],
      Exists: [8707],
      ExponentialE: [8519],
      Fcy: [1060],
      Ffr: [120073],
      FilledSmallSquare: [9724],
      FilledVerySmallSquare: [9642],
      Fopf: [120125],
      ForAll: [8704],
      Fouriertrf: [8497],
      Fscr: [8497],
      GJcy: [1027],
      GT: [62],
      Gamma: [915],
      Gammad: [988],
      Gbreve: [286],
      Gcedil: [290],
      Gcirc: [284],
      Gcy: [1043],
      Gdot: [288],
      Gfr: [120074],
      Gg: [8921],
      Gopf: [120126],
      GreaterEqual: [8805],
      GreaterEqualLess: [8923],
      GreaterFullEqual: [8807],
      GreaterGreater: [10914],
      GreaterLess: [8823],
      GreaterSlantEqual: [10878],
      GreaterTilde: [8819],
      Gscr: [119970],
      Gt: [8811],
      HARDcy: [1066],
      Hacek: [711],
      Hat: [94],
      Hcirc: [292],
      Hfr: [8460],
      HilbertSpace: [8459],
      Hopf: [8461],
      HorizontalLine: [9472],
      Hscr: [8459],
      Hstrok: [294],
      HumpDownHump: [8782],
      HumpEqual: [8783],
      IEcy: [1045],
      IJlig: [306],
      IOcy: [1025],
      Iacute: [205],
      Icirc: [206],
      Icy: [1048],
      Idot: [304],
      Ifr: [8465],
      Igrave: [204],
      Im: [8465],
      Imacr: [298],
      ImaginaryI: [8520],
      Implies: [8658],
      Int: [8748],
      Integral: [8747],
      Intersection: [8898],
      InvisibleComma: [8291],
      InvisibleTimes: [8290],
      Iogon: [302],
      Iopf: [120128],
      Iota: [921],
      Iscr: [8464],
      Itilde: [296],
      Iukcy: [1030],
      Iuml: [207],
      Jcirc: [308],
      Jcy: [1049],
      Jfr: [120077],
      Jopf: [120129],
      Jscr: [119973],
      Jsercy: [1032],
      Jukcy: [1028],
      KHcy: [1061],
      KJcy: [1036],
      Kappa: [922],
      Kcedil: [310],
      Kcy: [1050],
      Kfr: [120078],
      Kopf: [120130],
      Kscr: [119974],
      LJcy: [1033],
      LT: [60],
      Lacute: [313],
      Lambda: [923],
      Lang: [10218],
      Laplacetrf: [8466],
      Larr: [8606],
      Lcaron: [317],
      Lcedil: [315],
      Lcy: [1051],
      LeftAngleBracket: [10216],
      LeftArrow: [8592],
      LeftArrowBar: [8676],
      LeftArrowRightArrow: [8646],
      LeftCeiling: [8968],
      LeftDoubleBracket: [10214],
      LeftDownTeeVector: [10593],
      LeftDownVector: [8643],
      LeftDownVectorBar: [10585],
      LeftFloor: [8970],
      LeftRightArrow: [8596],
      LeftRightVector: [10574],
      LeftTee: [8867],
      LeftTeeArrow: [8612],
      LeftTeeVector: [10586],
      LeftTriangle: [8882],
      LeftTriangleBar: [10703],
      LeftTriangleEqual: [8884],
      LeftUpDownVector: [10577],
      LeftUpTeeVector: [10592],
      LeftUpVector: [8639],
      LeftUpVectorBar: [10584],
      LeftVector: [8636],
      LeftVectorBar: [10578],
      Leftarrow: [8656],
      Leftrightarrow: [8660],
      LessEqualGreater: [8922],
      LessFullEqual: [8806],
      LessGreater: [8822],
      LessLess: [10913],
      LessSlantEqual: [10877],
      LessTilde: [8818],
      Lfr: [120079],
      Ll: [8920],
      Lleftarrow: [8666],
      Lmidot: [319],
      LongLeftArrow: [10229],
      LongLeftRightArrow: [10231],
      LongRightArrow: [10230],
      Longleftarrow: [10232],
      Longleftrightarrow: [10234],
      Longrightarrow: [10233],
      Lopf: [120131],
      LowerLeftArrow: [8601],
      LowerRightArrow: [8600],
      Lscr: [8466],
      Lsh: [8624],
      Lstrok: [321],
      Lt: [8810],
      Map: [10501],
      Mcy: [1052],
      MediumSpace: [8287],
      Mellintrf: [8499],
      Mfr: [120080],
      MinusPlus: [8723],
      Mopf: [120132],
      Mscr: [8499],
      Mu: [924],
      NJcy: [1034],
      Nacute: [323],
      Ncaron: [327],
      Ncedil: [325],
      Ncy: [1053],
      NegativeMediumSpace: [8203],
      NegativeThickSpace: [8203],
      NegativeThinSpace: [8203],
      NegativeVeryThinSpace: [8203],
      NestedGreaterGreater: [8811],
      NestedLessLess: [8810],
      NewLine: [10],
      Nfr: [120081],
      NoBreak: [8288],
      NonBreakingSpace: [160],
      Nopf: [8469],
      Not: [10988],
      NotCongruent: [8802],
      NotCupCap: [8813],
      NotDoubleVerticalBar: [8742],
      NotElement: [8713],
      NotEqual: [8800],
      NotEqualTilde: [8770, 824],
      NotExists: [8708],
      NotGreater: [8815],
      NotGreaterEqual: [8817],
      NotGreaterFullEqual: [8807, 824],
      NotGreaterGreater: [8811, 824],
      NotGreaterLess: [8825],
      NotGreaterSlantEqual: [10878, 824],
      NotGreaterTilde: [8821],
      NotHumpDownHump: [8782, 824],
      NotHumpEqual: [8783, 824],
      NotLeftTriangle: [8938],
      NotLeftTriangleBar: [10703, 824],
      NotLeftTriangleEqual: [8940],
      NotLess: [8814],
      NotLessEqual: [8816],
      NotLessGreater: [8824],
      NotLessLess: [8810, 824],
      NotLessSlantEqual: [10877, 824],
      NotLessTilde: [8820],
      NotNestedGreaterGreater: [10914, 824],
      NotNestedLessLess: [10913, 824],
      NotPrecedes: [8832],
      NotPrecedesEqual: [10927, 824],
      NotPrecedesSlantEqual: [8928],
      NotReverseElement: [8716],
      NotRightTriangle: [8939],
      NotRightTriangleBar: [10704, 824],
      NotRightTriangleEqual: [8941],
      NotSquareSubset: [8847, 824],
      NotSquareSubsetEqual: [8930],
      NotSquareSuperset: [8848, 824],
      NotSquareSupersetEqual: [8931],
      NotSubset: [8834, 8402],
      NotSubsetEqual: [8840],
      NotSucceeds: [8833],
      NotSucceedsEqual: [10928, 824],
      NotSucceedsSlantEqual: [8929],
      NotSucceedsTilde: [8831, 824],
      NotSuperset: [8835, 8402],
      NotSupersetEqual: [8841],
      NotTilde: [8769],
      NotTildeEqual: [8772],
      NotTildeFullEqual: [8775],
      NotTildeTilde: [8777],
      NotVerticalBar: [8740],
      Nscr: [119977],
      Ntilde: [209],
      Nu: [925],
      OElig: [338],
      Oacute: [211],
      Ocirc: [212],
      Ocy: [1054],
      Odblac: [336],
      Ofr: [120082],
      Ograve: [210],
      Omacr: [332],
      Omega: [937],
      Omicron: [927],
      Oopf: [120134],
      OpenCurlyDoubleQuote: [8220],
      OpenCurlyQuote: [8216],
      Or: [10836],
      Oscr: [119978],
      Oslash: [216],
      Otilde: [213],
      Otimes: [10807],
      Ouml: [214],
      OverBar: [8254],
      OverBrace: [9182],
      OverBracket: [9140],
      OverParenthesis: [9180],
      PartialD: [8706],
      Pcy: [1055],
      Pfr: [120083],
      Phi: [934],
      Pi: [928],
      PlusMinus: [177],
      Poincareplane: [8460],
      Popf: [8473],
      Pr: [10939],
      Precedes: [8826],
      PrecedesEqual: [10927],
      PrecedesSlantEqual: [8828],
      PrecedesTilde: [8830],
      Prime: [8243],
      Product: [8719],
      Proportion: [8759],
      Proportional: [8733],
      Pscr: [119979],
      Psi: [936],
      QUOT: [34],
      Qfr: [120084],
      Qopf: [8474],
      Qscr: [119980],
      RBarr: [10512],
      REG: [174],
      Racute: [340],
      Rang: [10219],
      Rarr: [8608],
      Rarrtl: [10518],
      Rcaron: [344],
      Rcedil: [342],
      Rcy: [1056],
      Re: [8476],
      ReverseElement: [8715],
      ReverseEquilibrium: [8651],
      ReverseUpEquilibrium: [10607],
      Rfr: [8476],
      Rho: [929],
      RightAngleBracket: [10217],
      RightArrow: [8594],
      RightArrowBar: [8677],
      RightArrowLeftArrow: [8644],
      RightCeiling: [8969],
      RightDoubleBracket: [10215],
      RightDownTeeVector: [10589],
      RightDownVector: [8642],
      RightDownVectorBar: [10581],
      RightFloor: [8971],
      RightTee: [8866],
      RightTeeArrow: [8614],
      RightTeeVector: [10587],
      RightTriangle: [8883],
      RightTriangleBar: [10704],
      RightTriangleEqual: [8885],
      RightUpDownVector: [10575],
      RightUpTeeVector: [10588],
      RightUpVector: [8638],
      RightUpVectorBar: [10580],
      RightVector: [8640],
      RightVectorBar: [10579],
      Rightarrow: [8658],
      Ropf: [8477],
      RoundImplies: [10608],
      Rrightarrow: [8667],
      Rscr: [8475],
      Rsh: [8625],
      RuleDelayed: [10740],
      SHCHcy: [1065],
      SHcy: [1064],
      SOFTcy: [1068],
      Sacute: [346],
      Sc: [10940],
      Scaron: [352],
      Scedil: [350],
      Scirc: [348],
      Scy: [1057],
      Sfr: [120086],
      ShortDownArrow: [8595],
      ShortLeftArrow: [8592],
      ShortRightArrow: [8594],
      ShortUpArrow: [8593],
      Sigma: [931],
      SmallCircle: [8728],
      Sopf: [120138],
      Sqrt: [8730],
      Square: [9633],
      SquareIntersection: [8851],
      SquareSubset: [8847],
      SquareSubsetEqual: [8849],
      SquareSuperset: [8848],
      SquareSupersetEqual: [8850],
      SquareUnion: [8852],
      Sscr: [119982],
      Star: [8902],
      Sub: [8912],
      Subset: [8912],
      SubsetEqual: [8838],
      Succeeds: [8827],
      SucceedsEqual: [10928],
      SucceedsSlantEqual: [8829],
      SucceedsTilde: [8831],
      SuchThat: [8715],
      Sum: [8721],
      Sup: [8913],
      Superset: [8835],
      SupersetEqual: [8839],
      Supset: [8913],
      THORN: [222],
      TRADE: [8482],
      TSHcy: [1035],
      TScy: [1062],
      Tab: [9],
      Tau: [932],
      Tcaron: [356],
      Tcedil: [354],
      Tcy: [1058],
      Tfr: [120087],
      Therefore: [8756],
      Theta: [920],
      ThickSpace: [8287, 8202],
      ThinSpace: [8201],
      Tilde: [8764],
      TildeEqual: [8771],
      TildeFullEqual: [8773],
      TildeTilde: [8776],
      Topf: [120139],
      TripleDot: [8411],
      Tscr: [119983],
      Tstrok: [358],
      Uacute: [218],
      Uarr: [8607],
      Uarrocir: [10569],
      Ubrcy: [1038],
      Ubreve: [364],
      Ucirc: [219],
      Ucy: [1059],
      Udblac: [368],
      Ufr: [120088],
      Ugrave: [217],
      Umacr: [362],
      UnderBar: [95],
      UnderBrace: [9183],
      UnderBracket: [9141],
      UnderParenthesis: [9181],
      Union: [8899],
      UnionPlus: [8846],
      Uogon: [370],
      Uopf: [120140],
      UpArrow: [8593],
      UpArrowBar: [10514],
      UpArrowDownArrow: [8645],
      UpDownArrow: [8597],
      UpEquilibrium: [10606],
      UpTee: [8869],
      UpTeeArrow: [8613],
      Uparrow: [8657],
      Updownarrow: [8661],
      UpperLeftArrow: [8598],
      UpperRightArrow: [8599],
      Upsi: [978],
      Upsilon: [933],
      Uring: [366],
      Uscr: [119984],
      Utilde: [360],
      Uuml: [220],
      VDash: [8875],
      Vbar: [10987],
      Vcy: [1042],
      Vdash: [8873],
      Vdashl: [10982],
      Vee: [8897],
      Verbar: [8214],
      Vert: [8214],
      VerticalBar: [8739],
      VerticalLine: [124],
      VerticalSeparator: [10072],
      VerticalTilde: [8768],
      VeryThinSpace: [8202],
      Vfr: [120089],
      Vopf: [120141],
      Vscr: [119985],
      Vvdash: [8874],
      Wcirc: [372],
      Wedge: [8896],
      Wfr: [120090],
      Wopf: [120142],
      Wscr: [119986],
      Xfr: [120091],
      Xi: [926],
      Xopf: [120143],
      Xscr: [119987],
      YAcy: [1071],
      YIcy: [1031],
      YUcy: [1070],
      Yacute: [221],
      Ycirc: [374],
      Ycy: [1067],
      Yfr: [120092],
      Yopf: [120144],
      Yscr: [119988],
      Yuml: [376],
      ZHcy: [1046],
      Zacute: [377],
      Zcaron: [381],
      Zcy: [1047],
      Zdot: [379],
      ZeroWidthSpace: [8203],
      Zeta: [918],
      Zfr: [8488],
      Zopf: [8484],
      Zscr: [119989],
      aacute: [225],
      abreve: [259],
      ac: [8766],
      acE: [8766, 819],
      acd: [8767],
      acirc: [226],
      acute: [180],
      acy: [1072],
      aelig: [230],
      af: [8289],
      afr: [120094],
      agrave: [224],
      alefsym: [8501],
      aleph: [8501],
      alpha: [945],
      amacr: [257],
      amalg: [10815],
      amp: [38],
      and: [8743],
      andand: [10837],
      andd: [10844],
      andslope: [10840],
      andv: [10842],
      ang: [8736],
      ange: [10660],
      angle: [8736],
      angmsd: [8737],
      angmsdaa: [10664],
      angmsdab: [10665],
      angmsdac: [10666],
      angmsdad: [10667],
      angmsdae: [10668],
      angmsdaf: [10669],
      angmsdag: [10670],
      angmsdah: [10671],
      angrt: [8735],
      angrtvb: [8894],
      angrtvbd: [10653],
      angsph: [8738],
      angst: [197],
      angzarr: [9084],
      aogon: [261],
      aopf: [120146],
      ap: [8776],
      apE: [10864],
      apacir: [10863],
      ape: [8778],
      apid: [8779],
      apos: [39],
      approx: [8776],
      approxeq: [8778],
      aring: [229],
      ascr: [119990],
      ast: [42],
      asymp: [8776],
      asympeq: [8781],
      atilde: [227],
      auml: [228],
      awconint: [8755],
      awint: [10769],
      bNot: [10989],
      backcong: [8780],
      backepsilon: [1014],
      backprime: [8245],
      backsim: [8765],
      backsimeq: [8909],
      barvee: [8893],
      barwed: [8965],
      barwedge: [8965],
      bbrk: [9141],
      bbrktbrk: [9142],
      bcong: [8780],
      bcy: [1073],
      bdquo: [8222],
      becaus: [8757],
      because: [8757],
      bemptyv: [10672],
      bepsi: [1014],
      bernou: [8492],
      beta: [946],
      beth: [8502],
      between: [8812],
      bfr: [120095],
      bigcap: [8898],
      bigcirc: [9711],
      bigcup: [8899],
      bigodot: [10752],
      bigoplus: [10753],
      bigotimes: [10754],
      bigsqcup: [10758],
      bigstar: [9733],
      bigtriangledown: [9661],
      bigtriangleup: [9651],
      biguplus: [10756],
      bigvee: [8897],
      bigwedge: [8896],
      bkarow: [10509],
      blacklozenge: [10731],
      blacksquare: [9642],
      blacktriangle: [9652],
      blacktriangledown: [9662],
      blacktriangleleft: [9666],
      blacktriangleright: [9656],
      blank: [9251],
      blk12: [9618],
      blk14: [9617],
      blk34: [9619],
      block: [9608],
      bne: [61, 8421],
      bnequiv: [8801, 8421],
      bnot: [8976],
      bopf: [120147],
      bot: [8869],
      bottom: [8869],
      bowtie: [8904],
      boxDL: [9559],
      boxDR: [9556],
      boxDl: [9558],
      boxDr: [9555],
      boxH: [9552],
      boxHD: [9574],
      boxHU: [9577],
      boxHd: [9572],
      boxHu: [9575],
      boxUL: [9565],
      boxUR: [9562],
      boxUl: [9564],
      boxUr: [9561],
      boxV: [9553],
      boxVH: [9580],
      boxVL: [9571],
      boxVR: [9568],
      boxVh: [9579],
      boxVl: [9570],
      boxVr: [9567],
      boxbox: [10697],
      boxdL: [9557],
      boxdR: [9554],
      boxdl: [9488],
      boxdr: [9484],
      boxh: [9472],
      boxhD: [9573],
      boxhU: [9576],
      boxhd: [9516],
      boxhu: [9524],
      boxminus: [8863],
      boxplus: [8862],
      boxtimes: [8864],
      boxuL: [9563],
      boxuR: [9560],
      boxul: [9496],
      boxur: [9492],
      boxv: [9474],
      boxvH: [9578],
      boxvL: [9569],
      boxvR: [9566],
      boxvh: [9532],
      boxvl: [9508],
      boxvr: [9500],
      bprime: [8245],
      breve: [728],
      brvbar: [166],
      bscr: [119991],
      bsemi: [8271],
      bsim: [8765],
      bsime: [8909],
      bsol: [92],
      bsolb: [10693],
      bsolhsub: [10184],
      bull: [8226],
      bullet: [8226],
      bump: [8782],
      bumpE: [10926],
      bumpe: [8783],
      bumpeq: [8783],
      cacute: [263],
      cap: [8745],
      capand: [10820],
      capbrcup: [10825],
      capcap: [10827],
      capcup: [10823],
      capdot: [10816],
      caps: [8745, 65024],
      caret: [8257],
      caron: [711],
      ccaps: [10829],
      ccaron: [269],
      ccedil: [231],
      ccirc: [265],
      ccups: [10828],
      ccupssm: [10832],
      cdot: [267],
      cedil: [184],
      cemptyv: [10674],
      cent: [162],
      centerdot: [183],
      cfr: [120096],
      chcy: [1095],
      check: [10003],
      checkmark: [10003],
      chi: [967],
      cir: [9675],
      cirE: [10691],
      circ: [710],
      circeq: [8791],
      circlearrowleft: [8634],
      circlearrowright: [8635],
      circledR: [174],
      circledS: [9416],
      circledast: [8859],
      circledcirc: [8858],
      circleddash: [8861],
      cire: [8791],
      cirfnint: [10768],
      cirmid: [10991],
      cirscir: [10690],
      clubs: [9827],
      clubsuit: [9827],
      colon: [58],
      colone: [8788],
      coloneq: [8788],
      comma: [44],
      commat: [64],
      comp: [8705],
      compfn: [8728],
      complement: [8705],
      complexes: [8450],
      cong: [8773],
      congdot: [10861],
      conint: [8750],
      copf: [120148],
      coprod: [8720],
      copy: [169],
      copysr: [8471],
      crarr: [8629],
      cross: [10007],
      cscr: [119992],
      csub: [10959],
      csube: [10961],
      csup: [10960],
      csupe: [10962],
      ctdot: [8943],
      cudarrl: [10552],
      cudarrr: [10549],
      cuepr: [8926],
      cuesc: [8927],
      cularr: [8630],
      cularrp: [10557],
      cup: [8746],
      cupbrcap: [10824],
      cupcap: [10822],
      cupcup: [10826],
      cupdot: [8845],
      cupor: [10821],
      cups: [8746, 65024],
      curarr: [8631],
      curarrm: [10556],
      curlyeqprec: [8926],
      curlyeqsucc: [8927],
      curlyvee: [8910],
      curlywedge: [8911],
      curren: [164],
      curvearrowleft: [8630],
      curvearrowright: [8631],
      cuvee: [8910],
      cuwed: [8911],
      cwconint: [8754],
      cwint: [8753],
      cylcty: [9005],
      dArr: [8659],
      dHar: [10597],
      dagger: [8224],
      daleth: [8504],
      darr: [8595],
      dash: [8208],
      dashv: [8867],
      dbkarow: [10511],
      dblac: [733],
      dcaron: [271],
      dcy: [1076],
      dd: [8518],
      ddagger: [8225],
      ddarr: [8650],
      ddotseq: [10871],
      deg: [176],
      delta: [948],
      demptyv: [10673],
      dfisht: [10623],
      dfr: [120097],
      dharl: [8643],
      dharr: [8642],
      diam: [8900],
      diamond: [8900],
      diamondsuit: [9830],
      diams: [9830],
      die: [168],
      digamma: [989],
      disin: [8946],
      div: [247],
      divide: [247],
      divideontimes: [8903],
      divonx: [8903],
      djcy: [1106],
      dlcorn: [8990],
      dlcrop: [8973],
      dollar: [36],
      dopf: [120149],
      dot: [729],
      doteq: [8784],
      doteqdot: [8785],
      dotminus: [8760],
      dotplus: [8724],
      dotsquare: [8865],
      doublebarwedge: [8966],
      downarrow: [8595],
      downdownarrows: [8650],
      downharpoonleft: [8643],
      downharpoonright: [8642],
      drbkarow: [10512],
      drcorn: [8991],
      drcrop: [8972],
      dscr: [119993],
      dscy: [1109],
      dsol: [10742],
      dstrok: [273],
      dtdot: [8945],
      dtri: [9663],
      dtrif: [9662],
      duarr: [8693],
      duhar: [10607],
      dwangle: [10662],
      dzcy: [1119],
      dzigrarr: [10239],
      eDDot: [10871],
      eDot: [8785],
      eacute: [233],
      easter: [10862],
      ecaron: [283],
      ecir: [8790],
      ecirc: [234],
      ecolon: [8789],
      ecy: [1101],
      edot: [279],
      ee: [8519],
      efDot: [8786],
      efr: [120098],
      eg: [10906],
      egrave: [232],
      egs: [10902],
      egsdot: [10904],
      el: [10905],
      elinters: [9191],
      ell: [8467],
      els: [10901],
      elsdot: [10903],
      emacr: [275],
      empty: [8709],
      emptyset: [8709],
      emptyv: [8709],
      emsp: [8195],
      emsp13: [8196],
      emsp14: [8197],
      eng: [331],
      ensp: [8194],
      eogon: [281],
      eopf: [120150],
      epar: [8917],
      eparsl: [10723],
      eplus: [10865],
      epsi: [949],
      epsilon: [949],
      epsiv: [1013],
      eqcirc: [8790],
      eqcolon: [8789],
      eqsim: [8770],
      eqslantgtr: [10902],
      eqslantless: [10901],
      equals: [61],
      equest: [8799],
      equiv: [8801],
      equivDD: [10872],
      eqvparsl: [10725],
      erDot: [8787],
      erarr: [10609],
      escr: [8495],
      esdot: [8784],
      esim: [8770],
      eta: [951],
      eth: [240],
      euml: [235],
      euro: [8364],
      excl: [33],
      exist: [8707],
      expectation: [8496],
      exponentiale: [8519],
      fallingdotseq: [8786],
      fcy: [1092],
      female: [9792],
      ffilig: [64259],
      fflig: [64256],
      ffllig: [64260],
      ffr: [120099],
      filig: [64257],
      fjlig: [102, 106],
      flat: [9837],
      fllig: [64258],
      fltns: [9649],
      fnof: [402],
      fopf: [120151],
      forall: [8704],
      fork: [8916],
      forkv: [10969],
      fpartint: [10765],
      frac12: [189],
      frac13: [8531],
      frac14: [188],
      frac15: [8533],
      frac16: [8537],
      frac18: [8539],
      frac23: [8532],
      frac25: [8534],
      frac34: [190],
      frac35: [8535],
      frac38: [8540],
      frac45: [8536],
      frac56: [8538],
      frac58: [8541],
      frac78: [8542],
      frasl: [8260],
      frown: [8994],
      fscr: [119995],
      gE: [8807],
      gEl: [10892],
      gacute: [501],
      gamma: [947],
      gammad: [989],
      gap: [10886],
      gbreve: [287],
      gcirc: [285],
      gcy: [1075],
      gdot: [289],
      ge: [8805],
      gel: [8923],
      geq: [8805],
      geqq: [8807],
      geqslant: [10878],
      ges: [10878],
      gescc: [10921],
      gesdot: [10880],
      gesdoto: [10882],
      gesdotol: [10884],
      gesl: [8923, 65024],
      gesles: [10900],
      gfr: [120100],
      gg: [8811],
      ggg: [8921],
      gimel: [8503],
      gjcy: [1107],
      gl: [8823],
      glE: [10898],
      gla: [10917],
      glj: [10916],
      gnE: [8809],
      gnap: [10890],
      gnapprox: [10890],
      gne: [10888],
      gneq: [10888],
      gneqq: [8809],
      gnsim: [8935],
      gopf: [120152],
      grave: [96],
      gscr: [8458],
      gsim: [8819],
      gsime: [10894],
      gsiml: [10896],
      gt: [62],
      gtcc: [10919],
      gtcir: [10874],
      gtdot: [8919],
      gtlPar: [10645],
      gtquest: [10876],
      gtrapprox: [10886],
      gtrarr: [10616],
      gtrdot: [8919],
      gtreqless: [8923],
      gtreqqless: [10892],
      gtrless: [8823],
      gtrsim: [8819],
      gvertneqq: [8809, 65024],
      gvnE: [8809, 65024],
      hArr: [8660],
      hairsp: [8202],
      half: [189],
      hamilt: [8459],
      hardcy: [1098],
      harr: [8596],
      harrcir: [10568],
      harrw: [8621],
      hbar: [8463],
      hcirc: [293],
      hearts: [9829],
      heartsuit: [9829],
      hellip: [8230],
      hercon: [8889],
      hfr: [120101],
      hksearow: [10533],
      hkswarow: [10534],
      hoarr: [8703],
      homtht: [8763],
      hookleftarrow: [8617],
      hookrightarrow: [8618],
      hopf: [120153],
      horbar: [8213],
      hscr: [119997],
      hslash: [8463],
      hstrok: [295],
      hybull: [8259],
      hyphen: [8208],
      iacute: [237],
      ic: [8291],
      icirc: [238],
      icy: [1080],
      iecy: [1077],
      iexcl: [161],
      iff: [8660],
      ifr: [120102],
      igrave: [236],
      ii: [8520],
      iiiint: [10764],
      iiint: [8749],
      iinfin: [10716],
      iiota: [8489],
      ijlig: [307],
      imacr: [299],
      image: [8465],
      imagline: [8464],
      imagpart: [8465],
      imath: [305],
      imof: [8887],
      imped: [437],
      "in": [8712],
      incare: [8453],
      infin: [8734],
      infintie: [10717],
      inodot: [305],
      "int": [8747],
      intcal: [8890],
      integers: [8484],
      intercal: [8890],
      intlarhk: [10775],
      intprod: [10812],
      iocy: [1105],
      iogon: [303],
      iopf: [120154],
      iota: [953],
      iprod: [10812],
      iquest: [191],
      iscr: [119998],
      isin: [8712],
      isinE: [8953],
      isindot: [8949],
      isins: [8948],
      isinsv: [8947],
      isinv: [8712],
      it: [8290],
      itilde: [297],
      iukcy: [1110],
      iuml: [239],
      jcirc: [309],
      jcy: [1081],
      jfr: [120103],
      jmath: [567],
      jopf: [120155],
      jscr: [119999],
      jsercy: [1112],
      jukcy: [1108],
      kappa: [954],
      kappav: [1008],
      kcedil: [311],
      kcy: [1082],
      kfr: [120104],
      kgreen: [312],
      khcy: [1093],
      kjcy: [1116],
      kopf: [120156],
      kscr: [120000],
      lAarr: [8666],
      lArr: [8656],
      lAtail: [10523],
      lBarr: [10510],
      lE: [8806],
      lEg: [10891],
      lHar: [10594],
      lacute: [314],
      laemptyv: [10676],
      lagran: [8466],
      lambda: [955],
      lang: [10216],
      langd: [10641],
      langle: [10216],
      lap: [10885],
      laquo: [171],
      larr: [8592],
      larrb: [8676],
      larrbfs: [10527],
      larrfs: [10525],
      larrhk: [8617],
      larrlp: [8619],
      larrpl: [10553],
      larrsim: [10611],
      larrtl: [8610],
      lat: [10923],
      latail: [10521],
      late: [10925],
      lates: [10925, 65024],
      lbarr: [10508],
      lbbrk: [10098],
      lbrace: [123],
      lbrack: [91],
      lbrke: [10635],
      lbrksld: [10639],
      lbrkslu: [10637],
      lcaron: [318],
      lcedil: [316],
      lceil: [8968],
      lcub: [123],
      lcy: [1083],
      ldca: [10550],
      ldquo: [8220],
      ldquor: [8222],
      ldrdhar: [10599],
      ldrushar: [10571],
      ldsh: [8626],
      le: [8804],
      leftarrow: [8592],
      leftarrowtail: [8610],
      leftharpoondown: [8637],
      leftharpoonup: [8636],
      leftleftarrows: [8647],
      leftrightarrow: [8596],
      leftrightarrows: [8646],
      leftrightharpoons: [8651],
      leftrightsquigarrow: [8621],
      leftthreetimes: [8907],
      leg: [8922],
      leq: [8804],
      leqq: [8806],
      leqslant: [10877],
      les: [10877],
      lescc: [10920],
      lesdot: [10879],
      lesdoto: [10881],
      lesdotor: [10883],
      lesg: [8922, 65024],
      lesges: [10899],
      lessapprox: [10885],
      lessdot: [8918],
      lesseqgtr: [8922],
      lesseqqgtr: [10891],
      lessgtr: [8822],
      lesssim: [8818],
      lfisht: [10620],
      lfloor: [8970],
      lfr: [120105],
      lg: [8822],
      lgE: [10897],
      lhard: [8637],
      lharu: [8636],
      lharul: [10602],
      lhblk: [9604],
      ljcy: [1113],
      ll: [8810],
      llarr: [8647],
      llcorner: [8990],
      llhard: [10603],
      lltri: [9722],
      lmidot: [320],
      lmoust: [9136],
      lmoustache: [9136],
      lnE: [8808],
      lnap: [10889],
      lnapprox: [10889],
      lne: [10887],
      lneq: [10887],
      lneqq: [8808],
      lnsim: [8934],
      loang: [10220],
      loarr: [8701],
      lobrk: [10214],
      longleftarrow: [10229],
      longleftrightarrow: [10231],
      longmapsto: [10236],
      longrightarrow: [10230],
      looparrowleft: [8619],
      looparrowright: [8620],
      lopar: [10629],
      lopf: [120157],
      loplus: [10797],
      lotimes: [10804],
      lowast: [8727],
      lowbar: [95],
      loz: [9674],
      lozenge: [9674],
      lozf: [10731],
      lpar: [40],
      lparlt: [10643],
      lrarr: [8646],
      lrcorner: [8991],
      lrhar: [8651],
      lrhard: [10605],
      lrm: [8206],
      lrtri: [8895],
      lsaquo: [8249],
      lscr: [120001],
      lsh: [8624],
      lsim: [8818],
      lsime: [10893],
      lsimg: [10895],
      lsqb: [91],
      lsquo: [8216],
      lsquor: [8218],
      lstrok: [322],
      lt: [60],
      ltcc: [10918],
      ltcir: [10873],
      ltdot: [8918],
      lthree: [8907],
      ltimes: [8905],
      ltlarr: [10614],
      ltquest: [10875],
      ltrPar: [10646],
      ltri: [9667],
      ltrie: [8884],
      ltrif: [9666],
      lurdshar: [10570],
      luruhar: [10598],
      lvertneqq: [8808, 65024],
      lvnE: [8808, 65024],
      mDDot: [8762],
      macr: [175],
      male: [9794],
      malt: [10016],
      maltese: [10016],
      map: [8614],
      mapsto: [8614],
      mapstodown: [8615],
      mapstoleft: [8612],
      mapstoup: [8613],
      marker: [9646],
      mcomma: [10793],
      mcy: [1084],
      mdash: [8212],
      measuredangle: [8737],
      mfr: [120106],
      mho: [8487],
      micro: [181],
      mid: [8739],
      midast: [42],
      midcir: [10992],
      middot: [183],
      minus: [8722],
      minusb: [8863],
      minusd: [8760],
      minusdu: [10794],
      mlcp: [10971],
      mldr: [8230],
      mnplus: [8723],
      models: [8871],
      mopf: [120158],
      mp: [8723],
      mscr: [120002],
      mstpos: [8766],
      mu: [956],
      multimap: [8888],
      mumap: [8888],
      nGg: [8921, 824],
      nGt: [8811, 8402],
      nGtv: [8811, 824],
      nLeftarrow: [8653],
      nLeftrightarrow: [8654],
      nLl: [8920, 824],
      nLt: [8810, 8402],
      nLtv: [8810, 824],
      nRightarrow: [8655],
      nVDash: [8879],
      nVdash: [8878],
      nabla: [8711],
      nacute: [324],
      nang: [8736, 8402],
      nap: [8777],
      napE: [10864, 824],
      napid: [8779, 824],
      napos: [329],
      napprox: [8777],
      natur: [9838],
      natural: [9838],
      naturals: [8469],
      nbsp: [160],
      nbump: [8782, 824],
      nbumpe: [8783, 824],
      ncap: [10819],
      ncaron: [328],
      ncedil: [326],
      ncong: [8775],
      ncongdot: [10861, 824],
      ncup: [10818],
      ncy: [1085],
      ndash: [8211],
      ne: [8800],
      neArr: [8663],
      nearhk: [10532],
      nearr: [8599],
      nearrow: [8599],
      nedot: [8784, 824],
      nequiv: [8802],
      nesear: [10536],
      nesim: [8770, 824],
      nexist: [8708],
      nexists: [8708],
      nfr: [120107],
      ngE: [8807, 824],
      nge: [8817],
      ngeq: [8817],
      ngeqq: [8807, 824],
      ngeqslant: [10878, 824],
      nges: [10878, 824],
      ngsim: [8821],
      ngt: [8815],
      ngtr: [8815],
      nhArr: [8654],
      nharr: [8622],
      nhpar: [10994],
      ni: [8715],
      nis: [8956],
      nisd: [8954],
      niv: [8715],
      njcy: [1114],
      nlArr: [8653],
      nlE: [8806, 824],
      nlarr: [8602],
      nldr: [8229],
      nle: [8816],
      nleftarrow: [8602],
      nleftrightarrow: [8622],
      nleq: [8816],
      nleqq: [8806, 824],
      nleqslant: [10877, 824],
      nles: [10877, 824],
      nless: [8814],
      nlsim: [8820],
      nlt: [8814],
      nltri: [8938],
      nltrie: [8940],
      nmid: [8740],
      nopf: [120159],
      not: [172],
      notin: [8713],
      notinE: [8953, 824],
      notindot: [8949, 824],
      notinva: [8713],
      notinvb: [8951],
      notinvc: [8950],
      notni: [8716],
      notniva: [8716],
      notnivb: [8958],
      notnivc: [8957],
      npar: [8742],
      nparallel: [8742],
      nparsl: [11005, 8421],
      npart: [8706, 824],
      npolint: [10772],
      npr: [8832],
      nprcue: [8928],
      npre: [10927, 824],
      nprec: [8832],
      npreceq: [10927, 824],
      nrArr: [8655],
      nrarr: [8603],
      nrarrc: [10547, 824],
      nrarrw: [8605, 824],
      nrightarrow: [8603],
      nrtri: [8939],
      nrtrie: [8941],
      nsc: [8833],
      nsccue: [8929],
      nsce: [10928, 824],
      nscr: [120003],
      nshortmid: [8740],
      nshortparallel: [8742],
      nsim: [8769],
      nsime: [8772],
      nsimeq: [8772],
      nsmid: [8740],
      nspar: [8742],
      nsqsube: [8930],
      nsqsupe: [8931],
      nsub: [8836],
      nsubE: [10949, 824],
      nsube: [8840],
      nsubset: [8834, 8402],
      nsubseteq: [8840],
      nsubseteqq: [10949, 824],
      nsucc: [8833],
      nsucceq: [10928, 824],
      nsup: [8837],
      nsupE: [10950, 824],
      nsupe: [8841],
      nsupset: [8835, 8402],
      nsupseteq: [8841],
      nsupseteqq: [10950, 824],
      ntgl: [8825],
      ntilde: [241],
      ntlg: [8824],
      ntriangleleft: [8938],
      ntrianglelefteq: [8940],
      ntriangleright: [8939],
      ntrianglerighteq: [8941],
      nu: [957],
      num: [35],
      numero: [8470],
      numsp: [8199],
      nvDash: [8877],
      nvHarr: [10500],
      nvap: [8781, 8402],
      nvdash: [8876],
      nvge: [8805, 8402],
      nvgt: [62, 8402],
      nvinfin: [10718],
      nvlArr: [10498],
      nvle: [8804, 8402],
      nvlt: [60, 8402],
      nvltrie: [8884, 8402],
      nvrArr: [10499],
      nvrtrie: [8885, 8402],
      nvsim: [8764, 8402],
      nwArr: [8662],
      nwarhk: [10531],
      nwarr: [8598],
      nwarrow: [8598],
      nwnear: [10535],
      oS: [9416],
      oacute: [243],
      oast: [8859],
      ocir: [8858],
      ocirc: [244],
      ocy: [1086],
      odash: [8861],
      odblac: [337],
      odiv: [10808],
      odot: [8857],
      odsold: [10684],
      oelig: [339],
      ofcir: [10687],
      ofr: [120108],
      ogon: [731],
      ograve: [242],
      ogt: [10689],
      ohbar: [10677],
      ohm: [937],
      oint: [8750],
      olarr: [8634],
      olcir: [10686],
      olcross: [10683],
      oline: [8254],
      olt: [10688],
      omacr: [333],
      omega: [969],
      omicron: [959],
      omid: [10678],
      ominus: [8854],
      oopf: [120160],
      opar: [10679],
      operp: [10681],
      oplus: [8853],
      or: [8744],
      orarr: [8635],
      ord: [10845],
      order: [8500],
      orderof: [8500],
      ordf: [170],
      ordm: [186],
      origof: [8886],
      oror: [10838],
      orslope: [10839],
      orv: [10843],
      oscr: [8500],
      oslash: [248],
      osol: [8856],
      otilde: [245],
      otimes: [8855],
      otimesas: [10806],
      ouml: [246],
      ovbar: [9021],
      par: [8741],
      para: [182],
      parallel: [8741],
      parsim: [10995],
      parsl: [11005],
      part: [8706],
      pcy: [1087],
      percnt: [37],
      period: [46],
      permil: [8240],
      perp: [8869],
      pertenk: [8241],
      pfr: [120109],
      phi: [966],
      phiv: [981],
      phmmat: [8499],
      phone: [9742],
      pi: [960],
      pitchfork: [8916],
      piv: [982],
      planck: [8463],
      planckh: [8462],
      plankv: [8463],
      plus: [43],
      plusacir: [10787],
      plusb: [8862],
      pluscir: [10786],
      plusdo: [8724],
      plusdu: [10789],
      pluse: [10866],
      plusmn: [177],
      plussim: [10790],
      plustwo: [10791],
      pm: [177],
      pointint: [10773],
      popf: [120161],
      pound: [163],
      pr: [8826],
      prE: [10931],
      prap: [10935],
      prcue: [8828],
      pre: [10927],
      prec: [8826],
      precapprox: [10935],
      preccurlyeq: [8828],
      preceq: [10927],
      precnapprox: [10937],
      precneqq: [10933],
      precnsim: [8936],
      precsim: [8830],
      prime: [8242],
      primes: [8473],
      prnE: [10933],
      prnap: [10937],
      prnsim: [8936],
      prod: [8719],
      profalar: [9006],
      profline: [8978],
      profsurf: [8979],
      prop: [8733],
      propto: [8733],
      prsim: [8830],
      prurel: [8880],
      pscr: [120005],
      psi: [968],
      puncsp: [8200],
      qfr: [120110],
      qint: [10764],
      qopf: [120162],
      qprime: [8279],
      qscr: [120006],
      quaternions: [8461],
      quatint: [10774],
      quest: [63],
      questeq: [8799],
      quot: [34],
      rAarr: [8667],
      rArr: [8658],
      rAtail: [10524],
      rBarr: [10511],
      rHar: [10596],
      race: [8765, 817],
      racute: [341],
      radic: [8730],
      raemptyv: [10675],
      rang: [10217],
      rangd: [10642],
      range: [10661],
      rangle: [10217],
      raquo: [187],
      rarr: [8594],
      rarrap: [10613],
      rarrb: [8677],
      rarrbfs: [10528],
      rarrc: [10547],
      rarrfs: [10526],
      rarrhk: [8618],
      rarrlp: [8620],
      rarrpl: [10565],
      rarrsim: [10612],
      rarrtl: [8611],
      rarrw: [8605],
      ratail: [10522],
      ratio: [8758],
      rationals: [8474],
      rbarr: [10509],
      rbbrk: [10099],
      rbrace: [125],
      rbrack: [93],
      rbrke: [10636],
      rbrksld: [10638],
      rbrkslu: [10640],
      rcaron: [345],
      rcedil: [343],
      rceil: [8969],
      rcub: [125],
      rcy: [1088],
      rdca: [10551],
      rdldhar: [10601],
      rdquo: [8221],
      rdquor: [8221],
      rdsh: [8627],
      real: [8476],
      realine: [8475],
      realpart: [8476],
      reals: [8477],
      rect: [9645],
      reg: [174],
      rfisht: [10621],
      rfloor: [8971],
      rfr: [120111],
      rhard: [8641],
      rharu: [8640],
      rharul: [10604],
      rho: [961],
      rhov: [1009],
      rightarrow: [8594],
      rightarrowtail: [8611],
      rightharpoondown: [8641],
      rightharpoonup: [8640],
      rightleftarrows: [8644],
      rightleftharpoons: [8652],
      rightrightarrows: [8649],
      rightsquigarrow: [8605],
      rightthreetimes: [8908],
      ring: [730],
      risingdotseq: [8787],
      rlarr: [8644],
      rlhar: [8652],
      rlm: [8207],
      rmoust: [9137],
      rmoustache: [9137],
      rnmid: [10990],
      roang: [10221],
      roarr: [8702],
      robrk: [10215],
      ropar: [10630],
      ropf: [120163],
      roplus: [10798],
      rotimes: [10805],
      rpar: [41],
      rpargt: [10644],
      rppolint: [10770],
      rrarr: [8649],
      rsaquo: [8250],
      rscr: [120007],
      rsh: [8625],
      rsqb: [93],
      rsquo: [8217],
      rsquor: [8217],
      rthree: [8908],
      rtimes: [8906],
      rtri: [9657],
      rtrie: [8885],
      rtrif: [9656],
      rtriltri: [10702],
      ruluhar: [10600],
      rx: [8478],
      sacute: [347],
      sbquo: [8218],
      sc: [8827],
      scE: [10932],
      scap: [10936],
      scaron: [353],
      sccue: [8829],
      sce: [10928],
      scedil: [351],
      scirc: [349],
      scnE: [10934],
      scnap: [10938],
      scnsim: [8937],
      scpolint: [10771],
      scsim: [8831],
      scy: [1089],
      sdot: [8901],
      sdotb: [8865],
      sdote: [10854],
      seArr: [8664],
      searhk: [10533],
      searr: [8600],
      searrow: [8600],
      sect: [167],
      semi: [59],
      seswar: [10537],
      setminus: [8726],
      setmn: [8726],
      sext: [10038],
      sfr: [120112],
      sfrown: [8994],
      sharp: [9839],
      shchcy: [1097],
      shcy: [1096],
      shortmid: [8739],
      shortparallel: [8741],
      shy: [173],
      sigma: [963],
      sigmaf: [962],
      sigmav: [962],
      sim: [8764],
      simdot: [10858],
      sime: [8771],
      simeq: [8771],
      simg: [10910],
      simgE: [10912],
      siml: [10909],
      simlE: [10911],
      simne: [8774],
      simplus: [10788],
      simrarr: [10610],
      slarr: [8592],
      smallsetminus: [8726],
      smashp: [10803],
      smeparsl: [10724],
      smid: [8739],
      smile: [8995],
      smt: [10922],
      smte: [10924],
      smtes: [10924, 65024],
      softcy: [1100],
      sol: [47],
      solb: [10692],
      solbar: [9023],
      sopf: [120164],
      spades: [9824],
      spadesuit: [9824],
      spar: [8741],
      sqcap: [8851],
      sqcaps: [8851, 65024],
      sqcup: [8852],
      sqcups: [8852, 65024],
      sqsub: [8847],
      sqsube: [8849],
      sqsubset: [8847],
      sqsubseteq: [8849],
      sqsup: [8848],
      sqsupe: [8850],
      sqsupset: [8848],
      sqsupseteq: [8850],
      squ: [9633],
      square: [9633],
      squarf: [9642],
      squf: [9642],
      srarr: [8594],
      sscr: [120008],
      ssetmn: [8726],
      ssmile: [8995],
      sstarf: [8902],
      star: [9734],
      starf: [9733],
      straightepsilon: [1013],
      straightphi: [981],
      strns: [175],
      sub: [8834],
      subE: [10949],
      subdot: [10941],
      sube: [8838],
      subedot: [10947],
      submult: [10945],
      subnE: [10955],
      subne: [8842],
      subplus: [10943],
      subrarr: [10617],
      subset: [8834],
      subseteq: [8838],
      subseteqq: [10949],
      subsetneq: [8842],
      subsetneqq: [10955],
      subsim: [10951],
      subsub: [10965],
      subsup: [10963],
      succ: [8827],
      succapprox: [10936],
      succcurlyeq: [8829],
      succeq: [10928],
      succnapprox: [10938],
      succneqq: [10934],
      succnsim: [8937],
      succsim: [8831],
      sum: [8721],
      sung: [9834],
      sup: [8835],
      sup1: [185],
      sup2: [178],
      sup3: [179],
      supE: [10950],
      supdot: [10942],
      supdsub: [10968],
      supe: [8839],
      supedot: [10948],
      suphsol: [10185],
      suphsub: [10967],
      suplarr: [10619],
      supmult: [10946],
      supnE: [10956],
      supne: [8843],
      supplus: [10944],
      supset: [8835],
      supseteq: [8839],
      supseteqq: [10950],
      supsetneq: [8843],
      supsetneqq: [10956],
      supsim: [10952],
      supsub: [10964],
      supsup: [10966],
      swArr: [8665],
      swarhk: [10534],
      swarr: [8601],
      swarrow: [8601],
      swnwar: [10538],
      szlig: [223],
      target: [8982],
      tau: [964],
      tbrk: [9140],
      tcaron: [357],
      tcedil: [355],
      tcy: [1090],
      tdot: [8411],
      telrec: [8981],
      tfr: [120113],
      there4: [8756],
      therefore: [8756],
      theta: [952],
      thetasym: [977],
      thetav: [977],
      thickapprox: [8776],
      thicksim: [8764],
      thinsp: [8201],
      thkap: [8776],
      thksim: [8764],
      thorn: [254],
      tilde: [732],
      times: [215],
      timesb: [8864],
      timesbar: [10801],
      timesd: [10800],
      tint: [8749],
      toea: [10536],
      top: [8868],
      topbot: [9014],
      topcir: [10993],
      topf: [120165],
      topfork: [10970],
      tosa: [10537],
      tprime: [8244],
      trade: [8482],
      triangle: [9653],
      triangledown: [9663],
      triangleleft: [9667],
      trianglelefteq: [8884],
      triangleq: [8796],
      triangleright: [9657],
      trianglerighteq: [8885],
      tridot: [9708],
      trie: [8796],
      triminus: [10810],
      triplus: [10809],
      trisb: [10701],
      tritime: [10811],
      trpezium: [9186],
      tscr: [120009],
      tscy: [1094],
      tshcy: [1115],
      tstrok: [359],
      twixt: [8812],
      twoheadleftarrow: [8606],
      twoheadrightarrow: [8608],
      uArr: [8657],
      uHar: [10595],
      uacute: [250],
      uarr: [8593],
      ubrcy: [1118],
      ubreve: [365],
      ucirc: [251],
      ucy: [1091],
      udarr: [8645],
      udblac: [369],
      udhar: [10606],
      ufisht: [10622],
      ufr: [120114],
      ugrave: [249],
      uharl: [8639],
      uharr: [8638],
      uhblk: [9600],
      ulcorn: [8988],
      ulcorner: [8988],
      ulcrop: [8975],
      ultri: [9720],
      umacr: [363],
      uml: [168],
      uogon: [371],
      uopf: [120166],
      uparrow: [8593],
      updownarrow: [8597],
      upharpoonleft: [8639],
      upharpoonright: [8638],
      uplus: [8846],
      upsi: [965],
      upsih: [978],
      upsilon: [965],
      upuparrows: [8648],
      urcorn: [8989],
      urcorner: [8989],
      urcrop: [8974],
      uring: [367],
      urtri: [9721],
      uscr: [120010],
      utdot: [8944],
      utilde: [361],
      utri: [9653],
      utrif: [9652],
      uuarr: [8648],
      uuml: [252],
      uwangle: [10663],
      vArr: [8661],
      vBar: [10984],
      vBarv: [10985],
      vDash: [8872],
      vangrt: [10652],
      varepsilon: [1013],
      varkappa: [1008],
      varnothing: [8709],
      varphi: [981],
      varpi: [982],
      varpropto: [8733],
      varr: [8597],
      varrho: [1009],
      varsigma: [962],
      varsubsetneq: [8842, 65024],
      varsubsetneqq: [10955, 65024],
      varsupsetneq: [8843, 65024],
      varsupsetneqq: [10956, 65024],
      vartheta: [977],
      vartriangleleft: [8882],
      vartriangleright: [8883],
      vcy: [1074],
      vdash: [8866],
      vee: [8744],
      veebar: [8891],
      veeeq: [8794],
      vellip: [8942],
      verbar: [124],
      vert: [124],
      vfr: [120115],
      vltri: [8882],
      vnsub: [8834, 8402],
      vnsup: [8835, 8402],
      vopf: [120167],
      vprop: [8733],
      vrtri: [8883],
      vscr: [120011],
      vsubnE: [10955, 65024],
      vsubne: [8842, 65024],
      vsupnE: [10956, 65024],
      vsupne: [8843, 65024],
      vzigzag: [10650],
      wcirc: [373],
      wedbar: [10847],
      wedge: [8743],
      wedgeq: [8793],
      weierp: [8472],
      wfr: [120116],
      wopf: [120168],
      wp: [8472],
      wr: [8768],
      wreath: [8768],
      wscr: [120012],
      xcap: [8898],
      xcirc: [9711],
      xcup: [8899],
      xdtri: [9661],
      xfr: [120117],
      xhArr: [10234],
      xharr: [10231],
      xi: [958],
      xlArr: [10232],
      xlarr: [10229],
      xmap: [10236],
      xnis: [8955],
      xodot: [10752],
      xopf: [120169],
      xoplus: [10753],
      xotime: [10754],
      xrArr: [10233],
      xrarr: [10230],
      xscr: [120013],
      xsqcup: [10758],
      xuplus: [10756],
      xutri: [9651],
      xvee: [8897],
      xwedge: [8896],
      yacute: [253],
      yacy: [1103],
      ycirc: [375],
      ycy: [1099],
      yen: [165],
      yfr: [120118],
      yicy: [1111],
      yopf: [120170],
      yscr: [120014],
      yucy: [1102],
      yuml: [255],
      zacute: [378],
      zcaron: [382],
      zcy: [1079],
      zdot: [380],
      zeetrf: [8488],
      zeta: [950],
      zfr: [120119],
      zhcy: [1078],
      zigrarr: [8669],
      zopf: [120171],
      zscr: [120015],
      zwj: [8205],
      zwnj: [8204]
    };
  });
enifed("simple-html-tokenizer/char-refs/min",
  ["exports"],
  function(__exports__) {
    "use strict";
    __exports__["default"] = {
      quot: [34],
      amp: [38],
      apos: [39],
      lt: [60],
      gt: [62]
    };
  });
enifed("simple-html-tokenizer/entity-parser",
  ["exports"],
  function(__exports__) {
    "use strict";
    function EntityParser(namedCodepoints) {
      this.namedCodepoints = namedCodepoints;
    }

    EntityParser.prototype.parse = function (tokenizer) {
      var input = tokenizer.input.slice(tokenizer["char"]);
      var matches = input.match(/^#(?:x|X)([0-9A-Fa-f]+);/);
      if (matches) {
        tokenizer["char"] += matches[0].length;
        return String.fromCharCode(parseInt(matches[1], 16));
      }
      matches = input.match(/^#([0-9]+);/);
      if (matches) {
        tokenizer["char"] += matches[0].length;
        return String.fromCharCode(parseInt(matches[1], 10));
      }
      matches = input.match(/^([A-Za-z]+);/);
      if (matches) {
        var codepoints = this.namedCodepoints[matches[1]];
        if (codepoints) {
          tokenizer["char"] += matches[0].length;
          for (var i = 0, buffer = ''; i < codepoints.length; i++) {
            buffer += String.fromCharCode(codepoints[i]);
          }
          return buffer;
        }
      }
    };

    __exports__["default"] = EntityParser;
  });
enifed("simple-html-tokenizer/generate",
  ["./generator","exports"],
  function(__dependency1__, __exports__) {
    "use strict";
    var Generator = __dependency1__["default"];

    __exports__["default"] = function generate(tokens) {
      var generator = new Generator();
      return generator.generate(tokens);
    }
  });
enifed("simple-html-tokenizer/generator",
  ["exports"],
  function(__exports__) {
    "use strict";
    var escape =  (function () {
      var test = /[&<>"'`]/;
      var replace = /[&<>"'`]/g;
      var map = {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#x27;",
        "`": "&#x60;"
      };
      function escapeChar(char) {
        return map["char"];
      }
      return function escape(string) {
        if(!test.test(string)) {
          return string;
        }
        return string.replace(replace, escapeChar);
      };
    }());

    function Generator() {
      this.escape = escape;
    }

    Generator.prototype = {
      generate: function (tokens) {
        var buffer = '';
        var token;
        for (var i=0; i<tokens.length; i++) {
          token = tokens[i];
          buffer += this[token.type](token);
        }
        return buffer;
      },

      escape: function (text) {
        var unsafeCharsMap = this.unsafeCharsMap;
        return text.replace(this.unsafeChars, function (char) {
          return unsafeCharsMap["char"] || char;
        });
      },

      StartTag: function (token) {
        var out = "<";
        out += token.tagName;

        if (token.attributes.length) {
          out += " " + this.Attributes(token.attributes);
        }

        out += ">";

        return out;
      },

      EndTag: function (token) {
        return "</" + token.tagName + ">";
      },

      Chars: function (token) {
        return this.escape(token.chars);
      },

      Comment: function (token) {
        return "<!--" + token.chars + "-->";
      },

      Attributes: function (attributes) {
        var out = [], attribute;

        for (var i=0, l=attributes.length; i<l; i++) {
          attribute = attributes[i];

          out.push(this.Attribute(attribute[0], attribute[1]));
        }

        return out.join(" ");
      },

      Attribute: function (name, value) {
        var attrString = name;

        if (value) {
          value = this.escape(value);
          attrString += "=\"" + value + "\"";
        }

        return attrString;
      }
    };

    __exports__["default"] = Generator;
  });
enifed("simple-html-tokenizer/tokenize",
  ["./tokenizer","./entity-parser","./char-refs/full","exports"],
  function(__dependency1__, __dependency2__, __dependency3__, __exports__) {
    "use strict";
    var Tokenizer = __dependency1__["default"];
    var EntityParser = __dependency2__["default"];
    var namedCodepoints = __dependency3__["default"];

    __exports__["default"] = function tokenize(input) {
      var tokenizer = new Tokenizer(input, new EntityParser(namedCodepoints));
      return tokenizer.tokenize();
    }
  });
enifed("simple-html-tokenizer/tokenizer",
  ["./utils","./tokens","exports"],
  function(__dependency1__, __dependency2__, __exports__) {
    "use strict";
    var preprocessInput = __dependency1__.preprocessInput;
    var isAlpha = __dependency1__.isAlpha;
    var isSpace = __dependency1__.isSpace;
    var StartTag = __dependency2__.StartTag;
    var EndTag = __dependency2__.EndTag;
    var Chars = __dependency2__.Chars;
    var Comment = __dependency2__.Comment;

    function Tokenizer(input, entityParser) {
      this.input = preprocessInput(input);
      this.entityParser = entityParser;
      this["char"] = 0;
      this.line = 1;
      this.column = 0;

      this.state = 'data';
      this.token = null;
    }

    Tokenizer.prototype = {
      tokenize: function() {
        var tokens = [], token;

        while (true) {
          token = this.lex();
          if (token === 'EOF') { break; }
          if (token) { tokens.push(token); }
        }

        if (this.token) {
          tokens.push(this.token);
        }

        return tokens;
      },

      tokenizePart: function(string) {
        this.input += preprocessInput(string);
        var tokens = [], token;

        while (this["char"] < this.input.length) {
          token = this.lex();
          if (token) { tokens.push(token); }
        }

        this.tokens = (this.tokens || []).concat(tokens);
        return tokens;
      },

      tokenizeEOF: function() {
        var token = this.token;
        if (token) {
          this.token = null;
          return token;
        }
      },

      createTag: function(Type, char) {
        var lastToken = this.token;
        this.token = new Type(char);
        this.state = 'tagName';
        return lastToken;
      },

      addToTagName: function(char) {
        this.token.tagName += char;
      },

      selfClosing: function() {
        this.token.selfClosing = true;
      },

      createAttribute: function(char) {
        this._currentAttribute = [char.toLowerCase(), "", null];
        this.token.attributes.push(this._currentAttribute);
        this.state = 'attributeName';
      },

      addToAttributeName: function(char) {
        this._currentAttribute[0] += char;
      },

      markAttributeQuoted: function(value) {
        this._currentAttribute[2] = value;
      },

      finalizeAttributeValue: function() {
        if (this._currentAttribute) {
          if (this._currentAttribute[2] === null) {
            this._currentAttribute[2] = false;
          }
          this._currentAttribute = undefined;
        }
      },

      addToAttributeValue: function(char) {
        this._currentAttribute[1] = this._currentAttribute[1] || "";
        this._currentAttribute[1] += char;
      },

      createComment: function() {
        var lastToken = this.token;
        this.token = new Comment();
        this.state = 'commentStart';
        return lastToken;
      },

      addToComment: function(char) {
        this.addChar(char);
      },

      addChar: function(char) {
        this.token.chars += char;
      },

      finalizeToken: function() {
        if (this.token.type === 'StartTag') {
          this.finalizeAttributeValue();
        }
        return this.token;
      },

      emitData: function() {
        this.addLocInfo(this.line, this.column - 1);
        var lastToken = this.token;
        this.token = null;
        this.state = 'tagOpen';
        return lastToken;
      },

      emitToken: function() {
        this.addLocInfo();
        var lastToken = this.finalizeToken();
        this.token = null;
        this.state = 'data';
        return lastToken;
      },

      addData: function(char) {
        if (this.token === null) {
          this.token = new Chars();
          this.markFirst();
        }

        this.addChar(char);
      },

      markFirst: function(line, column) {
        this.firstLine = (line === 0) ? 0 : (line || this.line);
        this.firstColumn = (column === 0) ? 0 : (column || this.column);
      },

      addLocInfo: function(line, column) {
        if (!this.token) {
          return;
        }
        this.token.firstLine = this.firstLine;
        this.token.firstColumn = this.firstColumn;
        this.token.lastLine = (line === 0) ? 0 : (line || this.line);
        this.token.lastColumn = (column === 0) ? 0 : (column || this.column);
      },

      consumeCharRef: function() {
        return this.entityParser.parse(this);
      },

      lex: function() {
        var char = this.input.charAt(this["char"]++);

        if (char) {
          if (char === "\n") {
            this.line++;
            this.column = 0;
          } else {
            this.column++;
          }
          return this.states[this.state].call(this, char);
        } else {
          this.addLocInfo(this.line, this.column);
          return 'EOF';
        }
      },

      states: {
        data: function(char) {
          if (char === "<") {
            var chars = this.emitData();
            this.markFirst();
            return chars;
          } else if (char === "&") {
            this.addData(this.consumeCharRef() || "&");
          } else {
            this.addData(char);
          }
        },

        tagOpen: function(char) {
          if (char === "!") {
            this.state = 'markupDeclaration';
          } else if (char === "/") {
            this.state = 'endTagOpen';
          } else if (isAlpha(char)) {
            return this.createTag(StartTag, char.toLowerCase());
          }
        },

        markupDeclaration: function(char) {
          if (char === "-" && this.input.charAt(this["char"]) === "-") {
            this["char"]++;
            this.createComment();
          }
        },

        commentStart: function(char) {
          if (char === "-") {
            this.state = 'commentStartDash';
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.addToComment(char);
            this.state = 'comment';
          }
        },

        commentStartDash: function(char) {
          if (char === "-") {
            this.state = 'commentEnd';
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.addToComment("-");
            this.state = 'comment';
          }
        },

        comment: function(char) {
          if (char === "-") {
            this.state = 'commentEndDash';
          } else {
            this.addToComment(char);
          }
        },

        commentEndDash: function(char) {
          if (char === "-") {
            this.state = 'commentEnd';
          } else {
            this.addToComment("-" + char);
            this.state = 'comment';
          }
        },

        commentEnd: function(char) {
          if (char === ">") {
            return this.emitToken();
          } else {
            this.addToComment("--" + char);
            this.state = 'comment';
          }
        },

        tagName: function(char) {
          if (isSpace(char)) {
            this.state = 'beforeAttributeName';
          } else if (char === "/") {
            this.state = 'selfClosingStartTag';
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.addToTagName(char);
          }
        },

        beforeAttributeName: function(char) {
          if (isSpace(char)) {
            return;
          } else if (char === "/") {
            this.state = 'selfClosingStartTag';
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.createAttribute(char);
          }
        },

        attributeName: function(char) {
          if (isSpace(char)) {
            this.state = 'afterAttributeName';
          } else if (char === "/") {
            this.state = 'selfClosingStartTag';
          } else if (char === "=") {
            this.state = 'beforeAttributeValue';
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.addToAttributeName(char);
          }
        },

        afterAttributeName: function(char) {
          if (isSpace(char)) {
            return;
          } else if (char === "/") {
            this.state = 'selfClosingStartTag';
          } else if (char === "=") {
            this.state = 'beforeAttributeValue';
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.finalizeAttributeValue();
            this.createAttribute(char);
          }
        },

        beforeAttributeValue: function(char) {
          if (isSpace(char)) {
            return;
          } else if (char === '"') {
            this.state = 'attributeValueDoubleQuoted';
            this.markAttributeQuoted(true);
          } else if (char === "'") {
            this.state = 'attributeValueSingleQuoted';
            this.markAttributeQuoted(true);
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.state = 'attributeValueUnquoted';
            this.markAttributeQuoted(false);
            this.addToAttributeValue(char);
          }
        },

        attributeValueDoubleQuoted: function(char) {
          if (char === '"') {
            this.finalizeAttributeValue();
            this.state = 'afterAttributeValueQuoted';
          } else if (char === "&") {
            this.addToAttributeValue(this.consumeCharRef('"') || "&");
          } else {
            this.addToAttributeValue(char);
          }
        },

        attributeValueSingleQuoted: function(char) {
          if (char === "'") {
            this.finalizeAttributeValue();
            this.state = 'afterAttributeValueQuoted';
          } else if (char === "&") {
            this.addToAttributeValue(this.consumeCharRef("'") || "&");
          } else {
            this.addToAttributeValue(char);
          }
        },

        attributeValueUnquoted: function(char) {
          if (isSpace(char)) {
            this.finalizeAttributeValue();
            this.state = 'beforeAttributeName';
          } else if (char === "&") {
            this.addToAttributeValue(this.consumeCharRef(">") || "&");
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this.addToAttributeValue(char);
          }
        },

        afterAttributeValueQuoted: function(char) {
          if (isSpace(char)) {
            this.state = 'beforeAttributeName';
          } else if (char === "/") {
            this.state = 'selfClosingStartTag';
          } else if (char === ">") {
            return this.emitToken();
          } else {
            this["char"]--;
            this.state = 'beforeAttributeName';
          }
        },

        selfClosingStartTag: function(char) {
          if (char === ">") {
            this.selfClosing();
            return this.emitToken();
          } else {
            this["char"]--;
            this.state = 'beforeAttributeName';
          }
        },

        endTagOpen: function(char) {
          if (isAlpha(char)) {
            this.createTag(EndTag, char.toLowerCase());
          }
        }
      }
    };

    __exports__["default"] = Tokenizer;
  });
enifed("simple-html-tokenizer/tokens",
  ["exports"],
  function(__exports__) {
    "use strict";
    function StartTag(tagName, attributes, selfClosing) {
      this.type = 'StartTag';
      this.tagName = tagName || '';
      this.attributes = attributes || [];
      this.selfClosing = selfClosing === true;
    }

    __exports__.StartTag = StartTag;function EndTag(tagName) {
      this.type = 'EndTag';
      this.tagName = tagName || '';
    }

    __exports__.EndTag = EndTag;function Chars(chars) {
      this.type = 'Chars';
      this.chars = chars || "";
    }

    __exports__.Chars = Chars;function Comment(chars) {
      this.type = 'Comment';
      this.chars = chars || '';
    }

    __exports__.Comment = Comment;
  });
enifed("simple-html-tokenizer/utils",
  ["exports"],
  function(__exports__) {
    "use strict";
    function isSpace(char) {
      return (/[\t\n\f ]/).test(char);
    }

    __exports__.isSpace = isSpace;function isAlpha(char) {
      return (/[A-Za-z]/).test(char);
    }

    __exports__.isAlpha = isAlpha;function preprocessInput(input) {
      return input.replace(/\r\n?/g, "\n");
    }

    __exports__.preprocessInput = preprocessInput;
  });
requireModule("ember-template-compiler");

})();
;
if (typeof exports === "object") {
  module.exports = Ember.__loader.require("ember-template-compiler");
 }