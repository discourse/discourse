/**
  This controller supports actions on the site header

  @class HeaderController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
export default Discourse.Controller.extend({
  topic: null,
  showExtraInfo: null,
  notifications: null,
  loading_notifications: null,

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

      if (self.get('currentUser.unread_notifications') || self.get('currentUser.unread_private_messages') || !self.get('notifications')) {
        self.set("loading_notifications", true);
        Discourse.ajax("/notifications").then(function(result) {
          self.setProperties({
            notifications: result,
            loading_notifications: false,
            'currentUser.unread_notifications': 0
          });
        });
      }
      headerView.showDropdownBySelector("#user-notifications");
    },

    jumpToTopPost: function () {
      var topic = this.get('topic');
      if (topic) {
        Discourse.URL.routeTo(topic.get('firstPostUrl'));
      }
    }
  }

});
