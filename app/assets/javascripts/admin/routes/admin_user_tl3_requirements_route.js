/**
  Shows all the requirements for being at trust level 3 and if the
  given user is meeting them.

  @class AdminUserLeaderRequirementsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUserTl3RequirementsRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('adminUser');
  }
});
