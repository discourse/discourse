/**
  This controller handles actions related to a user's private messages.

  @class UserPrivateMessagesController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesController = Discourse.ObjectController.extend({
  needs: ['composer'],

  composePrivateMessage: function() {
    this.get('controllers.composer').open({
      action: Discourse.Composer.PRIVATE_MESSAGE,
      archetypeId: 'private_message',
      draftKey: 'new_private_message'
    });
  }

});
