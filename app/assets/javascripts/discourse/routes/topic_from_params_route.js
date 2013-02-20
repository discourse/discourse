(function() {

  window.Discourse.TopicFromParamsRoute = Discourse.Route.extend({
    setupController: function(controller, params) {
      var topicController;
      params = params || {};
      params.trackVisit = true;
      topicController = this.controllerFor('topic');
      topicController.cancelFilter();
      return this.modelFor('topic').loadPosts(params);
    }
  });

}).call(this);
