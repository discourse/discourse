window.Discourse.UserActivityRoute = Discourse.Route.extend
  renderTemplate: ->
    @render into: 'user', outlet: 'userOutlet'

  setupController: (controller) ->
    userController = @controllerFor('user')
    userController.set('filter', null) # clear filter
    controller.set('content', userController.get('content'))