/* global requirejs, require */
/**
  A custom resolver to allow template names in the format we like.

  @class Resolver
  @extends Ember.DefaultResolver
  @namespace Discourse
  @module Discourse
**/

var classify = Ember.String.classify;
var get = Ember.get;

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

Discourse.Resolver = Ember.DefaultResolver.extend({

  parseName: parseName,

  normalize: function(fullName) {
    var split = fullName.split(':');
    if (split.length > 1) {
      var dashed = Ember.String.dasherize(split[1].replace(/\./g, '/')),
          moduleName = 'discourse/' + split[0] + 's/' + dashed;
      if (requirejs.entries[moduleName]) {
        return split[0] + ":" + dashed;
      }
    }
    return this._super(fullName);
  },

  customResolve: function(parsedName) {
    // If we end with the name we want, use it. This allows us to define components within plugins.
    var suffix = parsedName.type + 's/' + parsedName.fullNameWithoutType,
        moduleName = Ember.keys(requirejs.entries).find(function(e) {
          return e.indexOf(suffix, e.length - suffix.length) !== -1;
        });

    var module;
    if (moduleName) {
      module = require(moduleName, null, null, true /* force sync */);
      if (module && module['default']) { module = module['default']; }
    }
    return module;
  },

  resolveView: function(parsedName) {
    return this.customResolve(parsedName) || this._super(parsedName);
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
    return this.customResolve(parsedName) || this._super(parsedName);
  },

  /**
    Attaches a view and wires up the container properly

    @method resolveTemplate
    @param {String} parsedName the name of the template we want to resolve
    @returns {Template} the template (if found)
  **/
  resolveTemplate: function(parsedName) {
    return this.findPluginTemplate(parsedName) ||
           this.findMobileTemplate(parsedName) ||
           this.findTemplate(parsedName) ||
           Ember.TEMPLATES.not_found;
  },

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
    return this._super(parsedName) || this.findSlashedTemplate(parsedName) || this.findAdminTemplate(parsedName);
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
      return Ember.TEMPLATES[decamelized];
    }
  }

});
