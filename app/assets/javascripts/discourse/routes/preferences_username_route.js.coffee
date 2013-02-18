window.Discourse.PreferencesUsernameRoute = Discourse.RestrictedUserRoute.extend
  renderTemplate: ->
    @render into: 'user', outlet: 'userOutlet'
  setupController: (controller) ->
    user = @controllerFor('user').get('content')
    controller.set('content', user)
    controller.set('newUsername', user.get('username'))
