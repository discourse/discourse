/**
  This controller supports all actions on a user's activity stream

  @class UserActivityController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityController = Discourse.ObjectController.extend({
  needs: ['composer'],

  privateMessageView: function() {
    return (this.get('userActionType') === Discourse.UserAction.TYPES.messages_sent) ||
           (this.get('userActionType') === Discourse.UserAction.TYPES.messages_received);
  }.property('userActionType'),

  composePrivateMessage: function() {
    return this.get('controllers.composer').open({
      action: Discourse.Composer.PRIVATE_MESSAGE,
      usernames: this.get('model.username'),
      archetypeId: 'private_message',
      draftKey: 'new_private_message'
    });
  },

  privateMessagesActive: Em.computed.equal('pmView', 'index'),
  privateMessagesMineActive: Em.computed.equal('pmView', 'mine'),
  privateMessagesUnreadActive: Em.computed.equal('pmView', 'unread')
});
