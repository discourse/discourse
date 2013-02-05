window.Discourse.UserInvitedRoute = Discourse.Route.extend
  renderTemplate: ->
    @render into: 'user', outlet: 'userOutlet'

  setupController: (controller) ->
    Discourse.InviteList.findInvitedBy(@controllerFor('user').get('content')).then (invited) =>
      controller.set('content', invited)