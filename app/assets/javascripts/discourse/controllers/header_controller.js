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
  notifications: Ember.computed.alias('currentUser.recent_notifications'),

  showStarButton: function() {
    return this.get('currentUser') && !this.get('topic.isPrivateMessage');
  }.property('topic.isPrivateMessage'),

  actions: {
    toggleStar: function() {
      var topic = this.get('topic');
      if (topic) topic.toggleStar();
      return false;
    },

    showNotifications: function(headerView) {
      headerView.showDropdownBySelector("#user-notifications");
      this.set("currentUser.unread_notifications", 0);

      var notifications = this.get('notifications');
      if ( notifications && notifications.length > 0 ) {

        var last_notification = _.max(notifications, function (notification) {
          return notification.id;
        });
        Discourse.ajax("/users/" + this.get("currentUser.id") + "/saw_notification", {
          type: 'PUT',
          data: { last_notification_id: last_notification.id }
        });
      }
      return false;
    }
  }

});


