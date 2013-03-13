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

  setupController: function(controller) {
    Discourse.InviteList.findInvitedBy(this.controllerFor('user').get('content')).then(function(invited) {
      controller.set('content', invited);
    });
  }

});


