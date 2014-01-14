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
  _.each(Discourse.StaticController.PAGES, function (page) {
    router.route(page, { path: '/' + page });
  });

  this.resource('discovery', { path: '/' }, function() {

    router = this;
    
    // top
    this.route('top');
    this.route('topCategory', { path: '/category/:slug/l/top' });
    this.route('topCategoryNone', { path: '/category/:slug/none/l/top' });
    this.route('topCategory', { path: '/category/:parentSlug/:slug/l/top' });

    // top by periods
    Discourse.Site.currentProp('periods').forEach(function(period) {
      var top = 'top' + period.capitalize();
      router.route(top, { path: '/top/' + period });
      router.route(top, { path: '/top/' + period + '/more' });
      router.route(top + 'Category', { path: '/category/:slug/l/top/' + period });
      router.route(top + 'Category', { path: '/category/:slug/l/top/' + period + '/more' });
      router.route(top + 'CategoryNone', { path: '/category/:slug/none/l/top/' + period });
      router.route(top + 'CategoryNone', { path: '/category/:slug/none/l/top/' + period + '/more' });
      router.route(top + 'Category', { path: '/category/:parentSlug/:slug/l/top/' + period });
      router.route(top + 'Category', { path: '/category/:parentSlug/:slug/l/top/' + period + '/more' });
    });

    Discourse.Site.currentProp('filters').forEach(function(filter) {
      router.route(filter, { path: '/' + filter });
      router.route(filter, { path: '/' + filter + '/more' });
      router.route(filter + 'Category', { path: '/category/:slug/l/' + filter });
      router.route(filter + 'Category', { path: '/category/:slug/l/' + filter + '/more' });
      router.route(filter + 'CategoryNone', { path: '/category/:slug/none/l/' + filter });
      router.route(filter + 'CategoryNone', { path: '/category/:slug/none/l/' + filter + '/more' });
      router.route(filter + 'Category', { path: '/category/:parentSlug/:slug/l/' + filter });
      router.route(filter + 'Category', { path: '/category/:parentSlug/:slug/l/' + filter + '/more' });
    });

    this.route('categories');

    // default filter for a category
    this.route('category', { path: '/category/:slug' });
    this.route('category', { path: '/category/:slug/more' });
    this.route('categoryNone', { path: '/category/:slug/none' });
    this.route('categoryNone', { path: '/category/:slug/none/more' });
    this.route('category', { path: '/category/:parentSlug/:slug' });

    // homepage
    var homepage = Discourse.User.current() ? Discourse.User.currentProp('homepage') : Discourse.Utilities.defaultHomepage();
    this.route(homepage, { path: '/' });
  });

  // User routes
  this.resource('user', { path: '/users/:username' }, function() {
    this.resource('userActivity', { path: '/activity' }, function() {
      router = this;
      _.map(Discourse.UserAction.TYPES, function (id, userAction) {
        router.route(userAction, { path: userAction.replace('_', '-') });
      });
    });

    this.resource('userPrivateMessages', { path: '/private-messages' }, function() {
      this.route('mine');
      this.route('unread');
    });

    this.resource('preferences', function() {
      this.route('username');
      this.route('email');
      this.route('about', { path: '/about-me' });
    });

    this.route('invited');
  });
});
