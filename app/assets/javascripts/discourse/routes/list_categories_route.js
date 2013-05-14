/**
  The route for listing categories.

  @class ListCategoriesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoriesRoute = Discourse.Route.extend({

  exit: function() {
    this._super();
    this.controllerFor('list').set('canCreateCategory', false);
  },

  setupController: function(controller) {
    var listController,
      _this = this;
    listController = this.controllerFor('list');
    listController.set('filterMode', 'categories');
    listController.load('categories').then(function(categoryList) {
      _this.render('listCategories', {
        into: 'list',
        outlet: 'listView',
        controller: 'listCategories'
      });
      listController.set('canCreateCategory', categoryList.get('can_create_category'));
      listController.set('canCreateTopic', categoryList.get('can_create_topic'));
      listController.set('category', null);
      _this.controllerFor('listCategories').set('content', categoryList);
    });
  }

});


