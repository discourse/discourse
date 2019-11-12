(function() {

var loader, define, requireModule, require, requirejs;

(function (global) {
  'use strict';

  var heimdall = global.heimdall;

  function dict() {
    var obj = Object.create(null);
    obj['__'] = undefined;
    delete obj['__'];
    return obj;
  }

  // Save off the original values of these globals, so we can restore them if someone asks us to
  var oldGlobals = {
    loader: loader,
    define: define,
    requireModule: requireModule,
    require: require,
    requirejs: requirejs
  };

  requirejs = require = requireModule = function (name) {
    var pending = [];
    var mod = findModule(name, '(require)', pending);

    for (var i = pending.length - 1; i >= 0; i--) {
      pending[i].exports();
    }

    return mod.module.exports;
  };

  loader = {
    noConflict: function (aliases) {
      var oldName, newName;

      for (oldName in aliases) {
        if (aliases.hasOwnProperty(oldName)) {
          if (oldGlobals.hasOwnProperty(oldName)) {
            newName = aliases[oldName];

            global[newName] = global[oldName];
            global[oldName] = oldGlobals[oldName];
          }
        }
      }
    }
  };

  var _isArray;
  if (!Array.isArray) {
    _isArray = function (x) {
      return Object.prototype.toString.call(x) === '[object Array]';
    };
  } else {
    _isArray = Array.isArray;
  }

  var registry = dict();
  var seen = dict();

  var uuid = 0;

  function unsupportedModule(length) {
    throw new Error('an unsupported module was defined, expected `define(name, deps, module)` instead got: `' + length + '` arguments to define`');
  }

  var defaultDeps = ['require', 'exports', 'module'];

  function Module(name, deps, callback, alias) {
    this.id = uuid++;
    this.name = name;
    this.deps = !deps.length && callback.length ? defaultDeps : deps;
    this.module = { exports: {} };
    this.callback = callback;
    this.hasExportsAsDep = false;
    this.isAlias = alias;
    this.reified = new Array(deps.length);

    /*
       Each module normally passes through these states, in order:
         new       : initial state
         pending   : this module is scheduled to be executed
         reifying  : this module's dependencies are being executed
         reified   : this module's dependencies finished executing successfully
         errored   : this module's dependencies failed to execute
         finalized : this module executed successfully
     */
    this.state = 'new';
  }

  Module.prototype.makeDefaultExport = function () {
    var exports = this.module.exports;
    if (exports !== null && (typeof exports === 'object' || typeof exports === 'function') && exports['default'] === undefined && Object.isExtensible(exports)) {
      exports['default'] = exports;
    }
  };

  Module.prototype.exports = function () {
    // if finalized, there is no work to do. If reifying, there is a
    // circular dependency so we must return our (partial) exports.
    if (this.state === 'finalized' || this.state === 'reifying') {
      return this.module.exports;
    }

    if (loader.wrapModules) {
      this.callback = loader.wrapModules(this.name, this.callback);
    }

    this.reify();

    var result = this.callback.apply(this, this.reified);
    this.state = 'finalized';

    if (!(this.hasExportsAsDep && result === undefined)) {
      this.module.exports = result;
    }
    this.makeDefaultExport();
    return this.module.exports;
  };

  Module.prototype.unsee = function () {
    this.state = 'new';
    this.module = { exports: {} };
  };

  Module.prototype.reify = function () {
    if (this.state === 'reified') {
      return;
    }
    this.state = 'reifying';
    try {
      this.reified = this._reify();
      this.state = 'reified';
    } finally {
      if (this.state === 'reifying') {
        this.state = 'errored';
      }
    }
  };

  Module.prototype._reify = function () {
    var reified = this.reified.slice();
    for (var i = 0; i < reified.length; i++) {
      var mod = reified[i];
      reified[i] = mod.exports ? mod.exports : mod.module.exports();
    }
    return reified;
  };

  Module.prototype.findDeps = function (pending) {
    if (this.state !== 'new') {
      return;
    }

    this.state = 'pending';

    var deps = this.deps;

    for (var i = 0; i < deps.length; i++) {
      var dep = deps[i];
      var entry = this.reified[i] = { exports: undefined, module: undefined };
      if (dep === 'exports') {
        this.hasExportsAsDep = true;
        entry.exports = this.module.exports;
      } else if (dep === 'require') {
        entry.exports = this.makeRequire();
      } else if (dep === 'module') {
        entry.exports = this.module;
      } else {
        entry.module = findModule(resolve(dep, this.name), this.name, pending);
      }
    }
  };

  Module.prototype.makeRequire = function () {
    var name = this.name;
    var r = function (dep) {
      return require(resolve(dep, name));
    };
    r['default'] = r;
    r.has = function (dep) {
      return has(resolve(dep, name));
    };
    return r;
  };

  define = function (name, deps, callback) {
    var module = registry[name];

    // If a module for this name has already been defined and is in any state
    // other than `new` (meaning it has been or is currently being required),
    // then we return early to avoid redefinition.
    if (module && module.state !== 'new') {
      return;
    }

    if (arguments.length < 2) {
      unsupportedModule(arguments.length);
    }

    if (!_isArray(deps)) {
      callback = deps;
      deps = [];
    }

    if (callback instanceof Alias) {
      registry[name] = new Module(callback.name, deps, callback, true);
    } else {
      registry[name] = new Module(name, deps, callback, false);
    }
  };

  // we don't support all of AMD
  // define.amd = {};

  function Alias(path) {
    this.name = path;
  }

  define.alias = function (path) {
    return new Alias(path);
  };

  function missingModule(name, referrer) {
    throw new Error('Could not find module `' + name + '` imported from `' + referrer + '`');
  }

  function findModule(name, referrer, pending) {
    var mod = registry[name] || registry[name + '/index'];

    while (mod && mod.isAlias) {
      mod = registry[mod.name];
    }

    if (!mod) {
      missingModule(name, referrer);
    }

    if (pending && mod.state !== 'pending' && mod.state !== 'finalized') {
      mod.findDeps(pending);
      pending.push(mod);
    }
    return mod;
  }

  function resolve(child, name) {
    if (child.charAt(0) !== '.') {
      return child;
    }

    var parts = child.split('/');
    var nameParts = name.split('/');
    var parentBase = nameParts.slice(0, -1);

    for (var i = 0, l = parts.length; i < l; i++) {
      var part = parts[i];

      if (part === '..') {
        if (parentBase.length === 0) {
          throw new Error('Cannot access parent module of root');
        }
        parentBase.pop();
      } else if (part === '.') {
        continue;
      } else {
        parentBase.push(part);
      }
    }

    return parentBase.join('/');
  }

  function has(name) {
    return !!(registry[name] || registry[name + '/index']);
  }

  requirejs.entries = requirejs._eak_seen = registry;
  requirejs.has = has;
  requirejs.unsee = function (moduleName) {
    findModule(moduleName, '(unsee)', false).unsee();
  };

  requirejs.clear = function () {
    requirejs.entries = requirejs._eak_seen = registry = dict();
    seen = dict();
  };

  // This code primes the JS engine for good performance by warming the
  // JIT compiler for these functions.
  define('foo', function () {});
  define('foo/bar', [], function () {});
  define('foo/asdf', ['module', 'exports', 'require'], function (module, exports, require) {
    if (require.has('foo/bar')) {
      require('foo/bar');
    }
  });
  define('foo/baz', [], define.alias('foo'));
  define('foo/quz', define.alias('foo'));
  define('foo/bar', ['foo', './quz', './baz', './asdf', './bar', '../foo'], function () {});
  define('foo/main', ['foo/bar'], function () {});

  require('foo/main');
  require.unsee('foo/bar');

  requirejs.clear();

  if (typeof exports === 'object' && typeof module === 'object' && module.exports) {
    module.exports = { require: require, define: define };
  }
})(this);
define('ember-qunit', ['exports', 'ember-qunit/module-for', 'ember-qunit/module-for-component', 'ember-qunit/module-for-model', 'ember-qunit/adapter', 'ember-test-helpers', 'qunit'], function (exports, _emberQunitModuleFor, _emberQunitModuleForComponent, _emberQunitModuleForModel, _emberQunitAdapter, _emberTestHelpers, _qunit) {
  'use strict';

  exports.module = _qunit.module;
  exports.test = _qunit.test;
  exports.skip = _qunit.skip;
  exports.only = _qunit.only;
  exports.todo = _qunit.todo;
  exports.moduleFor = _emberQunitModuleFor['default'];
  exports.moduleForComponent = _emberQunitModuleForComponent['default'];
  exports.moduleForModel = _emberQunitModuleForModel['default'];
  exports.setResolver = _emberTestHelpers.setResolver;
  exports.QUnitAdapter = _emberQunitAdapter['default'];
});
define('ember-qunit/adapter', ['exports', 'ember', 'qunit'], function (exports, _ember, _qunit) {
  'use strict';

  exports['default'] = _ember['default'].Test.Adapter.extend({
    init: function init() {
      this.doneCallbacks = [];
    },

    asyncStart: function asyncStart() {
      this.doneCallbacks.push(_qunit['default'].config.current ? _qunit['default'].config.current.assert.async() : null);
    },

    asyncEnd: function asyncEnd() {
      var done = this.doneCallbacks.pop();
      // This can be null if asyncStart() was called outside of a test
      if (done) {
        done();
      }
    },

    exception: function exception(error) {
      _qunit['default'].config.current.assert.ok(false, _ember['default'].inspect(error));
    }
  });
});
define('ember-qunit/module-for-component', ['exports', './qunit-module', 'ember-test-helpers'], function (exports, _qunitModule, _emberTestHelpers) {
  'use strict';

  exports['default'] = moduleForComponent;

  function moduleForComponent(name, description, callbacks) {
    _qunitModule.createModule(_emberTestHelpers.TestModuleForComponent, name, description, callbacks);
  }
});
define('ember-qunit/module-for-model', ['exports', './qunit-module', 'ember-test-helpers'], function (exports, _qunitModule, _emberTestHelpers) {
  'use strict';

  exports['default'] = moduleForModel;

  function moduleForModel(name, description, callbacks) {
    _qunitModule.createModule(_emberTestHelpers.TestModuleForModel, name, description, callbacks);
  }
});
define('ember-qunit/module-for', ['exports', './qunit-module', 'ember-test-helpers'], function (exports, _qunitModule, _emberTestHelpers) {
  'use strict';

  exports['default'] = moduleFor;

  function moduleFor(name, description, callbacks) {
    _qunitModule.createModule(_emberTestHelpers.TestModule, name, description, callbacks);
  }
});
define('ember-qunit/qunit-module', ['exports', 'ember', 'qunit'], function (exports, _ember, _qunit) {
  'use strict';

  exports.createModule = createModule;

  function noop() {}

  function callbackFor(name, callbacks) {
    if (typeof callbacks !== 'object') {
      return noop;
    }
    if (!callbacks) {
      return noop;
    }

    var callback = noop;

    if (callbacks[name]) {
      callback = callbacks[name];
      delete callbacks[name];
    }

    return callback;
  }

  function createModule(Constructor, name, description, callbacks) {
    if (!callbacks && typeof description === 'object') {
      callbacks = description;
      description = name;
    }

    var _before = callbackFor('before', callbacks);
    var _beforeEach = callbackFor('beforeEach', callbacks);
    var _afterEach = callbackFor('afterEach', callbacks);
    var _after = callbackFor('after', callbacks);

    var module;
    var moduleName = typeof description === 'string' ? description : name;

    _qunit.module(moduleName, {
      before: function before() {
        // storing this in closure scope to avoid exposing these
        // private internals to the test context
        module = new Constructor(name, description, callbacks);
        return _before.apply(this, arguments);
      },

      beforeEach: function beforeEach() {
        var _module2,
            _this = this,
            _arguments = arguments;

        // provide the test context to the underlying module
        module.setContext(this);

        return (_module2 = module).setup.apply(_module2, arguments).then(function () {
          return _beforeEach.apply(_this, _arguments);
        });
      },

      afterEach: function afterEach() {
        var _arguments2 = arguments;

        var result = _afterEach.apply(this, arguments);
        return _ember['default'].RSVP.resolve(result).then(function () {
          var _module3;

          return (_module3 = module).teardown.apply(_module3, _arguments2);
        });
      },

      after: function after() {
        try {
          return _after.apply(this, arguments);
        } finally {
          _after = _afterEach = _before = _beforeEach = callbacks = module = null;
        }
      }
    });
  }
});
define('ember-test-helpers', ['exports', 'ember', 'ember-test-helpers/test-module', 'ember-test-helpers/test-module-for-acceptance', 'ember-test-helpers/test-module-for-integration', 'ember-test-helpers/test-module-for-component', 'ember-test-helpers/test-module-for-model', 'ember-test-helpers/test-context', 'ember-test-helpers/test-resolver'], function (exports, _ember, _emberTestHelpersTestModule, _emberTestHelpersTestModuleForAcceptance, _emberTestHelpersTestModuleForIntegration, _emberTestHelpersTestModuleForComponent, _emberTestHelpersTestModuleForModel, _emberTestHelpersTestContext, _emberTestHelpersTestResolver) {
  'use strict';

  _ember['default'].testing = true;

  exports.TestModule = _emberTestHelpersTestModule['default'];
  exports.TestModuleForAcceptance = _emberTestHelpersTestModuleForAcceptance['default'];
  exports.TestModuleForIntegration = _emberTestHelpersTestModuleForIntegration['default'];
  exports.TestModuleForComponent = _emberTestHelpersTestModuleForComponent['default'];
  exports.TestModuleForModel = _emberTestHelpersTestModuleForModel['default'];
  exports.getContext = _emberTestHelpersTestContext.getContext;
  exports.setContext = _emberTestHelpersTestContext.setContext;
  exports.unsetContext = _emberTestHelpersTestContext.unsetContext;
  exports.setResolver = _emberTestHelpersTestResolver.setResolver;
});
define('ember-test-helpers/-legacy-overrides', ['exports', 'ember', './has-ember-version'], function (exports, _ember, _hasEmberVersion) {
  'use strict';

  exports.preGlimmerSetupIntegrationForComponent = preGlimmerSetupIntegrationForComponent;

  function preGlimmerSetupIntegrationForComponent() {
    var module = this;
    var context = this.context;

    this.actionHooks = {};

    context.dispatcher = this.container.lookup('event_dispatcher:main') || _ember['default'].EventDispatcher.create();
    context.dispatcher.setup({}, '#ember-testing');
    context.actions = module.actionHooks;

    (this.registry || this.container).register('component:-test-holder', _ember['default'].Component.extend());

    context.render = function (template) {
      // in case `this.render` is called twice, make sure to teardown the first invocation
      module.teardownComponent();

      if (!template) {
        throw new Error("in a component integration test you must pass a template to `render()`");
      }
      if (_ember['default'].isArray(template)) {
        template = template.join('');
      }
      if (typeof template === 'string') {
        template = _ember['default'].Handlebars.compile(template);
      }
      module.component = module.container.lookupFactory('component:-test-holder').create({
        layout: template
      });

      module.component.set('context', context);
      module.component.set('controller', context);

      _ember['default'].run(function () {
        module.component.appendTo('#ember-testing');
      });

      context._element = module.component.element;
    };

    context.$ = function () {
      return module.component.$.apply(module.component, arguments);
    };

    context.set = function (key, value) {
      var ret = _ember['default'].run(function () {
        return _ember['default'].set(context, key, value);
      });

      if (_hasEmberVersion['default'](2, 0)) {
        return ret;
      }
    };

    context.setProperties = function (hash) {
      var ret = _ember['default'].run(function () {
        return _ember['default'].setProperties(context, hash);
      });

      if (_hasEmberVersion['default'](2, 0)) {
        return ret;
      }
    };

    context.get = function (key) {
      return _ember['default'].get(context, key);
    };

    context.getProperties = function () {
      var args = Array.prototype.slice.call(arguments);
      return _ember['default'].getProperties(context, args);
    };

    context.on = function (actionName, handler) {
      module.actionHooks[actionName] = handler;
    };

    context.send = function (actionName) {
      var hook = module.actionHooks[actionName];
      if (!hook) {
        throw new Error("integration testing template received unexpected action " + actionName);
      }
      hook.apply(module, Array.prototype.slice.call(arguments, 1));
    };

    context.clearRender = function () {
      module.teardownComponent();
    };
  }
});
define('ember-test-helpers/abstract-test-module', ['exports', './wait', './test-context', 'ember'], function (exports, _wait, _testContext, _ember) {
  'use strict';

  function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

  // calling this `merge` here because we cannot
  // actually assume it is like `Object.assign`
  // with > 2 args
  var merge = _ember['default'].assign || _ember['default'].merge;

  var _default = (function () {
    function _default(name, options) {
      _classCallCheck(this, _default);

      this.context = undefined;
      this.name = name;
      this.callbacks = options || {};

      this.initSetupSteps();
      this.initTeardownSteps();
    }

    _default.prototype.setup = function setup(assert) {
      var _this = this;

      return this.invokeSteps(this.setupSteps, this, assert).then(function () {
        _this.contextualizeCallbacks();
        return _this.invokeSteps(_this.contextualizedSetupSteps, _this.context, assert);
      });
    };

    _default.prototype.teardown = function teardown(assert) {
      var _this2 = this;

      return this.invokeSteps(this.contextualizedTeardownSteps, this.context, assert).then(function () {
        return _this2.invokeSteps(_this2.teardownSteps, _this2, assert);
      }).then(function () {
        _this2.cache = null;
        _this2.cachedCalls = null;
      });
    };

    _default.prototype.initSetupSteps = function initSetupSteps() {
      this.setupSteps = [];
      this.contextualizedSetupSteps = [];

      if (this.callbacks.beforeSetup) {
        this.setupSteps.push(this.callbacks.beforeSetup);
        delete this.callbacks.beforeSetup;
      }

      this.setupSteps.push(this.setupContext);
      this.setupSteps.push(this.setupTestElements);
      this.setupSteps.push(this.setupAJAXListeners);

      if (this.callbacks.setup) {
        this.contextualizedSetupSteps.push(this.callbacks.setup);
        delete this.callbacks.setup;
      }
    };

    _default.prototype.invokeSteps = function invokeSteps(steps, context, assert) {
      steps = steps.slice();

      function nextStep() {
        var step = steps.shift();
        if (step) {
          // guard against exceptions, for example missing components referenced from needs.
          return new _ember['default'].RSVP.Promise(function (resolve) {
            resolve(step.call(context, assert));
          }).then(nextStep);
        } else {
          return _ember['default'].RSVP.resolve();
        }
      }
      return nextStep();
    };

    _default.prototype.contextualizeCallbacks = function contextualizeCallbacks() {};

    _default.prototype.initTeardownSteps = function initTeardownSteps() {
      this.teardownSteps = [];
      this.contextualizedTeardownSteps = [];

      if (this.callbacks.teardown) {
        this.contextualizedTeardownSteps.push(this.callbacks.teardown);
        delete this.callbacks.teardown;
      }

      this.teardownSteps.push(this.teardownContext);
      this.teardownSteps.push(this.teardownTestElements);
      this.teardownSteps.push(this.teardownAJAXListeners);

      if (this.callbacks.afterTeardown) {
        this.teardownSteps.push(this.callbacks.afterTeardown);
        delete this.callbacks.afterTeardown;
      }
    };

    _default.prototype.setupTestElements = function setupTestElements() {
      var testEl = document.querySelector('#ember-testing');
      if (!testEl) {
        var element = document.createElement('div');
        element.setAttribute('id', 'ember-testing');

        document.body.appendChild(element);
        this.fixtureResetValue = '';
      } else {
        this.fixtureResetValue = testEl.innerHTML;
      }
    };

    _default.prototype.setupContext = function setupContext(options) {
      var context = this.getContext();

      merge(context, {
        dispatcher: null,
        inject: {}
      });
      merge(context, options);

      this.setToString();
      _testContext.setContext(context);
      this.context = context;
    };

    _default.prototype.setContext = function setContext(context) {
      this.context = context;
    };

    _default.prototype.getContext = function getContext() {
      if (this.context) {
        return this.context;
      }

      return this.context = _testContext.getContext() || {};
    };

    _default.prototype.setToString = function setToString() {
      var _this3 = this;

      this.context.toString = function () {
        if (_this3.subjectName) {
          return 'test context for: ' + _this3.subjectName;
        }

        if (_this3.name) {
          return 'test context for: ' + _this3.name;
        }
      };
    };

    _default.prototype.setupAJAXListeners = function setupAJAXListeners() {
      _wait._setupAJAXHooks();
    };

    _default.prototype.teardownAJAXListeners = function teardownAJAXListeners() {
      _wait._teardownAJAXHooks();
    };

    _default.prototype.teardownTestElements = function teardownTestElements() {
      document.getElementById('ember-testing').innerHTML = this.fixtureResetValue;

      // Ember 2.0.0 removed Ember.View as public API, so only do this when
      // Ember.View is present
      if (_ember['default'].View && _ember['default'].View.views) {
        _ember['default'].View.views = {};
      }
    };

    _default.prototype.teardownContext = function teardownContext() {
      var context = this.context;
      this.context = undefined;
      _testContext.unsetContext();

      if (context && context.dispatcher && !context.dispatcher.isDestroyed) {
        _ember['default'].run(function () {
          context.dispatcher.destroy();
        });
      }
    };

    return _default;
  })();

  exports['default'] = _default;
});
define('ember-test-helpers/build-registry', ['exports', 'require', 'ember'], function (exports, _require, _ember) {
  /* globals global, self, requirejs */

  'use strict';

  function exposeRegistryMethodsWithoutDeprecations(container) {
    var methods = ['register', 'unregister', 'resolve', 'normalize', 'typeInjection', 'injection', 'factoryInjection', 'factoryTypeInjection', 'has', 'options', 'optionsForType'];

    function exposeRegistryMethod(container, method) {
      if (method in container) {
        container[method] = function () {
          return container._registry[method].apply(container._registry, arguments);
        };
      }
    }

    for (var i = 0, l = methods.length; i < l; i++) {
      exposeRegistryMethod(container, methods[i]);
    }
  }

  var Owner = (function () {
    if (_ember['default']._RegistryProxyMixin && _ember['default']._ContainerProxyMixin) {
      return _ember['default'].Object.extend(_ember['default']._RegistryProxyMixin, _ember['default']._ContainerProxyMixin);
    }

    return _ember['default'].Object.extend();
  })();

  exports['default'] = function (resolver) {
    var fallbackRegistry, registry, container;
    var namespace = _ember['default'].Object.create({
      Resolver: { create: function create() {
          return resolver;
        } }
    });

    function register(name, factory) {
      var thingToRegisterWith = registry || container;

      if (!(container.factoryFor ? container.factoryFor(name) : container.lookupFactory(name))) {
        thingToRegisterWith.register(name, factory);
      }
    }

    if (_ember['default'].Application.buildRegistry) {
      fallbackRegistry = _ember['default'].Application.buildRegistry(namespace);
      fallbackRegistry.register('component-lookup:main', _ember['default'].ComponentLookup);

      registry = new _ember['default'].Registry({
        fallback: fallbackRegistry
      });

      if (_ember['default'].ApplicationInstance && _ember['default'].ApplicationInstance.setupRegistry) {
        _ember['default'].ApplicationInstance.setupRegistry(registry);
      }

      // these properties are set on the fallback registry by `buildRegistry`
      // and on the primary registry within the ApplicationInstance constructor
      // but we need to manually recreate them since ApplicationInstance's are not
      // exposed externally
      registry.normalizeFullName = fallbackRegistry.normalizeFullName;
      registry.makeToString = fallbackRegistry.makeToString;
      registry.describe = fallbackRegistry.describe;

      var owner = Owner.create({
        __registry__: registry,
        __container__: null
      });

      container = registry.container({ owner: owner });
      owner.__container__ = container;

      exposeRegistryMethodsWithoutDeprecations(container);
    } else {
      container = _ember['default'].Application.buildContainer(namespace);
      container.register('component-lookup:main', _ember['default'].ComponentLookup);
    }

    // Ember 1.10.0 did not properly add `view:toplevel` or `view:default`
    // to the registry in Ember.Application.buildRegistry :(
    //
    // Ember 2.0.0 removed Ember.View as public API, so only do this when
    // Ember.View is present
    if (_ember['default'].View) {
      register('view:toplevel', _ember['default'].View.extend());
    }

    // Ember 2.0.0 removed Ember._MetamorphView from the Ember global, so only
    // do this when present
    if (_ember['default']._MetamorphView) {
      register('view:default', _ember['default']._MetamorphView);
    }

    var globalContext = typeof global === 'object' && global || self;
    if (requirejs.entries['ember-data/setup-container']) {
      // ember-data is a proper ember-cli addon since 2.3; if no 'import
      // 'ember-data'' is present somewhere in the tests, there is also no `DS`
      // available on the globalContext and hence ember-data wouldn't be setup
      // correctly for the tests; that's why we import and call setupContainer
      // here; also see https://github.com/emberjs/data/issues/4071 for context
      var setupContainer = _require['default']('ember-data/setup-container')['default'];
      setupContainer(registry || container);
    } else if (globalContext.DS) {
      var DS = globalContext.DS;
      if (DS._setupContainer) {
        DS._setupContainer(registry || container);
      } else {
        register('transform:boolean', DS.BooleanTransform);
        register('transform:date', DS.DateTransform);
        register('transform:number', DS.NumberTransform);
        register('transform:string', DS.StringTransform);
        register('serializer:-default', DS.JSONSerializer);
        register('serializer:-rest', DS.RESTSerializer);
        register('adapter:-rest', DS.RESTAdapter);
      }
    }

    return {
      registry: registry,
      container: container
    };
  };
});
define('ember-test-helpers/has-ember-version', ['exports', 'ember'], function (exports, _ember) {
  'use strict';

  exports['default'] = hasEmberVersion;

  function hasEmberVersion(major, minor) {
    var numbers = _ember['default'].VERSION.split('-')[0].split('.');
    var actualMajor = parseInt(numbers[0], 10);
    var actualMinor = parseInt(numbers[1], 10);
    return actualMajor > major || actualMajor === major && actualMinor >= minor;
  }
});
define("ember-test-helpers/test-context", ["exports"], function (exports) {
  "use strict";

  exports.setContext = setContext;
  exports.getContext = getContext;
  exports.unsetContext = unsetContext;
  var __test_context__;

  function setContext(context) {
    __test_context__ = context;
  }

  function getContext() {
    return __test_context__;
  }

  function unsetContext() {
    __test_context__ = undefined;
  }
});
define('ember-test-helpers/test-module-for-acceptance', ['exports', './abstract-test-module', 'ember', './test-context'], function (exports, _abstractTestModule, _ember, _testContext) {
  'use strict';

  function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

  function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

  var _default = (function (_AbstractTestModule) {
    _inherits(_default, _AbstractTestModule);

    function _default() {
      _classCallCheck(this, _default);

      _AbstractTestModule.apply(this, arguments);
    }

    _default.prototype.setupContext = function setupContext() {
      _AbstractTestModule.prototype.setupContext.call(this, { application: this.createApplication() });
    };

    _default.prototype.teardownContext = function teardownContext() {
      _ember['default'].run(function () {
        _testContext.getContext().application.destroy();
      });

      _AbstractTestModule.prototype.teardownContext.call(this);
    };

    _default.prototype.createApplication = function createApplication() {
      var _callbacks = this.callbacks;
      var Application = _callbacks.Application;
      var config = _callbacks.config;

      var application = undefined;

      _ember['default'].run(function () {
        application = Application.create(config);
        application.setupForTesting();
        application.injectTestHelpers();
      });

      return application;
    };

    return _default;
  })(_abstractTestModule['default']);

  exports['default'] = _default;
});
define('ember-test-helpers/test-module-for-component', ['exports', './test-module', 'ember', './has-ember-version', './-legacy-overrides'], function (exports, _testModule, _ember, _hasEmberVersion, _legacyOverrides) {
  'use strict';

  exports.setupComponentIntegrationTest = _setupComponentIntegrationTest;

  function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

  function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

  var ACTION_KEY = undefined;
  if (_hasEmberVersion['default'](2, 0)) {
    ACTION_KEY = 'actions';
  } else {
    ACTION_KEY = '_actions';
  }

  var isPreGlimmer = !_hasEmberVersion['default'](1, 13);

  var getOwner = _ember['default'].getOwner;

  var _default = (function (_TestModule) {
    _inherits(_default, _TestModule);

    function _default(componentName, description, callbacks) {
      _classCallCheck(this, _default);

      // Allow `description` to be omitted
      if (!callbacks && typeof description === 'object') {
        callbacks = description;
        description = null;
      } else if (!callbacks) {
        callbacks = {};
      }

      var integrationOption = callbacks.integration;
      var hasNeeds = Array.isArray(callbacks.needs);

      _TestModule.call(this, 'component:' + componentName, description, callbacks);

      this.componentName = componentName;

      if (hasNeeds || callbacks.unit || integrationOption === false) {
        this.isUnitTest = true;
      } else if (integrationOption) {
        this.isUnitTest = false;
      } else {
        _ember['default'].deprecate("the component:" + componentName + " test module is implicitly running in unit test mode, " + "which will change to integration test mode by default in an upcoming version of " + "ember-test-helpers. Add `unit: true` or a `needs:[]` list to explicitly opt in to unit " + "test mode.", false, { id: 'ember-test-helpers.test-module-for-component.test-type', until: '0.6.0' });
        this.isUnitTest = true;
      }

      if (!this.isUnitTest && !this.isLegacy) {
        callbacks.integration = true;
      }

      if (this.isUnitTest || this.isLegacy) {
        this.setupSteps.push(this.setupComponentUnitTest);
      } else {
        this.callbacks.subject = function () {
          throw new Error("component integration tests do not support `subject()`. Instead, render the component as if it were HTML: `this.render('<my-component foo=true>');`. For more information, read: http://guides.emberjs.com/v2.2.0/testing/testing-components/");
        };
        this.setupSteps.push(this.setupComponentIntegrationTest);
        this.teardownSteps.unshift(this.teardownComponent);
      }

      if (_ember['default'].View && _ember['default'].View.views) {
        this.setupSteps.push(this._aliasViewRegistry);
        this.teardownSteps.unshift(this._resetViewRegistry);
      }
    }

    _default.prototype.initIntegration = function initIntegration(options) {
      this.isLegacy = options.integration === 'legacy';
      this.isIntegration = options.integration !== 'legacy';
    };

    _default.prototype._aliasViewRegistry = function _aliasViewRegistry() {
      this._originalGlobalViewRegistry = _ember['default'].View.views;
      var viewRegistry = this.container.lookup('-view-registry:main');

      if (viewRegistry) {
        _ember['default'].View.views = viewRegistry;
      }
    };

    _default.prototype._resetViewRegistry = function _resetViewRegistry() {
      _ember['default'].View.views = this._originalGlobalViewRegistry;
    };

    _default.prototype.setupComponentUnitTest = function setupComponentUnitTest() {
      var _this = this;
      var resolver = this.resolver;
      var context = this.context;

      var layoutName = 'template:components/' + this.componentName;

      var layout = resolver.resolve(layoutName);

      var thingToRegisterWith = this.registry || this.container;
      if (layout) {
        thingToRegisterWith.register(layoutName, layout);
        thingToRegisterWith.injection(this.subjectName, 'layout', layoutName);
      }

      context.dispatcher = this.container.lookup('event_dispatcher:main') || _ember['default'].EventDispatcher.create();
      context.dispatcher.setup({}, '#ember-testing');

      context._element = null;

      this.callbacks.render = function () {
        var subject;

        _ember['default'].run(function () {
          subject = context.subject();
          subject.appendTo('#ember-testing');
        });

        context._element = subject.element;

        _this.teardownSteps.unshift(function () {
          _ember['default'].run(function () {
            _ember['default'].tryInvoke(subject, 'destroy');
          });
        });
      };

      this.callbacks.append = function () {
        _ember['default'].deprecate('this.append() is deprecated. Please use this.render() or this.$() instead.', false, { id: 'ember-test-helpers.test-module-for-component.append', until: '0.6.0' });
        return context.$();
      };

      context.$ = function () {
        this.render();
        var subject = this.subject();

        return subject.$.apply(subject, arguments);
      };
    };

    _default.prototype.setupComponentIntegrationTest = function setupComponentIntegrationTest() {
      if (isPreGlimmer) {
        return _legacyOverrides.preGlimmerSetupIntegrationForComponent.apply(this, arguments);
      } else {
        return _setupComponentIntegrationTest.apply(this, arguments);
      }
    };

    _default.prototype.setupContext = function setupContext() {
      _TestModule.prototype.setupContext.call(this);

      // only setup the injection if we are running against a version
      // of Ember that has `-view-registry:main` (Ember >= 1.12)
      if (this.container.factoryFor ? this.container.factoryFor('-view-registry:main') : this.container.lookupFactory('-view-registry:main')) {
        (this.registry || this.container).injection('component', '_viewRegistry', '-view-registry:main');
      }

      if (!this.isUnitTest && !this.isLegacy) {
        this.context.factory = function () {};
      }
    };

    _default.prototype.teardownComponent = function teardownComponent() {
      var component = this.component;
      if (component) {
        _ember['default'].run(component, 'destroy');
        this.component = null;
      }
    };

    return _default;
  })(_testModule['default']);

  exports['default'] = _default;

  function _setupComponentIntegrationTest() {
    var module = this;
    var context = this.context;

    this.actionHooks = context[ACTION_KEY] = {};
    context.dispatcher = this.container.lookup('event_dispatcher:main') || _ember['default'].EventDispatcher.create();
    context.dispatcher.setup({}, '#ember-testing');

    var hasRendered = false;
    var OutletView = module.container.factoryFor ? module.container.factoryFor('view:-outlet') : module.container.lookupFactory('view:-outlet');
    var OutletTemplate = module.container.lookup('template:-outlet');
    var toplevelView = module.component = OutletView.create();
    var hasOutletTemplate = !!OutletTemplate;
    var outletState = {
      render: {
        owner: getOwner ? getOwner(module.container) : undefined,
        into: undefined,
        outlet: 'main',
        name: 'application',
        controller: module.context,
        ViewClass: undefined,
        template: OutletTemplate
      },

      outlets: {}
    };

    var element = document.getElementById('ember-testing');
    var templateId = 0;

    if (hasOutletTemplate) {
      _ember['default'].run(function () {
        toplevelView.setOutletState(outletState);
      });
    }

    context.render = function (template) {
      if (!template) {
        throw new Error("in a component integration test you must pass a template to `render()`");
      }
      if (_ember['default'].isArray(template)) {
        template = template.join('');
      }
      if (typeof template === 'string') {
        template = _ember['default'].Handlebars.compile(template);
      }

      var templateFullName = 'template:-undertest-' + ++templateId;
      this.registry.register(templateFullName, template);
      var stateToRender = {
        owner: getOwner ? getOwner(module.container) : undefined,
        into: undefined,
        outlet: 'main',
        name: 'index',
        controller: module.context,
        ViewClass: undefined,
        template: module.container.lookup(templateFullName),
        outlets: {}
      };

      if (hasOutletTemplate) {
        stateToRender.name = 'index';
        outletState.outlets.main = { render: stateToRender, outlets: {} };
      } else {
        stateToRender.name = 'application';
        outletState = { render: stateToRender, outlets: {} };
      }

      _ember['default'].run(function () {
        toplevelView.setOutletState(outletState);
      });

      if (!hasRendered) {
        _ember['default'].run(module.component, 'appendTo', '#ember-testing');
        hasRendered = true;
      }

      // ensure the element is based on the wrapping toplevel view
      // Ember still wraps the main application template with a
      // normal tagged view
      context._element = element = document.querySelector('#ember-testing > .ember-view');
    };

    context.$ = function (selector) {
      // emulates Ember internal behavor of `this.$` in a component
      // https://github.com/emberjs/ember.js/blob/v2.5.1/packages/ember-views/lib/views/states/has_element.js#L18
      return selector ? _ember['default'].$(selector, element) : _ember['default'].$(element);
    };

    context.set = function (key, value) {
      var ret = _ember['default'].run(function () {
        return _ember['default'].set(context, key, value);
      });

      if (_hasEmberVersion['default'](2, 0)) {
        return ret;
      }
    };

    context.setProperties = function (hash) {
      var ret = _ember['default'].run(function () {
        return _ember['default'].setProperties(context, hash);
      });

      if (_hasEmberVersion['default'](2, 0)) {
        return ret;
      }
    };

    context.get = function (key) {
      return _ember['default'].get(context, key);
    };

    context.getProperties = function () {
      var args = Array.prototype.slice.call(arguments);
      return _ember['default'].getProperties(context, args);
    };

    context.on = function (actionName, handler) {
      module.actionHooks[actionName] = handler;
    };

    context.send = function (actionName) {
      var hook = module.actionHooks[actionName];
      if (!hook) {
        throw new Error("integration testing template received unexpected action " + actionName);
      }
      hook.apply(module.context, Array.prototype.slice.call(arguments, 1));
    };

    context.clearRender = function () {
      _ember['default'].run(function () {
        toplevelView.setOutletState({
          render: {
            owner: module.container,
            into: undefined,
            outlet: 'main',
            name: 'application',
            controller: module.context,
            ViewClass: undefined,
            template: undefined
          },
          outlets: {}
        });
      });
    };
  }
});
define('ember-test-helpers/test-module-for-integration', ['exports', 'ember', './abstract-test-module', './test-resolver', './build-registry', './has-ember-version', './-legacy-overrides', './test-module-for-component'], function (exports, _ember, _abstractTestModule, _testResolver, _buildRegistry, _hasEmberVersion, _legacyOverrides, _testModuleForComponent) {
  'use strict';

  function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

  function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

  var isPreGlimmer = !_hasEmberVersion['default'](1, 13);

  var _default = (function (_AbstractTestModule) {
    _inherits(_default, _AbstractTestModule);

    function _default() {
      _classCallCheck(this, _default);

      _AbstractTestModule.apply(this, arguments);
      this.resolver = this.callbacks.resolver || _testResolver.getResolver();
    }

    _default.prototype.initSetupSteps = function initSetupSteps() {
      this.setupSteps = [];
      this.contextualizedSetupSteps = [];

      if (this.callbacks.beforeSetup) {
        this.setupSteps.push(this.callbacks.beforeSetup);
        delete this.callbacks.beforeSetup;
      }

      this.setupSteps.push(this.setupContainer);
      this.setupSteps.push(this.setupContext);
      this.setupSteps.push(this.setupTestElements);
      this.setupSteps.push(this.setupAJAXListeners);
      this.setupSteps.push(this.setupComponentIntegrationTest);

      if (_ember['default'].View && _ember['default'].View.views) {
        this.setupSteps.push(this._aliasViewRegistry);
      }

      if (this.callbacks.setup) {
        this.contextualizedSetupSteps.push(this.callbacks.setup);
        delete this.callbacks.setup;
      }
    };

    _default.prototype.initTeardownSteps = function initTeardownSteps() {
      this.teardownSteps = [];
      this.contextualizedTeardownSteps = [];

      if (this.callbacks.teardown) {
        this.contextualizedTeardownSteps.push(this.callbacks.teardown);
        delete this.callbacks.teardown;
      }

      this.teardownSteps.push(this.teardownContainer);
      this.teardownSteps.push(this.teardownContext);
      this.teardownSteps.push(this.teardownAJAXListeners);
      this.teardownSteps.push(this.teardownComponent);

      if (_ember['default'].View && _ember['default'].View.views) {
        this.teardownSteps.push(this._resetViewRegistry);
      }

      this.teardownSteps.push(this.teardownTestElements);

      if (this.callbacks.afterTeardown) {
        this.teardownSteps.push(this.callbacks.afterTeardown);
        delete this.callbacks.afterTeardown;
      }
    };

    _default.prototype.setupContainer = function setupContainer() {
      var resolver = this.resolver;
      var items = _buildRegistry['default'](resolver);

      this.container = items.container;
      this.registry = items.registry;

      if (_hasEmberVersion['default'](1, 13)) {
        var thingToRegisterWith = this.registry || this.container;
        var router = resolver.resolve('router:main');
        router = router || _ember['default'].Router.extend();
        thingToRegisterWith.register('router:main', router);
      }
    };

    _default.prototype.setupContext = function setupContext() {
      var subjectName = this.subjectName;
      var container = this.container;

      var factory = function factory() {
        return container.factoryFor ? container.factoryFor(subjectName) : container.lookupFactory(subjectName);
      };

      _AbstractTestModule.prototype.setupContext.call(this, {
        container: this.container,
        registry: this.registry,
        factory: factory,
        register: function register() {
          var target = this.registry || this.container;
          return target.register.apply(target, arguments);
        }
      });

      var context = this.context;

      if (_ember['default'].setOwner) {
        _ember['default'].setOwner(context, this.container.owner);
      }

      if (_ember['default'].inject) {
        var keys = (Object.keys || _ember['default'].keys)(_ember['default'].inject);
        keys.forEach(function (typeName) {
          context.inject[typeName] = function (name, opts) {
            var alias = opts && opts.as || name;
            _ember['default'].run(function () {
              _ember['default'].set(context, alias, context.container.lookup(typeName + ':' + name));
            });
          };
        });
      }

      // only setup the injection if we are running against a version
      // of Ember that has `-view-registry:main` (Ember >= 1.12)
      if (this.container.factoryFor ? this.container.factoryFor('-view-registry:main') : this.container.lookupFactory('-view-registry:main')) {
        (this.registry || this.container).injection('component', '_viewRegistry', '-view-registry:main');
      }
    };

    _default.prototype.setupComponentIntegrationTest = function setupComponentIntegrationTest() {
      if (isPreGlimmer) {
        return _legacyOverrides.preGlimmerSetupIntegrationForComponent.apply(this, arguments);
      } else {
        return _testModuleForComponent.setupComponentIntegrationTest.apply(this, arguments);
      }
    };

    _default.prototype.teardownComponent = function teardownComponent() {
      var component = this.component;
      if (component) {
        _ember['default'].run(function () {
          component.destroy();
        });
      }
    };

    _default.prototype.teardownContainer = function teardownContainer() {
      var container = this.container;
      _ember['default'].run(function () {
        container.destroy();
      });
    };

    // allow arbitrary named factories, like rspec let

    _default.prototype.contextualizeCallbacks = function contextualizeCallbacks() {
      var callbacks = this.callbacks;
      var context = this.context;

      this.cache = this.cache || {};
      this.cachedCalls = this.cachedCalls || {};

      var keys = (Object.keys || _ember['default'].keys)(callbacks);
      var keysLength = keys.length;

      if (keysLength) {
        for (var i = 0; i < keysLength; i++) {
          this._contextualizeCallback(context, keys[i], context);
        }
      }
    };

    _default.prototype._contextualizeCallback = function _contextualizeCallback(context, key, callbackContext) {
      var _this = this;
      var callbacks = this.callbacks;
      var factory = context.factory;

      context[key] = function (options) {
        if (_this.cachedCalls[key]) {
          return _this.cache[key];
        }

        var result = callbacks[key].call(callbackContext, options, factory());

        _this.cache[key] = result;
        _this.cachedCalls[key] = true;

        return result;
      };
    };

    _default.prototype._aliasViewRegistry = function _aliasViewRegistry() {
      this._originalGlobalViewRegistry = _ember['default'].View.views;
      var viewRegistry = this.container.lookup('-view-registry:main');

      if (viewRegistry) {
        _ember['default'].View.views = viewRegistry;
      }
    };

    _default.prototype._resetViewRegistry = function _resetViewRegistry() {
      _ember['default'].View.views = this._originalGlobalViewRegistry;
    };

    return _default;
  })(_abstractTestModule['default']);

  exports['default'] = _default;
});
define('ember-test-helpers/test-module-for-model', ['exports', 'require', './test-module', 'ember'], function (exports, _require, _testModule, _ember) {
  /* global DS, requirejs */ // added here to prevent an import from erroring when ED is not present

  'use strict';

  function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

  function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

  var _default = (function (_TestModule) {
    _inherits(_default, _TestModule);

    function _default(modelName, description, callbacks) {
      _classCallCheck(this, _default);

      _TestModule.call(this, 'model:' + modelName, description, callbacks);

      this.modelName = modelName;

      this.setupSteps.push(this.setupModel);
    }

    _default.prototype.setupModel = function setupModel() {
      var container = this.container;
      var defaultSubject = this.defaultSubject;
      var callbacks = this.callbacks;
      var modelName = this.modelName;

      var adapterFactory = container.factoryFor ? container.factoryFor('adapter:application') : container.lookupFactory('adapter:application');
      if (!adapterFactory) {
        if (requirejs.entries['ember-data/adapters/json-api']) {
          adapterFactory = _require['default']('ember-data/adapters/json-api')['default'];
        }

        // when ember-data/adapters/json-api is provided via ember-cli shims
        // using Ember Data 1.x the actual JSONAPIAdapter isn't found, but the
        // above require statement returns a bizzaro object with only a `default`
        // property (circular reference actually)
        if (!adapterFactory || !adapterFactory.create) {
          adapterFactory = DS.JSONAPIAdapter || DS.FixtureAdapter;
        }

        var thingToRegisterWith = this.registry || this.container;
        thingToRegisterWith.register('adapter:application', adapterFactory);
      }

      callbacks.store = function () {
        var container = this.container;
        return container.lookup('service:store') || container.lookup('store:main');
      };

      if (callbacks.subject === defaultSubject) {
        callbacks.subject = function (options) {
          var container = this.container;

          return _ember['default'].run(function () {
            var store = container.lookup('service:store') || container.lookup('store:main');
            return store.createRecord(modelName, options);
          });
        };
      }
    };

    return _default;
  })(_testModule['default']);

  exports['default'] = _default;
});
define('ember-test-helpers/test-module', ['exports', 'ember', './abstract-test-module', './test-resolver', './build-registry', './has-ember-version'], function (exports, _ember, _abstractTestModule, _testResolver, _buildRegistry, _hasEmberVersion) {
  'use strict';

  function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

  function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

  var _default = (function (_AbstractTestModule) {
    _inherits(_default, _AbstractTestModule);

    function _default(subjectName, description, callbacks) {
      _classCallCheck(this, _default);

      // Allow `description` to be omitted, in which case it should
      // default to `subjectName`
      if (!callbacks && typeof description === 'object') {
        callbacks = description;
        description = subjectName;
      }

      _AbstractTestModule.call(this, description || subjectName, callbacks);

      this.subjectName = subjectName;
      this.description = description || subjectName;
      this.resolver = this.callbacks.resolver || _testResolver.getResolver();

      if (this.callbacks.integration && this.callbacks.needs) {
        throw new Error("cannot declare 'integration: true' and 'needs' in the same module");
      }

      if (this.callbacks.integration) {
        this.initIntegration(callbacks);
        delete callbacks.integration;
      }

      this.initSubject();
      this.initNeeds();
    }

    _default.prototype.initIntegration = function initIntegration(options) {
      if (options.integration === 'legacy') {
        throw new Error('`integration: \'legacy\'` is only valid for component tests.');
      }
      this.isIntegration = true;
    };

    _default.prototype.initSubject = function initSubject() {
      this.callbacks.subject = this.callbacks.subject || this.defaultSubject;
    };

    _default.prototype.initNeeds = function initNeeds() {
      this.needs = [this.subjectName];
      if (this.callbacks.needs) {
        this.needs = this.needs.concat(this.callbacks.needs);
        delete this.callbacks.needs;
      }
    };

    _default.prototype.initSetupSteps = function initSetupSteps() {
      this.setupSteps = [];
      this.contextualizedSetupSteps = [];

      if (this.callbacks.beforeSetup) {
        this.setupSteps.push(this.callbacks.beforeSetup);
        delete this.callbacks.beforeSetup;
      }

      this.setupSteps.push(this.setupContainer);
      this.setupSteps.push(this.setupContext);
      this.setupSteps.push(this.setupTestElements);
      this.setupSteps.push(this.setupAJAXListeners);

      if (this.callbacks.setup) {
        this.contextualizedSetupSteps.push(this.callbacks.setup);
        delete this.callbacks.setup;
      }
    };

    _default.prototype.initTeardownSteps = function initTeardownSteps() {
      this.teardownSteps = [];
      this.contextualizedTeardownSteps = [];

      if (this.callbacks.teardown) {
        this.contextualizedTeardownSteps.push(this.callbacks.teardown);
        delete this.callbacks.teardown;
      }

      this.teardownSteps.push(this.teardownSubject);
      this.teardownSteps.push(this.teardownContainer);
      this.teardownSteps.push(this.teardownContext);
      this.teardownSteps.push(this.teardownTestElements);
      this.teardownSteps.push(this.teardownAJAXListeners);

      if (this.callbacks.afterTeardown) {
        this.teardownSteps.push(this.callbacks.afterTeardown);
        delete this.callbacks.afterTeardown;
      }
    };

    _default.prototype.setupContainer = function setupContainer() {
      if (this.isIntegration || this.isLegacy) {
        this._setupIntegratedContainer();
      } else {
        this._setupIsolatedContainer();
      }
    };

    _default.prototype.setupContext = function setupContext() {
      var subjectName = this.subjectName;
      var container = this.container;

      var factory = function factory() {
        return container.factoryFor ? container.factoryFor(subjectName) : container.lookupFactory(subjectName);
      };

      _AbstractTestModule.prototype.setupContext.call(this, {
        container: this.container,
        registry: this.registry,
        factory: factory,
        register: function register() {
          var target = this.registry || this.container;
          return target.register.apply(target, arguments);
        }
      });

      if (_ember['default'].setOwner) {
        _ember['default'].setOwner(this.context, this.container.owner);
      }

      this.setupInject();
    };

    _default.prototype.setupInject = function setupInject() {
      var module = this;
      var context = this.context;

      if (_ember['default'].inject) {
        var keys = (Object.keys || _ember['default'].keys)(_ember['default'].inject);

        keys.forEach(function (typeName) {
          context.inject[typeName] = function (name, opts) {
            var alias = opts && opts.as || name;
            _ember['default'].run(function () {
              _ember['default'].set(context, alias, module.container.lookup(typeName + ':' + name));
            });
          };
        });
      }
    };

    _default.prototype.teardownSubject = function teardownSubject() {
      var subject = this.cache.subject;

      if (subject) {
        _ember['default'].run(function () {
          _ember['default'].tryInvoke(subject, 'destroy');
        });
      }
    };

    _default.prototype.teardownContainer = function teardownContainer() {
      var container = this.container;
      _ember['default'].run(function () {
        container.destroy();
      });
    };

    _default.prototype.defaultSubject = function defaultSubject(options, factory) {
      return factory.create(options);
    };

    // allow arbitrary named factories, like rspec let

    _default.prototype.contextualizeCallbacks = function contextualizeCallbacks() {
      var callbacks = this.callbacks;
      var context = this.context;

      this.cache = this.cache || {};
      this.cachedCalls = this.cachedCalls || {};

      var keys = (Object.keys || _ember['default'].keys)(callbacks);
      var keysLength = keys.length;

      if (keysLength) {
        var deprecatedContext = this._buildDeprecatedContext(this, context);
        for (var i = 0; i < keysLength; i++) {
          this._contextualizeCallback(context, keys[i], deprecatedContext);
        }
      }
    };

    _default.prototype._contextualizeCallback = function _contextualizeCallback(context, key, callbackContext) {
      var _this = this;
      var callbacks = this.callbacks;
      var factory = context.factory;

      context[key] = function (options) {
        if (_this.cachedCalls[key]) {
          return _this.cache[key];
        }

        var result = callbacks[key].call(callbackContext, options, factory());

        _this.cache[key] = result;
        _this.cachedCalls[key] = true;

        return result;
      };
    };

    /*
      Builds a version of the passed in context that contains deprecation warnings
      for accessing properties that exist on the module.
    */

    _default.prototype._buildDeprecatedContext = function _buildDeprecatedContext(module, context) {
      var deprecatedContext = Object.create(context);

      var keysForDeprecation = Object.keys(module);

      for (var i = 0, l = keysForDeprecation.length; i < l; i++) {
        this._proxyDeprecation(module, deprecatedContext, keysForDeprecation[i]);
      }

      return deprecatedContext;
    };

    /*
      Defines a key on an object to act as a proxy for deprecating the original.
    */

    _default.prototype._proxyDeprecation = function _proxyDeprecation(obj, proxy, key) {
      if (typeof proxy[key] === 'undefined') {
        Object.defineProperty(proxy, key, {
          get: function get() {
            _ember['default'].deprecate('Accessing the test module property "' + key + '" from a callback is deprecated.', false, { id: 'ember-test-helpers.test-module.callback-context', until: '0.6.0' });
            return obj[key];
          }
        });
      }
    };

    _default.prototype._setupContainer = function _setupContainer(isolated) {
      var resolver = this.resolver;

      var items = _buildRegistry['default'](!isolated ? resolver : Object.create(resolver, {
        resolve: {
          value: function value() {}
        }
      }));

      this.container = items.container;
      this.registry = items.registry;

      if (_hasEmberVersion['default'](1, 13)) {
        var thingToRegisterWith = this.registry || this.container;
        var router = resolver.resolve('router:main');
        router = router || _ember['default'].Router.extend();
        thingToRegisterWith.register('router:main', router);
      }
    };

    _default.prototype._setupIsolatedContainer = function _setupIsolatedContainer() {
      var resolver = this.resolver;
      this._setupContainer(true);

      var thingToRegisterWith = this.registry || this.container;

      for (var i = this.needs.length; i > 0; i--) {
        var fullName = this.needs[i - 1];
        var normalizedFullName = resolver.normalize(fullName);
        thingToRegisterWith.register(fullName, resolver.resolve(normalizedFullName));
      }

      if (!this.registry) {
        this.container.resolver = function () {};
      }
    };

    _default.prototype._setupIntegratedContainer = function _setupIntegratedContainer() {
      this._setupContainer();
    };

    return _default;
  })(_abstractTestModule['default']);

  exports['default'] = _default;
});
define('ember-test-helpers/test-resolver', ['exports'], function (exports) {
  'use strict';

  exports.setResolver = setResolver;
  exports.getResolver = getResolver;
  var __resolver__;

  function setResolver(resolver) {
    __resolver__ = resolver;
  }

  function getResolver() {
    if (__resolver__ == null) {
      throw new Error('you must set a resolver with `testResolver.set(resolver)`');
    }

    return __resolver__;
  }
});
define('ember-test-helpers/wait', ['exports', 'ember'], function (exports, _ember) {
  /* globals self */

  'use strict';

  exports._teardownAJAXHooks = _teardownAJAXHooks;
  exports._setupAJAXHooks = _setupAJAXHooks;
  exports['default'] = wait;

  var jQuery = $;

  var requests;
  function incrementAjaxPendingRequests(_, xhr) {
    requests.push(xhr);
  }

  function decrementAjaxPendingRequests(_, xhr) {
    for (var i = 0; i < requests.length; i++) {
      if (xhr === requests[i]) {
        requests.splice(i, 1);
      }
    }
  }

  function _teardownAJAXHooks() {
    if (!jQuery) {
      return;
    }

    jQuery(document).off('ajaxSend', incrementAjaxPendingRequests);
    jQuery(document).off('ajaxComplete', decrementAjaxPendingRequests);
  }

  function _setupAJAXHooks() {
    requests = [];

    if (!jQuery) {
      return;
    }

    jQuery(document).on('ajaxSend', incrementAjaxPendingRequests);
    jQuery(document).on('ajaxComplete', decrementAjaxPendingRequests);
  }

  var _internalCheckWaiters;
  if (_ember['default'].__loader.registry['ember-testing/test/waiters']) {
    _internalCheckWaiters = _ember['default'].__loader.require('ember-testing/test/waiters').checkWaiters;
  }

  function checkWaiters() {
    if (_internalCheckWaiters) {
      return _internalCheckWaiters();
    } else if (_ember['default'].Test.waiters) {
      if (_ember['default'].Test.waiters.any(function (_ref) {
        var context = _ref[0];
        var callback = _ref[1];
        return !callback.call(context);
      })) {
        return true;
      }
    }

    return false;
  }

  function wait(_options) {
    var options = _options || {};
    var waitForTimers = options.hasOwnProperty('waitForTimers') ? options.waitForTimers : true;
    var waitForAJAX = options.hasOwnProperty('waitForAJAX') ? options.waitForAJAX : true;
    var waitForWaiters = options.hasOwnProperty('waitForWaiters') ? options.waitForWaiters : true;

    return new _ember['default'].RSVP.Promise(function (resolve) {
      var watcher = self.setInterval(function () {
        if (waitForTimers && (_ember['default'].run.hasScheduledTimers() || _ember['default'].run.currentRunLoop)) {
          return;
        }

        if (waitForAJAX && requests && requests.length > 0) {
          return;
        }

        if (waitForWaiters && checkWaiters()) {
          return;
        }

        // Stop polling
        self.clearInterval(watcher);

        // Synchronously resolve the promise
        _ember['default'].run(null, resolve);
      }, 10);
    });
  }
});
define("qunit", ["exports"], function (exports) {
  /* globals QUnit */

  "use strict";

  var _module = QUnit.module;
  exports.module = _module;
  var test = QUnit.test;
  exports.test = test;
  var skip = QUnit.skip;
  exports.skip = skip;
  var only = QUnit.only;
  exports.only = only;
  var todo = QUnit.todo;

  exports.todo = todo;
  exports["default"] = QUnit;
});
define("ember", ["exports"], function(__exports__) {
  __exports__["default"] = window.Ember;
});

var emberQUnit = requireModule("ember-qunit");

for (var exportName in emberQUnit) {
  window[exportName] = emberQUnit[exportName];
}

})();
//# sourceMappingURL=ember-qunit.map
