/**
  This view handles the rendering of the top lists

  @class ListTopView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ListTopView = Discourse.View.extend({

  didInsertElement: function() {
    this._super();
    Em.run.schedule('afterRender', function() {
      $('html, body').scrollTop(0);
    });
  },

});
