/**
  This route is used when listing a particular category's topics

  @class ListCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoryRoute = Discourse.FilteredListRoute.extend({

  model: function(params) {
    return Discourse.Category.findBySlug(Em.get(params, 'slug'), Em.get(params, 'parentSlug'));
  },

  setupController: function(controller, category) {
    var listTopicsController = this.controllerFor('listTopics');
    if (listTopicsController) {
      var listContent = listTopicsController.get('content');
      if (listContent) {
        listContent.set('loaded', false);
      }
    }

    var listController = this.controllerFor('list'),
        urlId = Discourse.Category.slugFor(category),
        self = this;

    listController.set('filterMode', "category/" + urlId);
    listController.load("category/" + urlId).then(function(topicList) {
      listController.setProperties({
        canCreateTopic: topicList.get('can_create_topic'),
        category: category
      });
      self.controllerFor('listTopics').set('content', topicList);
      self.controllerFor('listTopics').set('category', category);
    });
  },

  activate: function() {
    this._super();

    // Add a search context
    this.controllerFor('search').set('searchContext', this.modelFor('listCategory').get('searchContext'));
  },

  deactivate: function() {
    this._super();

    // Clear the search context
    this.controllerFor('search').set('searchContext', null);
  }


});


