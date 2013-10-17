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
    this.route('fromParamsNear', { path: '/:nearPost' });
  });

  // Generate static page routes
  Discourse.StaticController.pages.forEach(function(p) {
    router.route(p, { path: "/" + p });
  });

  // List routes
  this.resource('list', { path: '/' }, function() {
    router = this;

    // Generate routes for all our filters
    Discourse.ListController.filters.forEach(function(filter) {
      router.route(filter, { path: "/" + filter });
      router.route(filter, { path: "/" + filter + "/more" });
    });

    // the homepage is the first item of the 'top_menu' site setting
    var settings = Discourse.SiteSettings;
    var homepage = settings.top_menu.split("|")[0].split(",")[0];
    this.route(homepage, { path: '/' });

    this.route('categories', { path: '/categories' });
    this.route('category', { path: '/category/:slug/more' });
    this.route('category', { path: '/category/:slug' });
  });

  // User routes
  this.resource('user', { path: '/users/:username' }, function() {
    this.route('index', { path: '/'} );

    this.resource('userActivity', { path: '/activity' }, function() {
      var resource = this;
      Object.keys(Discourse.UserAction.TYPES).forEach(function (userAction) {
        resource.route(userAction, { path: userAction.replace("_", "-") });
      });
    });

    this.resource('userPrivateMessages', { path: '/private-messages' }, function() {
      this.route('mine', {path: '/mine'});
      this.route('unread', {path: '/unread'});
    });

    this.resource('preferences', { path: '/preferences' }, function() {
      this.route('username', { path: '/username' });
      this.route('email', { path: '/email' });
      this.route('about', { path: '/about-me' });
      this.route('avatar', { path: '/avatar' });
    });

    this.route('invited', { path: 'invited' });
  });
});
