/**
  Handles routes related to viewing old flags.

  @class AdminFlagsOldRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminFlagsOldRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.FlaggedPost.findAll('old');
  },

  setupController: function(controller, model) {
    var adminFlagsController = this.controllerFor('adminFlags');
    adminFlagsController.set('content', model);
    adminFlagsController.set('query', 'old');
  }

});


