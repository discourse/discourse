Discourse.UserPrivateMessagesController = Ember.ObjectController.extend

  editPreferences: ->
    Discourse.routeTo("/users/#{@get('content.username_lower')}/preferences")

  composePrivateMessage: ->
    composerController = Discourse.get('router.composerController')
    composerController.open
      action: Discourse.Composer.PRIVATE_MESSAGE
      archetypeId: 'private_message'
      draftKey: 'new_private_message'
