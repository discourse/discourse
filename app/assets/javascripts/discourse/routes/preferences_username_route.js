/**
  The route for updating a user's username

  @class PreferencesUsernameRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesUsernameRoute = Discourse.RestrictedUserRoute.extend({

  renderTemplate: function() {
    return this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller) {
    var user = this.controllerFor('user').get('content');
    controller.set('content', user);
    return controller.set('newUsername', user.get('username'));
  }

});


