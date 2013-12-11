/**
  The route for listing categories.

  @class ListCategoriesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoriesRoute = Discourse.Route.extend({

  template: function() {
    // Remove the option to have 2-column layout on categories page.
    // TODO: remove this old code when we're sure about it.
    // return Discourse.SiteSettings.enable_wide_category_list ? 'listWideCategories' : 'listCategories';
    return 'listWideCategories';
  }.property(),

  redirect: function() { Discourse.redirectIfLoginRequired(this); },

  actions: {
    createCategory: function() {
      Discourse.Route.showModal(this, 'editCategory', Discourse.Category.create({
        color: 'AB9364', text_color: 'FFFFFF', hotness: 5, group_permissions: [{group_name: "everyone", permission_type: 1}],
        available_groups: Discourse.Site.current().group_names
      }));
      this.controllerFor('editCategory').set('selectedTab', 'general');
    }
  },

  model: function() {
    var listTopicsController = this.controllerFor('listTopics');
    if (listTopicsController) { listTopicsController.set('content', null); }
    return this.controllerFor('list').load('categories');
  },

  deactivate: function() {
    this._super();
    this.controllerFor('list').set('canCreateCategory', false);
  },

  renderTemplate: function() {
    this.render(this.get('template'), { into: 'list', outlet: 'listView' });
  },

  afterModel: function(categoryList) {
    this.controllerFor('list').setProperties({
      canCreateCategory: categoryList.get('can_create_category'),
      canCreateTopic: categoryList.get('can_create_topic')
    });
  },

  activate: function() {
    this.controllerFor('list').setProperties({
      filterMode: 'categories',
      category: null
    });
  }

});


