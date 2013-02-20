(function() {

  window.Discourse.TopicRoute = Discourse.Route.extend({
    model: function(params) {
      var currentModel, _ref;
      if (currentModel = (_ref = this.controllerFor('topic')) ? _ref.get('content') : void 0) {
        if (currentModel.get('id') === parseInt(params.id, 10)) {
          return currentModel;
        }
      }
      return Discourse.Topic.create(params);
    },
    enter: function() {
      return Discourse.set('transient.lastTopicIdViewed', parseInt(this.modelFor('topic').get('id'), 10));
    },
    exit: function() {
      var headerController, topicController;
      topicController = this.controllerFor('topic');
      topicController.cancelFilter();
      topicController.set('multiSelect', false);
      if (headerController = this.controllerFor('header')) {
        headerController.set('topic', null);
        return headerController.set('showExtraInfo', false);
      }
    },
    setupController: function(controller, model) {
      var headerController;
      controller.set('showExtraHeaderInfo', false);
      headerController = this.controllerFor('header');
      headerController.set('topic', model);
    }
  });

}).call(this);
