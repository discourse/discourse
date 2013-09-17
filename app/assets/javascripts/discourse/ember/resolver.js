/**
  A custom resolver to allow template names in the format we like.

  @class Resolver
  @extends Ember.DefaultResolver
  @namespace Discourse
  @module Discourse
**/
Discourse.Resolver = Ember.DefaultResolver.extend({

  /**
    Attaches a view and wires up the container properly

    @method resolveTemplate
    @param {String} parsedName the name of the template we want to resolve
    @returns {Template} the template (if found)
  **/
  resolveTemplate: function(parsedName) {
    if (Discourse.Mobile.mobileView) {
      var mobileParsedName = this.parseName(parsedName.fullName.replace("template:", "template:mobile/"));
      var mobileTemplate = this.findTemplate(mobileParsedName);
      if (mobileTemplate) return mobileTemplate;
    }
    return this.findTemplate(parsedName) || Ember.TEMPLATES.not_found;
  },

  findTemplate: function(parsedName) {
    var resolvedTemplate = this._super(parsedName);
    if (resolvedTemplate) { return resolvedTemplate; }

    var decamelized = parsedName.fullNameWithoutType.decamelize();

    // See if we can find it with slashes instead of underscores
    var slashed = decamelized.replace("_", "/");
    resolvedTemplate = Ember.TEMPLATES[slashed];
    if (resolvedTemplate) { return resolvedTemplate; }

    // If we can't find a template, check to see if it's similar to how discourse
    // lays out templates like: adminEmail => admin/templates/email
    if (parsedName.fullNameWithoutType.indexOf('admin') === 0) {
      decamelized = decamelized.replace(/^admin\_/, 'admin/templates/');
      decamelized = decamelized.replace(/^admin\./, 'admin/templates/');
      decamelized = decamelized.replace(/\./, '_');

      resolvedTemplate = Ember.TEMPLATES[decamelized];
      if (resolvedTemplate) { return resolvedTemplate; }
    }
  }

});