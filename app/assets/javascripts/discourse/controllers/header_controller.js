/**
  This controller supports actions on the site header

  @class HeaderController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.HeaderController = Discourse.Controller.extend({
  topic: null,
  showExtraInfo: null,
  notifications: null,

  showStarButton: function() {
    return Discourse.User.current() && !this.get('topic.isPrivateMessage');
  }.property('topic.isPrivateMessage'),

  actions: {
    toggleStar: function() {
      var topic = this.get('topic');
      if (topic) topic.toggleStar();
      return false;
    },

    showNotifications: function(headerView) {
      var self = this;

      Discourse.ajax("/notifications").then(function(result) {
        self.set("notifications", result);
        self.set("currentUser.unread_notifications", 0);
        headerView.showDropdownBySelector("#user-notifications");
      });
    }
  }

});


