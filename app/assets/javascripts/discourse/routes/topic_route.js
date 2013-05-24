/**
  This route handles requests for topics

  @class TopicRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicRoute = Discourse.Route.extend({

  model: function(params) {
    var currentModel, _ref;
    if (currentModel = (_ref = this.controllerFor('topic')) ? _ref.get('content') : void 0) {
      if (currentModel.get('id') === parseInt(params.id, 10)) {
        return currentModel;
      }
    }
    return Discourse.Topic.create(params);
  },

  activate: function() {
    this._super();

    var topic = this.modelFor('topic');
    Discourse.set('transient.lastTopicIdViewed', parseInt(topic.get('id'), 10));

    // Set the search context
    this.controllerFor('search').set('searchContext', topic.get('searchContext'));
  },

  deactivate: function() {
    this._super();

    // Clear the search context
    this.controllerFor('search').set('searchContext', null);

    var headerController, topicController;
    topicController = this.controllerFor('topic');
    topicController.cancelFilter();
    topicController.set('multiSelect', false);
    this.controllerFor('composer').set('topic', null);

    if (headerController = this.controllerFor('header')) {
      headerController.set('topic', null);
      headerController.set('showExtraInfo', false);
    }
  },

  setupController: function(controller, model) {
    this.controllerFor('header').set('topic', model);
    this.controllerFor('composer').set('topic', model);
  }

});


