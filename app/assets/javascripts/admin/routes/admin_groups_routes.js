/**
  Handles routes for admin groups

  @class AdminGroupsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminGroupsRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.Group.findAll();
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    controller.set('aliasLevelOptions', Discourse.Group.aliasLevelOptions());
  }

});

