/**
  This mixin will cause a view to scroll the viewport to the top once it has been inserted

  @class Discourse.ScrollTop
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.ScrollTop = Em.Mixin.create({

  _scrollTop: function() {
    Em.run.schedule('afterRender', function() {
      $(document).scrollTop(0);
    });
  }.on('didInsertElement')
});

