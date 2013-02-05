window.Discourse.ApplicationRoute = Discourse.Route.extend
  setupController: (controller) ->
    Discourse.set('site', Discourse.Site.create(PreloadStore.getStatic('site')))
    currentUser = PreloadStore.getStatic('currentUser')
    Discourse.set('currentUser', Discourse.User.create(currentUser)) if currentUser