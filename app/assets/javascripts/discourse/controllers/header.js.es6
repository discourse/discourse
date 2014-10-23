import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  topic: null,
  showExtraInfo: null,
  notifications: null,
  loadingNotifications: false,
  needs: ['application'],

  loginRequired: Em.computed.alias('controllers.application.loginRequired'),
  canSignUp: Em.computed.alias('controllers.application.canSignUp'),

  hasCategory: function() {
    var cat = this.get('topic.category');
    return cat &&
           !cat.get('isUncategorizedCategory') ||
           !this.siteSettings.suppress_uncategorized_badge;
  }.property('topic.category'),

  showPrivateMessageGlyph: function() {
    return !this.get('topic.is_warning') && this.get('topic.isPrivateMessage');
  }.property('topic.is_warning', 'topic.isPrivateMessage'),

  showSignUpButton: function() {
    return this.get('canSignUp') && !this.get('showExtraInfo');
  }.property('canSignUp', 'showExtraInfo'),

  showStarButton: function() {
    return Discourse.User.current() && !this.get('topic.isPrivateMessage');
  }.property('topic.isPrivateMessage'),

  _resetCachedNotifications: function(){
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
    if (self.get("loadingNotifications")) { return; }

    self.set("loadingNotifications", true);
    Discourse.NotificationContainer.loadRecent().then(function(result) {
      self.setProperties({
        'currentUser.unread_notifications': 0,
        notifications: result
      });
    }).catch(function() {
      self.setProperties({
        notifications: null
      });
    }).finally(function() {
      self.set("loadingNotifications", false);
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
