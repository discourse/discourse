/**
  This view handles rendering of a user's activity stream

  @class UserActivityView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityView = Discourse.View.extend({
  userBinding: 'controller.content',

  didInsertElement: function() {
    window.scrollTo(0, 0);
  }

});


