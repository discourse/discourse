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

  afterModel: function(model) {
    var self = this;
    return Discourse.Group.findPostsCount(model.get('name')).then(function (c) {
      self.set('postsCount', c);
    });
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      postsCount: this.get('postsCount')
    });
  }
});
