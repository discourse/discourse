/**
  This controller handles general user actions

  @class UserController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
export default Discourse.ObjectController.extend({

  viewingSelf: function() {
    return this.get('content.username') === Discourse.User.currentProp('username');
  }.property('content.username'),

  collapsedInfo: Em.computed.not('indexStream'),

  canSeePrivateMessages: function() {
    return this.get('viewingSelf') || Discourse.User.currentProp('admin');
  }.property('viewingSelf'),

  showBadges: function() {
    return Discourse.SiteSettings.enable_badges && (this.get('content.badge_count') > 0);
  }.property('content.badge_count'),

  privateMessageView: function() {
    return (this.get('userActionType') === Discourse.UserAction.TYPES.messages_sent) ||
           (this.get('userActionType') === Discourse.UserAction.TYPES.messages_received);
  }.property('userActionType'),

  /**
    Can the currently logged in user invite users to the site

    @property canInviteToForum
  **/
  canInviteToForum: function() {
    return Discourse.User.currentProp('can_invite_to_forum');
  }.property(),

  privateMessagesActive: Em.computed.equal('pmView', 'index'),
  privateMessagesMineActive: Em.computed.equal('pmView', 'mine'),
  privateMessagesUnreadActive: Em.computed.equal('pmView', 'unread')

});
