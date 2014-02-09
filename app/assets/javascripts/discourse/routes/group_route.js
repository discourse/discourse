/**
  The base route for a group

  @class GroupRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.GroupRoute = Discourse.Route.extend({

  model: function(params) {
    return Discourse.Group.find(params.name);
  },

});
