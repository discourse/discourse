/**
  This controller handles actions related to a user's invitations

  @class UserInvitedController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserInvitedController = Discourse.ObjectController.extend({

  actions: {
    rescind: function(invite) {
      invite.rescind();
      return false;
    }
  }

});


