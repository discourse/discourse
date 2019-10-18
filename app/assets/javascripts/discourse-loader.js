var define, requirejs;

(function() {
  // In future versions of ember we don't need this
  var EMBER_MODULES = {};
  if (typeof Ember !== "undefined") {
    EMBER_MODULES = {
      "@ember/component": { default: Ember.Component },
      "@ember/routing/route": { default: Ember.Route }
    };
  }

  var _isArray;
  if (!Array.isArray) {
    _isArray = function(x) {
      return Object.prototype.toString.call(x) === "[object Array]";
    };
  } else {
    _isArray = Array.isArray;
  }

  var registry = {};
  var seen = {};
  var FAILED = false;

  var uuid = 0;

  function tryFinally(tryable, finalizer) {
    try {
      return tryable();
    } finally {
      finalizer();
    }
  }

  function unsupportedModule(length) {
    throw new Error(
      "an unsupported module was defined, expected `define(name, deps, module)` instead got: `" +
        length +
        "` arguments to define`"
    );
  }

  var defaultDeps = ["require", "exports", "module"];

  function Module(name, deps, callback, exports) {
    this.id = uuid++;
    this.name = name;
    this.deps = !deps.length && callback.length ? defaultDeps : deps;
    this.exports = exports || {};
    this.callback = callback;
    this.state = undefined;
    this._require = undefined;
  }

  Module.prototype.makeRequire = function() {
    var name = this.name;

    return (
      this._require ||
      (this._require = function(dep) {
        return requirejs(resolve(dep, name));
      })
    );
  };

  define = function(name, deps, callback) {
    if (arguments.length < 2) {
      unsupportedModule(arguments.length);
    }

    if (!_isArray(deps)) {
      callback = deps;
      deps = [];
    }

    registry[name] = new Module(name, deps, callback);
  };

  // we don't support all of AMD
  // define.amd = {};
  // we will support petals...
  define.petal = {};

  function Alias(path) {
    this.name = path;
  }

  define.alias = function(path) {
    return new Alias(path);
  };

  function reify(mod, name, rseen) {
    var deps = mod.deps;
    var length = deps.length;
    var reified = new Array(length);
    var dep;
    // TODO: new Module
    // TODO: seen refactor
    var module = {};

    for (var i = 0, l = length; i < l; i++) {
      dep = deps[i];
      if (dep === "exports") {
        module.exports = reified[i] = rseen;
      } else if (dep === "require") {
        reified[i] = mod.makeRequire();
      } else if (dep === "module") {
        mod.exports = rseen;
        module = reified[i] = mod;
      } else {
        reified[i] = requireFrom(resolve(dep, name), name);
      }
    }

    return {
      deps: reified,
      module: module
    };
  }

  function requireFrom(name, origin) {
    var mod = EMBER_MODULES[name] || registry[name];
    if (!mod) {
      throw new Error(
        "Could not find module `" + name + "` imported from `" + origin + "`"
      );
    }
    return requirejs(name);
  }

  function missingModule(name) {
    throw new Error("Could not find module " + name);
  }

  requirejs = require = function(name) {
    if (EMBER_MODULES[name]) {
      return EMBER_MODULES[name];
    }

    var mod = registry[name];

    if (mod && mod.callback instanceof Alias) {
      mod = registry[mod.callback.name];
    }

    if (!mod) {
      missingModule(name);
    }

    if (mod.state !== FAILED && seen.hasOwnProperty(name)) {
      return seen[name];
    }

    var reified;
    var module;
    var loaded = false;

    seen[name] = {}; // placeholder for run-time cycles

    tryFinally(
      function() {
        reified = reify(mod, name, seen[name]);
        module = mod.callback.apply(this, reified.deps);
        loaded = true;
      },
      function() {
        if (!loaded) {
          mod.state = FAILED;
        }
      }
    );

    var obj;
    if (module === undefined && reified.module.exports) {
      obj = reified.module.exports;
    } else {
      obj = seen[name] = module;
    }

    if (
      obj !== null &&
      (typeof obj === "object" || typeof obj === "function") &&
      obj["default"] === undefined
    ) {
      obj["default"] = obj;
    }

    return (seen[name] = obj);
  };
  window.requireModule = requirejs;

  function resolve(child, name) {
    if (child.charAt(0) !== ".") {
      return child;
    }

    var parts = child.split("/");
    var nameParts = name.split("/");
    var parentBase = nameParts.slice(0, -1);

    for (var i = 0, l = parts.length; i < l; i++) {
      var part = parts[i];

      if (part === "..") {
        if (parentBase.length === 0) {
          throw new Error("Cannot access parent module of root");
        }
        parentBase.pop();
      } else if (part === ".") {
        continue;
      } else {
        parentBase.push(part);
      }
    }

    return parentBase.join("/");
  }

  requirejs.entries = requirejs._eak_seen = registry;
  requirejs.clear = function() {
    requirejs.entries = requirejs._eak_seen = registry = {};
    seen = {};
  };
})();
