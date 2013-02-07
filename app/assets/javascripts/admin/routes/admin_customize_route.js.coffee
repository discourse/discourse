Discourse.AdminCustomizeRoute = Discourse.Route.extend
  model: -> Discourse.SiteCustomization.findAll()
