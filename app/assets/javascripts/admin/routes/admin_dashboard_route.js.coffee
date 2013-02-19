Discourse.AdminDashboardRoute = Discourse.Route.extend
  setupController: (c) ->
    Discourse.VersionCheck.find().then (vc) ->
      # Loading finished!
      c.set('versionCheck', vc)
      c.set('loading', false)
