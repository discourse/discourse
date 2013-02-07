window.Discourse.UserRoute = Discourse.Route.extend
  model: (params) -> Discourse.User.find(params.username)
  serialize: (params) -> username: Em.get(params, 'username').toLowerCase()
