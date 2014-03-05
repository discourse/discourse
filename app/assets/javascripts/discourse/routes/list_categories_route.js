/**
  The route for listing categories.

  @class ListCategoriesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoriesRoute = Discourse.Route.extend({

  model: function() {
    this.controllerFor('listTop').set('content', null);
    this.controllerFor('listTopics').set('content', null);
    return this.controllerFor('list').load('categories');
  },

  activate: function() {
    this._super();
    this.controllerFor('list').setProperties({ filterMode: 'categories', category: null });
  },

  redirect: function() { Discourse.redirectIfLoginRequired(this); },

  afterModel: function(categoryList) {
    this.controllerFor('list').setProperties({
      canCreateCategory: categoryList.get('can_create_category'),
      canCreateTopic: categoryList.get('can_create_topic')
    });
  },

  renderTemplate: function() {
    this.render('listCategories', { into: 'list', outlet: 'listView' });
  },

  deactivate: function() {
    this._super();
    this.controllerFor('list').set('canCreateCategory', false);
  },

  actions: {
    createCategory: function() {
      Discourse.Route.showModal(this, 'editCategory', Discourse.Category.create({
        color: 'AB9364', text_color: 'FFFFFF', hotness: 5, group_permissions: [{group_name: 'everyone', permission_type: 1}],
        available_groups: Discourse.Site.current().group_names
      }));
      this.controllerFor('editCategory').set('selectedTab', 'general');
    }
  },

});
