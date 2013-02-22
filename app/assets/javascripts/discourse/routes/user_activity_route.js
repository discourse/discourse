/**
  This route handles shows a user's activity

  @class UserActivityRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityRoute = Discourse.Route.extend({

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller) {
    var userController = this.controllerFor('user');
    userController.set('filter', null);
    controller.set('content', userController.get('content'));
  }

});


