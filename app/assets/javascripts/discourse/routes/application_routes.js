/**
  Builds the routes for the application

  @method buildRoutes
  @for Discourse.ApplicationRoute
**/
Discourse.Route.buildRoutes(function() {
  var router = this;

  // Topic routes
  this.resource('topic', { path: '/t/:slug/:id' }, function() {
    this.route('fromParams', { path: '/' });
    this.route('fromParams', { path: '/:nearPost' });
    this.route('bestOf', { path: '/best_of' });
  });

  // Generate static page routes
  Discourse.StaticController.pages.forEach(function(p) {
    router.route(p, { path: "/" + p });
  });

  this.route('faq', { path: '/faq' });
  this.route('tos', { path: '/tos' });
  this.route('privacy', { path: '/privacy' });

  // List routes
  this.resource('list', { path: '/' }, function() {
    router = this;

    // Generate routes for all our filters
    Discourse.ListController.filters.forEach(function(r) {
      router.route(r, { path: "/" + r });
      router.route(r, { path: "/" + r + "/more" });
    });

    this.route('popular', { path: '/' });
    this.route('categories', { path: '/categories' });
    this.route('category', { path: '/category/:slug/more' });
    this.route('category', { path: '/category/:slug' });
  });

  // User routes
  this.resource('user', { path: '/users/:username' }, function() {
    this.route('activity', { path: '/' });
    this.resource('preferences', { path: '/preferences' }, function() {
      this.route('username', { path: '/username' });
      this.route('email', { path: '/email' });
    });
    this.route('privateMessages', { path: '/private-messages' });
    this.route('invited', { path: 'invited' });
  });
});


