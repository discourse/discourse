/**
  The common route stuff for a user's preference

  @class PreferencesRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesRoute = Discourse.RestrictedUserRoute.extend({

  renderTemplate: function() {
    this.render('preferences', {
      into: 'user',
      outlet: 'userOutlet',
      controller: 'preferences'
    });
  },

  setupController: function(controller) {
    controller.set('content', this.controllerFor('user').get('content'));
  }

});
