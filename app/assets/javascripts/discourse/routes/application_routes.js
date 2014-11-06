/**
  Builds the routes for the application

  @method buildRoutes
  @for Discourse.ApplicationRoute
**/
Discourse.Route.buildRoutes(function() {
  var router = this;

  // Error page
  this.route('exception', { path: '/exception' });

  this.resource('about', { path: '/about' });

  // Topic routes
  this.resource('topic', { path: '/t/:slug/:id' }, function() {
    this.route('fromParams', { path: '/' });
    this.route('fromParamsNear', { path: '/:nearPost' });
  });
  this.resource('topicBySlug', { path: '/t/:slug' });

  this.resource('discovery', { path: '/' }, function() {
    router = this;
    // top
    this.route('top');
    this.route('topCategory', { path: '/c/:slug/l/top' });
    this.route('topCategoryNone', { path: '/c/:slug/none/l/top' });
    this.route('topCategory', { path: '/c/:parentSlug/:slug/l/top' });

    // top by periods
    Discourse.Site.currentProp('periods').forEach(function(period) {
      var top = 'top' + period.capitalize();
      router.route(top, { path: '/top/' + period });
      router.route(top + 'Category', { path: '/c/:slug/l/top/' + period });
      router.route(top + 'CategoryNone', { path: '/c/:slug/none/l/top/' + period });
      router.route(top + 'Category', { path: '/c/:parentSlug/:slug/l/top/' + period });
    });

    // filters
    Discourse.Site.currentProp('filters').forEach(function(filter) {
      router.route(filter, { path: '/' + filter });
      router.route(filter + 'Category', { path: '/c/:slug/l/' + filter });
      router.route(filter + 'CategoryNone', { path: '/c/:slug/none/l/' + filter });
      router.route(filter + 'Category', { path: '/c/:parentSlug/:slug/l/' + filter });
    });

    this.route('categories');

    // default filter for a category
    this.route('parentCategory', { path: '/c/:slug' });
    this.route('categoryNone', { path: '/c/:slug/none' });
    this.route('category', { path: '/c/:parentSlug/:slug' });


    // homepage
    this.route(Discourse.Utilities.defaultHomepage(), { path: '/' });
  });

  this.resource('group', { path: '/groups/:name' }, function() {
    this.route('members');
  });

  // User routes
  this.resource('user', { path: '/users/:username' }, function() {
    this.resource('userActivity', { path: '/activity' }, function() {
      router = this;
      _.map(Discourse.UserAction.TYPES, function (id, userAction) {
        router.route(userAction, { path: userAction.replace('_', '-') });
      });
    });

    this.route('badges');
    this.route('notifications');
    this.route('flaggedPosts', { path: '/flagged-posts' });
    this.route('deletedPosts', { path: '/deleted-posts' });

    this.resource('userPrivateMessages', { path: '/private-messages' }, function() {
      this.route('mine');
      this.route('unread');
    });

    this.resource('preferences', function() {
      this.route('username');
      this.route('email');
      this.route('about', { path: '/about-me' });
      this.route('badgeTitle', { path: '/badge_title' });
      this.route('card-badge', { path: '/card-badge' });
    });

    this.route('invited');
  });

  this.route('signup', {path: '/signup'});
  this.route('login', {path: '/login'});
  this.route('faq', {path: '/faq'});
  this.route('tos', {path: '/tos'});
  this.route('privacy', {path: '/privacy'});
  this.route('guidelines', {path: '/guidelines'});

  this.resource('badges', function() {
    this.route('show', {path: '/:id/:slug'});
  });
});
