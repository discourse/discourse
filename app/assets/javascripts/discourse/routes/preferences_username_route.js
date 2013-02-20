(function() {

  window.Discourse.PreferencesUsernameRoute = Discourse.RestrictedUserRoute.extend({
    renderTemplate: function() {
      return this.render({
        into: 'user',
        outlet: 'userOutlet'
      });
    },
    setupController: function(controller) {
      var user;
      user = this.controllerFor('user').get('content');
      controller.set('content', user);
      return controller.set('newUsername', user.get('username'));
    }
  });

}).call(this);
