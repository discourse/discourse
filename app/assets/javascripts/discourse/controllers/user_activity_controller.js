/**
  This controller supports all actions on a user's activity stream

  @class UserActivityController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityController = Discourse.ObjectController.extend({
  needs: ['composer'],

  kickOffPrivateMessage: (function() {
    if (this.get('content.openPrivateMessage')) {
      this.composePrivateMessage();
    }
  }).observes('content.openPrivateMessage'),

  composePrivateMessage: function() {
    return this.get('controllers.composer').open({
      action: Discourse.Composer.PRIVATE_MESSAGE,
      usernames: this.get('content.user.username'),
      archetypeId: 'private_message',
      draftKey: 'new_private_message'
    });
  }
});
