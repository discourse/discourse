Discourse.AdminUserRoute = Discourse.Route.extend
  model: (params) -> Discourse.AdminUser.find(params.username)
