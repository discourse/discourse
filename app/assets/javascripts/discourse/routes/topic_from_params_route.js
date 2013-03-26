/**
  This route is used for retrieving a topic based on params

  @class TopicFromParamsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicFromParamsRoute = Discourse.Route.extend({

  setupController: function(controller, params) {
    params = params || {};
    params.trackVisit = true;

    var topicController = this.controllerFor('topic');
    topicController.cancelFilter();
    topicController.loadPosts(params);
  }

});


