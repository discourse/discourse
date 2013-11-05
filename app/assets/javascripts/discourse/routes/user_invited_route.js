/**
  This route shows who a user has invited

  @class UserInvitedRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserInvitedRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    return Discourse.Invite.findInvitedBy(this.modelFor('user'));
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      user: this.controllerFor('user').get('model'),
      searchTerm: ''
    });
    this.controllerFor('user').set('indexStream', false);
  }

});