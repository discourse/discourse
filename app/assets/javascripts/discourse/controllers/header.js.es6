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

  resetCachedNotifications: function(){
    // a bit hacky, but if we have no focus, hide notifications first
    var visible = $("#notifications-dropdown").is(":visible");

    if(!Discourse.get("hasFocus")) {
      if(visible){
        $("html").click();
      }
      this.set("notifications", null);
      return;
    }
    if(visible){
      this.refreshNotifications();
    } else {
      this.set("notifications", null);
    }
  }.observes("currentUser.lastNotificationChange"),

  refreshNotifications: function(){
    var self = this;

    if(self.get("loading_notifications")){return;}

    self.set("loading_notifications", true);
    Discourse.ajax("/notifications").then(function(result) {
      self.set('currentUser.unread_notifications', 0);
      self.setProperties({
        notifications: result,
        loading_notifications: false
      });
    }, function(){
      self.set("loading_notifications", false);
    });
  },

  actions: {
    toggleStar: function() {
      var topic = this.get('topic');
      if (topic) topic.toggleStar();
      return false;
    },

    showNotifications: function(headerView) {
      var self = this;

      if (self.get('currentUser.unread_notifications') || self.get('currentUser.unread_private_messages') || !self.get('notifications')) {
        self.refreshNotifications();
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
