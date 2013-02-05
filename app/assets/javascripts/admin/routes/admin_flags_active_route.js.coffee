Discourse.AdminFlagsActiveRoute = Discourse.Route.extend
  model: -> Discourse.FlaggedPost.findAll('active')
  setupController: (controller, model) ->
    c = @controllerFor('adminFlags')
    c.set('content', model)
    c.set('query', 'active')