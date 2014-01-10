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
      router.route(filter + "Category", { path: "/category/:slug/l/" + filter });
      router.route(filter + "Category", { path: "/category/:slug/l/" + filter + "/more" });
      router.route(filter + "Category", { path: "/category/:parentSlug/:slug/l/" + filter });
      router.route(filter + "Category", { path: "/category/:parentSlug/:slug/l/" + filter + "/more" });
    });

    // homepage
    var homepage = Discourse.User.current() ?
                   Discourse.User.currentProp("homepage") :
                   Discourse.Utilities.defaultHomepage();
    this.route(homepage, { path: '/' });

    // categories page
    this.route('categories', { path: '/categories' });

    // category
    this.route('category', { path: '/category/:slug' });
    this.route('category', { path: '/category/:slug/more' });
    this.route('categoryNone', { path: '/category/:slug/none' });
    this.route('categoryNone', { path: '/category/:slug/none/more' });
    this.route('category', { path: '/category/:parentSlug/:slug' });
    this.route('category', { path: '/category/:parentSlug/:slug/more' });

    // top page
    this.route('top', { path: '/top' });
  });

  // User routes
  this.resource('user', { path: '/users/:username' }, function() {
    this.route('index', { path: '/'} );

    this.resource('userActivity', { path: '/activity' }, function() {
      var self = this;
      Object.keys(Discourse.UserAction.TYPES).forEach(function (userAction) {
        self.route(userAction, { path: userAction.replace("_", "-") });
      });
    });

    this.resource('userPrivateMessages', { path: '/private-messages' }, function() {
      this.route('mine', { path: '/mine' });
      this.route('unread', { path: '/unread' });
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
