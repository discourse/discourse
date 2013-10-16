/**
  This view handles rendering of a user including the navigational menu

  @class UserView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.UserView = Discourse.View.extend({
  templateName: 'user/user',
  userBinding: 'controller.content',

  updateTitle: function() {
    var username;
    username = this.get('user.username');
    if (username) {
      return Discourse.set('title', "" + (I18n.t("user.profile")) + " - " + username);
    }
  }.observes('user.loaded', 'user.username'),

  didInsertElement: function() {
    window.scrollTo(0, 0);
  }

});


