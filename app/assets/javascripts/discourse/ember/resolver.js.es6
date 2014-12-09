/* global requirejs, require */

var classify = Ember.String.classify;
var get = Ember.get;

var LOADING_WHITELIST = ['badges', 'userActivity', 'userPrivateMessages', 'admin', 'adminFlags',
                         'user', 'preferences', 'adminEmail', 'adminUsersList'],
    _dummyRoute,
    _loadingView;

function loadingResolver(cb) {
  return function(parsedName) {
    var fullNameWithoutType = parsedName.fullNameWithoutType;

    if (fullNameWithoutType.indexOf('Loading') >= 0) {
      fullNameWithoutType = fullNameWithoutType.replace('Loading', '');
      if (LOADING_WHITELIST.indexOf(fullNameWithoutType) !== -1) {
        return cb(fullNameWithoutType);
      }
    }
  };
}

function parseName(fullName) {
  /*jshint validthis:true */

  var nameParts = fullName.split(":"),
      type = nameParts[0], fullNameWithoutType = nameParts[1],
      name = fullNameWithoutType,
      namespace = get(this, 'namespace'),
      root = namespace;

  return {
    fullName: fullName,
    type: type,
    fullNameWithoutType: fullNameWithoutType,
    name: name,
    root: root,
    resolveMethodName: "resolve" + classify(type)
  };
}

export default Ember.DefaultResolver.extend({

  parseName: parseName,

  normalize: function(fullName) {
    var split = fullName.split(':');
    if (split.length > 1) {
      var discourseBase = 'discourse/' + split[0] + 's/';
      var adminBase = 'admin/' + split[0] + 's/';

      // Allow render 'admin/templates/xyz' too
      split[1] = split[1].replace('.templates', '').replace('/templates', '');

      // Try slashes
      var dashed = Ember.String.dasherize(split[1].replace(/\./g, '/'));
      if (requirejs.entries[discourseBase + dashed] || requirejs.entries[adminBase + dashed]) {
        return split[0] + ":" + dashed;
      }

      // Try with dashes instead of slashes
      dashed = Ember.String.dasherize(split[1].replace(/\./g, '-'));
      if (requirejs.entries[discourseBase + dashed] || requirejs.entries[adminBase + dashed]) {
        return split[0] + ":" + dashed;
      }
    }
    return this._super(fullName);
  },

  customResolve: function(parsedName) {
    // If we end with the name we want, use it. This allows us to define components within plugins.
    var suffix = parsedName.type + 's/' + parsedName.fullNameWithoutType,
        dashed = Ember.String.dasherize(suffix),
        moduleName = Ember.keys(requirejs.entries).find(function(e) {
          return (e.indexOf(suffix, e.length - suffix.length) !== -1) ||
                 (e.indexOf(dashed, e.length - dashed.length) !== -1);
        });

    var module;
    if (moduleName) {
      module = require(moduleName, null, null, true /* force sync */);
      if (module && module['default']) { module = module['default']; }
    }
    return module;
  },

  resolveView: function(parsedName) {
    return this.findLoadingView(parsedName) || this.customResolve(parsedName) || this._super(parsedName);
  },

  resolveHelper: function(parsedName) {
    return this.customResolve(parsedName) || this._super(parsedName);
  },

  resolveController: function(parsedName) {
    return this.customResolve(parsedName) || this._super(parsedName);
  },

  resolveComponent: function(parsedName) {
    return this.customResolve(parsedName) || this._super(parsedName);
  },

  resolveRoute: function(parsedName) {
    return this.findLoadingRoute(parsedName) || this.customResolve(parsedName) || this._super(parsedName);
  },

  resolveTemplate: function(parsedName) {
    return this.findPluginTemplate(parsedName) ||
           this.findMobileTemplate(parsedName) ||
           this.findTemplate(parsedName) ||
           Ember.TEMPLATES.not_found;
  },

  findLoadingRoute: loadingResolver(function() {
    _dummyRoute = _dummyRoute || Ember.Route.extend();
    return _dummyRoute;
  }),

  findLoadingView: loadingResolver(function() {
    if (!_loadingView) {
      _loadingView = require('discourse/views/loading', null, null, true /* force sync */);
      if (_loadingView && _loadingView['default']) { _loadingView = _loadingView['default']; }
    }
    return _loadingView;
  }),

  findPluginTemplate: function(parsedName) {
    var pluginParsedName = this.parseName(parsedName.fullName.replace("template:", "template:javascripts/"));
    return this.findTemplate(pluginParsedName);
  },

  findMobileTemplate: function(parsedName) {
    if (Discourse.Mobile.mobileView) {
      var mobileParsedName = this.parseName(parsedName.fullName.replace("template:", "template:mobile/"));
      return this.findTemplate(mobileParsedName);
    }
  },

  findTemplate: function(parsedName) {
    return this._super(parsedName) || this.findSlashedTemplate(parsedName) || this.findAdminTemplate(parsedName) || this.findUnderscoredTemplate(parsedName);
  },

  findUnderscoredTemplate: function(parsedName) {
    var decamelized = parsedName.fullNameWithoutType.decamelize();
    var underscored = decamelized.replace(/\-/g, "_");
    return Ember.TEMPLATES[underscored];
  },

  // Try to find a template with slash instead of first underscore, e.g. foo_bar_baz => foo/bar_baz
  findSlashedTemplate: function(parsedName) {
    var decamelized = parsedName.fullNameWithoutType.decamelize();
    var slashed = decamelized.replace("_", "/");
    return Ember.TEMPLATES[slashed];
  },

  // Try to find a template within a special admin namespace, e.g. adminEmail => admin/templates/email
  // (similar to how discourse lays out templates)
  findAdminTemplate: function(parsedName) {
    var decamelized = parsedName.fullNameWithoutType.decamelize();
    if (decamelized.indexOf('admin') === 0) {
      decamelized = decamelized.replace(/^admin\_/, 'admin/templates/');
      decamelized = decamelized.replace(/^admin\./, 'admin/templates/');
      decamelized = decamelized.replace(/\./, '_');
      var dashed = decamelized.replace(/_/g, '-');
      return Ember.TEMPLATES[decamelized] || Ember.TEMPLATES[dashed];
    }
  }

});
