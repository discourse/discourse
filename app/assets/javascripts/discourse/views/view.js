/**
  A base view that gives us common functionality, for example `present` and `blank`

  @class View
  @extends Ember.View
  @uses Discourse.Presence
  @namespace Discourse
  @module Discourse
**/
Discourse.View = Ember.View.extend(Discourse.Presence, {});

Discourse.GroupedView = Ember.View.extend(Discourse.Presence, {
  init: function() {
    this._super();
    this.set('context', this.get('content'));

    var templateData = this.get('templateData');
    if (templateData) {
      this.set('templateData.insideGroup', true);
    }
  }
});



Discourse.View.reopenClass({

  /**
    Register a view helper for ease of use

    @method registerHelper
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
  },

  /**
    Returns an observer that will re-render if properties change. This is useful for
    views where rendering is done to a buffer manually and need to know when to trigger
    a new render call.

    @method renderIfChanged
    @params {String} propertyNames*
    @return {Function} observer
  **/
  renderIfChanged: function() {
    var args = Array.prototype.slice.call(arguments, 0);
    args.unshift(function () { this.rerender(); });
    return Ember.observer.apply(this, args);
  }

});
