(function() {

  window.Discourse.PreferencesRoute = Discourse.RestrictedUserRoute.extend({
    renderTemplate: function() {
      return this.render('preferences', {
        into: 'user',
        outlet: 'userOutlet',
        controller: 'preferences'
      });
    },
    setupController: function(controller) {
      return controller.set('content', this.controllerFor('user').get('content'));
    }
  });

}).call(this);
