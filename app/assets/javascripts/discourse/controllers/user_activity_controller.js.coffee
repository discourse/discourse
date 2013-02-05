Discourse.UserActivityController = Ember.ObjectController.extend

  needs: ['composer']

  kickOffPrivateMessage: ( ->
    if @get('content.openPrivateMessage')
      @composePrivateMessage()
  ).observes('content.openPrivateMessage')

  composePrivateMessage: ->
    @get('controllers.composer').open
      action: Discourse.Composer.PRIVATE_MESSAGE
      usernames: @get('content').username
      archetypeId: 'private_message'
      draftKey: 'new_private_message'
