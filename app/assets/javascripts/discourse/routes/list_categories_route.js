/**
  The route for listing categories.

  @class ListCategoriesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoriesRoute = Discourse.Route.extend({

  model: function() {
    var listTopicsController = this.controllerFor('listTopics');
    if (listTopicsController) listTopicsController.set('content', null);

    return this.controllerFor('list').load('categories');
  },

  deactivate: function() {
    this._super();
    this.controllerFor('list').set('canCreateCategory', false);
  },

  setupController: function(controller, categoryList) {
    this.render('listCategories', { into: 'list', outlet: 'listView' });

    this.controllerFor('list').setProperties({
      canCreateCategory: categoryList.get('can_create_category'),
      canCreateTopic: categoryList.get('can_create_topic'),
      filterMode: 'categories',
      category: null
    });
  }

});


