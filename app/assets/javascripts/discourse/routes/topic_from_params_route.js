/**
  This route is used for retrieving a topic based on params

  @class TopicFromParamsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicFromParamsRoute = Discourse.Route.extend({

  setupController: function(controller, params) {
    var topicController;
    params = params || {};
    params.trackVisit = true;
    topicController = this.controllerFor('topic');
    topicController.cancelFilter();
    this.modelFor('topic').loadPosts(params);
  }

});


