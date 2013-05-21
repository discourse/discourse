/**
  Handles routes related to viewing active flags.

  @class AdminFlagsActiveRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminFlagsActiveRoute = Discourse.Route.extend({

  setupController: function() {
    var adminFlagsController = this.controllerFor('adminFlags');
    adminFlagsController.set('content', Discourse.FlaggedPost.findAll('active'));
    adminFlagsController.set('query', 'active');
  }

});


