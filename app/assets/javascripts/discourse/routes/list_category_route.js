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
        categorySlug = Discourse.Category.slugFor(category),
        self = this,
        filter = this.filter || "latest",
        url = "category/" + categorySlug + "/l/" + filter;

    listController.set('filterMode', url);
    listController.load(url).then(function(topicList) {
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
    this.controllerFor('search').set('searchContext', this.modelFor(this.get('routeName')).get('searchContext'));
  },

  deactivate: function() {
    this._super();

    // Clear the search context
    this.controllerFor('search').set('searchContext', null);
  }


});


Discourse.ListController.filters.forEach(function(filter) {
  Discourse["List" + (filter.capitalize()) + "CategoryRoute"] = Discourse.ListCategoryRoute.extend({ filter: filter });
});


