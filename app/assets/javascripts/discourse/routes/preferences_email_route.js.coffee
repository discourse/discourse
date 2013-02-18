window.Discourse.PreferencesEmailRoute = Discourse.RestrictedUserRoute.extend
  renderTemplate: ->
    @render into: 'user', outlet: 'userOutlet'
  setupController: (controller) ->
    controller.set('content', @controllerFor('user').get('content'))
