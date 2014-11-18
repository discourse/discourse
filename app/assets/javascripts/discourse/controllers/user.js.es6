import ObjectController from 'discourse/controllers/object';
import CanCheckEmails from 'discourse/mixins/can-check-emails';

export default ObjectController.extend(CanCheckEmails, {
  indexStream: true,
  needs: ['user-notifications', 'user_topics_list'],

  viewingSelf: function() {
    return this.get('content.username') === Discourse.User.currentProp('username');
  }.property('content.username'),

  collapsedInfo: Em.computed.not('indexStream'),

  websiteName: function() {
    var website = this.get('website');
    if (Em.isEmpty(website)) { return; }
    return this.get('website').split("/")[2];
  }.property('website'),

  linkWebsite: Em.computed.not('isBasic'),

  canSeePrivateMessages: function() {
    return this.get('viewingSelf') || Discourse.User.currentProp('admin');
  }.property('viewingSelf'),

  canSeeNotificationHistory: Em.computed.alias('canSeePrivateMessages'),

  showBadges: function() {
    return Discourse.SiteSettings.enable_badges && (this.get('content.badge_count') > 0);
  }.property('content.badge_count'),

  privateMessageView: function() {
    return (this.get('userActionType') === Discourse.UserAction.TYPES.messages_sent) ||
           (this.get('userActionType') === Discourse.UserAction.TYPES.messages_received);
  }.property('userActionType'),

  canInviteToForum: function() {
    return Discourse.User.currentProp('can_invite_to_forum');
  }.property(),

  canDeleteUser: function() {
    return this.get('can_be_deleted') && this.get('can_delete_all_posts');
  }.property('can_be_deleted', 'can_delete_all_posts'),

  loadedAllItems: function() {
    switch (this.get("datasource")) {
      case "badges": { return true; }
      case "notifications": { return !this.get("controllers.user-notifications.canLoadMore"); }
      case "topic_list": { return !this.get("controllers.user_topics_list.canLoadMore"); }
      case "stream": {
        if (this.get("userActionType")) {
          var stat = _.find(this.get("stats"), { action_type: this.get("userActionType") });
          return stat && stat.count <= this.get("stream.itemsLoaded");
        } else {
          return this.get("statsCountNonPM") <= this.get("stream.itemsLoaded");
        }
      }
    }

    return false;
  }.property("datasource",
    "userActionType", "stats", "stream.itemsLoaded",
    "controllers.user_topics_list.canLoadMore",
    "controllers.user-notifications.canLoadMore"),

  privateMessagesActive: Em.computed.equal('pmView', 'index'),
  privateMessagesMineActive: Em.computed.equal('pmView', 'mine'),
  privateMessagesUnreadActive: Em.computed.equal('pmView', 'unread'),

  actions: {
    adminDelete: function() {
      Discourse.AdminUser.find(this.get('username').toLowerCase()).then(function(user){
        user.destroy({deletePosts: true});
      });
    }
  }
});
