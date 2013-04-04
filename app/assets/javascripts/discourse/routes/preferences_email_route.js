/**
  The route for editing a user's email

  @class PreferencesEmailRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesEmailRoute = Discourse.RestrictedUserRoute.extend({

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  exit: function() {
    this._super();
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


