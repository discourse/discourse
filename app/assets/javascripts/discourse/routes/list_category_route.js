/**
  This route is used when listing a particular category's topics

  @class ListCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoryRoute = Discourse.FilteredListRoute.extend({

  model: function(params) {
    var categories = Discourse.Category.list();

    var slug = Em.get(params, 'slug');

    var uncategorized = Discourse.Category.uncategorizedInstance();
    if (slug === uncategorized.get('slug')) return uncategorized;

    var category = categories.findProperty('slug', Em.get(params, 'slug'))

    // In case the slug didn't work, try to find it by id instead.
    if (!category) {
      category = categories.findProperty('id', parseInt(slug, 10));
    }

    return category;
  },

  setupController: function(controller, category) {
    var listTopicsController = this.controllerFor('listTopics');
    if (listTopicsController) {
      var listContent = listTopicsController.get('content');
      if (listContent) {
        listContent.set('loaded', false);
      }
    }

    var listController = this.controllerFor('list');
    var urlId = Discourse.Category.slugFor(category);
    listController.set('filterMode', "category/" + urlId);

    var router = this;
    listController.load("category/" + urlId).then(function(topicList) {
      listController.set('canCreateTopic', topicList.get('can_create_topic'));
      listController.set('category', category);
      router.controllerFor('listTopics').set('content', topicList);
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


