
/* Ways we can filter the topics list
*/


(function() {

  Discourse.buildRoutes(function() {
    var router;
    this.resource('topic', {
      path: '/t/:slug/:id'
    }, function() {
      this.route('fromParams', {
        path: '/'
      });
      this.route('fromParams', {
        path: '/:nearPost'
      });
      return this.route('bestOf', {
        path: '/best_of'
      });
    });
    /* Generate static page routes
    */

    router = this;
    Discourse.StaticController.pages.forEach(function(p) {
      return router.route(p, {
        path: "/" + p
      });
    });
    this.route('faq', {
      path: '/faq'
    });
    this.route('tos', {
      path: '/tos'
    });
    this.route('privacy', {
      path: '/privacy'
    });
    this.resource('list', {
      path: '/'
    }, function() {
      router = this;
      /* Generate routes for all our filters
      */

      Discourse.ListController.filters.forEach(function(r) {
        router.route(r, {
          path: "/" + r
        });
        return router.route(r, {
          path: "/" + r + "/more"
        });
      });
      router.route('popular', {
        path: '/'
      });
      router.route('categories', {
        path: '/categories'
      });
      router.route('category', {
        path: '/category/:slug/more'
      });
      return router.route('category', {
        path: '/category/:slug'
      });
    });
    return this.resource('user', {
      path: '/users/:username'
    }, function() {
      this.route('activity', {
        path: '/'
      });
      this.resource('preferences', {
        path: '/preferences'
      }, function() {
        this.route('username', {
          path: '/username'
        });
        return this.route('email', {
          path: '/email'
        });
      });
      this.route('privateMessages', {
        path: '/private-messages'
      });
      return this.route('invited', {
        path: 'invited'
      });
    });
  });

}).call(this);
