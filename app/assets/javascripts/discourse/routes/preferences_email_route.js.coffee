window.Discourse.PreferencesEmailRoute = Discourse.Route.extend
  renderTemplate: ->
    @render into: 'user', outlet: 'userOutlet'
  setupController: (controller) ->
    controller.set('content', @controllerFor('user').get('content'))