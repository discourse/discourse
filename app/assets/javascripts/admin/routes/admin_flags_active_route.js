/**
  Handles routes related to viewing active flags.

  @class AdminFlagsActiveRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminFlagsActiveRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.FlaggedPost.findAll('active');
  },

  setupController: function(controller, model) {
    var adminFlagsController = this.controllerFor('adminFlags');
    adminFlagsController.set('content', model);
    adminFlagsController.set('query', 'active');
  }

});


