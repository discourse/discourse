Discourse.buildRoutes ->
  @resource 'admin', path: '/admin', ->
    @route 'dashboard', path: '/'
    @route 'site_settings', path: '/site_settings'
    @route 'email_logs', path: '/email_logs'
    @route 'customize', path: '/customize'

    @resource 'adminFlags', path: '/flags', ->
      @route 'active', path: '/active'
      @route 'old', path: '/old'

    @resource 'adminUsers', path: '/users', ->
      @resource 'adminUser', path: '/:username'
      @resource 'adminUsersList', path: '/list', ->
        @route 'active', path: '/active'
        @route 'new', path: '/new'
        @route 'pending', path: '/pending'
