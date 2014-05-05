/* global requirejs, require */
/**
  A custom resolver to allow template names in the format we like.

  @class Resolver
  @extends Ember.DefaultResolver
  @namespace Discourse
  @module Discourse
**/
Discourse.Resolver = Ember.DefaultResolver.extend({

  /**
    For our ES6 modules, Discourse standardizes on dashed, lower case names.
    This method converts camelCase to that format.

    @method normalizeName
    @param {String} name to convert
    @returns {String} the converted name

  **/
  normalizeName: function(name) {
    return name.replace(/([a-z])([A-Z])/g, '$1-$2').replace('_', '-').toLowerCase();
  },

  resolveController: function(parsedName) {
    var normalized = this.normalizeName(parsedName.fullNameWithoutType),
        moduleName = "discourse/controllers/" + normalized,
        module = requirejs.entries[moduleName];

    if (module) {
      if (normalized !== parsedName.fullNameWithoutType) {
        Em.Logger.error(parsedName.fullNameWithoutType + " was used to look up an ES6 module. You should use " + normalized+ " instead.");
      }

      module = require(moduleName, null, null, true /* force sync */);
      if (module && module['default']) { module = module['default']; }
    }
    return module || this._super(parsedName);
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
