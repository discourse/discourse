(function() {

  window.Discourse.ApplicationRoute = Discourse.Route.extend({
    setupController: function(controller) {
      var currentUser;
      Discourse.set('site', Discourse.Site.create(PreloadStore.getStatic('site')));
      currentUser = PreloadStore.getStatic('currentUser');
      if (currentUser) {
        return Discourse.set('currentUser', Discourse.User.create(currentUser));
      }
    }
  });

}).call(this);
