Discourse.AdminFlagsOldRoute = Discourse.Route.extend
  model: -> Discourse.FlaggedPost.findAll('old')
  setupController: (controller, model) ->
    c = @controllerFor('adminFlags')
    c.set('content', model)
    c.set('query', 'old')