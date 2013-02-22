/**
  This route is used when a topic's "best of" filter is applied

  @class TopicBestOfRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicBestOfRoute = Discourse.Route.extend({

  setupController: function(controller, params) {
    var topicController;
    params = params || {};
    params.trackVisit = true;
    params.bestOf = true;
    topicController = this.controllerFor('topic');
    topicController.cancelFilter();
    topicController.set('bestOf', true);
    this.modelFor('topic').loadPosts(params);
  }

});


