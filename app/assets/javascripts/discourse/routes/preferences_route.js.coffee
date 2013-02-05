window.Discourse.PreferencesRoute = Discourse.Route.extend
  renderTemplate: ->
    @render 'preferences', into: 'user', outlet: 'userOutlet', controller: 'preferences'

  setupController: (controller) ->
    controller.set('content', @controllerFor('user').get('content'))