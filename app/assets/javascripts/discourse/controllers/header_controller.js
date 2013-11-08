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

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  showFavoriteButton: function() {
    return Discourse.User.current() && !this.get('topic.isPrivateMessage');
  }.property('topic.isPrivateMessage'),

  mobileDevice: function() {
    return Discourse.Mobile.isMobileDevice;
  }.property(),

  mobileView: function() {
    return Discourse.Mobile.mobileView;
  }.property(),

  showMobileToggle: function() {
    return Discourse.SiteSettings.enable_mobile_theme;
  }.property(),

  actions: {
    toggleStar: function() {
      var topic = this.get('topic');
      if (topic) topic.toggleStar();
      return false;
    },

    toggleMobileView: function() {
      Discourse.Mobile.toggleMobileView();
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


