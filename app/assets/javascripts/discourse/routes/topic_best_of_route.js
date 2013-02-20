(function() {

  window.Discourse.TopicBestOfRoute = Discourse.Route.extend({
    setupController: function(controller, params) {
      var topicController;
      params = params || {};
      params.trackVisit = true;
      params.bestOf = true;
      topicController = this.controllerFor('topic');
      topicController.cancelFilter();
      topicController.set('bestOf', true);
      return this.modelFor('topic').loadPosts(params);
    }
  });

}).call(this);
