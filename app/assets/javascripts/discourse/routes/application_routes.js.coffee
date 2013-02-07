# Ways we can filter the topics list
Discourse.buildRoutes ->
  @resource 'topic', path: '/t/:slug/:id', ->
    @route 'fromParams', path: '/'
    @route 'fromParams', path: '/:nearPost'
    @route 'bestOf', path: '/best_of'

  # Generate static page routes
  router = @
  Discourse.StaticController.pages.forEach (p) -> router.route(p, path: "/#{p}")

  @route 'faq', path: '/faq'
  @route 'tos', path: '/tos'
  @route 'privacy', path: '/privacy'

  @resource 'list', path: '/', ->
    router = @
    # Generate routes for all our filters
    Discourse.ListController.filters.forEach (r) ->
      router.route(r, path: "/#{r}")
      router.route(r, path: "/#{r}/more")

    router.route 'popular', path: '/'
    router.route 'categories', path: '/categories'
    router.route 'category', path: '/category/:slug/more'
    router.route 'category', path: '/category/:slug'

  @resource 'user', path: '/users/:username', ->
    @route 'activity', path: '/'

    @resource 'preferences', path: '/preferences', ->
      @route 'username', path: '/username'
      @route 'email', path: '/email'
    @route 'privateMessages', path: '/private-messages'
    @route 'invited', path: 'invited'


