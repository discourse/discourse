/**
  Builds the routes for the admin section

  @method buildRoutes
  @for Discourse.AdminRoute
**/
Discourse.Route.buildRoutes(function() {
  this.resource('admin', { path: '/admin' }, function() {
    this.route('dashboard', { path: '/' });
    this.route('site_settings', { path: '/site_settings' });


    this.resource('adminSiteContents', { path: '/site_contents' }, function() {
      this.resource('adminSiteContentEdit', {path: '/:content_type'});
    });

    this.route('email_logs', { path: '/email_logs' });
    this.route('customize', { path: '/customize' });
    this.route('api', {path: '/api'});

    this.resource('adminReports', { path: '/reports/:type' });

    this.resource('adminFlags', { path: '/flags' }, function() {
      this.route('active', { path: '/active' });
      this.route('old', { path: '/old' });
    });

    this.route('groups', {path: '/groups'});

    this.resource('adminUsers', { path: '/users' }, function() {
      this.resource('adminUser', { path: '/:username' });
      this.resource('adminUsersList', { path: '/list' }, function() {
        this.route('active', { path: '/active' });
        this.route('new', { path: '/new' });
        this.route('pending', { path: '/pending' });
        this.route('admins', { path: '/admins' });
        this.route('moderators', { path: '/moderators' });
        // Trust Levels:
        this.route('newuser', { path: '/newuser' });
        this.route('basic', { path: '/basic' });
        this.route('regular', { path: '/regular' });
        this.route('leaders', { path: '/leaders' });
        this.route('elders', { path: '/elders' });
      });
    });

  });
});


