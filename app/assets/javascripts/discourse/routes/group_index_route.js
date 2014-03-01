/**
  The route for the index of a Group

  @class GroupIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.GroupIndexRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('group').findPosts();
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    this.controllerFor('group').set('showing', 'index');
  }
});
