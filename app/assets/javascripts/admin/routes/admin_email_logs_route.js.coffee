Discourse.AdminEmailLogsRoute = Discourse.Route.extend
  model: -> Discourse.EmailLog.findAll()
