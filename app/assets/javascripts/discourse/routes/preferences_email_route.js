(function() {

  window.Discourse.PreferencesEmailRoute = Discourse.RestrictedUserRoute.extend({
    renderTemplate: function() {
      return this.render({
        into: 'user',
        outlet: 'userOutlet'
      });
    },
    setupController: function(controller) {
      return controller.set('content', this.controllerFor('user').get('content'));
    }
  });

}).call(this);
