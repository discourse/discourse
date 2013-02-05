Discourse.AdminSiteSettingsRoute = Discourse.Route.extend
  model: -> Discourse.SiteSetting.findAll()
