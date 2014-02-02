/**
  This view handles the rendering of the top lists

  @class DiscoveryTopView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopView = Discourse.View.extend({

  didInsertElement: function() {
    this._super();
    Em.run.schedule('afterRender', function() {
      $('document').scrollTop(0);
    });
  },

});
