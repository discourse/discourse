Discourse.UserInvitedController = Ember.ObjectController.extend

  rescind: (invite) ->
    invite.rescind()
    false