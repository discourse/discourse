window.Discourse.UserPrivateMessagesRoute = Discourse.Route.extend
  renderTemplate: ->
    @render into: 'user', outlet: 'userOutlet'
  setupController: (controller, user) ->
    user = @controllerFor('user').get('content')
    controller.set('content', user)
    user.filterStream(13)
    
    Discourse.Draft.get('new_private_message').then (data)=>
      if data.draft
        @controllerFor('composer').open
          draft: data.draft
          draftKey: 'new_private_message'
          ignoreIfChanged: true
          draftSequence: data.draft_sequence
