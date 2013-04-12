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
    var user = userController.get('content');
    controller.set('content', user);
    user.set('filter', null);
    if (user.get('streamFilter')) {
      user.filterStream(null);
    }
  }

});


