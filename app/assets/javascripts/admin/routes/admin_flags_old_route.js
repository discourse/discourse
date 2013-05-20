/**
  Handles routes related to viewing old flags.

  @class AdminFlagsOldRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminFlagsOldRoute = Discourse.Route.extend({

  setupController: function(controller, model) {
    var adminFlagsController = this.controllerFor('adminFlags');
    adminFlagsController.set('content', Discourse.FlaggedPost.findAll('old'));
    adminFlagsController.set('query', 'old');
  }

});


