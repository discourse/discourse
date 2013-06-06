/**
  A base view that gives us common functionality, for example `present` and `blank`

  @class View
  @extends Ember.View
  @uses Discourse.Presence
  @namespace Discourse
  @module Discourse
**/
Discourse.View = Ember.View.extend(Discourse.Presence, {});

Discourse.View.reopenClass({

  /**
    Register a view helper for ease of use

    @method registerHElper
    @param {String} helperName the name of the helper
    @param {Ember.View} helperClass the view that will be inserted by the helper
  **/
  registerHelper: function(helperName, helperClass) {
    Ember.Handlebars.registerHelper(helperName, function(options) {
      var hash = options.hash,
          types = options.hashTypes;

      Discourse.Utilities.normalizeHash(hash, types);
      return Ember.Handlebars.helpers.view.call(this, helperClass, options);
    });
  }

})
