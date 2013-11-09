/**
  This controller handles general user actions

  @class UserController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserController = Discourse.ObjectController.extend({

  viewingSelf: function() {
    return this.get('content.username') === Discourse.User.currentProp('username');
  }.property('content.username'),

  collapsedInfo: Em.computed.not('indexStream'),

  canSeePrivateMessages: function() {
    return this.get('viewingSelf') || Discourse.User.currentProp('staff');
  }.property('viewingSelf'),

  privateMessageView: function() {
    return (this.get('userActionType') === Discourse.UserAction.TYPES.messages_sent) ||
           (this.get('userActionType') === Discourse.UserAction.TYPES.messages_received);
  }.property('userActionType'),

  privateMessagesActive: Em.computed.equal('pmView', 'index'),
  privateMessagesMineActive: Em.computed.equal('pmView', 'mine'),
  privateMessagesUnreadActive: Em.computed.equal('pmView', 'unread')

});


